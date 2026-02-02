const admin = require('firebase-admin');

// Uses GOOGLE_APPLICATION_CREDENTIALS for authentication
admin.initializeApp();
const db = admin.firestore();

async function migrate() {
  const snapshot = await db.collection('clientes').get();
  console.log(`Encontrados ${snapshot.size} clientes.`);

  let created = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const uid = doc.id;
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();

    if (userSnap.exists) {
      skipped += 1;
      continue;
    }

    await userRef.set({
      uid,
      role: 'client',
      nome: data.nome || '',
      sobrenome: data.sobrenome || '',
      email: data.email || '',
      telefone: String(data.telefone ?? ''),
      migratedFrom: 'clientes',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    created += 1;
  }

  console.log(`Migração concluída. Criados: ${created}. Ignorados: ${skipped}.`);
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });