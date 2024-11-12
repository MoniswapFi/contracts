import { network } from "hardhat";
import { deploy, getContractAt } from "./utils/helpers";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import protocolConstants from "./constants/protocol.json";
import deployAggContracts from "./constants/output/AggregatorOutput.json";
import { Adapter, AggregatorRouter } from "../artifacts/types";

interface AggregatorOutput {
  Adapters: string[];
  Router: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const pConstants = protocolConstants[chainId as unknown as keyof typeof protocolConstants];
  const deployedAggCtr = deployAggContracts[chainId as unknown as keyof typeof deployAggContracts];

  const aggregatorRouter = await getContractAt<Adapter>("Adapter", "0x37B56002E37aC44a51c68697E4786A72806DC943");

  aggregatorRouter.name().then(console.log).catch(console.debug);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
