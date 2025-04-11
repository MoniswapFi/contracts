import "@nomiclabs/hardhat-ethers";
import { deploy, deployLibrary } from "./utils/helpers";
import { writeFile, readFile } from "fs/promises";
import { join } from "path";
import { Libraries } from "hardhat/types";
import { network } from "hardhat";
import {
  ManagedRewardsFactory,
  VotingRewardsFactory,
  GaugeFactory,
  PoolFactory,
  FactoryRegistry,
  Pool,
  Minter,
  RewardsDistributor,
  Router,
  Moni,
  Voter,
  VeArtProxy,
  VotingEscrow,
  ProtocolForwarder,
  AirdropDistributor,
  TradeHelper,
  PoolHelper,
  VeNFTHelper,
  RewardHelper,
  ExchangeHelper,
  Oracle
} from "../artifacts/types";
import constants from "./constants/protocol.json";
import { BigNumber } from "ethers";

interface ProtocolOutput {
  ArtProxy: string;
  Distributor: string;
  FactoryRegistry: string;
  Forwarder: string;
  GaugeFactory: string;
  ManagedRewardsFactory: string;
  Minter: string;
  PoolFactory: string;
  Router: string;
  MONI: string;
  Voter: string;
  VotingEscrow: string;
  VotingRewardsFactory: string;
  TradeHelper: string;
  veNFTHelper: string;
  ExchangeHelper: string;
  RewardHelper: string;
  PoolHelper: string;
  Oracle: string;
}

interface AirdropInfo {
  amount: number;
  wallet: string;
}

async function main() {
  // ====== start _deploySetupBefore() ======
  const AIRDROPPER_BALANCE = 50_000_000;
  const DECIMAL = BigNumber.from(10).pow(18);
  const jsonConstants = constants[(network.config.chainId as unknown as keyof typeof constants).toString()];

  const MONI = await deploy<Moni>("Moni");
  console.log("Deployed MONI");

  const whitelistTokens = jsonConstants.whitelistTokens;
  whitelistTokens.push(MONI.address);
  // ====== end _deploySetupBefore() ======

  // ====== start _coreSetup() ======

  // ====== start deployFactories() ======
  const implementation = await deploy<Pool>("Pool");
  console.log("Deployed pool contract");

  const poolFactory = await deploy<PoolFactory>("PoolFactory", undefined, implementation.address, jsonConstants.team);
  console.log("Deployed pool factory");
  await poolFactory.setFee(true, 1);
  await poolFactory.setFee(false, 1);

  const votingRewardsFactory = await deploy<VotingRewardsFactory>("VotingRewardsFactory");
  console.log("Deployed voting rewards factory");

  const gaugeFactory = await deploy<GaugeFactory>("GaugeFactory");
  console.log("Deployed gauge factory");

  const managedRewardsFactory = await deploy<ManagedRewardsFactory>("ManagedRewardsFactory");
  console.log("Deployed managed rewards factory");

  const factoryRegistry = await deploy<FactoryRegistry>(
    "FactoryRegistry",
    undefined,
    poolFactory.address,
    votingRewardsFactory.address,
    gaugeFactory.address,
    managedRewardsFactory.address
  );
  console.log("Deployed factory registry");
  // ====== end deployFactories() ======

  const forwarder = await deploy<ProtocolForwarder>("ProtocolForwarder");
  console.log("Deployed protocol forwarder");

  const balanceLogicLibrary = await deployLibrary("BalanceLogicLibrary");
  const delegationLogicLibrary = await deployLibrary("DelegationLogicLibrary");
  const libraries: Libraries = {
    BalanceLogicLibrary: balanceLogicLibrary.address,
    DelegationLogicLibrary: delegationLogicLibrary.address
  };
  console.log("Deployed libraries");

  const escrow = await deploy<VotingEscrow>("VotingEscrow", libraries, forwarder.address, MONI.address, factoryRegistry.address);
  console.log("Deployed voting escrow");

  const trig = await deployLibrary("Trig");
  const perlinNoise = await deployLibrary("PerlinNoise");
  const artLibraries: Libraries = {
    Trig: trig.address,
    PerlinNoise: perlinNoise.address
  };

  const artProxy = await deploy<VeArtProxy>("VeArtProxy", artLibraries, escrow.address);
  console.log("Deployed art proxy");
  await escrow.setArtProxy(artProxy.address);

  const distributor = await deploy<RewardsDistributor>("RewardsDistributor", undefined, escrow.address);
  console.log("Deployed distributor");

  const voter = await deploy<Voter>("Voter", undefined, forwarder.address, escrow.address, factoryRegistry.address);
  console.log("Deployed voter");

  await escrow.setVoterAndDistributor(voter.address, distributor.address);

  const router = await deploy<Router>(
    "Router",
    undefined,
    forwarder.address,
    factoryRegistry.address,
    poolFactory.address,
    voter.address,
    jsonConstants.WETH
  );
  console.log("Deployed router");

  const minter = await deploy<Minter>("Minter", undefined, voter.address, escrow.address, distributor.address);
  console.log("Deployed minter");
  await distributor.setMinter(minter.address);
  await MONI.setMinter(minter.address);

  const airdrop = await deploy<AirdropDistributor>("AirdropDistributor", undefined, escrow.address);

  await voter.initialize(whitelistTokens, minter.address);
  // ====== end _coreSetup() ======

  // ====== start _deploySetupAfter() ======

  // Minter initialization
  let lockedAirdropInfo: AirdropInfo[] = jsonConstants.minter.locked;
  let liquidAirdropInfo: AirdropInfo[] = jsonConstants.minter.liquid;

  let liquidWallets: string[] = [];
  let lockedWallets: string[] = [];
  let liquidAmounts: BigNumber[] = [];
  let lockedAmounts: BigNumber[] = [];

  // First add the AirdropDistributor's address and its amount
  liquidWallets.push(airdrop.address);
  liquidAmounts.push(BigNumber.from(AIRDROPPER_BALANCE).mul(DECIMAL));

  liquidAirdropInfo.forEach((drop) => {
    liquidWallets.push(drop.wallet);
    liquidAmounts.push(BigNumber.from(drop.amount / 1e18).mul(DECIMAL));
  });

  lockedAirdropInfo.forEach((drop) => {
    lockedWallets.push(drop.wallet);
    lockedAmounts.push(BigNumber.from(drop.amount / 1e18).mul(DECIMAL));
  });

  await minter.initialize({
    liquidWallets: liquidWallets,
    liquidAmounts: liquidAmounts,
    lockedWallets: lockedWallets,
    lockedAmounts: lockedAmounts
  });

  // Set protocol state to team
  await escrow.setTeam(jsonConstants.team);
  await minter.setTeam(jsonConstants.team);
  await poolFactory.setPauser(jsonConstants.team);
  await voter.setEmergencyCouncil(jsonConstants.team);
  await voter.setEpochGovernor(jsonConstants.team);
  await voter.setGovernor(jsonConstants.team);
  await factoryRegistry.transferOwnership(jsonConstants.team);

  await poolFactory.setFeeManager(jsonConstants.feeManager);
  await poolFactory.setVoter(voter.address);

  // Deploy oracle
  const oracle = await deploy<Oracle>("Oracle", undefined, []);

  // Deploy helpers
  const tradeHelper = await deploy<TradeHelper>("TradeHelper", undefined, poolFactory.address);
  const poolHelper = await deploy<PoolHelper>("PoolHelper", undefined, voter.address, poolFactory.address);
  const venftHelper = await deploy<VeNFTHelper>(
    "veNFTHelper",
    undefined,
    voter.address,
    distributor.address,
    poolHelper.address,
    poolFactory.address
  );
  const rewardHelper = await deploy<RewardHelper>("RewardHelper", undefined, voter.address, poolFactory.address);
  const exchangeHelper = await deploy<ExchangeHelper>(
    "ExchangeHelper",
    undefined,
    tradeHelper.address,
    voter.address,
    jsonConstants.WETH,
    oracle.address
  );

  // ====== end _deploySetupAfter() ======

  const outputDirectory = "scripts/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, "ProtocolOutput.json");

  const output: ProtocolOutput = {
    ArtProxy: artProxy.address,
    Distributor: distributor.address,
    FactoryRegistry: factoryRegistry.address,
    Forwarder: forwarder.address,
    GaugeFactory: gaugeFactory.address,
    ManagedRewardsFactory: managedRewardsFactory.address,
    Minter: minter.address,
    PoolFactory: poolFactory.address,
    Router: router.address,
    MONI: MONI.address,
    Voter: voter.address,
    VotingEscrow: escrow.address,
    VotingRewardsFactory: votingRewardsFactory.address,
    TradeHelper: tradeHelper.address,
    PoolHelper: poolHelper.address,
    veNFTHelper: venftHelper.address,
    ExchangeHelper: exchangeHelper.address,
    RewardHelper: rewardHelper.address,
    Oracle: oracle.address
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
  process.exit(1);
});
