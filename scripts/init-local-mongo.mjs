import { createRequire } from 'node:module';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { MongoClient } = require('mongodb');
const port = Number(process.env.LUDO_MONGO_PORT || 27028);
const client = new MongoClient(`mongodb://127.0.0.1:${port}/?directConnection=true`, { serverSelectionTimeoutMS: 2000 });
for (let i = 0; ; i++) {
  try { await client.connect(); break; } catch (e) { if (i >= 20) throw e; await new Promise(r => setTimeout(r, 500)); }
}
try {
  try { await client.db('admin').command({ replSetGetStatus: 1 }); }
  catch (e) {
    if (e.code !== 94) throw e;
    await client.db('admin').command({ replSetInitiate: { _id: 'ludo', members: [{ _id: 0, host: `127.0.0.1:${port}` }] } });
  }
  for (let i = 0; ; i++) {
    if ((await client.db('admin').command({ hello: 1 })).isWritablePrimary) break;
    if (i >= 30) throw new Error('MongoDB did not become primary');
    await new Promise(r => setTimeout(r, 500));
  }
  console.log('Local MongoDB replica set ready.');
} finally { await client.close(); }
