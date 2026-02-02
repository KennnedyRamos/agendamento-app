const admin = require('firebase-admin');

const apply = process.argv.includes('--apply');
const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID;

if (!projectId && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Defina GOOGLE_APPLICATION_CREDENTIALS ou GCLOUD_PROJECT/FIREBASE_PROJECT_ID.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: projectId || undefined,
  });
}

const db = admin.firestore();

(async () => {
  const shops = await db.collection('barbershops').get();
  let updates = 0;

  for (const doc of shops.docs) {
    const data = doc.data();
    const ownerId = data.ownerId || doc.id;
    const currentPhone = (data.telefone || '').toString().trim();
    if (currentPhone) continue;

    const userDoc = await db.collection('users').doc(ownerId).get();
    if (!userDoc.exists) continue;
    const phone = (userDoc.data().telefone || '').toString().trim();
    if (!phone) continue;

    console.log(`barbershops/${doc.id} <- ${phone}`);
    updates++;
    if (apply) {
      await db.collection('barbershops').doc(doc.id).update({ telefone: phone });
    }
  }

  if (!apply) {
    console.log(`Dry-run. ${updates} atualizações possíveis. Use --apply.`);
  } else {
    console.log(`Atualizações feitas: ${updates}.`);
  }
})();
