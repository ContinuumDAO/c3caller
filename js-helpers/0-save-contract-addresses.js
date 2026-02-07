/**
 * Uses deployments.toml as the source of truth.
 * - Reads deployments.toml and (if present) broadcast/DeployC3Caller.s.sol/<chainId>/run-latest.json.
 * - Merges broadcast addresses (uuidKeeper, dappManager, c3caller) into the config for deployed chains.
 * - Writes contract-addresses.json. If broadcast was merged, patches deployments.toml in place (address lines only) so comments are preserved.
 *
 * Run after deploy to push new addresses from broadcast into both deployments.toml and contract-addresses.json.
 */

const fs = require("fs");
const path = require("path");
const TOML = require("@iarna/toml");

const rootDir = path.join(__dirname, "..");
const deploymentsPath = path.join(rootDir, "deployments.toml");
const broadcastDir = path.join(rootDir, "broadcast/DeployC3Caller.s.sol");
const feeTokenPath = path.join(rootDir, "fee-token.json");
const outputJsonPath = path.join(rootDir, "contract-addresses.json");

// Build chain name -> chain ID from fee-token.json so we support both numeric and name keys in deployments.toml
let chainNameToId = {};
if (fs.existsSync(feeTokenPath)) {
  try {
    const feeToken = JSON.parse(fs.readFileSync(feeTokenPath, "utf8"));
    for (const entry of feeToken) {
      if (entry.chain && entry.chainId != null) chainNameToId[entry.chain] = String(entry.chainId);
    }
  } catch (e) {
    // ignore
  }
}
function toChainId(key) {
  if (/^\d+$/.test(String(key))) return String(key);
  return chainNameToId[key] || null;
}

if (!fs.existsSync(deploymentsPath)) {
  console.error("Error: deployments.toml not found");
  console.error(`Expected: ${deploymentsPath}`);
  process.exit(1);
}

// Load deployments.toml (source of truth)
const tomlContent = fs.readFileSync(deploymentsPath, "utf8");
let config;
try {
  config = TOML.parse(tomlContent);
} catch (err) {
  console.error("Error parsing deployments.toml:", err.message);
  process.exit(1);
}

let mergedFromBroadcast = false;
const mergedChainIds = [];

// Optionally merge in addresses from broadcast
if (fs.existsSync(broadcastDir)) {
  const chainDirs = fs.readdirSync(broadcastDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== "31337")
    .map((d) => d.name);

  for (const chainId of chainDirs) {
    const runPath = path.join(broadcastDir, chainId, "run-latest.json");
    if (!fs.existsSync(runPath)) continue;

    try {
      const run = require(runPath);
      const addresses = {};
      for (const tx of run.transactions || []) {
        if (tx.transactionType !== "CREATE" || !tx.contractAddress) continue;
        switch (tx.contractName) {
          case "C3UUIDKeeper":
            addresses.uuidKeeper = tx.contractAddress;
            break;
          case "C3DAppManager":
            addresses.dappManager = tx.contractAddress;
            break;
          case "C3Caller":
            addresses.c3caller = tx.contractAddress;
            break;
        }
      }
      if (addresses.uuidKeeper || addresses.dappManager || addresses.c3caller) {
        const key = String(chainId);
        if (!config[key]) config[key] = {};
        if (!config[key].address) config[key].address = {};
        if (addresses.uuidKeeper) config[key].address.uuidKeeper = addresses.uuidKeeper;
        if (addresses.dappManager) config[key].address.dappManager = addresses.dappManager;
        if (addresses.c3caller) config[key].address.c3caller = addresses.c3caller;
        mergedFromBroadcast = true;
        mergedChainIds.push(String(chainId));
        console.log(`Merged broadcast addresses for chain ${chainId}`);
      }
    } catch (e) {
      console.warn(`Warning: could not process chain ${chainId}:`, e.message);
    }
  }
}

// Build contract-addresses.json from config (same shape as before). Support numeric or chain-name keys.
const contractAddresses = {};
for (const [key, chain] of Object.entries(config)) {
  const chainId = toChainId(key);
  if (!chainId || !chain || typeof chain !== "object") continue;
  const addr = chain.address;
  const str = chain.string;
  if (!addr || !addr.dappManager) continue;
  contractAddresses[chainId] = {
    uuidKeeper: addr.uuidKeeper || "",
    dappManager: addr.dappManager,
    c3caller: addr.c3caller || "",
    dapp_key: (str && str.dapp_key) || "v1.ctm.continuumdao",
    metadata: (str && str.metadata) || '{"version":1,"name":"CTM","description":"CTM","email":"continuumdao@proton.me","url":"continuumdao.org"}',
  };
}

// Write contract-addresses.json
fs.writeFileSync(outputJsonPath, JSON.stringify(contractAddresses, null, 2), "utf8");
console.log(`Source: ${deploymentsPath}`);
console.log(`Generated: ${outputJsonPath}`);
console.log(`Chains: ${Object.keys(contractAddresses).join(", ")}`);

// If we merged from broadcast, patch deployments.toml in place (address lines only) to preserve comments
if (mergedFromBroadcast && mergedChainIds.length > 0) {
  let tomlText = fs.readFileSync(deploymentsPath, "utf8");
  for (const chainId of mergedChainIds) {
    const addr = config[chainId] && config[chainId].address;
    if (!addr || !addr.dappManager) continue;
    const blockRe = new RegExp(
      `(\\[${chainId}\\.address\\]\\n)(uuidKeeper = ")[^"]*("\\n)(dappManager = ")[^"]*("\\n)(c3caller = ")[^"]*("\\n)`,
      "g"
    );
    const replacement = `$1$2${addr.uuidKeeper}$3$4${addr.dappManager}$5$6${addr.c3caller}$7`;
    tomlText = tomlText.replace(blockRe, replacement);
  }
  fs.writeFileSync(deploymentsPath, tomlText, "utf8");
  console.log(`Updated: ${deploymentsPath} (chains ${mergedChainIds.join(", ")})`);
}
