// Regenerates expected.json: one review round on source.md, run through the
// VS Code extension's own Markdown Browser code (its compiled review-marks
// and markdownBrowserEdits, its webview's blocks.js), so the Dart test holds
// tom_md_editor to the same file. Run from tom_md_editor:
//   node test/fixtures/review_round/generate_expected.js <path to tom_vscode_extension>
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ext = path.resolve(process.argv[2]);
const marks = require(path.join(ext, 'out/services/review-marks.js'));
const edits = require(path.join(ext, 'out/utils/markdownBrowserEdits.js'));
const blocks = {};
vm.createContext(blocks);
vm.runInContext(fs.readFileSync(path.join(ext, 'media/markdownBrowser/blocks.js'), 'utf-8'), blocks);

const here = __dirname;
let text = fs.readFileSync(path.join(here, 'source.md'), 'utf-8');
const steps = [];
const lines = () => text.split('\n');
const lineOf = (needle) => lines().findIndex((l) => l.includes(needle));
const apply = (r) => { if (!r.ok) throw new Error(r.reason); text = r.text; };

// 1. A comment after the scope paragraph, by Alexis, with the next id.
{
  const at = lineOf('Replace per-region');
  const nextId = blocks.mdbNextCommentId(text);
  const written = blocks.mdbWriteComment('Start with the EU.', nextId, 'Alexis');
  const ls = lines();
  const source = ls.slice(at, at + 1).join('\n');
  const after = ls[at + 1] !== undefined && ls[at + 1].trim() !== '' ? '\n' : '';
  apply(edits.applyMdLineEdit(text, { startLine: at, endLine: at + 1, expected: source, replacement: source + '\n\n' + written + after }));
  steps.push({ op: 'addComment', startLine: at, endLine: at + 1, text: 'Start with the EU.', author: 'Alexis', nextId, expected: text });
}
// 2. Accept the substitution in the first paragraph.
{
  const at = lineOf('Unify three');
  const block = lines()[at];
  apply(marks.reviewMarkEdit(text, { startLine: at, endLine: at + 1, expected: block, markup: '{~~one~>a single~~}', occurrence: 0, decision: 'accept' }));
  steps.push({ op: 'decideMark', startLine: at, endLine: at + 1, blockText: block, markup: '{~~one~>a single~~}', occurrence: 0, decision: 'accept', expected: text });
}
// 3. Reject the deletion in the scope paragraph.
{
  const at = lineOf('Replace per-region');
  const block = lines()[at];
  apply(marks.reviewMarkEdit(text, { startLine: at, endLine: at + 1, expected: block, markup: '{-- that nobody owns--}', occurrence: 0, decision: 'reject' }));
  steps.push({ op: 'decideMark', startLine: at, endLine: at + 1, blockText: block, markup: '{-- that nobody owns--}', occurrence: 0, decision: 'reject', expected: text });
}
// 4. Remove the highlight's comment.
{
  const at = lineOf('Three systems');
  const block = lines()[at];
  apply(marks.reviewMarkEdit(text, { startLine: at, endLine: at + 1, expected: block, markup: '{==no shared customer record==}{>>the root cause<<}', occurrence: 0, decision: 'remove' }));
  steps.push({ op: 'decideMark', startLine: at, endLine: at + 1, blockText: block, markup: '{==no shared customer record==}{>>the root cause<<}', occurrence: 0, decision: 'remove', expected: text });
}
// 5. Answer the question in place.
{
  const at = lineOf('**Answer:**');
  const was = lines()[at];
  apply(edits.applyMdLineEdit(text, { startLine: at, endLine: at + 1, expected: was, replacement: '> **Answer:** (b) because the US volume is larger.' }));
  steps.push({ op: 'lineEdit', startLine: at, endLine: at + 1, expectedLines: was, replacement: '> **Answer:** (b) because the US volume is larger.', expected: text });
}
// 6. Edit comment C-1.
{
  const at = lineOf('**C-1**');
  const ls = lines();
  const comment = blocks.mdbCommentAt(ls, at);
  const written = blocks.mdbWriteComment('⬆️ **C-1** (Reviewer): Is the EU region in scope? Yes.', blocks.mdbNextCommentId(text), 'Alexis');
  apply(edits.applyMdLineEdit(text, { startLine: comment.startLine, endLine: comment.endLine, expected: ls.slice(comment.startLine, comment.endLine).join('\n'), replacement: written }));
  steps.push({ op: 'editComment', line: at, text: '⬆️ **C-1** (Reviewer): Is the EU region in scope? Yes.', author: 'Alexis', expected: text });
}
// 7. Accept every remaining change.
{
  const r = marks.decideAllChanges(text, 'accept');
  text = r.text;
  steps.push({ op: 'decideAll', decision: 'accept', decided: r.decided, expected: text });
}
fs.writeFileSync(path.join(here, 'expected.json'), JSON.stringify({ steps }, null, 2) + '\n');
console.log(`wrote ${steps.length} steps`);
