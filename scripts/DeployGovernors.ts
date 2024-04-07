import { network } from "hardhat";
import { deploy } from "./utils/helpers";
import { ProtocolGovernor, EpochGovernor } from "../artifacts/types";
import jsonConstants from "./constants/protocol.json";
import deployedContracts from "./constants/output/ProtocolOutput.json";

async function main() {
  const chainId = network.config.chainId as number;
  const configConstants = jsonConstants[chainId as unknown as keyof typeof jsonConstants];
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const governor = await deploy<ProtocolGovernor>("ProtocolGovernor", undefined, deployedCtr.VotingEscrow);
  await deploy<EpochGovernor>("EpochGovernor", undefined, deployedCtr.Forwarder, deployedCtr.VotingEscrow, deployedCtr.Minter);

  await governor.setVetoer(configConstants.team);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
