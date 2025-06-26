// npx hardhat run scripts/sendCSV.ts --network beam
import { ethers } from "hardhat";
import hre from "hardhat";

const tokenbeamerContract = "0xf88BA2d0A380615893325c51C23a33cB10C93478";
const tokenAddress = "0x02d6d189078bde6D548E0664B61Dd7ACea96f0Aa";

const batchSize = 256;

// Replace with your actual csv ("address,amount")
const csv = [
  "0xb410d2a8b78fda835a3f7ad79c6cf6422dbb8406,117.761879640471000",
  "0x448a51db3eb83ccfda55c4742fdb80bebdc272d8,136.487334518695000",
  "0x68631d5753db4be1090c51501d210a932f135863,79.7609491116278000",
  "0x59cdb9a7a07d16b458e940093befcd39963caa11,164.421370015029000",
];

const recipients: string[] = [];
const amounts: bigint[] = [];

csv.forEach((line) => {
  const [dirtyAddress, stringAmount] = line.split(",");
  const address = dirtyAddress.trim();

  if (!ethers.isAddress(address)) {
    throw new Error(`Invalid address: ${address}`);
  }
  if (!stringAmount) {
    throw new Error(`Amount missing for address: ${address}`);
  }

  const amount = ethers.parseUnits(stringAmount.trim(), 18);
  if (amount <= 0n) {
    console.error(`Zero amount for address ${address}: ${stringAmount}, ignoring`);
    return;
  }

  recipients.push(address);
  amounts.push(amount);
});

async function main() {
  // Get signer (assumes you have a local account configured)
  const [ledgerSigner] = await hre.ethers.getSigners();

  const TokenBeamer = await hre.ethers.getContractAt("TokenBeamer", tokenbeamerContract, ledgerSigner);

  // Process in batches
  for (let i = 0; i < recipients.length; i += batchSize) {
    const batchAddresses = recipients.slice(i, i + batchSize);
    const batchAmounts = amounts.slice(i, i + batchSize);
    console.log(`Beaming tokens to batch ${i / batchSize + 1}: ${batchAddresses.length} recipients`);

    const batchTokens = batchAddresses.map(() => tokenAddress);
    const batchTypes = batchAddresses.map(() => 20);
    const batchIds = batchAddresses.map(() => 0n);

    const tx = await TokenBeamer.beamTokens(batchAddresses, batchTokens, batchTypes, batchIds, batchAmounts);
    console.log(`Transaction submitted: ${tx.hash}`);

    // wait before confirming the transaction
    await new Promise((resolve) => setTimeout(resolve, 4000));
    await tx.wait();
    console.log(`Transaction confirmed\n`);
  }

  console.log("✅ All batches processed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
