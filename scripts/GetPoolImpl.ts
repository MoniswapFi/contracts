import { PoolFactory } from "../artifacts/types";
import { getContractAt } from "./utils/helpers";
import deployedContracts from "./constants/output/ProtocolOutput.json";
import { network } from "hardhat";


async function main() {
  const chainId = network.config.chainId as number;
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const factory = await getContractAt<PoolFactory>("PoolFactory", deployedCtr.PoolFactory);
  const impl = await factory.implementation();
  console.log(impl);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
