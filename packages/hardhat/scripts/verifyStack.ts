import hre from "hardhat";

async function main() {
  const { deployments } = hre;
  const contracts = ["Vault", "StrategySplitter", "TreasurySplitter", "MockAavePool", "MockSwapRouter", "MockUSD"];

  for (const name of contracts) {
    try {
      const deployment = await deployments.get(name);
      console.log(`Verifying ${name} at ${deployment.address}`);
      await hre.run("verify:verify", {
        address: deployment.address,
        constructorArguments: deployment.args || [],
      });
    } catch (err) {
      console.warn(`Skipping ${name}:`, err);
    }
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
