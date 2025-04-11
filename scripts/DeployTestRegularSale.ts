import "@nomiclabs/hardhat-ethers";
import { deploy, getContractAt } from "./utils/helpers";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import { network } from "hardhat";
import { RegularSale, TestERC20 } from "../artifacts/types";

interface SalesOutput {
  RS: string;
  VRS: string;
  PS: string;
  VPS: string;
}

async function main() {
  const testRS = await deploy<RegularSale>("RegularSale");
  const startTime = Math.floor(Date.now() / 1000) + 3600; // 1 hour
  const duration = 345600; // 4 days
  await testRS.initialize(
    "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578",
    startTime,
    duration,
    "0x33a2F2d21afbc7E45482c3F8cEEcAB9A589f77Ca",
    "0xb086748cd5b4Cba2e129A40436B3D6Ab6d22ecDE",
    "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578",
    "1000000000000000000",
    0,
    { gasLimit: 7000000 }
  );

  // Approve
  const usdc = await getContractAt<TestERC20>("TestERC20", "0x33a2F2d21afbc7E45482c3F8cEEcAB9A589f77Ca");
  usdc.approve(testRS.address, "10000000000000000000000");
  // Notify rewards
  testRS.notifyReward("10000000000000000000000", { gasLimit: 7000000 });

  // ====== end _deploySetupAfter() ======

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "SalesOutput.json");

  const output: SalesOutput = {
    RS: testRS.address,
    VRS: "",
    PS: "",
    VPS: ""
  };

  try {
    const buf = await readFile(outputFile);
    const contents = JSON.parse(buf.toString());
    await writeFile(outputFile, JSON.stringify({ ...contents, [network.config.chainId as any]: output }, null, 2));
  } catch (err) {
    console.error(`Error writing output file: ${err}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
