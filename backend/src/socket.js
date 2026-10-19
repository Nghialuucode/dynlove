const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { pool } = require('./db');

let io;

function initSocket(httpServer) {
  io = new Server(httpServer, { cors: { origin: '*' } });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      const { rows } = await pool.query(
        'SELECT id, couple_id FROM users WHERE id=$1',
        [payload.sub]
      );
      if (!rows.length) return next(new Error('no_user'));
      socket.userId = rows[0].id;
      socket.coupleId = rows[0].couple_id;
      next();
    } catch {
      next(new Error('bad_token'));
    }
  });

  io.on('connection', (socket) => {
    if (socket.coupleId) socket.join(`couple:${socket.coupleId}`);
    console.log(`[Socket] ${socket.userId} connected`);

    socket.on('chat:send', async ({ content }, cb) => {
      if (!socket.coupleId || !content?.trim()) return;
      const { rows } = await pool.query(
        `INSERT INTO messages (couple_id, sender_id, content)
         VALUES ($1,$2,$3) RETURNING *`,
        [socket.coupleId, socket.userId, content.trim()]
      );
      const msg = rows[0];
      io.to(`couple:${socket.coupleId}`).emit('chat:new', msg);
      cb?.({ ok: true, id: msg.id });
    });

    socket.on('chat:typing', ({ typing }) => {
      if (!socket.coupleId) return;
      socket.to(`couple:${socket.coupleId}`).emit('chat:typing', {
        userId: socket.userId, typing: !!typing
      });
    });

    socket.on('love:touch', () => {
      if (!socket.coupleId) return;
      socket.to(`couple:${socket.coupleId}`).emit('love:touch', {
        from: socket.userId, ts: Date.now()
      });
    });

    socket.on('disconnect', () => {
      console.log(`[Socket] ${socket.userId} disconnected`);
    });
  });
}

function emitToCouple(coupleId, event, data) {
  if (io) io.to(`couple:${coupleId}`).emit(event, data);
}

module.exports = { initSocket, emitToCouple };
