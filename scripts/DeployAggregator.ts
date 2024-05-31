import { network } from "hardhat";
import { deploy } from "./utils/helpers";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import constants from "./constants/aggregator.json";
import protocolConstants from "./constants/protocol.json";
import deployedContracts from "./constants/output/ProtocolOutput.json";
import { AggregatorRouter, MoniswapAdapter, PancakeswapLikeAdapter, UniswapV3Adapter } from "../artifacts/types";

interface AggregatorOutput {
  Adapters: string[];
  Router: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const aggConstants = constants[chainId as unknown as keyof typeof constants];
  const pConstants = protocolConstants[chainId as unknown as keyof typeof protocolConstants];
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];

  const Adapters: string[] = [];

  const moniswapAdapter = await deploy<MoniswapAdapter>("MoniswapAdapter", undefined, deployedCtr.PoolFactory, 215000);

  Adapters.push(moniswapAdapter.address);

  for (const adptr of aggConstants.pancakeswapLikeAdapters) {
    const pancakeswapLikeAdapter = await deploy<PancakeswapLikeAdapter>("PancakeswapLikeAdapter", undefined, adptr.name, adptr.factory, 25, 215000);
    Adapters.push(pancakeswapLikeAdapter.address);
  }

  const aggregatorRouter = await deploy<AggregatorRouter>(
    "AggregatorRouter",
    undefined,
    Adapters,
    pConstants.team,
    pConstants.WETH,
    pConstants.whitelistTokens
  );
  const Router = aggregatorRouter.address;

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "AggregatorOutput.json");

  const output: AggregatorOutput = {
    Adapters,
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
