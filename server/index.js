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

  socket.on('create_room', (data, callback) => {
    if (socket.data.roomCode) handleLeave();
    const roomCode = generateRoomCode();
    const seed = generateSeed();
    const knifeIndex = Number.isFinite(Number(data?.knifeIndex))
      ? Number(data.knifeIndex)
      : 0;
    rooms.set(roomCode, {
      players: [{ id: socket.id, playerNumber: 1, knifeIndex }],
      seed,
      rematchVotes: new Set(),
      readyPlayers: new Set(),
      throwSeq: 0,
      p1ThrowsMade: 0,
      p2ThrowsMade: 0,
      p1Score: 0,
      p2Score: 0,
      gameEnded: false,
      gameStarted: false,
    });
    socket.join(roomCode);
    socket.data.roomCode = roomCode;
    socket.data.playerNumber = 1;

    console.log(`[room created] ${roomCode} by ${socket.id} (knife=${knifeIndex})`);
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

    const knifeIndex = Number.isFinite(Number(data?.knifeIndex))
      ? Number(data.knifeIndex)
      : 0;
    room.players.push({ id: socket.id, playerNumber: 2, knifeIndex });
    socket.join(rawCode);
    socket.data.roomCode = rawCode;
    socket.data.playerNumber = 2;

    // Reset throw counters and ready state for fresh game
    room.readyPlayers.clear();
    room.throwSeq = 0;
    room.p1ThrowsMade = 0;
    room.p2ThrowsMade = 0;
    room.p1Score = 0;
    room.p2Score = 0;
    room.gameEnded = false;
    room.gameStarted = true;

    const p1 = room.players.find((p) => p.playerNumber === 1);
    const p2 = room.players.find((p) => p.playerNumber === 2);
    const p1KnifeIndex = p1?.knifeIndex ?? 0;
    const p2KnifeIndex = p2?.knifeIndex ?? 0;

    console.log(`[room joined] ${rawCode} by ${socket.id} (p1Knife=${p1KnifeIndex}, p2Knife=${p2KnifeIndex})`);
    if (typeof callback === 'function') {
      callback({
        ok: true,
        roomCode: rawCode,
        playerNumber: 2,
        seed: room.seed,
        p1KnifeIndex,
        p2KnifeIndex,
      });
    }

    // Emit game_start to entire room (both players)
    io.to(rawCode).emit('game_start', {
      roomCode: rawCode,
      seed: room.seed,
      p1KnifeIndex,
      p2KnifeIndex,
    });
  });

  socket.on('player_ready', () => {
    const roomCode = socket.data.roomCode;
    if (!roomCode) return;
    const room = rooms.get(roomCode);
    if (!room) return;

    room.readyPlayers.add(socket.id);
    if (room.readyPlayers.size >= 2) {
      room.readyPlayers.clear();
      console.log(`[countdown_start] room=${roomCode}`);
      io.to(roomCode).emit('countdown_start');
    }
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

  socket.on('throw_result', (data) => {
    const roomCode = socket.data.roomCode;
    if (!roomCode) return;
    const room = rooms.get(roomCode);
    if (!room) return;

    const playerNumber = socket.data.playerNumber;
    const isHit = Boolean(data?.isHit);
    const impactLocalAngle = Number(data?.impactLocalAngle ?? 0);
    const score = Number(data?.score ?? 0);
    const throwsMade = Number(data?.throwsMade ?? 0);
    const isGameOver = Boolean(data?.isGameOver);
    const winner = data?.winner ? String(data.winner) : '';

    if (playerNumber === 1) {
      room.p1Score = score;
    } else if (playerNumber === 2) {
      room.p2Score = score;
    }

    socket.to(roomCode).emit('opponent_throw_result', {
      playerNumber,
      isHit,
      impactLocalAngle,
      score,
      throwsMade,
      isGameOver,
      winner,
    });

    if (isGameOver && !room.gameEnded) {
      room.gameEnded = true;
      let resolvedWinner = winner;
      if (!resolvedWinner) {
        if (room.p1Score > room.p2Score) resolvedWinner = 'RED';
        else if (room.p2Score > room.p1Score) resolvedWinner = 'BLUE';
        else resolvedWinner = 'TIE';
      }
      console.log(`[game_over] room=${roomCode} winner=${resolvedWinner} p1=${room.p1Score} p2=${room.p2Score}`);
      io.to(roomCode).emit('game_over', {
        winner: resolvedWinner,
        p1Score: room.p1Score,
        p2Score: room.p2Score,
      });
    }
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
      // Reset server-side throw counters and ready state for new match
      room.readyPlayers.clear();
      room.throwSeq = 0;
      room.p1ThrowsMade = 0;
      room.p2ThrowsMade = 0;
      room.p1Score = 0;
      room.p2Score = 0;
      room.gameEnded = false;
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
