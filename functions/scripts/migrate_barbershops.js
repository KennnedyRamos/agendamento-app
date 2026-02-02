const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const legacyCollections = ['barbearias', 'barbearias_legacy', 'barbershops_legacy'];
const serviceCollections = ['servicos', 'services', 'barbearia_servicos'];

function buildAvailability(days, startHour, endHour) {
  const availability = {};
  if (!Array.isArray(days) || days.length === 0) {
    return availability;
  }
  for (const day of days) {
    const hours = [];
    for (let h = startHour; h <= endHour; h += 1) {
      hours.push(String(h).padStart(2, '0'));
    }
    availability[String(day)] = hours;
  }
  return availability;
}

function normalizeServices(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => ({
      nome: item.nome || item.name || '',
      preco: typeof item.preco === 'number'
        ? item.preco
        : Number(item.preco || item.price || 0),
    }))
    .filter((item) => item.nome);
}

async function loadServicesByShopId(shopId) {
  for (const col of serviceCollections) {
    const snapshot = await db.collection(col)
      .where('barbeariaId', '==', shopId)
      .get();
    if (!snapshot.empty) {
      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          nome: data.nome || data.name || '',
          preco: typeof data.preco === 'number'
            ? data.preco
            : Number(data.preco || data.price || 0),
        };
      }).filter((item) => item.nome);
    }

    const snapshotAlt = await db.collection(col)
      .where('barbershopId', '==', shopId)
      .get();
    if (!snapshotAlt.empty) {
      return snapshotAlt.docs.map((doc) => {
        const data = doc.data();
        return {
          nome: data.nome || data.name || '',
          preco: typeof data.preco === 'number'
            ? data.preco
            : Number(data.preco || data.price || 0),
        };
      }).filter((item) => item.nome);
    }
  }
  return [];
}

async function migrate() {
  let migrated = 0;
  let skipped = 0;

  for (const collectionName of legacyCollections) {
    const snapshot = await db.collection(collectionName).get();
    if (snapshot.empty) {
      continue;
    }

    console.log(`Migrando coleção ${collectionName} (${snapshot.size} registros)...`);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const ownerId = data.ownerId || data.barberId || data.userId || doc.id;
      const barbershopRef = db.collection('barbershops').doc(ownerId);
      const existing = await barbershopRef.get();

      if (existing.exists) {
        skipped += 1;
        continue;
      }

      const endereco = {
        bairro: data.bairro || data.neighborhood || '',
        cidade: data.cidade || data.city || '',
        rua: data.rua || data.street || '',
        numero: data.numero || data.number || '',
        cep: data.cep || data.zip || '',
      };

      const services = normalizeServices(data.services || data.servicos || [])
        .concat(await loadServicesByShopId(doc.id));

      const availability = data.availability && typeof data.availability === 'object'
        ? data.availability
        : buildAvailability(data.diasAtendimento || [1,2,3,4,5,6],
          data.horaInicio ?? 9,
          data.horaFim ?? 18);

      const nome = data.nome || data.name || 'Barbearia';

      await barbershopRef.set({
        ownerId,
        nome,
        endereco,
        imageUrl: data.imageUrl || data.logoUrl || null,
        services,
        availability,
        nomeLower: nome.trim().toLowerCase(),
        cidadeLower: String(endereco.cidade || '').trim().toLowerCase(),
        bairroLower: String(endereco.bairro || '').trim().toLowerCase(),
        migratedFrom: collectionName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      migrated += 1;
    }
  }

  console.log(`Migração de barbearias concluída. Criados: ${migrated}. Ignorados: ${skipped}.`);
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });