// Syntax-checks Lua files with luaparse (Lua 5.1 grammar, as used by WoW).
// Usage: node check-lua.js <luaparse.js path> <file1.lua> [file2.lua ...]
const fs = require('fs');
const luaparse = require(process.argv[2]);

let failed = 0;
for (const file of process.argv.slice(3)) {
  try {
    luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
    console.log('OK    ' + file);
  } catch (e) {
    failed++;
    console.log('ERROR ' + file + ': ' + e.message);
  }
}
console.log(failed ? `${failed} file(s) with errors` : 'All files OK');
process.exit(failed ? 1 : 0);
