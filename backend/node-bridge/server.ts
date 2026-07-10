import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { spawn } from 'child_process';
import path from 'path';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 4000;
const RUST_BINARY_PATH = path.join(__dirname, '../../target/release/chronos-drift-collector');

interface DriftData {
  local_ts: number;
  atomic_ts: number;
  drift_ms: number;
  stratum: number;
  precision: number;
  jitter: number;
}

/**
 * Orchestrates the execution of the Rust NTP collector and pipes 
 * data to the WebSocket clients for real-time visualization.
 */
function startTelemetryStream() {
  console.log(`Starting Rust binary at: ${RUST_BINARY_PATH}`);
  
  const collector = spawn(RUST_BINARY_PATH, ['--json', '--interval', '1000']);

  collector.stdout.on('data', (data) => {
    const lines = data.toString().split('\n');
    for (const line of lines) {
      if (!line.trim()) continue;
      
      try {
        const payload: DriftData = JSON.parse(line);
        io.emit('drift_update', payload);
      } catch (err) {
        console.error('Error parsing Rust binary output:', err);
      }
    }
  });

  collector.stderr.on('data', (data) => {
    console.error(`Collector Error: ${data}`);
  });

  collector.on('close', (code) => {
    console.log(`Rust process exited with code ${code}. Restarting in 5s...`);
    setTimeout(startTelemetryStream, 5000);
  });
}

// REST endpoints for historical health checks
app.get('/api/health', (req, res) => {
  res.json({ status: 'active', timestamp: Date.now() });
});

io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);
  
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

httpServer.listen(PORT, () => {
  console.log(`Chronos Drift Node-Bridge running on port ${PORT}`);
  
  // Start the Rust subprocess only if not in a dry-run environment
  if (process.env.NODE_ENV !== 'test') {
    startTelemetryStream();
  }
});

process.on('SIGTERM', () => {
  console.info('SIGTERM signal received. Closing HTTP server.');
  httpServer.close(() => {
    process.exit(0);
  });
});