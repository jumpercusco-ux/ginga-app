/**
 * In-Memory Firestore Adapter for GINGA Testing Harness
 * Provides full emulation of Firestore collections, documents, queries,
 * transactions, batches, FieldValue, and Timestamp without network or GCP dependencies.
 */

class MockTimestamp {
  constructor(date) {
    this._date = date instanceof Date ? date : new Date(date);
    this.seconds = Math.floor(this._date.getTime() / 1000);
    this.nanoseconds = (this._date.getTime() % 1000) * 1e6;
  }
  toDate() {
    return new Date(this._date.getTime());
  }
  toMillis() {
    return this._date.getTime();
  }
  toISOString() {
    return this._date.toISOString();
  }
  static fromDate(date) {
    return new MockTimestamp(date);
  }
  static fromMillis(ms) {
    return new MockTimestamp(new Date(ms));
  }
  static now() {
    return new MockTimestamp(new Date());
  }
}

class MockFieldValue {
  constructor(type, value) {
    this._type = type;
    this._value = value;
  }
  static serverTimestamp() {
    return new MockFieldValue('serverTimestamp', new MockTimestamp(new Date()));
  }
  static delete() {
    return new MockFieldValue('delete', undefined);
  }
}

function deepClone(val) {
  if (val === null || val === undefined) return val;
  if (val instanceof MockTimestamp) return new MockTimestamp(val.toDate());
  if (val instanceof MockFieldValue) return val;
  if (val instanceof Date) return new Date(val.getTime());
  if (Array.isArray(val)) return val.map(deepClone);
  if (typeof val === 'object') {
    const copy = {};
    for (const k of Object.keys(val)) {
      copy[k] = deepClone(val[k]);
    }
    return copy;
  }
  return val;
}

function resolveFieldValue(val) {
  if (val instanceof MockFieldValue) {
    if (val._type === 'serverTimestamp') return MockTimestamp.now();
  }
  if (Array.isArray(val)) return val.map(resolveFieldValue);
  if (val && typeof val === 'object' && !(val instanceof MockTimestamp) && !(val instanceof Date)) {
    const copy = {};
    for (const k of Object.keys(val)) {
      if (val[k] instanceof MockFieldValue && val[k]._type === 'delete') {
        continue;
      }
      copy[k] = resolveFieldValue(val[k]);
    }
    return copy;
  }
  return val;
}

class InMemoryFirestore {
  constructor() {
    this.collections = new Map(); // path -> Map(docId -> data)
    this.listeners = [];
  }

  _getStore(collectionPath) {
    if (!this.collections.has(collectionPath)) {
      this.collections.set(collectionPath, new Map());
    }
    return this.collections.get(collectionPath);
  }

  collection(collectionPath) {
    return new CollectionReference(this, collectionPath);
  }

  doc(docPath) {
    const parts = docPath.split('/');
    if (parts.length % 2 !== 0) {
      throw new Error(`Invalid document path: ${docPath}`);
    }
    const docId = parts.pop();
    const colPath = parts.join('/');
    return new DocumentReference(this, colPath, docId);
  }

  async runTransaction(updateFunction) {
    const transaction = new Transaction(this);
    return await updateFunction(transaction);
  }

  batch() {
    return new WriteBatch(this);
  }

  dump() {
    const result = {};
    for (const [colPath, store] of this.collections.entries()) {
      result[colPath] = {};
      for (const [docId, data] of store.entries()) {
        result[colPath][docId] = deepClone(data);
      }
    }
    return result;
  }

  reset() {
    this.collections.clear();
  }

  seedBaseline() {
    this.reset();

    // 1. config/negocio
    this.doc('config/negocio').setRaw({
      mensualidad: 140,
      promo_2x: 260,
      promos_multimes: { '3': 380, '6': 720 },
      yape_numero: '984 123 456',
      telefono_instructor: '+51984000111',
      ciudad: 'Cusco',
    });

    // 2. config/whatsapp_agent
    this.doc('config/whatsapp_agent').setRaw({
      system_prompt: null, // default
    });

    // 3. clases regulares
    this.doc('clases/clase_ninos_regular').setRaw({
      nombre: 'Capoeira Niños',
      nivel: 'Iniciación Infantil',
      tipo: 'regular',
      publico: 'niños',
      dias: 'M, J',
      hora: '18:00',
      hora_fin: '19:00',
      edad_min: 6,
      edad_max: 13,
      cupos_disponibles: 8,
      clase_gratuita: true,
      descripcion: 'Clase de prueba para niños de 6 a 13 años',
      sede: 'Cusco',
      ubicacion: 'Av. de la Cultura E-4, 2do piso (frente a Divergym, encima de Caja Arequipa), Cusco',
      instructor_id: 'inst_mestre_1',
    });

    this.doc('clases/clase_adultos_regular').setRaw({
      nombre: 'Capoeira Jóvenes y Adultos',
      nivel: 'Básico / Todos los niveles',
      tipo: 'regular',
      publico: 'jovenes_adultos',
      dias: 'M, J',
      hora: '19:30',
      hora_fin: '21:00',
      edad_min: 14,
      edad_max: 80,
      cupos_disponibles: 10,
      clase_gratuita: true,
      descripcion: 'Clase de prueba para jóvenes y adultos',
      sede: 'Cusco',
      ubicacion: 'Av. de la Cultura E-4, 2do piso (frente a Divergym, encima de Caja Arequipa), Cusco',
      instructor_id: 'inst_mestre_1',
    });

    // 4. users (instructor)
    this.doc('users/inst_mestre_1').setRaw({
      nombre: 'Instrutor FIU',
      rol: 'profesor',
      notifications_enabled: true,
    });
  }
}

class DocumentReference {
  constructor(db, colPath, id) {
    this.db = db;
    this.colPath = colPath;
    this.id = id;
    this.path = `${colPath}/${id}`;
  }

  collection(subCollectionName) {
    return new CollectionReference(this.db, `${this.path}/${subCollectionName}`);
  }

  setRaw(data) {
    const store = this.db._getStore(this.colPath);
    store.set(this.id, deepClone(resolveFieldValue(data)));
  }

  async get() {
    const store = this.db._getStore(this.colPath);
    const data = store.get(this.id);
    return new DocumentSnapshot(this, data);
  }

  async set(data, options = {}) {
    const store = this.db._getStore(this.colPath);
    let finalData = resolveFieldValue(data);
    if (options.merge) {
      const existing = store.get(this.id) || {};
      finalData = { ...deepClone(existing), ...finalData };
    }
    store.set(this.id, deepClone(finalData));
    return { writeTime: MockTimestamp.now() };
  }

  async update(updates) {
    const store = this.db._getStore(this.colPath);
    const existing = store.get(this.id);
    if (!existing) {
      throw new Error(`Document ${this.path} does not exist to update.`);
    }
    const resolved = resolveFieldValue(updates);
    const merged = { ...deepClone(existing) };
    for (const [key, val] of Object.entries(resolved)) {
      if (val instanceof MockFieldValue && val._type === 'delete') {
        delete merged[key];
      } else {
        merged[key] = val;
      }
    }
    store.set(this.id, merged);
    return { writeTime: MockTimestamp.now() };
  }

  async delete() {
    const store = this.db._getStore(this.colPath);
    store.delete(this.id);
    return { writeTime: MockTimestamp.now() };
  }
}

class DocumentSnapshot {
  constructor(ref, data) {
    this.ref = ref;
    this.id = ref.id;
    this._data = data ? deepClone(data) : undefined;
    this.exists = data !== undefined;
  }

  data() {
    return this._data ? deepClone(this._data) : undefined;
  }
}

class CollectionReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this._queries = [];
    this._limit = null;
    this._orderBy = [];
  }

  doc(id) {
    const docId = id || `mock_id_${Math.random().toString(36).substring(2, 10)}`;
    return new DocumentReference(this.db, this.path, docId);
  }

  where(field, op, value) {
    const query = new CollectionReference(this.db, this.path);
    query._queries = [...this._queries, { field, op, value }];
    query._limit = this._limit;
    query._orderBy = [...this._orderBy];
    return query;
  }

  limit(n) {
    const query = new CollectionReference(this.db, this.path);
    query._queries = [...this._queries];
    query._limit = n;
    query._orderBy = [...this._orderBy];
    return query;
  }

  orderBy(field, direction = 'asc') {
    const query = new CollectionReference(this.db, this.path);
    query._queries = [...this._queries];
    query._limit = this._limit;
    query._orderBy = [...this._orderBy, { field, direction }];
    return query;
  }

  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }

  async get() {
    const store = this.db._getStore(this.path);
    let docs = [];
    for (const [id, data] of store.entries()) {
      docs.push(new DocumentSnapshot(new DocumentReference(this.db, this.path, id), data));
    }

    // Apply where filters
    for (const q of this._queries) {
      docs = docs.filter((d) => {
        const val = d.data()?.[q.field];
        if (q.op === '==') return val === q.value;
        if (q.op === '!=') return val !== q.value;
        if (q.op === '>') return val > q.value;
        if (q.op === '>=') return val >= q.value;
        if (q.op === '<') return val < q.value;
        if (q.op === '<=') return val <= q.value;
        if (q.op === 'in') return Array.isArray(q.value) && q.value.includes(val);
        return false;
      });
    }

    // Apply orderBy
    for (const ob of this._orderBy) {
      docs.sort((a, b) => {
        const valA = a.data()?.[ob.field];
        const valB = b.data()?.[ob.field];
        let cmp = 0;
        if (valA instanceof MockTimestamp && valB instanceof MockTimestamp) {
          cmp = valA.toMillis() - valB.toMillis();
        } else if (valA < valB) cmp = -1;
        else if (valA > valB) cmp = 1;
        return ob.direction === 'desc' ? -cmp : cmp;
      });
    }

    // Apply limit
    if (this._limit !== null && this._limit >= 0) {
      docs = docs.slice(0, this._limit);
    }

    return new QuerySnapshot(docs);
  }
}

class QuerySnapshot {
  constructor(docs) {
    this.docs = docs;
    this.empty = docs.length === 0;
    this.size = docs.length;
  }
  forEach(callback) {
    this.docs.forEach(callback);
  }
}

class Transaction {
  constructor(db) {
    this.db = db;
    this.mutations = [];
  }

  async get(ref) {
    return await ref.get();
  }

  set(ref, data, options = {}) {
    ref.set(data, options);
  }

  update(ref, data) {
    ref.update(data);
  }

  delete(ref) {
    ref.delete();
  }
}

class WriteBatch {
  constructor(db) {
    this.db = db;
    this.operations = [];
  }

  set(ref, data, options = {}) {
    this.operations.push(() => ref.set(data, options));
    return this;
  }

  update(ref, data) {
    this.operations.push(() => ref.update(data));
    return this;
  }

  delete(ref) {
    this.operations.push(() => ref.delete());
    return this;
  }

  async commit() {
    for (const op of this.operations) {
      await op();
    }
  }
}

function createMockAdmin(inMemoryFirestore) {
  const admin = {
    initializeApp: () => {},
    firestore: Object.assign(() => inMemoryFirestore, {
      FieldValue: MockFieldValue,
      Timestamp: MockTimestamp,
    }),
  };
  return admin;
}

module.exports = {
  InMemoryFirestore,
  MockTimestamp,
  MockFieldValue,
  createMockAdmin,
};

