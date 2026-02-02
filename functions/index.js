const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

admin.initializeApp();

const R2_SECRET_NAMES = [
  'R2_ACCOUNT_ID',
  'R2_ACCESS_KEY_ID',
  'R2_SECRET_ACCESS_KEY',
  'R2_BUCKET',
  'R2_PUBLIC_BASE_URL',
];

function getR2Config() {
  return {
    accountId: process.env.R2_ACCOUNT_ID,
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    bucket: process.env.R2_BUCKET,
    publicBaseUrl: process.env.R2_PUBLIC_BASE_URL,
  };
}

function getR2Client(r2Config) {
  if (
    !r2Config.accountId ||
    !r2Config.accessKeyId ||
    !r2Config.secretAccessKey ||
    !r2Config.bucket
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configuracao do R2 ausente no ambiente.'
    );
  }

  return new S3Client({
    region: 'auto',
    endpoint: `https://${r2Config.accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: r2Config.accessKeyId,
      secretAccessKey: r2Config.secretAccessKey,
    },
  });
}

function buildPublicUrl(baseUrl, objectKey) {
  if (!baseUrl) return null;
  const trimmed = String(baseUrl).replace(/\/+$/, '');
  return `${trimmed}/${objectKey}`;
}

async function sendToUser(userId, payload) {
  const userSnap = await admin.firestore().collection('users').doc(userId).get();
  if (!userSnap.exists) return;
  const tokens = userSnap.data().fcmTokens || [];
  if (!Array.isArray(tokens) || tokens.length === 0) return;

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: payload.notification,
    data: payload.data,
  });
}

exports.getR2UploadUrl = functions
  .runWith({ secrets: R2_SECRET_NAMES })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
  }

  const objectKey = typeof data?.objectKey === 'string' ? data.objectKey.trim() : '';
  if (!objectKey) {
    throw new functions.https.HttpsError('invalid-argument', 'objectKey e obrigatorio.');
  }
  if (objectKey.includes('..')) {
    throw new functions.https.HttpsError('invalid-argument', 'objectKey invalido.');
  }

  const uid = context.auth.uid;
  const allowedPrefix = `barbershops/${uid}/`;
  if (!objectKey.startsWith(allowedPrefix)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Sem permissao para enviar arquivos fora do seu diretorio.'
    );
  }

  const contentType =
    typeof data?.contentType === 'string' && data.contentType.trim().length > 0
      ? data.contentType.trim()
      : 'application/octet-stream';

  const r2Config = getR2Config();
  const client = getR2Client(r2Config);
  const command = new PutObjectCommand({
    Bucket: r2Config.bucket,
    Key: objectKey,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(client, command, { expiresIn: 60 * 5 });
  const publicUrl = buildPublicUrl(r2Config.publicBaseUrl, objectKey);

  return {
    uploadUrl,
    publicUrl,
    objectKey,
  };
});

exports.cancelAppointment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
  }

  const appointmentId = data?.appointmentId;
  if (!appointmentId) {
    throw new functions.https.HttpsError('invalid-argument', 'appointmentId e obrigatorio.');
  }

  const appointmentRef = admin.firestore().collection('appointments').doc(appointmentId);
  const appointmentSnap = await appointmentRef.get();

  if (!appointmentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Agendamento nao encontrado.');
  }

  const appointment = appointmentSnap.data();
  const userId = context.auth.uid;
  const isClient = appointment.clientId === userId;
  const isBarber = appointment.barberId === userId;

  if (!isClient && !isBarber) {
    throw new functions.https.HttpsError('permission-denied', 'Sem permissao para cancelar.');
  }

  if (appointment.status === 'cancelled') {
    return { status: 'already_cancelled' };
  }

  if (isClient) {
    let scheduledAt = appointment.scheduledAt?.toDate?.();
    if (!scheduledAt && appointment.date && appointment.hour) {
      scheduledAt = new Date(`${appointment.date}T${appointment.hour}:00:00`);
    }
    if (!scheduledAt) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Agendamento sem data valida para cancelamento.'
      );
    }
    const cancelDeadline = new Date(scheduledAt.getTime() - 12 * 60 * 60 * 1000);
    if (new Date() > cancelDeadline) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Prazo de cancelamento expirado (12h antes do horario).'
      );
    }
  }

  const cancelReason = data?.reason && String(data.reason).trim().length > 0
    ? String(data.reason).trim()
    : (isBarber
        ? 'Agendamento cancelado pelo barbeiro. Entre em contato para remarcar.'
        : 'Cancelado pelo cliente');

  const slotId = `${appointment.barberId}_${appointment.date}_${appointment.hour}`;
  const slotRef = admin.firestore().collection('slots').doc(slotId);

  await admin.firestore().runTransaction(async (tx) => {
    tx.delete(slotRef);
    tx.update(appointmentRef, {
      status: 'cancelled',
      cancelledBy: isBarber ? 'barber' : 'client',
      cancelReason,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { status: 'cancelled' };
});

exports.onAppointmentCreated = functions.firestore
  .document('appointments/{appointmentId}')
  .onCreate(async (snap) => {
    const appointment = snap.data();
    if (!appointment) return;

    const title = 'Novo agendamento';
    const bodyClient = `Seu horario foi confirmado para ${appointment.date} as ${appointment.hour}:00.`;
    const bodyBarber = `Novo agendamento em ${appointment.date} as ${appointment.hour}:00.`;

    await sendToUser(appointment.clientId, {
      notification: { title, body: bodyClient },
      data: { type: 'appointment_created', appointmentId: snap.id },
    });
    await sendToUser(appointment.barberId, {
      notification: { title, body: bodyBarber },
      data: { type: 'appointment_created', appointmentId: snap.id },
    });
  });

exports.onAppointmentUpdated = functions.firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return;

    if (before.status === after.status) return;
    if (after.status !== 'cancelled') return;

    const title = 'Agendamento cancelado';
    const reason = after.cancelReason || '';
    const bodyClient = `Agendamento cancelado. ${reason}`.trim();
    const bodyBarber = `Agendamento cancelado. ${reason}`.trim();

    await sendToUser(after.clientId, {
      notification: { title, body: bodyClient },
      data: { type: 'appointment_cancelled', appointmentId: change.after.id },
    });
    await sendToUser(after.barberId, {
      notification: { title, body: bodyBarber },
      data: { type: 'appointment_cancelled', appointmentId: change.after.id },
    });
  });
