import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const usdc = await deploy("MockUSDC", {
    from: deployer,
    contract: "MockERC20",
    args: ["Mock USD Coin", "mUSDC"],
    log: true,
  });

  const rewardToken = await deploy("MockRewardToken", {
    from: deployer,
    contract: "MockERC20",
    args: ["Reward", "RWD"],
    log: true,
  });

  const dough = await deploy("DOUGH", {
    from: deployer,
    args: [deployer],
    log: true,
  });

  const aavePool = await deploy("MockAavePool", {
    from: deployer,
    log: true,
  });

  const uniswap = await deploy("MockUniswapV3Router", {
    from: deployer,
    args: [30],
    log: true,
  });

  const oneInch = await deploy("MockOneInchRouter", {
    from: deployer,
    log: true,
  });

  const rewardSource = await deploy("MockRewardSource", {
    from: deployer,
    args: [rewardToken.address],
    log: true,
  });

  const strategySplitter = await deploy("StrategySplitter", {
    from: deployer,
    args: [deployer, usdc.address],
    log: true,
  });

  const treasurySplitter = await deploy("TreasurySplitter", {
    from: deployer,
    args: [deployer, rewardToken.address],
    log: true,
  });

  const controller = await deploy("Controller", {
    from: deployer,
    args: [usdc.address, dough.address, strategySplitter.address, treasurySplitter.address, 500],
    log: true,
  });

  const aaveStrategy = await deploy("AaveV3Strategy", {
    from: deployer,
    args: [usdc.address, aavePool.address, controller.address],
    log: true,
  });

  const doughContract = await ethers.getContractAt("DOUGH", dough.address, signer);
  await (await doughContract.grantRole(await doughContract.MINTER_ROLE(), controller.address)).wait();
  await (await doughContract.grantRole(await doughContract.BURNER_ROLE(), controller.address)).wait();

  const splitterContract = await ethers.getContractAt("StrategySplitter", strategySplitter.address, signer);
  await (await splitterContract.setController(controller.address)).wait();
  await (
    await splitterContract.setStrategies([
      {
        strategy: aaveStrategy.address,
        weight: 10_000,
      },
    ])
  ).wait();

  const treasuryContract = await ethers.getContractAt("TreasurySplitter", treasurySplitter.address, signer);
  await (await treasuryContract.setController(controller.address)).wait();
  await (await treasuryContract.setRouters(uniswap.address, oneInch.address)).wait();
  await (
    await treasuryContract.setRecipients([
      {
        account: deployer,
        weight: 10_000,
      },
    ])
  ).wait();

  const rewarder = await ethers.getContractAt("MockRewardSource", rewardSource.address, signer);
  const rewardErc20 = await ethers.getContractAt("MockERC20", rewardToken.address, signer);
  await (await rewardErc20.mint(deployer, ethers.parseEther("10000"))).wait();
  await (await rewardErc20.connect(signer).approve(rewardSource.address, ethers.MaxUint256)).wait();
  await (await rewarder.fund(ethers.parseEther("1000"))).wait();

  const usdcToken = await ethers.getContractAt("MockERC20", usdc.address, signer);
  await (await usdcToken.mint(deployer, ethers.parseEther("1000000"))).wait();
  log("DOUGH system deployed with Controller at", controller.address);
};

export default func;
func.tags = ["dough-system"];
