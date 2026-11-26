const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

const PORT = process.env.PORT || 3000;

// Active rooms: roomCode -> {
//   players: [{ id, playerNumber }],
//   seed,
//   rematchVotes: Set,
//   throwSeq: number,          // monotonically increasing throw counter
//   p1ThrowsMade: number,       // server-authoritative throw counts
//   p2ThrowsMade: number,
//   gameStarted: boolean,       // prevent duplicate game_start
// }
const rooms = new Map();

function generateRoomCode() {
  for (let attempt = 0; attempt < 1000; attempt++) {
    const code = String(Math.floor(Math.random() * 1000)).padStart(3, '0');
    if (!rooms.has(code)) return code;
  }
  return String(Math.floor(Math.random() * 1000)).padStart(3, '0');
}

function generateSeed() {
  return Math.floor(Math.random() * 2147483647);
}

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', activeRooms: rooms.size });
});

io.on('connection', (socket) => {
  console.log(`[connect] ${socket.id}`);

  const handleLeave = () => {
    const roomCode = socket.data.roomCode;
    if (!roomCode) return;
    const room = rooms.get(roomCode);
    if (room) {
      room.players = room.players.filter((p) => p.id !== socket.id);
      socket.to(roomCode).emit('opponent_disconnected');
      if (room.players.length === 0) {
        rooms.delete(roomCode);
        console.log(`[room closed] ${roomCode}`);
      }
    }
    socket.leave(roomCode);
    socket.data.roomCode = null;
    socket.data.playerNumber = null;
  };

  socket.on('create_room', (_data, callback) => {
    if (socket.data.roomCode) handleLeave();
    const roomCode = generateRoomCode();
    const seed = generateSeed();
    rooms.set(roomCode, {
      players: [{ id: socket.id, playerNumber: 1 }],
      seed,
      rematchVotes: new Set(),
      throwSeq: 0,
      p1ThrowsMade: 0,
      p2ThrowsMade: 0,
      gameStarted: false,
    });
    socket.join(roomCode);
    socket.data.roomCode = roomCode;
    socket.data.playerNumber = 1;

    console.log(`[room created] ${roomCode} by ${socket.id}`);
    const payload = { roomCode, playerNumber: 1, seed };
    if (typeof callback === 'function') callback({ ok: true, ...payload });
    socket.emit('room_created', payload);
  });

  socket.on('join_room', (data, callback) => {
    if (socket.data.roomCode) handleLeave();
    const rawCode = (data && data.roomCode ? String(data.roomCode) : '')
      .trim()
      .toUpperCase();

    const room = rooms.get(rawCode);
    if (!room) {
      const err = { ok: false, error: 'Room not found. Check the code and try again.' };
      if (typeof callback === 'function') {
        callback(err);
      } else {
        socket.emit('room_error', err);
      }
      return;
    }

    if (room.players.length >= 2) {
      const err = { ok: false, error: 'This room is already full.' };
      if (typeof callback === 'function') {
        callback(err);
      } else {
        socket.emit('room_error', err);
      }
      return;
    }

    room.players.push({ id: socket.id, playerNumber: 2 });
    socket.join(rawCode);
    socket.data.roomCode = rawCode;
    socket.data.playerNumber = 2;

    // Reset throw counters for fresh game
    room.throwSeq = 0;
    room.p1ThrowsMade = 0;
    room.p2ThrowsMade = 0;
    room.gameStarted = true;

    console.log(`[room joined] ${rawCode} by ${socket.id}`);
    if (typeof callback === 'function') {
      callback({ ok: true, roomCode: rawCode, playerNumber: 2, seed: room.seed });
    }

    // Emit game_start to entire room (both players)
    io.to(rawCode).emit('game_start', {
      roomCode: rawCode,
      seed: room.seed,
    });
  });

  socket.on('throw_knife', (data) => {
    const roomCode = socket.data.roomCode;
    if (!roomCode) return;
    const room = rooms.get(roomCode);
    if (!room) return;

    // Assign a monotonically increasing sequence number for ordering guarantees
    const seq = ++room.throwSeq;
    const playerNumber = socket.data.playerNumber;

    // Track server-side throw counts (for future authoritative state if needed)
    if (playerNumber === 1) room.p1ThrowsMade++;
    else room.p2ThrowsMade++;

    console.log(`[throw] room=${roomCode} p${playerNumber} seq=${seq} angle=${data?.targetAngle?.toFixed?.(3) ?? data?.targetAngle}`);

    socket.to(roomCode).emit('opponent_throw', {
      playerNumber,
      targetAngle: data?.targetAngle ?? 0,
      seq, // Client uses this to discard out-of-order events
    });
  });

  socket.on('target_sync', (data) => {
    const roomCode = socket.data.roomCode;
    if (!roomCode || socket.data.playerNumber !== 1) return;
    socket.to(roomCode).emit('target_sync', {
      angle: data?.angle ?? 0,
      directionSign: data?.directionSign ?? 1,
    });
  });

  socket.on('request_rematch', () => {
    const roomCode = socket.data.roomCode;
    if (!roomCode) return;
    const room = rooms.get(roomCode);
    if (!room) return;

    room.rematchVotes.add(socket.id);
    if (room.rematchVotes.size >= 2) {
      room.rematchVotes.clear();
      room.seed = generateSeed();
      // Reset server-side throw counters for new match
      room.throwSeq = 0;
      room.p1ThrowsMade = 0;
      room.p2ThrowsMade = 0;
      io.to(roomCode).emit('rematch_start', { seed: room.seed });
    } else {
      socket.to(roomCode).emit('opponent_rematch_ready');
    }
  });

  socket.on('leave_room', handleLeave);
  socket.on('disconnect', () => {
    console.log(`[disconnect] ${socket.id}`);
    handleLeave();
  });
});

server.listen(PORT, () => {
  console.log(`Knife Thrower Socket.IO server listening on http://localhost:${PORT}`);
});
