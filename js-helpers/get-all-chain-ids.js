/**
 * Outputs all chain IDs from deployments.toml (top-level section keys [97], [421614], ...).
 * One chain ID per line, or JSON array if --json.
 * Usage: node js-helpers/get-all-chain-ids.js
 *        node js-helpers/get-all-chain-ids.js --json   # ["97","421614",...]
 */

const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const deploymentsPath = path.join(rootDir, "deployments.toml");

if (!fs.existsSync(deploymentsPath)) {
  console.error("deployments.toml not found");
  process.exit(1);
}

const toml = fs.readFileSync(deploymentsPath, "utf8");
const re = /^\[(\d+)\]\s*$/gm;
const ids = [];
let m;
while ((m = re.exec(toml)) !== null) {
  ids.push(m[1]);
}

if (process.argv.includes("--json")) {
  console.log(JSON.stringify(ids));
} else {
  ids.forEach((id) => console.log(id));
}
