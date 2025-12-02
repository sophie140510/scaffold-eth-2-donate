import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const isLocal = ["hardhat", "localhost"].includes(network.name);
  const defaultStrategy = process.env.STRATEGY_RECIPIENT ?? deployer;
  const strategyBps = Number(process.env.STRATEGY_BPS ?? "5000");

  const accounts = await ethers.getSigners();
  const treasuryRecipients = (
    process.env.TREASURY_RECIPIENTS ?? `${deployer},${accounts[1].address ?? deployer}`
  ).split(",");
  const treasurySplits = (process.env.TREASURY_SPLITS ?? "6000,4000").split(",").map(n => Number(n));

  let assetAddress = process.env.UNDERLYING_ASSET;
  if (!assetAddress || isLocal) {
    const mockAsset = await deploy("MockUSD", {
      contract: "MockERC20",
      from: deployer,
      args: ["Mock USD", "mUSD", 18, deployer],
      log: true,
      autoMine: true,
    });
    assetAddress = mockAsset.address;
  }

  let poolAddress = process.env.AAVE_POOL;
  if (!poolAddress || isLocal) {
    const mockPool = await deploy("MockAavePool", {
      contract: "MockAavePool",
      from: deployer,
      args: [deployer],
      log: true,
      autoMine: true,
    });
    poolAddress = mockPool.address;
  }

  let routerAddress = process.env.SWAP_ROUTER;
  if (!routerAddress || isLocal) {
    const mockRouter = await deploy("MockSwapRouter", {
      contract: "MockSwapRouter",
      from: deployer,
      args: [deployer],
      log: true,
      autoMine: true,
    });
    routerAddress = mockRouter.address;
  }

  const treasury = await deploy("TreasurySplitter", {
    from: deployer,
    args: [routerAddress, treasuryRecipients, treasurySplits],
    log: true,
    autoMine: true,
  });

  const strategy = await deploy("StrategySplitter", {
    from: deployer,
    args: [ethers.ZeroAddress, treasury.address, defaultStrategy, strategyBps],
    log: true,
    autoMine: true,
  });

  const vault = await deploy("Vault", {
    from: deployer,
    args: [assetAddress, poolAddress, strategy.address],
    log: true,
    autoMine: true,
  });

  const strategyContract = await ethers.getContractAt("StrategySplitter", strategy.address);
  const tx = await strategyContract.setVault(vault.address);
  await tx.wait();
  log(`StrategySplitter wired to vault at ${vault.address}`);
};

func.tags = ["YieldStack"];

export default func;
