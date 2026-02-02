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

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value._seconds) return value._seconds * 1000;
  return 0;
}

(async () => {
  const snapshot = await db.collection('reviews').get();
  const groups = new Map();

  snapshot.forEach((doc) => {
    const data = doc.data();
    const barberId = data.barberId || 'unknown';
    const clientId = data.clientId || 'unknown';
    const key = `${barberId}::${clientId}`;
    const updatedAt = toMillis(data.updatedAt);
    const createdAt = toMillis(data.createdAt);
    const ts = Math.max(updatedAt, createdAt);

    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push({ id: doc.id, ts });
  });

  let duplicates = [];
  for (const [key, items] of groups.entries()) {
    if (items.length <= 1) continue;
    items.sort((a, b) => b.ts - a.ts);
    const keep = items[0];
    const remove = items.slice(1);
    duplicates.push({ key, keep, remove });
  }

  console.log(`Encontrados ${duplicates.length} grupos com duplicatas.`);
  let deleteCount = 0;
  for (const group of duplicates) {
    for (const item of group.remove) {
      console.log(`DUP ${group.key} -> remove ${item.id}`);
      if (apply) {
        await db.collection('reviews').doc(item.id).delete();
        deleteCount++;
      }
    }
  }

  if (apply) {
    console.log(`Removidos ${deleteCount} reviews duplicados.`);
  } else {
    console.log('Dry-run. Use --apply para deletar.');
  }
})();
