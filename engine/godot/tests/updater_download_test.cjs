// Local throughput regression. No packages or external network required.
// node tests/updater_download_test.cjs [path-to-godot-console]
const http = require('node:http');
const { spawn } = require('node:child_process');
const path = require('node:path');
const payload = Buffer.alloc(4 * 1024 * 1024, 90);
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Length': payload.length });
  res.end(payload);
});
server.listen(0, '127.0.0.1', () => {
  const godot = process.argv[2] || 'C:/godot/Godot_v4.7.2-stable_win64_console.exe';
  const child = spawn(godot, [
    '--headless', '--path', path.resolve(__dirname, '..'),
    '--script', 'res://tests/updater_download.gd', '--',
    `http://127.0.0.1:${server.address().port}/game.pck`,
  ], { stdio: 'inherit' });
  const timeout = setTimeout(() => child.kill(), 45000);
  child.on('error', error => {
    console.error(error);
    clearTimeout(timeout);
    server.close();
    process.exitCode = 1;
  });
  child.on('exit', code => {
    clearTimeout(timeout);
    server.close();
    process.exitCode = code === 0 ? 0 : 1;
  });
});
