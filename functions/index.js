const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

async function sendToUser(userId, payload) {
  const userSnap = await admin.firestore().collection('users').doc(userId).get();
  if (!userSnap.exists) return;
  const tokens = userSnap.data().fcmTokens || [];
  if (!Array.isArray(tokens) || tokens.length === 0) return;

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: payload.notification,
    data: payload.data,
  });

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      invalidTokens.push(tokens[index]);
    }
  });
  if (invalidTokens.length > 0) {
    await userSnap.ref.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
  }
}

async function saveNotificationHistory(userId, notificationId, data) {
  if (!userId) return;
  const reference = admin
    .firestore()
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .doc(notificationId);
  try {
    await reference.create({
      userId,
      actorId: data.actorId,
      appointmentId: data.appointmentId,
      type: data.type,
      title: data.title,
      body: data.body,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (error?.code !== 6 && error?.code !== 'already-exists') throw error;
  }
}

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
      scheduledAt = new Date(`${appointment.date}T${appointment.hour}:00:00-03:00`);
    }
    if (!scheduledAt) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Agendamento sem data valida para cancelamento.'
      );
    }
    const cancelDeadline = new Date(scheduledAt.getTime() - 6 * 60 * 60 * 1000);
    if (new Date() > cancelDeadline) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Prazo de cancelamento expirado (6h antes do horario).'
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
      cancelledByUserId: userId,
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

    const appointmentId = snap.id;
    const title = 'Novo agendamento';
    const bodyClient = `Seu horario foi confirmado para ${appointment.date} as ${appointment.hour}:00.`;
    const bodyBarber = `${appointment.clientName || 'Cliente'} agendou ${appointment.serviceName || 'um atendimento'} para ${appointment.date} as ${appointment.hour}:00.`;

    const tasks = [
      saveNotificationHistory(
        appointment.clientId,
        `${appointmentId}_created_client`,
        {
          actorId: appointment.clientId,
          appointmentId,
          type: 'appointment_created',
          title: 'Agendamento confirmado',
          body: bodyClient,
        }
      ),
      saveNotificationHistory(
        appointment.barberId,
        `${appointmentId}_created_barber`,
        {
          actorId: appointment.clientId,
          appointmentId,
          type: 'appointment_created',
          title,
          body: bodyBarber,
        }
      ),
      sendToUser(appointment.clientId, {
        notification: { title, body: bodyClient },
        data: { type: 'appointment_created', appointmentId },
      }),
      sendToUser(appointment.barberId, {
        notification: { title, body: bodyBarber },
        data: { type: 'appointment_created', appointmentId },
      }),
    ];

    if (appointment.paid === true) {
      tasks.push(
        saveNotificationHistory(
          appointment.clientId,
          `${appointmentId}_payment_client`,
          {
            actorId: appointment.clientId,
            appointmentId,
            type: 'payment_approved',
            title: 'Pagamento aprovado',
            body: `Pagamento de ${appointment.serviceName || 'seu atendimento'} confirmado.`,
          }
        ),
        saveNotificationHistory(
          appointment.barberId,
          `${appointmentId}_payment_barber`,
          {
            actorId: appointment.clientId,
            appointmentId,
            type: 'payment_received',
            title: 'Pagamento recebido',
            body: `Pagamento de ${appointment.clientName || 'Cliente'} confirmado.`,
          }
        )
      );
    }

    await Promise.all(tasks);
  });

exports.onAppointmentUpdated = functions.firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return;

    const appointmentId = change.after.id;
    const tasks = [];

    if (before.status !== after.status && after.status === 'cancelled') {
      const title = 'Agendamento cancelado';
      const reason = after.cancelReason || '';
      const bodyClient = `Agendamento cancelado. ${reason}`.trim();
      const bodyBarber = `${after.clientName || 'Cliente'} teve o agendamento cancelado. ${reason}`.trim();
      const actorId = after.cancelledBy === 'barber'
        ? after.barberId
        : after.clientId;
      tasks.push(
        saveNotificationHistory(after.clientId, `${appointmentId}_cancelled_client`, {
          actorId,
          appointmentId,
          type: 'appointment_cancelled',
          title,
          body: bodyClient,
        }),
        saveNotificationHistory(after.barberId, `${appointmentId}_cancelled_barber`, {
          actorId,
          appointmentId,
          type: 'appointment_cancelled',
          title,
          body: bodyBarber,
        }),
        sendToUser(after.clientId, {
          notification: { title, body: bodyClient },
          data: { type: 'appointment_cancelled', appointmentId },
        }),
        sendToUser(after.barberId, {
          notification: { title, body: bodyBarber },
          data: { type: 'appointment_cancelled', appointmentId },
        })
      );
    }

    if (before.status !== after.status && after.status === 'completed') {
      tasks.push(
        saveNotificationHistory(after.clientId, `${appointmentId}_completed_client`, {
          actorId: after.barberId,
          appointmentId,
          type: 'appointment_completed',
          title: 'Atendimento concluido',
          body: `Seu atendimento de ${after.serviceName || 'barbearia'} foi concluido.`,
        }),
        saveNotificationHistory(after.barberId, `${appointmentId}_completed_barber`, {
          actorId: after.barberId,
          appointmentId,
          type: 'appointment_completed',
          title: 'Atendimento concluido',
          body: `Atendimento de ${after.clientName || 'Cliente'} concluido.`,
        })
      );
    }

    if (before.paid !== true && after.paid === true) {
      tasks.push(
        saveNotificationHistory(after.clientId, `${appointmentId}_payment_client`, {
          actorId: after.clientId,
          appointmentId,
          type: 'payment_approved',
          title: 'Pagamento aprovado',
          body: `Pagamento de ${after.serviceName || 'seu atendimento'} confirmado.`,
        }),
        saveNotificationHistory(after.barberId, `${appointmentId}_payment_barber`, {
          actorId: after.clientId,
          appointmentId,
          type: 'payment_received',
          title: 'Pagamento recebido',
          body: `Pagamento de ${after.clientName || 'Cliente'} confirmado.`,
        })
      );
    }

    await Promise.all(tasks);
  });

exports.onChatMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message?.senderId || !message?.text) return;

    const conversationSnap = await admin
      .firestore()
      .collection('conversations')
      .doc(context.params.conversationId)
      .get();
    if (!conversationSnap.exists) return;

    const conversation = conversationSnap.data();
    const senderIsClient = message.senderId === conversation.clientId;
    const senderIsBarber = message.senderId === conversation.barberId;
    if (!senderIsClient && !senderIsBarber) return;

    const recipientId = senderIsClient
      ? conversation.barberId
      : conversation.clientId;
    const senderName = senderIsClient
      ? conversation.clientName || 'Cliente'
      : conversation.barbershopName || 'Barbearia';
    await sendToUser(recipientId, {
      notification: {
        title: `Nova mensagem de ${String(senderName).slice(0, 80)}`,
        body: String(message.text).slice(0, 200),
      },
      data: {
        type: 'message_received',
        conversationId: context.params.conversationId,
      },
    });
  });

const mercadoPago = require('./mercado_pago');

exports.createMercadoPagoConnectUrl = mercadoPago.createMercadoPagoConnectUrl;
exports.getMercadoPagoConnectionStatus = mercadoPago.getMercadoPagoConnectionStatus;
exports.getBarberFinancialDashboard = mercadoPago.getBarberFinancialDashboard;
exports.mercadoPagoOAuthCallback = mercadoPago.mercadoPagoOAuthCallback;
exports.createMercadoPagoCheckout = mercadoPago.createMercadoPagoCheckout;
exports.getPaymentIntentStatus = mercadoPago.getPaymentIntentStatus;
exports.mercadoPagoWebhook = mercadoPago.mercadoPagoWebhook;
