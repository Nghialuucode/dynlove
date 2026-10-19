require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const routes = require('./routes');
const { initSocket } = require('./socket');
const { initSchema } = require('./db');

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(routes);

const server = http.createServer(app);
initSocket(server);

const PORT = process.env.PORT || 3000;

(async () => {
  try {
    await initSchema();
    server.listen(PORT, '0.0.0.0', () =>
      console.log(`🚀 DynLove backend on :${PORT}`)
    );
  } catch (e) {
    console.error('Fatal:', e);
    process.exit(1);
  }
})();
