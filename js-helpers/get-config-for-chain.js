/**
 * Outputs env vars for UpdateC3DApp: DAPP_MANAGER, FEE_TOKEN, PAYLOAD_PER_BYTE_FEE, GAS_PER_ETHER_FEE, RPC_URL_ENV.
 * Reads only from deployments.toml per chainId.
 * RPC_URL_ENV is the name of the env var for the RPC URL (e.g. ARBITRUM_SEPOLIA_RPC_URL); shell expands with ${!RPC_URL_ENV}.
 * Usage: eval $(node js-helpers/get-config-for-chain.js --chain-id 421614)
 */

const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const deploymentsPath = path.join(rootDir, "deployments.toml");

function parseEndpointUrl(chainId, toml) {
  const sectionRe = new RegExp(
    `\\[${chainId}\\]\\s*\\nendpoint_url\\s*=\\s*"\\$\\{([^}]+)\\}"`
  );
  const m = toml.match(sectionRe);
  return m ? m[1] : null;
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

function parseDappKey(chainId, toml) {
  const sectionRe = new RegExp(
    `\\[${chainId}\\.string\\]\\s*\\n(?:[^\\n]*\\n)*?dapp_key\\s*=\\s*"([^"]*)"`
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
}

if (!chainId) {
  console.error("Usage: node get-config-for-chain.js --chain-id <id>");
  process.exit(1);
}

if (!fs.existsSync(deploymentsPath)) {
  console.error("deployments.toml not found");
  process.exit(1);
}

const toml = fs.readFileSync(deploymentsPath, "utf8");
const fee = parseFirstFeeTokens(chainId, toml);
const dappManager = parseDappManager(chainId, toml);
const rpcUrlEnv = parseEndpointUrl(chainId, toml);

if (!fee || !dappManager) {
  console.error(`Could not find fee_tokens or dappManager for chain ${chainId} in deployments.toml`);
  process.exit(1);
}

if (!rpcUrlEnv) {
  console.error(`Could not find [${chainId}].endpoint_url in deployments.toml`);
  process.exit(1);
}

function shEscape(s) {
  return "'" + String(s).replace(/'/g, "'\"'\"'") + "'";
}

console.log(
  `DAPP_MANAGER=${shEscape(dappManager)} FEE_TOKEN=${shEscape(fee.address)} PAYLOAD_PER_BYTE_FEE=${shEscape(fee.payloadPerByteFee)} GAS_PER_ETHER_FEE=${shEscape(fee.gasPerEtherFee)} RPC_URL_ENV=${shEscape(rpcUrlEnv)}`
);
