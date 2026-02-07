/**
 * After deploying the fee token (TestUSD via DeployFeeToken.s.sol), run this to update
 * deployments.toml ([chainId.address].fee_token) and fee-token.json from broadcast.
 * Usage: node save-fee-token.js <chain-name>
 * Example: node save-fee-token.js arbitrum-sepolia
 *
 * Resolves chainId from fee-token.json by chain name. Reads broadcast/DeployFeeToken.s.sol/<chainId>/run-latest.json.
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

const runPath = path.join(broadcastDir, chainId, "run-latest.json");
if (!fs.existsSync(runPath)) {
  console.error(`Broadcast not found: ${runPath}`);
  process.exit(1);
}

const run = JSON.parse(fs.readFileSync(runPath, "utf8"));
const createTx = (run.transactions || []).find((t) => t.transactionType === "CREATE" && t.contractAddress);
if (!createTx) {
  console.error("No CREATE transaction in broadcast");
  process.exit(1);
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

// Patch deployments.toml: [chainId.address] fee_token = "..." and add to [[chainId.fee_tokens]] if missing
if (!fs.existsSync(deploymentsPath)) {
  console.log("deployments.toml not found, skipping");
  process.exit(0);
}
let tomlText = fs.readFileSync(deploymentsPath, "utf8");
let changed = false;
// 1) Update primary fee_token line
const feeTokenRe = new RegExp(
  `(\\[${chainId}\\.address\\]\\n(?:[^\\n]*\\n){3})(fee_token = ")[^"]*("\\n)`
);
const afterFeeToken = tomlText.replace(feeTokenRe, `$1$2${address}$3`);
if (afterFeeToken !== tomlText) {
  tomlText = afterFeeToken;
  changed = true;
  console.log(`Updated deployments.toml: [${chainId}.address].fee_token -> ${address}`);
}
// 2) Ensure this address is in [[chainId.fee_tokens]]; if not, append one block before [chainId.string]
const stringSectionIdx = tomlText.indexOf(`[${chainId}.string]`);
if (stringSectionIdx !== -1) {
  const sectionBefore = tomlText.slice(0, stringSectionIdx);
  const feeTokenBlocks = sectionBefore.match(new RegExp(`\\[\\[${chainId}\\.fee_tokens\\]\\][^\\[]*`, "g"));
  const alreadyInList =
    feeTokenBlocks && feeTokenBlocks.some((block) => block.includes(`address = "${address}"`));
  if (!alreadyInList) {
    const insert =
      `[[${chainId}.fee_tokens]]\naddress = "${address}"\npayloadPerByteFee = ""\ngasPerEtherFee = ""\ngasToken = ""\ngasTokenPriceUSD = ""\n\n`;
    tomlText = tomlText.slice(0, stringSectionIdx) + insert + tomlText.slice(stringSectionIdx);
    changed = true;
    console.log(`Added to deployments.toml: [[${chainId}.fee_tokens]] -> ${address}`);
  }
}
if (changed) fs.writeFileSync(deploymentsPath, tomlText, "utf8");
