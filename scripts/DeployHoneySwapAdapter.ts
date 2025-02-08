import { network } from "hardhat";
import { join } from "path";
import deployedContracts from "./constants/output/AggregatorOutput.json";
import jsonConstants from "./constants/aggregator.json";
import { deploy, getContractAt } from "./utils/helpers";
import { AggregatorRouter, HoneySwapAdapter } from "../artifacts/types";
import { writeFile, readFile } from "fs/promises";

interface AggregatorOutput {
  Adapters: string[];
  Router: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const deployedC = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const constants = jsonConstants[chainId as unknown as keyof typeof jsonConstants];
  const honeySwapAdapter = await deploy<HoneySwapAdapter>(
    "HoneySwapAdapter",
    undefined,
    "0xA4aFef880F5cE1f63c9fb48F661E27F8B4216401",
    "0x285e147060CDc5ba902786d3A471224ee6cE0F91",
    215000,
    "0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce"
  );
  const Adapters = deployedC.Adapters;
  Adapters.push(honeySwapAdapter.address);

  const aggregatorRouter = await getContractAt<AggregatorRouter>("AggregatorRouter", deployedC.Router);
  await aggregatorRouter.setAdapters(Adapters);

  const output: AggregatorOutput = {
    ...deployedC,
    Adapters
  };

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "AggregatorOutput.json");

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
  process.exitCode = 1;
});
