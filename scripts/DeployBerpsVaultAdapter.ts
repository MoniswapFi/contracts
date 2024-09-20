import { network } from "hardhat";
import { join } from "path";
import deployedContracts from "./constants/output/AggregatorOutput.json";
import jsonConstants from "./constants/aggregator.json";
import { deploy, getContractAt } from "./utils/helpers";
import { AggregatorRouter, BerpsVaultAdapter } from "../artifacts/types";
import { writeFile, readFile } from "fs/promises";

interface AggregatorOutput {
  Adapters: string[];
  Router: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const deployedC = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const constants = jsonConstants[chainId as unknown as keyof typeof jsonConstants];
  const berpsVaultAdapter = await deploy<BerpsVaultAdapter>(
    "BerpsVaultAdapter",
    undefined,
    constants.berpsVaultAdapter.vault,
    215000,
    constants.berpsVaultAdapter.honey,
    constants.berpsVaultAdapter.bHoney
  );
  const Adapters = deployedC.Adapters;
  Adapters.push(berpsVaultAdapter.address);

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
