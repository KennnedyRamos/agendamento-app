const admin = require('firebase-admin');

const apply = process.argv.includes('--apply');
const deleteOld = process.argv.includes('--delete-old');
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
    groups.get(key).push({ id: doc.id, ts, data });
  });

  const plannedWrites = [];
  const plannedDeletes = [];

  for (const [key, items] of groups.entries()) {
    if (items.length === 0) continue;
    items.sort((a, b) => b.ts - a.ts);
    const keep = items[0];

    const barberId = keep.data.barberId || 'unknown';
    const clientId = keep.data.clientId || 'unknown';
    const targetId = `${barberId}_${clientId}`;

    plannedWrites.push({
      id: targetId,
      data: {
        barberId: keep.data.barberId,
        clientId: keep.data.clientId,
        rating: keep.data.rating ?? 0,
        comment: keep.data.comment ?? null,
        createdAt: keep.data.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    for (const item of items.slice(1)) {
      plannedDeletes.push(item.id);
    }
  }

  console.log(`Migrar ${plannedWrites.length} reviews para ID determinístico.`);
  console.log(`Duplicatas para remoção: ${plannedDeletes.length}.`);

  if (!apply) {
    console.log('Dry-run. Use --apply para gravar as novas reviews.');
    if (deleteOld) {
      console.log('Use --apply --delete-old para remover duplicadas antigas.');
    }
    process.exit(0);
  }

  const batchSize = 400;
  let batch = db.batch();
  let count = 0;

  for (const item of plannedWrites) {
    const ref = db.collection('reviews').doc(item.id);
    batch.set(ref, item.data, { merge: true });
    count++;
    if (count % batchSize === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (count % batchSize !== 0) {
    await batch.commit();
  }

  if (deleteOld && plannedDeletes.length) {
    batch = db.batch();
    count = 0;
    for (const id of plannedDeletes) {
      batch.delete(db.collection('reviews').doc(id));
      count++;
      if (count % batchSize === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    if (count % batchSize !== 0) {
      await batch.commit();
    }
  }

  console.log('Migração concluída.');
})();
