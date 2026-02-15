/**
 * Outputs env vars for setFeeConfig: DAPP_MANAGER, FEE_TOKEN, PAYLOAD_PER_BYTE_FEE, GAS_PER_ETHER_FEE.
 * Reads from deployments.toml using the first [[chainId.fee_tokens]] entry.
 * Usage: eval $(node js-helpers/get-fee-config.js --chain-id 421614)
 *    or: eval $(node js-helpers/get-fee-config.js --chain arbitrum-sepolia)
 */

const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const deploymentsPath = path.join(rootDir, "deployments.toml");
const feeTokenPath = path.join(rootDir, "fee-token.json");

const CHAIN_NAME_TO_ID = { holesky: "17000" };

function getChainIdFromName(chainName) {
  if (CHAIN_NAME_TO_ID[chainName]) return CHAIN_NAME_TO_ID[chainName];
  if (!fs.existsSync(feeTokenPath)) return null;
  const list = JSON.parse(fs.readFileSync(feeTokenPath, "utf8"));
  const entry = list.find((e) => e.chain === chainName);
  return entry ? String(entry.chainId) : null;
}

function parseFirstFeeTokens(chainId, toml) {
  const sectionRe = new RegExp(
    `\\[\\[${chainId}\\.fee_tokens\\]\\]\\s*\\n` +
      `address\\s*=\\s*"([^"]*)"\\s*\\n` +
      `payloadPerByteFee\\s*=\\s*"([^"]*)"\\s*\\n` +
      `gasPerEtherFee\\s*=\\s*"([^"]*)"`,
    "s"
  );
  const m = toml.match(sectionRe);
  if (!m) return null;
  return { address: m[1], payloadPerByteFee: m[2], gasPerEtherFee: m[3] };
}

function parseDappManager(chainId, toml) {
  const sectionRe = new RegExp(
    `\\[${chainId}\\.address\\]\\s*\\n(?:[^\\n]*\\n)*?dappManager\\s*=\\s*"([^"]*)"`
  );
  const m = toml.match(sectionRe);
  return m ? m[1] : null;
}

let chainId = null;
for (let i = 0; i < process.argv.length; i++) {
  if (process.argv[i] === "--chain-id" && process.argv[i + 1]) {
    chainId = String(process.argv[i + 1]);
    break;
  }
  if (process.argv[i] === "--chain" && process.argv[i + 1]) {
    chainId = getChainIdFromName(process.argv[i + 1]);
    break;
  }
}

if (!chainId) {
  console.error("Usage: node get-fee-config.js --chain-id <id> | --chain <chain-name>");
  process.exit(1);
}

if (!fs.existsSync(deploymentsPath)) {
  console.error("deployments.toml not found");
  process.exit(1);
}

const toml = fs.readFileSync(deploymentsPath, "utf8");
const fee = parseFirstFeeTokens(chainId, toml);
const dappManager = parseDappManager(chainId, toml);

if (!fee || !dappManager) {
  console.error(`Could not find first fee_tokens or dappManager for chain ${chainId}`);
  process.exit(1);
}

// Output for eval: DAPP_MANAGER=... FEE_TOKEN=... PAYLOAD_PER_BYTE_FEE=... GAS_PER_ETHER_FEE=...
function shEscape(s) {
  return "'" + String(s).replace(/'/g, "'\"'\"'") + "'";
}
console.log(
  `DAPP_MANAGER=${shEscape(dappManager)} FEE_TOKEN=${shEscape(fee.address)} PAYLOAD_PER_BYTE_FEE=${shEscape(fee.payloadPerByteFee)} GAS_PER_ETHER_FEE=${shEscape(fee.gasPerEtherFee)}`
);
