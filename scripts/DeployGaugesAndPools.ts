import { network } from "hardhat";
import { getContractAt } from "./utils/helpers";
import { PoolFactory, Voter } from "../artifacts/types";
import jsonConstants from "./constants/protocol.json";
import deployedContracts from "./constants/output/ProtocolOutput.json";

async function main() {
  const chainId = network.config.chainId as number;
  const configConstants = jsonConstants[chainId as unknown as keyof typeof jsonConstants];
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const factory = await getContractAt<PoolFactory>("PoolFactory", deployedCtr.PoolFactory);
  const voter = await getContractAt<Voter>("Voter", deployedCtr.Voter);

  // Deploy non-MONI pools and gauges
  for (var i = 0; i < configConstants.pools.length; i++) {
    const { stable, tokenA, tokenB } = configConstants.pools[i];
    await factory.functions["createPool(address,address,bool)"](tokenA, tokenB, stable);
    let pool = await factory.functions["getPool(address,address,bool)"](tokenA, tokenB, stable);
    await voter.createGauge(
      deployedCtr.PoolFactory, // PoolFactory
      pool[0]
    );
  }

  // Deploy AERO pools and gauges
  for (var i = 0; i < configConstants.poolsMoni.length; i++) {
    const [stable, token] = Object.values(configConstants.poolsMoni[i]);
    await factory.functions["createPool(address,address,bool)"](deployedCtr.MONI, token as string, stable as boolean);
    let pool = await factory.functions["getPool(address,address,bool)"](deployedCtr.MONI, token as string, stable as boolean);
    await voter.createGauge(
      deployedCtr.PoolFactory, // PoolFactory
      pool[0]
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
