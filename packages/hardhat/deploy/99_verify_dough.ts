import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hre.network.name === "hardhat") {
    console.log("Skipping verification on hardhat network");
    return;
  }

  const { deployer } = await hre.getNamedAccounts();
  const controller = await hre.deployments.get("Controller");
  const dough = await hre.deployments.get("DOUGH");
  const strategySplitter = await hre.deployments.get("StrategySplitter");
  const treasurySplitter = await hre.deployments.get("TreasurySplitter");
  const aaveStrategy = await hre.deployments.get("AaveV3Strategy");
  const usdc = await hre.deployments.get("MockUSDC");
  const rewardToken = await hre.deployments.get("MockRewardToken");
  const aavePool = await hre.deployments.get("MockAavePool");
  const uniswap = await hre.deployments.get("MockUniswapV3Router");
  const oneInch = await hre.deployments.get("MockOneInchRouter");

  const verify = async (address: string, constructorArguments: unknown[]) => {
    try {
      await hre.run("verify:verify", { address, constructorArguments });
    } catch (e) {
      console.warn("Verification skipped for", address, e);
    }
  };

  await verify(dough.address, [deployer]);
  await verify(strategySplitter.address, [controller.address, usdc.address]);
  await verify(treasurySplitter.address, [controller.address, rewardToken.address]);
  await verify(controller.address, [
    usdc.address,
    dough.address,
    strategySplitter.address,
    treasurySplitter.address,
    500,
  ]);
  await verify(aaveStrategy.address, [usdc.address, aavePool.address, controller.address]);
  await verify(uniswap.address, [30]);
  await verify(oneInch.address, []);
};

export default func;
func.tags = ["verify-dough"];
