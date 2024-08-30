import { network } from "hardhat";
import deployedContracts from "./constants/output/ProtocolOutput.json";
import { deploy } from "./utils/helpers";
import { Multicall } from "../artifacts/types";
import { join } from "path";
import { readFile, writeFile } from "fs/promises";

async function main() {
  const chainId = network.config.chainId as number;
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const multicall = await deploy<Multicall>("Multicall", undefined, [deployedCtr.Voter]);

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "MulticallOutput.json");

  try {
    const buf = await readFile(outputFile);
    const contents = JSON.parse(buf.toString());
    await writeFile(outputFile, JSON.stringify({ ...contents, [network.config.chainId as any]: multicall.address }, null, 2));
  } catch (err) {
    console.error(`Error writing output file: ${err}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
