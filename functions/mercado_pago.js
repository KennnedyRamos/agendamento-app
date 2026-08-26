const crypto = require('crypto');
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

const MP_SECRET_NAMES = [
  'MP_CLIENT_ID',
  'MP_CLIENT_SECRET',
  'MP_REDIRECT_URI',
  'MP_WEBHOOK_URL',
  'MP_WEBHOOK_SECRET',
  'MP_TOKEN_ENCRYPTION_KEY',
  'MP_MARKETPLACE_FEE_PERCENT',
  'MP_USE_SANDBOX',
];

const MP_API_URL = 'https://api.mercadopago.com';
const CHECKOUT_TTL_MINUTES = 30;

function db() {
  return admin.firestore();
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value || !String(value).trim()) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Configuracao obrigatoria ausente: ${name}.`
    );
  }
  return String(value).trim();
}

function encryptionKey() {
  const encoded = requireEnv('MP_TOKEN_ENCRYPTION_KEY');
  const key = Buffer.from(encoded, 'base64');
  if (key.length !== 32) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'MP_TOKEN_ENCRYPTION_KEY deve conter 32 bytes codificados em base64.'
    );
  }
  return key;
}

function encrypt(value) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey(), iv);
  const encrypted = Buffer.concat([
    cipher.update(String(value), 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [iv, tag, encrypted].map((part) => part.toString('base64url')).join('.');
}

function decrypt(value) {
  const [ivPart, tagPart, encryptedPart] = String(value).split('.');
  if (!ivPart || !tagPart || !encryptedPart) {
    throw new Error('Token criptografado invalido.');
  }
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    encryptionKey(),
    Buffer.from(ivPart, 'base64url')
  );
  decipher.setAuthTag(Buffer.from(tagPart, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(encryptedPart, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}

function toHttpsError(error, fallbackMessage) {
  if (error instanceof functions.https.HttpsError) return error;
  console.error(fallbackMessage, error);
  return new functions.https.HttpsError('internal', fallbackMessage);
}

async function mercadoPagoRequest(path, options = {}) {
  const response = await fetch(`${MP_API_URL}${path}`, {
    method: options.method || 'GET',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options.accessToken
        ? { Authorization: `Bearer ${options.accessToken}` }
        : {}),
      ...(options.idempotencyKey
        ? { 'X-Idempotency-Key': options.idempotencyKey }
        : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const rawBody = await response.text();
  let parsedBody = {};
  if (rawBody) {
    try {
      parsedBody = JSON.parse(rawBody);
    } catch (_) {
      parsedBody = { message: rawBody };
    }
  }
  if (!response.ok) {
    const error = new Error(
      parsedBody.message || `Mercado Pago respondeu HTTP ${response.status}.`
    );
    error.status = response.status;
    error.details = parsedBody;
    throw error;
  }
  return parsedBody;
}

async function exchangeAuthorizationCode({ code, codeVerifier }) {
  return mercadoPagoRequest('/oauth/token', {
    method: 'POST',
    body: {
      client_id: requireEnv('MP_CLIENT_ID'),
      client_secret: requireEnv('MP_CLIENT_SECRET'),
      grant_type: 'authorization_code',
      code,
      redirect_uri: requireEnv('MP_REDIRECT_URI'),
      code_verifier: codeVerifier,
      test_token: process.env.MP_USE_SANDBOX === 'true',
    },
  });
}

async function refreshSellerToken(accountRef, accountData) {
  const refreshed = await mercadoPagoRequest('/oauth/token', {
    method: 'POST',
    body: {
      client_id: requireEnv('MP_CLIENT_ID'),
      client_secret: requireEnv('MP_CLIENT_SECRET'),
      grant_type: 'refresh_token',
      refresh_token: decrypt(accountData.refreshTokenEncrypted),
    },
  });
  const expiresAt = Date.now() + Number(refreshed.expires_in || 0) * 1000;
  await accountRef.update({
    accessTokenEncrypted: encrypt(refreshed.access_token),
    refreshTokenEncrypted: encrypt(
      refreshed.refresh_token || decrypt(accountData.refreshTokenEncrypted)
    ),
    expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return refreshed.access_token;
}

async function sellerAccessToken(sellerId) {
  const accountRef = db().collection('payment_accounts').doc(sellerId);
  const accountSnap = await accountRef.get();
  if (!accountSnap.exists) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A barbearia ainda nao conectou uma conta Mercado Pago.'
    );
  }
  const accountData = accountSnap.data();
  const expiresAt = accountData.expiresAt?.toMillis?.() || 0;
  if (expiresAt <= Date.now() + 5 * 60 * 1000) {
    return refreshSellerToken(accountRef, accountData);
  }
  return decrypt(accountData.accessTokenEncrypted);
}

async function assertBarbershopOwner(uid) {
  const shopRef = db().collection('barbershops').doc(uid);
  const shopSnap = await shopRef.get();
  if (!shopSnap.exists || shopSnap.data().ownerId !== uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Somente o responsavel pela barbearia pode conectar pagamentos.'
    );
  }
  return { shopRef, shopData: shopSnap.data() };
}

exports.createMercadoPagoConnectUrl = functions
  .runWith({ secrets: MP_SECRET_NAMES })
  .https.onCall(async (_, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
    }
    try {
      await assertBarbershopOwner(context.auth.uid);
      const state = crypto.randomBytes(32).toString('hex');
      const codeVerifier = crypto.randomBytes(48).toString('base64url');
      const codeChallenge = crypto
        .createHash('sha256')
        .update(codeVerifier)
        .digest('base64url');
      const expiresAt = Date.now() + 10 * 60 * 1000;

      await db().collection('mercado_pago_oauth_states').doc(state).set({
        sellerId: context.auth.uid,
        codeVerifier,
        used: false,
        expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const query = new URLSearchParams({
        client_id: requireEnv('MP_CLIENT_ID'),
        response_type: 'code',
        platform_id: 'mp',
        state,
        redirect_uri: requireEnv('MP_REDIRECT_URI'),
        code_challenge: codeChallenge,
        code_challenge_method: 'S256',
      });
      return {
        authorizationUrl: `https://auth.mercadopago.com/authorization?${query}`,
      };
    } catch (error) {
      throw toHttpsError(error, 'Nao foi possivel iniciar a conexao com o Mercado Pago.');
    }
  });

exports.getMercadoPagoConnectionStatus = functions.https.onCall(
  async (_, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
    }
    const { shopData } = await assertBarbershopOwner(context.auth.uid);
    const accountSnap = await db()
      .collection('payment_accounts')
      .doc(context.auth.uid)
      .get();
    return {
      connected: accountSnap.exists && shopData.paymentConnected === true,
      provider: accountSnap.exists ? 'mercado_pago' : null,
      connectedAt: accountSnap.data()?.connectedAt?.toDate?.()?.toISOString() || null,
    };
  }
);

exports.mercadoPagoOAuthCallback = functions
  .runWith({ secrets: MP_SECRET_NAMES })
  .https.onRequest(async (request, response) => {
    const code = typeof request.query.code === 'string' ? request.query.code : '';
    const state = typeof request.query.state === 'string' ? request.query.state : '';
    if (!code || !state) {
      response.status(400).send(renderCallbackPage(false, 'Autorizacao incompleta.'));
      return;
    }

    const stateRef = db().collection('mercado_pago_oauth_states').doc(state);
    try {
      const stateData = await db().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(stateRef);
        if (!snapshot.exists) throw new Error('Estado OAuth nao encontrado.');
        const data = snapshot.data();
        if (data.used || data.expiresAt.toMillis() < Date.now()) {
          throw new Error('Esta autorizacao expirou ou ja foi utilizada.');
        }
        transaction.update(stateRef, { used: true });
        return data;
      });

      const token = await exchangeAuthorizationCode({
        code,
        codeVerifier: stateData.codeVerifier,
      });
      const expiresAt = Date.now() + Number(token.expires_in || 0) * 1000;
      const sellerId = stateData.sellerId;
      const batch = db().batch();
      batch.set(db().collection('payment_accounts').doc(sellerId), {
        provider: 'mercado_pago',
        sellerId,
        mercadoPagoUserId: String(token.user_id),
        accessTokenEncrypted: encrypt(token.access_token),
        refreshTokenEncrypted: encrypt(token.refresh_token),
        expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
        connectedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.update(db().collection('barbershops').doc(sellerId), {
        paymentConnected: true,
        paymentProvider: 'mercado_pago',
        paymentsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.delete(stateRef);
      await batch.commit();

      response.status(200).send(renderCallbackPage(true, 'Conta conectada com sucesso.'));
    } catch (error) {
      console.error('Falha no callback OAuth do Mercado Pago.', error);
      await stateRef.update({ used: false }).catch(() => undefined);
      response
        .status(400)
        .send(renderCallbackPage(false, 'Nao foi possivel conectar a conta. Tente novamente.'));
    }
  });

function renderCallbackPage(success, message) {
  const status = success ? 'success' : 'failure';
  const color = success ? '#087F5B' : '#C92A2A';
  return `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>BarberKR</title></head><body style="margin:0;background:#F6F3EE;font-family:Arial,sans-serif;color:#17201F;display:grid;min-height:100vh;place-items:center"><main style="max-width:420px;margin:24px;padding:32px;border-radius:24px;background:white;box-shadow:0 18px 50px rgba(23,32,31,.12);text-align:center"><div style="width:64px;height:64px;border-radius:20px;background:${color};margin:0 auto 20px"></div><h1 style="margin:0 0 12px">${message}</h1><p style="color:#66706E">Voce ja pode voltar ao aplicativo BarberKR.</p><a href="barberkr://mercadopago/${status}" style="display:block;margin-top:24px;padding:14px 18px;border-radius:14px;background:#173F3B;color:white;text-decoration:none;font-weight:700">Voltar ao aplicativo</a></main></body></html>`;
}

exports.createMercadoPagoCheckout = functions
  .runWith({ secrets: MP_SECRET_NAMES })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
    }
    const barbershopId = String(data?.barbershopId || '').trim();
    const serviceName = String(data?.serviceName || '').trim();
    const date = String(data?.date || '').trim();
    const hour = String(data?.hour || '').trim();
    if (!barbershopId || !serviceName || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}$/.test(hour)) {
      throw new functions.https.HttpsError('invalid-argument', 'Dados do agendamento invalidos.');
    }

    const shopRef = db().collection('barbershops').doc(barbershopId);
    const shopSnap = await shopRef.get();
    if (!shopSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Barbearia nao encontrada.');
    }
    const shop = shopSnap.data();
    if (shop.paymentConnected !== true) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Esta barbearia ainda nao habilitou pagamentos online.'
      );
    }
    const service = (Array.isArray(shop.services) ? shop.services : []).find(
      (item) => String(item.nome || '').trim() === serviceName
    );
    const unitPrice = Number(service?.preco);
    if (!service || !Number.isFinite(unitPrice) || unitPrice <= 0) {
      throw new functions.https.HttpsError('not-found', 'Servico ou valor invalido.');
    }

    const scheduledAt = new Date(`${date}T${hour}:00:00-03:00`);
    if (Number.isNaN(scheduledAt.getTime()) || scheduledAt.getTime() <= Date.now()) {
      throw new functions.https.HttpsError('failed-precondition', 'O horario selecionado ja passou.');
    }
    const weekday = scheduledAt.getDay() === 0 ? 7 : scheduledAt.getDay();
    const openHours = shop.availability?.[String(weekday)] || [];
    if (!openHours.includes(hour)) {
      throw new functions.https.HttpsError('failed-precondition', 'Horario fora da agenda da barbearia.');
    }

    const sellerId = shop.ownerId || barbershopId;
    const intentRef = db().collection('payment_intents').doc();
    const slotId = `${sellerId}_${date}_${hour}`;
    const slotRef = db().collection('slots').doc(slotId);
    const holdRef = db().collection('payment_slot_holds').doc(slotId);
    const expiresAtMillis = Date.now() + CHECKOUT_TTL_MINUTES * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromMillis(expiresAtMillis);
    const clientName = String(context.auth.token.name || context.auth.token.email || 'Cliente');

    await db().runTransaction(async (transaction) => {
      const [slotSnap, holdSnap] = await Promise.all([
        transaction.get(slotRef),
        transaction.get(holdRef),
      ]);
      if (slotSnap.exists) {
        throw new functions.https.HttpsError('already-exists', 'Este horario acabou de ser reservado.');
      }
      if (holdSnap.exists && holdSnap.data().expiresAt.toMillis() > Date.now()) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Existe um pagamento em andamento para este horario.'
        );
      }
      transaction.set(intentRef, {
        clientId: context.auth.uid,
        clientName,
        clientEmail: context.auth.token.email || null,
        sellerId,
        barbershopId,
        barbershopName: shop.nome,
        serviceName,
        amount: unitPrice,
        currency: 'BRL',
        date,
        hour,
        scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
        slotId,
        status: 'creating_checkout',
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(holdRef, {
        paymentIntentId: intentRef.id,
        clientId: context.auth.uid,
        sellerId,
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    try {
      const accessToken = await sellerAccessToken(sellerId);
      const feePercent = Math.max(
        0,
        Math.min(100, Number(process.env.MP_MARKETPLACE_FEE_PERCENT || 0))
      );
      const marketplaceFee = Math.round(unitPrice * feePercent) / 100;
      const preference = await mercadoPagoRequest('/checkout/preferences', {
        method: 'POST',
        accessToken,
        body: {
          items: [
            {
              id: intentRef.id,
              title: `${serviceName} - ${shop.nome}`,
              description: `Agendamento em ${date} as ${hour}:00`,
              category_id: 'services',
              quantity: 1,
              currency_id: 'BRL',
              unit_price: unitPrice,
            },
          ],
          payer: { email: context.auth.token.email || undefined },
          external_reference: intentRef.id,
          metadata: { payment_intent_id: intentRef.id, barbershop_id: barbershopId },
          marketplace_fee: marketplaceFee,
          notification_url: requireEnv('MP_WEBHOOK_URL'),
          back_urls: {
            success: `barberkr://payments/success?intentId=${intentRef.id}`,
            failure: `barberkr://payments/failure?intentId=${intentRef.id}`,
            pending: `barberkr://payments/pending?intentId=${intentRef.id}`,
          },
          auto_return: 'approved',
          expires: true,
          expiration_date_from: new Date().toISOString(),
          expiration_date_to: new Date(expiresAtMillis).toISOString(),
          payment_methods: { installments: 12 },
        },
      });
      const sandbox = process.env.MP_USE_SANDBOX === 'true';
      const checkoutUrl = sandbox
        ? preference.sandbox_init_point || preference.init_point
        : preference.init_point;
      await intentRef.update({
        status: 'checkout_created',
        preferenceId: preference.id,
        marketplaceFee,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { paymentIntentId: intentRef.id, checkoutUrl, expiresAt: new Date(expiresAtMillis).toISOString() };
    } catch (error) {
      await Promise.all([
        holdRef.delete().catch(() => undefined),
        intentRef.update({
          status: 'checkout_error',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
      ]);
      throw toHttpsError(error, 'Nao foi possivel criar o checkout do Mercado Pago.');
    }
  });

exports.getPaymentIntentStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
  }
  const intentId = String(data?.paymentIntentId || '').trim();
  if (!intentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Pagamento nao informado.');
  }
  const snapshot = await db().collection('payment_intents').doc(intentId).get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'Pagamento nao encontrado.');
  }
  const payment = snapshot.data();
  if (payment.clientId !== context.auth.uid && payment.sellerId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Sem acesso a este pagamento.');
  }
  return {
    status: payment.status,
    appointmentId: payment.appointmentId || null,
    paymentStatus: payment.paymentStatus || null,
    statusDetail: payment.statusDetail || null,
  };
});

function validateWebhookSignature(request) {
  const signatureHeader = request.get('x-signature') || '';
  const requestId = request.get('x-request-id') || '';
  const dataId = String(request.query['data.id'] || request.body?.data?.id || '').toLowerCase();
  const parts = Object.fromEntries(
    signatureHeader.split(',').map((part) => {
      const [key, value] = part.trim().split('=');
      return [key, value];
    })
  );
  if (!parts.ts || !parts.v1 || !dataId || !requestId) return false;
  const template = `id:${dataId};request-id:${requestId};ts:${parts.ts};`;
  const expected = crypto
    .createHmac('sha256', requireEnv('MP_WEBHOOK_SECRET'))
    .update(template)
    .digest('hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  const receivedBuffer = Buffer.from(parts.v1, 'hex');
  return (
    expectedBuffer.length === receivedBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, receivedBuffer)
  );
}

exports.mercadoPagoWebhook = functions
  .runWith({ secrets: MP_SECRET_NAMES })
  .https.onRequest(async (request, response) => {
    try {
      if (!validateWebhookSignature(request)) {
        response.status(401).send('invalid signature');
        return;
      }
      const type = String(request.body?.type || request.query.type || '');
      if (type !== 'payment') {
        response.status(200).send('ignored');
        return;
      }
      const paymentId = String(request.query['data.id'] || request.body?.data?.id || '');
      const mercadoPagoUserId = String(request.body?.user_id || '');
      const accounts = await db()
        .collection('payment_accounts')
        .where('mercadoPagoUserId', '==', mercadoPagoUserId)
        .limit(1)
        .get();
      if (accounts.empty) {
        response.status(200).send('seller not found');
        return;
      }
      const sellerId = accounts.docs[0].id;
      const accessToken = await sellerAccessToken(sellerId);
      const payment = await mercadoPagoRequest(`/v1/payments/${encodeURIComponent(paymentId)}`, {
        accessToken,
      });
      await applyPaymentUpdate(payment, sellerId);
      response.status(200).send('ok');
    } catch (error) {
      console.error('Falha ao processar webhook do Mercado Pago.', error);
      response.status(500).send('processing error');
    }
  });

async function applyPaymentUpdate(payment, sellerId) {
  const intentId = String(payment.external_reference || payment.metadata?.payment_intent_id || '');
  if (!intentId) return;
  const intentRef = db().collection('payment_intents').doc(intentId);
  const intentSnap = await intentRef.get();
  if (!intentSnap.exists) return;
  const intent = intentSnap.data();
  if (intent.sellerId !== sellerId) throw new Error('Vendedor divergente no pagamento.');
  const paidAmount = Math.round(Number(payment.transaction_amount) * 100);
  const expectedAmount = Math.round(Number(intent.amount) * 100);
  if (paidAmount !== expectedAmount) throw new Error('Valor divergente no pagamento.');

  const paymentFields = {
    paymentId: String(payment.id),
    paymentStatus: payment.status,
    statusDetail: payment.status_detail || null,
    paymentMethodId: payment.payment_method_id || null,
    paymentTypeId: payment.payment_type_id || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (payment.status !== 'approved') {
    const finalStatuses = new Set(['rejected', 'cancelled', 'refunded', 'charged_back']);
    await intentRef.update({
      ...paymentFields,
      status: finalStatuses.has(payment.status) ? 'payment_failed' : 'payment_pending',
    });
    if (finalStatuses.has(payment.status)) {
      await db().collection('payment_slot_holds').doc(intent.slotId).delete().catch(() => undefined);
    }
    return;
  }

  const slotRef = db().collection('slots').doc(intent.slotId);
  const holdRef = db().collection('payment_slot_holds').doc(intent.slotId);
  const appointmentRef = db().collection('appointments').doc(intentId);
  await db().runTransaction(async (transaction) => {
    const [freshIntent, slotSnap] = await Promise.all([
      transaction.get(intentRef),
      transaction.get(slotRef),
    ]);
    if (!freshIntent.exists || freshIntent.data().status === 'paid') return;
    if (slotSnap.exists && slotSnap.data().appointmentId !== appointmentRef.id) {
      transaction.update(intentRef, {
        ...paymentFields,
        status: 'manual_review',
        reviewReason: 'slot_conflict_after_payment',
      });
      return;
    }
    transaction.set(slotRef, {
      barberId: intent.sellerId,
      clientId: intent.clientId,
      date: intent.date,
      hour: intent.hour,
      appointmentId: appointmentRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.set(appointmentRef, {
      barberId: intent.sellerId,
      barbershopId: intent.barbershopId,
      barbershopName: intent.barbershopName,
      clientId: intent.clientId,
      clientName: intent.clientName,
      date: intent.date,
      hour: intent.hour,
      serviceName: intent.serviceName,
      servicePrice: intent.amount,
      status: 'active',
      paid: true,
      paymentMethod: 'mercado_pago',
      paymentStatus: 'paid',
      paymentProvider: 'mercado_pago',
      paymentId: String(payment.id),
      paymentIntentId: intentId,
      scheduledAt: intent.scheduledAt,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.update(intentRef, {
      ...paymentFields,
      status: 'paid',
      appointmentId: appointmentRef.id,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.delete(holdRef);
  });
}
