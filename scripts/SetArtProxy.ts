import { Minter, VotingEscrow } from "../artifacts/types";
import { getContractAt } from "./utils/helpers";
import deployedContracts from "./constants/output/ProtocolOutput.json";
import constants from "./constants/protocol.json";
import { network } from "hardhat";
import { BigNumber } from "ethers";

interface AirdropInfo {
  amount: number;
  wallet: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const deployedCtr = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const jsonConstants = constants[chainId as unknown as keyof typeof constants];
  const DECIMAL = BigNumber.from(10).pow(18);
  const escrow = await getContractAt<VotingEscrow>("VotingEscrow", deployedCtr.VotingEscrow);
  const minter = await getContractAt<Minter>("Minter", deployedCtr.Minter);
  await escrow.setArtProxy("0x0833c006EcB3Ed52408b475969BCC05190105c7f");
  console.info("Execute escrow actions");

  let lockedAirdropInfo: AirdropInfo[] = jsonConstants.minter.locked;
  let liquidAirdropInfo: AirdropInfo[] = jsonConstants.minter.liquid;

  let liquidWallets: string[] = [];
  let lockedWallets: string[] = [];
  let liquidAmounts: BigNumber[] = [];
  let lockedAmounts: BigNumber[] = [];

  liquidAirdropInfo.forEach((drop) => {
    liquidWallets.push(drop.wallet);
    liquidAmounts.push(BigNumber.from(drop.amount / 1e18).mul(DECIMAL));
  });

  lockedAirdropInfo.forEach((drop) => {
    lockedWallets.push(drop.wallet);
    lockedAmounts.push(BigNumber.from(drop.amount / 1e18).mul(DECIMAL));
  });

  await minter.initialize(
    {
      liquidWallets: liquidWallets,
      liquidAmounts: liquidAmounts,
      lockedWallets: lockedWallets,
      lockedAmounts: lockedAmounts
    },
    { gasLimit: 5000000 }
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
