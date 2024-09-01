import { network } from "hardhat";
import deployedContracts from "./constants/output/ProtocolOutput.json";
import { Moni, VotingEscrow } from "../artifacts/types";
import { getContractAt } from "./utils/helpers";
import { BigNumber } from "ethers";

async function main() {
  const chainId = network.config.chainId as number;
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const escrow = await getContractAt<VotingEscrow>("VotingEscrow", deployedCtr.VotingEscrow);
  const moni = await getContractAt<Moni>("Moni", deployedCtr.MONI);

  await moni.approve(escrow.address, BigNumber.from(10000000000000000000000n));
  await escrow.createLock(BigNumber.from(10000000000000000000000n), BigNumber.from(31536000), { gasLimit: 5000000 });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
