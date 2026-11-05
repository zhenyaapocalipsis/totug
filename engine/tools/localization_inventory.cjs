/* Read-only extraction of localization sources. Location IDs are review IDs,
 * not runtime translation keys. Run from any directory with Node.js. */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const game = path.join(root, 'engine/godot');
const output = path.join(root, 'Codex outputs/localization');
const relative = p => path.relative(root, p).replaceAll('\\', '/');
const hash = s => crypto.createHash('sha256').update(s).digest('hex');
function walk(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name, 'en')).flatMap(e => {
    if (['.godot', '.git', 'node_modules'].includes(e.name)) return [];
    const p = path.join(dir, e.name);
    return e.isDirectory() ? walk(p) : [p];
  });
}
// Lexer retains source escapes and skips # comments only outside strings.
// It also handles single quotes, triple quotes, and escaped quote characters.
function literals(source) {
  const result = [];
  let i = 0, line = 1, column = 1;
  const advance = () => { if (source[i++] === '\n') { line++; column = 1; } else column++; };
  while (i < source.length) {
    if (source[i] === '#') { while (i < source.length && source[i] !== '\n') advance(); continue; }
    const quote = source[i];
    if (quote !== '"' && quote !== "'") { advance(); continue; }
    const startLine = line, startColumn = column;
    const delimiter = source.startsWith(quote.repeat(3), i) ? quote.repeat(3) : quote;
    for (let k = 0; k < delimiter.length; k++) advance();
    const start = i;
    while (i < source.length && !source.startsWith(delimiter, i)) {
      if (source[i] === '\\') { advance(); if (i < source.length) advance(); }
      else advance();
    }
    if (i >= source.length) throw new Error(`Unclosed string at ${startLine}:${startColumn}`);
    const text = source.slice(start, i);
    for (let k = 0; k < delimiter.length; k++) advance();
    result.push({line: startLine, column: startColumn, delimiter, text});
  }
  return result;
}
function classify(text) {
  if (!/[A-Za-zА-Яа-яЁё]/u.test(text)) return 'symbol_or_format';
  if (/^(res:\/\/|user:\/\/|https?:\/\/)|\.(gd|tscn|png|json|ogg|mp3|cfg|shader)\b/i.test(text)) return 'path_or_reference';
  if (/^[a-z][a-z0-9_]*$/.test(text)) return 'identifier_or_short_text';
  if (/^[A-Z][A-Z0-9_]*$/.test(text)) return 'enum_or_caption';
  return 'text_candidate';
}
const rendererTools = ['pixel_cards.gd', 'build_pixel_font.gd', 'alt_arts.gd'];
const sourceFiles = walk(game).filter(p => /\.(gd|tscn|godot)$/.test(p) && !/[\\/]tests[\\/]/.test(p)
  && (!/[\\/]tools[\\/]/.test(p) || rendererTools.includes(path.basename(p))));
const sourceRows = [], dependencyRows = [], inputs = [];
for (const file of sourceFiles) {
  const source = fs.readFileSync(file, 'utf8');
  const rel = relative(file);
  inputs.push({file: rel, sha256: hash(source)});
  for (const token of literals(source)) sourceRows.push({id: `${rel}:${token.line}:${token.column}`, file: rel, ...token,
    category: classify(token.text), key: '', ru: '', status: 'needs_review'});
  source.split('\n').forEach((text, index) => {
    if (text.trimStart().startsWith('#')) return;
    if (/begins_with\("[A-Z]|find\(phrase|NAMES\.get\(text|SITE_NAMES\.has|SHORT_NAMES\.has/.test(text))
      dependencyRows.push({file: rel, line: index + 1, source: text.trim(), status: 'needs_semantic_id_review'});
  });
}
const dataRows = [];
for (const file of walk(path.join(game, 'data')).filter(p => p.endsWith('.json'))) {
  const source = fs.readFileSync(file, 'utf8'), rel = relative(file);
  inputs.push({file: rel, sha256: hash(source)});
  const visit = (value, pointer, field) => {
    if (typeof value === 'string') {
      const category = ['name', 'ability_text', 'flavor', 'text'].includes(field) ? 'display_field'
        : ['type', 'race', 'aspect'].includes(field) ? 'mechanical_enum_needs_display_mapping' : classify(value);
      dataRows.push({file: rel, pointer, text: value, category, key: '', ru: '', status: 'needs_review'});
    } else if (value && typeof value === 'object') {
      for (const [k, v] of Object.entries(value)) visit(v, pointer + '/' + k.replaceAll('~', '~0').replaceAll('/', '~1'), k);
    }
  };
  visit(JSON.parse(source), '', '');
}
const cards = JSON.parse(fs.readFileSync(path.join(game, 'data/cards/cards.json'), 'utf8'));
const decks = JSON.parse(fs.readFileSync(path.join(game, 'data/cards/half_decks.json'), 'utf8')).half_decks;
const cardRows = cards.map(c => ({card_id: String(c.card_id), half_decks: Object.entries(decks).filter(([, d]) => Object.hasOwn(d.copies, String(c.card_id))).map(([id]) => id).join(','),
  name_key: `card.${c.card_id}.name`, name_en: c.name, name_ru: '',
  ability_key: `card.${c.card_id}.ability`, ability_en: c.ability_text, ability_ru: '',
  aspect: c.aspect, type: c.type, race: c.race ?? '', status: 'not_translated'}));
if (new Set(cardRows.map(c => c.card_id)).size !== cards.length) throw new Error('Duplicate card_id');
const counts = rows => rows.reduce((out, row) => { out[row.category] = (out[row.category] || 0) + 1; return out; }, {});
const summary = {schema_version: 1, source_files: sourceFiles.length, input_files: inputs,
  source_literals: sourceRows.length, source_categories: counts(sourceRows),
  data_string_values: dataRows.length, data_categories: counts(dataRows),
  cards: cards.length, half_decks: Object.keys(decks).length,
  unassigned_cards: cardRows.filter(c => !c.half_decks).map(c => c.card_id),
  dependencies: dependencyRows.length,
  note: 'Mechanical inventory, not a validated translation catalog. Review all categories. Comments and tests excluded; tools excluded except pixel_cards.gd/build_pixel_font.gd/alt_arts.gd. Source escapes retained. TSCN/Godot extraction covers quoted values. Runtime keys require manual semantic assignment; card keys are proposed stable IDs.'};
const tsv = rows => {
  if (!rows.length) return '';
  const columns = Object.keys(rows[0]);
  const cell = v => String(v ?? '').replaceAll('\\', '\\\\').replaceAll('\t', '\\t').replaceAll('\r', '\\r').replaceAll('\n', '\\n');
  return columns.join('\t') + '\n' + rows.map(r => columns.map(k => cell(r[k])).join('\t')).join('\n') + '\n';
};
fs.mkdirSync(output, {recursive: true});
for (const [name, value] of Object.entries({'inventory_summary.json': summary, 'source_strings.json': sourceRows, 'data_strings.json': dataRows, 'text_dependencies.json': dependencyRows}))
  fs.writeFileSync(path.join(output, name), Array.isArray(value)
    ? '[\n' + value.map(row => JSON.stringify(row)).join(',\n') + '\n]\n'
    : JSON.stringify(value, null, 2) + '\n', 'utf8');
fs.writeFileSync(path.join(output, 'cards_translation.tsv'), tsv(cardRows), 'utf8');
console.log(JSON.stringify({...summary, input_files: summary.input_files.length}, null, 2));
