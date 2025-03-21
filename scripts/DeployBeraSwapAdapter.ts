import { network } from "hardhat";
import { join } from "path";
import deployedContracts from "./constants/output/AggregatorOutput.json";
import { deploy, getContractAt } from "./utils/helpers";
import { AggregatorRouter, BeraSwapAdapter } from "../artifacts/types";
import { writeFile, readFile } from "fs/promises";

interface AggregatorOutput {
  Adapters: string[];
  Router: string;
}

async function main() {
  const chainId = network.config.chainId as number;
  const deployedC = deployedContracts[chainId as unknown as keyof typeof deployedContracts];
  const beraswapAdapter = await deploy<BeraSwapAdapter>(
    "BeraSwapAdapter",
    undefined,
    "0x4Be03f781C497A489E3cB0287833452cA9B9E80B",
    "0x3C612e132624f4Bd500eE1495F54565F0bcc9b59",
    [
      "0xde04c469ad658163e2a5e860a03a86b52f6fa8c8000000000000000000000000",
      "0xf961a8f6d8c69e7321e78d254ecafbcc3a637621000000000000000000000001",
      "0x2c4a603a2aa5596287a06886862dc29d56dbc354000200000000000000000002",
      "0xdd70a5ef7d8cfe5c5134b5f9874b09fb5ce812b4000200000000000000000003",
      "0x38fdd999fe8783037db1bbfe465759e312f2d809000200000000000000000004",
      "0x4d0ac0ea757f0bb338457c7a135c41fc732ca67d000200000000000000000005",
      "0xb1f0c3a875512191eb718b305f192dc19564f5130000000000000000000000a4",
      "0x976ef125c739b5d2f7bb8d59045b14367ec6d44400000000000000000000003a",
      "0x5070fc065875b209f02e11eb33de3b65222aaa4c00020000000000000000009c",
      "0xb66d97c1de2bc2b61eef8ef9c761a87521df207d00020000000000000000005d",
      "0x54270bea720a79db0a34645053b02740ebcbfad5000200000000000000000097",
      "0xb28e64c0d573526f1f2e8d48466e62d16b86371c00020000000000000000000a",
      "0xa249b7502f328d1dc5ac6401b00f405b5899927b000200000000000000000018"
    ],
    215000
  );
  const Adapters = deployedC.Adapters as string[];
  Adapters.push(beraswapAdapter.address);

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
