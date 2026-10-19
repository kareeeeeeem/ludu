// Run with mongosh inside the MongoDB container.
try { rs.status(); } catch (_) { rs.initiate({ _id: 'ludo', members: [{ _id: 0, host: 'mongo:27017' }] }); }
