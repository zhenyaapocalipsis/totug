// Signed binary deltas. Node is needed on the build PC only, never by players.
// Content-defined boundaries keep matching after insertions/reordered PCK data.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const os = require('node:os');
const MAGIC = Buffer.from('TYRDELTA');
const KEEP = 5;
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const gear = new Uint32Array(256);
let seed = 0x718afb31;
for (let i = 0; i < gear.length; i++) {
  seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5;
  gear[i] = seed >>> 0;
}
function* chunks(data) {
  let start = 0, rolling = 0;
  for (let i = 0; i < data.length; i++) {
    rolling = ((rolling << 1) + gear[data[i]]) >>> 0;
    const size = i + 1 - start;
    if (size >= 262144 || (size >= 16384 && (rolling & 65535) === 0)) {
      yield [start, size]; start = i + 1; rolling = 0;
    }
  }
  if (start < data.length) yield [start, data.length - start];
}
function makePatch(base, target, build) {
  const index = new Map();
  for (const [offset, size] of chunks(base)) index.set(hash(base.subarray(offset, offset + size)), [offset, size]);
  const ops = [], literals = [];
  let payloadSize = 0;
  for (const [offset, size] of chunks(target)) {
    const bytes = target.subarray(offset, offset + size);
    const match = index.get(hash(bytes));
    const kind = match ? 0 : 1;
    const source = match ? match[0] : payloadSize;
    const last = ops.at(-1);
    if (last && last[0] === kind && last[1] + last[2] === source) last[2] += size;
    else ops.push([kind, source, size]);
    if (!match) { literals.push(bytes); payloadSize += size; }
  }
  const header = Buffer.from(JSON.stringify({ format: 1, build, from_sha: hash(base), target_sha: hash(target), target_size: target.length, ops }));
  const prefix = Buffer.alloc(12);
  MAGIC.copy(prefix); prefix.writeUInt32LE(header.length, 8);
  return Buffer.concat([prefix, header, ...literals]);
}
function publicKey() {
  return fs.readFileSync(path.join(__dirname, '../engine/godot/scenes/update_key.gd'), 'utf8').match(/-----BEGIN PUBLIC KEY-----[\s\S]*?-----END PUBLIC KEY-----/)[0];
}
function readVersion(dir) {
  const parts = fs.readFileSync(path.join(dir, 'version.txt'), 'utf8').trim().split(/\s+/);
  const [build, sha, signature] = parts;
  if (!/^\d+$/.test(build) || !/^[0-9a-f]{64}$/.test(sha) || !crypto.verify('sha256', Buffer.from(`${build} ${sha}`), publicKey(), Buffer.from(signature || '', 'base64'))) throw Error('Invalid signed build in ' + dir);
  return { build: Number(build), sha, parts };
}
function archive(buildDir) {
  if (!fs.existsSync(path.join(buildDir, 'version.txt'))) return;
  const version = readVersion(buildDir);
  const source = path.join(buildDir, 'TyrantsOfTheUnderdark.pck');
  if (hash(fs.readFileSync(source)) !== version.sha) throw Error('Current PCK differs from version.txt; refusing to lose the patch base');
  const out = path.join(buildDir, 'releases', String(version.build));
  fs.mkdirSync(out, { recursive: true });
  if (!fs.existsSync(path.join(out, 'game.pck'))) fs.copyFileSync(source, path.join(out, 'game.pck'));
  fs.copyFileSync(path.join(buildDir, 'version.txt'), path.join(out, 'version.txt'));
  console.log('Preserved patch base ' + version.build);
}
function generate(buildDir, keyPath) {
  const version = readVersion(buildDir);
  const target = fs.readFileSync(path.join(buildDir, 'TyrantsOfTheUnderdark.pck'));
  if (hash(target) !== version.sha) throw Error('Target PCK hash differs');
  const history = path.resolve(buildDir, 'releases');
  const builds = fs.existsSync(history) ? fs.readdirSync(history).filter(n => /^\d+$/.test(n) && Number(n) < version.build).sort((a, b) => Number(b) - Number(a)) : [];
  const out = path.join(buildDir, 'patches', String(version.build));
  fs.mkdirSync(out, { recursive: true });
  const patches = [];
  for (const name of builds.slice(0, KEEP)) {
    const dir = path.join(history, name);
    const baseVersion = readVersion(dir);
    const base = fs.readFileSync(path.join(dir, 'game.pck'));
    if (hash(base) !== baseVersion.sha) throw Error('Damaged patch base ' + name);
    if (patches.some(p => p.from_sha === baseVersion.sha)) continue;
    const patch = makePatch(base, target, version.build);
    if (patch.length >= target.length * 0.9) {
      console.log('Base ' + name + ': full package is more efficient'); continue;
    }
    fs.writeFileSync(path.join(out, baseVersion.sha + '.tdpatch'), patch);
    patches.push({ from_sha: baseVersion.sha, sha256: hash(patch), size: patch.length });
    console.log(`Patch ${name} -> ${version.build}: ${patch.length} bytes vs ${target.length} full`);
  }
  const index = Buffer.from(JSON.stringify({ format: 1, build: version.build, target_sha: version.sha, target_size: target.length, patches }));
  const indexSha = hash(index);
  const signature = crypto.sign('sha256', Buffer.from(`${version.build} ${indexSha}`), fs.readFileSync(keyPath)).toString('base64');
  if (!crypto.verify('sha256', Buffer.from(`${version.build} ${indexSha}`), publicKey(), Buffer.from(signature, 'base64'))) throw Error('Wrong patch signing key');
  fs.writeFileSync(path.join(out, 'index.json'), index);
  // First three fields are unchanged: legacy clients still download game.pck.
  fs.writeFileSync(path.join(buildDir, 'version.txt'), version.parts.slice(0, 3).join(' ') + ` ${indexSha} ${signature}\n`);
  // Only numeric release directories directly beneath our known history root.
  for (const name of builds.slice(KEEP)) {
    const child = path.resolve(history, name);
    if (path.dirname(child) !== history || !/^\d+$/.test(path.basename(child))) throw Error('Unsafe history path');
    fs.rmSync(child, { recursive: true });
  }
}
function validate(buildDir) {
  const version = readVersion(buildDir);
  if (hash(fs.readFileSync(path.join(buildDir, 'TyrantsOfTheUnderdark.pck'))) !== version.sha) throw Error('Target PCK hash differs');
  const indexBytes = fs.readFileSync(path.join(buildDir, 'patches', String(version.build), 'index.json'));
  const indexSha = hash(indexBytes);
  if (version.parts[3] !== indexSha || !crypto.verify('sha256', Buffer.from(`${version.build} ${indexSha}`), publicKey(), Buffer.from(version.parts[4] || '', 'base64'))) throw Error('Invalid signed patch index');
  const index = JSON.parse(indexBytes);
  if (index.format !== 1 || index.build !== version.build || index.target_sha !== version.sha || index.target_size !== fs.statSync(path.join(buildDir, 'TyrantsOfTheUnderdark.pck')).size) throw Error('Patch index target differs');
  for (const entry of index.patches) {
    if (!/^[0-9a-f]{64}$/.test(entry.from_sha)) throw Error('Invalid patch base');
    const bytes = fs.readFileSync(path.join(buildDir, 'patches', String(version.build), entry.from_sha + '.tdpatch'));
    if (bytes.length !== entry.size || hash(bytes) !== entry.sha256) throw Error('Damaged patch ' + entry.from_sha);
  }
  console.log('Verified signed release ' + version.build + ': ' + index.patches.length + ' patches');
}
if (require.main === module) {
  try {
    const [command, dir, key] = process.argv.slice(2);
    if (!dir || !['archive', 'generate', 'validate'].includes(command)) throw Error('Usage: node server/update_patches.cjs archive|generate|validate <build-dir> [private-key]');
    if (command === 'archive') archive(path.resolve(dir));
    else if (command === 'validate') validate(path.resolve(dir));
    else generate(path.resolve(dir), key || path.join(os.homedir(), '.ssh/tyrants_update.key'));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { makePatch, hash };
