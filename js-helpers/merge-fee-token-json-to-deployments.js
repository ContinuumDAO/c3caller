/**
 * Merges fee-token.json into deployments.toml: for each chain with an address,
 * sets [chainId.address].fee_token and ensures that address is in [[chainId.fee_tokens]]
 * (appends a block if missing). Used after deploy-fee-token-all.sh.
 */

const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const feeTokenPath = path.join(rootDir, "fee-token.json");
const deploymentsPath = path.join(rootDir, "deployments.toml");

if (!fs.existsSync(feeTokenPath) || !fs.existsSync(deploymentsPath)) {
  console.error("fee-token.json or deployments.toml not found");
  process.exit(1);
}

const feeTokenList = JSON.parse(fs.readFileSync(feeTokenPath, "utf8"));
let tomlText = fs.readFileSync(deploymentsPath, "utf8");
let updated = 0;

for (const entry of feeTokenList) {
  const address = entry.address;
  if (!address || typeof address !== "string" || !address.startsWith("0x")) continue;
  const chainId = String(entry.chainId);

  // 1) Update primary fee_token line for this chainId
  const feeTokenRe = new RegExp(
    `(\\[${chainId}\\.address\\]\\n(?:[^\\n]*\\n){3})(fee_token = ")[^"]*("\\n)`
  );
  const before = tomlText;
  tomlText = tomlText.replace(feeTokenRe, `$1$2${address}$3`);
  if (tomlText !== before) updated++;

  // 2) Ensure this address is in [[chainId.fee_tokens]]
  const stringSectionIdx = tomlText.indexOf(`[${chainId}.string]`);
  if (stringSectionIdx === -1) continue;
  const sectionBefore = tomlText.slice(0, stringSectionIdx);
  const feeTokenBlocks = sectionBefore.match(new RegExp(`\\[\\[${chainId}\\.fee_tokens\\]\\][^\\[]*`, "g"));
  const alreadyInList =
    feeTokenBlocks && feeTokenBlocks.some((block) => block.includes(`address = "${address}"`));
  if (!alreadyInList) {
    const insert =
      `[[${chainId}.fee_tokens]]\naddress = "${address}"\npayloadPerByteFee = ""\ngasPerEtherFee = ""\ngasToken = ""\ngasTokenPriceUSD = ""\n\n`;
    tomlText = tomlText.slice(0, stringSectionIdx) + insert + tomlText.slice(stringSectionIdx);
    updated++;
  }
}

fs.writeFileSync(deploymentsPath, tomlText, "utf8");
console.log(`Merged fee-token.json into deployments.toml (${updated} updates)`);
