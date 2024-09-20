import { network } from "hardhat";
import { deploy } from "./utils/helpers";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import protocolConstants from "./constants/protocol.json";
import deployAggContracts from "./constants/output/AggregatorOutput.json";
import { AggregatorRouter } from "../artifacts/types";

interface AggregatorOutput {
  Adapters: string[];
  Router: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const pConstants = protocolConstants[chainId as unknown as keyof typeof protocolConstants];
  const deployedAggCtr = deployAggContracts[chainId as unknown as keyof typeof deployAggContracts];

  const aggregatorRouter = await deploy<AggregatorRouter>(
    "AggregatorRouter",
    undefined,
    deployedAggCtr.Adapters,
    pConstants.team,
    pConstants.WETH,
    pConstants.whitelistTokens.filter((addr) => addr.toLowerCase() !== pConstants.WETH.toLowerCase())
  );
  const Router = aggregatorRouter.address;

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "AggregatorOutput.json");

  const output: AggregatorOutput = {
    ...deployedAggCtr,
    Router
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
  process.exitCode = 1;
});
