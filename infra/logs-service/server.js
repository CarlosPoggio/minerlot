const http = require('http');
const WebSocket = require('ws');
const { spawn } = require('child_process');

const LOG_PATH = process.env.LOG_PATH || '/data/debug.log';
const TAIL_LINES = process.env.TAIL_LINES || '200';
const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('minerlot logs service\n');
});

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  // One `tail -f` child process per connected client — expected
  // concurrency here is low (personal/LAN dashboard), so this is simpler
  // and more robust than maintaining a shared ring buffer across clients.
  const tail = spawn('tail', ['-n', TAIL_LINES, '-f', LOG_PATH]);

  tail.stdout.on('data', (chunk) => {
    if (ws.readyState !== WebSocket.OPEN) return;
    chunk
      .toString('utf8')
      .split('\n')
      .filter((line) => line.length > 0)
      .forEach((line) => ws.send(line));
  });

  tail.stderr.on('data', (chunk) => {
    console.error('tail stderr:', chunk.toString());
  });

  tail.on('error', (err) => {
    console.error('tail spawn error:', err.message);
  });

  const cleanup = () => {
    if (!tail.killed) tail.kill();
  };
  ws.on('close', cleanup);
  ws.on('error', cleanup);
});

server.listen(PORT, () => {
  console.log(`Logs service listening on ${PORT}, tailing ${LOG_PATH}`);
});
