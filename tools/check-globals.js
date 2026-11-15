// Lists assignments to global variables (usually a missing "local" or a typo).
// Usage: node check-globals.js <luaparse.js path> <file1.lua> [...]
const fs = require('fs');
const luaparse = require(process.argv[2]);

function walk(node, visit) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) { node.forEach(n => walk(n, visit)); return; }
  visit(node);
  for (const key of Object.keys(node)) {
    if (key !== 'loc' && key !== 'range') walk(node[key], visit);
  }
}

for (const file of process.argv.slice(3)) {
  const ast = luaparse.parse(fs.readFileSync(file, 'utf8'),
    { luaVersion: '5.1', scope: true, locations: true });
  walk(ast, n => {
    if (n.type === 'AssignmentStatement') {
      for (const v of n.variables) {
        if (v.type === 'Identifier' && !v.isLocal) {
          console.log(`${file}:${v.loc.start.line}  global assignment: ${v.name}`);
        }
      }
    }
    if (n.type === 'FunctionDeclaration' && !n.isLocal && n.identifier && n.identifier.type === 'Identifier') {
      console.log(`${file}:${n.loc.start.line}  global function: ${n.identifier.name}`);
    }
  });
}
