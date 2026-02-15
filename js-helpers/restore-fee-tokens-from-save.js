#!/usr/bin/env node
/**
 * Restore [[chainId.fee_tokens]] in deployments.toml from deployments-save.toml.
 * Uses fee field values (payloadPerByteFee, etc.) from save; replaces address
 * 0x375E2A148102bF179AE7743A28A34cF959bE9499 (any case) with
 * 0x70b52c6cdda7c6b881de77196edfdf5a704b55f2. Other addresses (e.g. 240) are kept.
 */
const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const savePath = path.join(rootDir, "deployments-save.toml");
const tomlPath = path.join(rootDir, "deployments.toml");

const OLD_ADDR = /0x375[eE]2[aA]148102[bB][fF]179[aA][eE]7743[aA]28[aA]34[cC][fF]959[bB][eE]9499/;
const NEW_ADDR = "0x70b52c6cdda7c6b881de77196edfdf5a704b55f2";

if (!fs.existsSync(savePath)) {
  console.error("deployments-save.toml not found");
  process.exit(1);
}
if (!fs.existsSync(tomlPath)) {
  console.error("deployments.toml not found");
  process.exit(1);
}

const saveText = fs.readFileSync(savePath, "utf8");
let tomlText = fs.readFileSync(tomlPath, "utf8");

// Extract from save: for each [[chainId.fee_tokens]] block, get chainId and block text (with address replaced if old)
const saveBlocks = new Map();
const blockRe = /\[\[(\d+)\.fee_tokens\]\]\n([\s\S]*?)(?=\n\n(?=\[|\#)|$)/g;
let m;
while ((m = blockRe.exec(saveText)) !== null) {
  const chainId = m[1];
  let block = m[2].trim();
  if (OLD_ADDR.test(block)) {
    block = block.replace(OLD_ADDR, NEW_ADDR);
  }
  saveBlocks.set(chainId, `[[${chainId}.fee_tokens]]\n${block}\n\n`);
}

// For each chainId in save, update deployments.toml: replace existing fee_tokens block(s) or insert before [chainId.string]
for (const [chainId, newBlock] of saveBlocks) {
  const stringSection = `[${chainId}.string]`;
  const idx = tomlText.indexOf(stringSection);
  if (idx === -1) continue;

  const sectionBefore = tomlText.slice(0, idx);
  const sectionAfter = tomlText.slice(idx);

  // Match one or more consecutive [[chainId.fee_tokens]] blocks so we replace with a single block
  const existingBlockRe = new RegExp(
    `(\\[\\[${chainId}\\.fee_tokens\\]\\][\\s\\S]*?(?=\\n\\n(?=\\[|\\#)|$))+`,
    "g"
  );
  const withNewBlock = sectionBefore.replace(existingBlockRe, newBlock);

  if (withNewBlock === sectionBefore) {
    const insertIdx = sectionBefore.length;
    tomlText = tomlText.slice(0, insertIdx) + newBlock + tomlText.slice(insertIdx);
  } else {
    tomlText = withNewBlock + sectionAfter;
  }
}

fs.writeFileSync(tomlPath, tomlText, "utf8");
console.log("Restored fee_tokens from deployments-save.toml into deployments.toml (old address -> new where applicable).");
console.log("Chains updated:", saveBlocks.size);
process.exit(0);
