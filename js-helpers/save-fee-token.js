/**
 * After deploying the fee token (TestUSD via DeployFeeToken.s.sol), run this to update
 * deployments.toml [[chainId.fee_tokens]] and fee-token.json from broadcast.
 * Usage: node save-fee-token.js <chain-name>
 * Example: node save-fee-token.js arbitrum-sepolia
 *
 * Resolves chainId from fee-token.json by chain name. Reads broadcast/DeployFeeToken.s.sol/<chainId>/
 * and uses the run file whose "chain" field matches chainId (run-latest.json if it matches, else
 * the latest run-<timestamp>.json for this chain), so the correct address is used even when
 * run-latest.json points at another chain's run.
 */

const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const feeTokenPath = path.join(rootDir, "fee-token.json");
const deploymentsPath = path.join(rootDir, "deployments.toml");
const broadcastDir = path.join(rootDir, "broadcast/DeployFeeToken.s.sol");

const chainName = process.argv[2];
if (!chainName) {
  console.error("Usage: node save-fee-token.js <chain-name>");
  console.error("Example: node save-fee-token.js arbitrum-sepolia");
  process.exit(1);
}

if (!fs.existsSync(feeTokenPath)) {
  console.error("fee-token.json not found");
  process.exit(1);
}
const feeTokenList = JSON.parse(fs.readFileSync(feeTokenPath, "utf8"));
const entry = feeTokenList.find((e) => e.chain === chainName);
if (!entry) {
  console.error(`Chain "${chainName}" not found in fee-token.json`);
  process.exit(1);
}
const chainId = String(entry.chainId);
const chainIdNum = Number(entry.chainId);
const chainDir = path.join(broadcastDir, chainId);
if (!fs.existsSync(chainDir)) {
  console.error(`Broadcast dir not found: ${chainDir}`);
  process.exit(1);
}

function parseRun(filePath) {
  const run = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const createTx = (run.transactions || []).find((t) => t.transactionType === "CREATE" && t.contractAddress);
  return { run, createTx };
}

let runPath = path.join(chainDir, "run-latest.json");
let run, createTx;
if (fs.existsSync(runPath)) {
  const parsed = parseRun(runPath);
  if (parsed.run.chain === chainIdNum || parsed.run.chain === chainId) {
    run = parsed.run;
    createTx = parsed.createTx;
  }
}
if (!createTx) {
  const files = (fs.readdirSync(chainDir) || []).filter((f) => /^run-\d+\.json$/.test(f));
  let best = null;
  for (const f of files) {
    const p = path.join(chainDir, f);
    try {
      const parsed = parseRun(p);
      if (!parsed.createTx) continue;
      if (parsed.run.chain !== chainIdNum && parsed.run.chain !== chainId) continue;
      const ts = parsed.run.timestamp || 0;
      if (best === null || ts > best.timestamp) best = { path: p, ...parsed, timestamp: ts };
    } catch (_) {}
  }
  if (!best) {
    console.error(`No broadcast for chain ${chainId} (${chainName}) in ${chainDir}`);
    process.exit(1);
  }
  runPath = best.path;
  run = best.run;
  createTx = best.createTx;
}
const address = createTx.contractAddress;

// Update fee-token.json
for (const e of feeTokenList) {
  if (String(e.chainId) === chainId) {
    e.address = address;
    e.error = null;
    break;
  }
}
fs.writeFileSync(feeTokenPath, JSON.stringify(feeTokenList, null, 2) + "\n", "utf8");
console.log(`Updated fee-token.json: ${chainName} (${chainId}) -> ${address}`);

// Patch deployments.toml: add address to [[chainId.fee_tokens]] if missing (append at end)
if (!fs.existsSync(deploymentsPath)) {
  console.log("deployments.toml not found, skipping");
  process.exit(0);
}
let tomlText = fs.readFileSync(deploymentsPath, "utf8");
const stringSectionIdx = tomlText.indexOf(`[${chainId}.string]`);
if (stringSectionIdx === -1) process.exit(0);
const sectionBefore = tomlText.slice(0, stringSectionIdx);
const feeTokenBlocks = sectionBefore.match(new RegExp(`\\[\\[${chainId}\\.fee_tokens\\]\\][^\\[]*`, "g"));
const alreadyInList =
  feeTokenBlocks && feeTokenBlocks.some((block) => block.includes(`address = "${address}"`));
if (!alreadyInList) {
  const firstBlock = (feeTokenBlocks && feeTokenBlocks[0]) || "";
  const payloadPerByteFee = (firstBlock.match(/payloadPerByteFee = "([^"]*)"/) || [null, ""])[1];
  const gasPerEtherFee = (firstBlock.match(/gasPerEtherFee = "([^"]*)"/) || [null, ""])[1];
  const gasToken = (firstBlock.match(/gasToken = "([^"]*)"/) || [null, ""])[1];
  const gasTokenPriceUSD = (firstBlock.match(/gasTokenPriceUSD = "([^"]*)"/) || [null, ""])[1];
  const insert =
    `[[${chainId}.fee_tokens]]\naddress = "${address}"\npayloadPerByteFee = "${payloadPerByteFee}"\ngasPerEtherFee = "${gasPerEtherFee}"\ngasToken = "${gasToken}"\ngasTokenPriceUSD = "${gasTokenPriceUSD}"\n\n`;
  tomlText = sectionBefore + insert + tomlText.slice(stringSectionIdx);
  fs.writeFileSync(deploymentsPath, tomlText, "utf8");
  console.log(`Added to deployments.toml: [[${chainId}.fee_tokens]] -> ${address}`);
}
