import "@nomiclabs/hardhat-ethers";
import { deploy } from "./utils/helpers";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import { network } from "hardhat";
import { TestERC20 } from "../artifacts/types";

interface TestTokensOutput {
  USDT: string;
  USDC: string;
}

async function main() {
  const usdc = await deploy<TestERC20>("TestERC20", undefined, "Fake USD Coin", "USDC", 70000000000000000000000000n);
  const usdt = await deploy<TestERC20>("TestERC20", undefined, "Fake Tether USD", "USDT", 90000000000000000000000000n);

  // ====== end _deploySetupAfter() ======

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "TestTokensOutput.json");

  const output: TestTokensOutput = {
    USDC: usdc.address,
    USDT: usdt.address
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
