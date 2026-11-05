// Real HTTP + RSA signatures + Godot reconstruction/fallback integration tests.
// node engine/godot/tests/updater_patches_test.cjs [godot-console-executable]
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');
const { makePatch, hash } = require('../../../server/update_patches.cjs');
const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'tyrants-patches-'));
const base = Buffer.alloc(4 * 1024 * 1024);
let state = 0x12345678;
for (let i = 0; i < base.length; i++) {
  state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
  base[i] = state & 255;
}
const older = Buffer.from(base); older.fill(7, older.length - 10000);
const target = Buffer.concat([base.subarray(0, 1048576), Buffer.from('Changed rules\n'.repeat(600)), base.subarray(1048576 + 1234)]);
const keys = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const sign = sha => crypto.sign('sha256', Buffer.from(`9 ${sha}`), keys.privateKey).toString('base64');
const patch = makePatch(base, target, 9);
const oldPatch = makePatch(older, target, 9);
if (patch.length >= base.length / 8 || oldPatch.length >= base.length / 8) throw Error('Delta did not reuse unchanged content');
console.log(`Fixture patch ${patch.length} bytes; full ${target.length} bytes`);
fs.writeFileSync(path.join(folder, 'base.pck'), base);
fs.writeFileSync(path.join(folder, 'base-older.pck'), older);
fs.writeFileSync(path.join(folder, 'public.pem'), keys.publicKey.export({ type: 'spki', format: 'pem' }));
const scenarios = ['patch', 'older', 'reparent', 'chunked-patch', 'interrupted-patch', 'stalled-patch', 'legacy', 'missing-index', 'missing-patch', 'bad-index-signature', 'tampered-index', 'oversized-index', 'oversized-patch', 'corrupt-patch', 'malformed-patch', 'unknown-base', 'bad-version-signature', 'corrupt-full', 'stalled-full'];
const malformed = (() => {
  const headerSize = patch.readUInt32LE(8);
  const header = JSON.parse(patch.subarray(12, 12 + headerSize));
  header.ops[0][1] = 2 ** 40;
  const json = Buffer.from(JSON.stringify(header));
  const prefix = Buffer.from(patch.subarray(0, 12)); prefix.writeUInt32LE(json.length, 8);
  return Buffer.concat([prefix, json, patch.subarray(12 + headerSize)]);
})();
const requests = {};
const server = http.createServer((req, res) => {
  const [, scenario, ...parts] = req.url.split('/');
  const resource = parts.join('/');
  (requests[scenario] ||= []).push(resource);
  let data = resource === 'game.pck' ? target : null;
  const offeredPatch = scenario === 'malformed-patch' ? malformed : patch;
  const entries = [
    { from_sha: hash(base), sha256: hash(offeredPatch), size: offeredPatch.length },
    { from_sha: hash(older), sha256: hash(oldPatch), size: oldPatch.length },
  ];
  if (scenario === 'unknown-base') entries.length = 0;
  const index = Buffer.from(JSON.stringify({ format: 1, build: 9, target_sha: hash(target), target_size: target.length, patches: entries,
    ...(scenario === 'oversized-index' ? { padding: 'x'.repeat(1024 * 1024) } : {}) }));
  if (resource === 'version.txt') {
    data = Buffer.from(`9 ${hash(target)} ${scenario === 'bad-version-signature' ? sign(hash(base)) : sign(hash(target))}` +
      (['legacy', 'corrupt-full', 'stalled-full'].includes(scenario) ? '' : ` ${hash(index)} ${sign(scenario === 'bad-index-signature' ? hash(base) : hash(index))}`));
  } else if (resource === 'patches/9/index.json' && scenario !== 'missing-index') {
    data = scenario === 'tampered-index' ? Buffer.from('{}') : index;
  } else if (resource === `patches/9/${hash(base)}.tdpatch` && scenario !== 'missing-patch') data = offeredPatch;
  else if (resource === `patches/9/${hash(older)}.tdpatch`) data = oldPatch;
  if (data && ((scenario === 'corrupt-patch' && resource.endsWith('.tdpatch')) || (scenario === 'corrupt-full' && resource === 'game.pck'))) {
    data = Buffer.from(data); data[data.length - 1] ^= 1;
  }
  if (data && scenario === 'oversized-patch' && resource.endsWith('.tdpatch')) data = Buffer.concat([data, Buffer.alloc(1024)]);
  if ((scenario === 'stalled-patch' && resource.endsWith('.tdpatch')) || (scenario === 'stalled-full' && resource === 'game.pck')) {
    res.writeHead(200, { 'Content-Length': data.length }); res.write(data.subarray(0, 1)); return;
  }
  if (scenario === 'interrupted-patch' && resource.endsWith('.tdpatch') && requests[scenario].filter(r => r.endsWith('.tdpatch')).length === 1) {
    res.writeHead(200, { 'Content-Length': data.length }); res.write(data.subarray(0, 1000)); setTimeout(() => res.destroy(), 10); return;
  }
  const send = () => { res.writeHead(data ? 200 : 404,
    scenario === 'chunked-patch' && resource.endsWith('.tdpatch') ? { 'Transfer-Encoding': 'chunked' } : { 'Content-Length': data ? data.length : 0 }); res.end(data || undefined); };
  if (scenario === 'reparent' && resource === 'version.txt') setTimeout(send, 200);
  else send();
});
server.listen(0, '127.0.0.1', () => {
  const child = spawn(process.argv[2] || 'C:/godot/Godot_v4.7.2-stable_win64_console.exe', [
    '--headless', '--path', path.resolve(__dirname, '..'), '--script', 'res://tests/updater_patches.gd', '--',
    folder, `http://127.0.0.1:${server.address().port}/`, hash(target), ...scenarios,
  ], { stdio: 'inherit' });
  const timeout = setTimeout(() => child.kill(), 90000);
  child.on('error', error => { console.error(error); child.emit('exit', 1); });
  child.on('exit', code => {
    clearTimeout(timeout);
    let failed = code !== 0;
    for (const scenario of scenarios) {
      const seen = requests[scenario] || [];
      const shouldFull = !['patch', 'older', 'reparent', 'chunked-patch', 'interrupted-patch', 'bad-version-signature'].includes(scenario);
      if (seen.filter(r => r === 'game.pck').length !== (shouldFull ? 1 : 0)) { console.error('Wrong fallback requests', scenario, seen); failed = true; }
      if (['legacy', 'bad-index-signature', 'bad-version-signature'].includes(scenario) && seen.some(r => r.includes('index.json'))) { console.error('Untrusted index requested', scenario); failed = true; }
      if (scenario === 'interrupted-patch' && seen.filter(r => r.endsWith('.tdpatch')).length !== 2) { console.error('Interrupted patch was not retried'); failed = true; }
    }
    console.log('HTTP routes/fallbacks: ' + (failed ? 'FAILED' : 'OK'));
    server.close();
    server.closeAllConnections();
    // Check the absolute cleanup target is our specific temporary fixture folder.
    if (path.dirname(path.resolve(folder)) === path.resolve(os.tmpdir()) && path.basename(folder).startsWith('tyrants-patches-')) fs.rmSync(folder, { recursive: true });
    process.exitCode = failed ? 1 : 0;
  });
});
