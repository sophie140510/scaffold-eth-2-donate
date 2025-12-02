// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import {Vault} from "../../contracts/Vault.sol";
import {StrategySplitter} from "../../contracts/StrategySplitter.sol";
import {TreasurySplitter} from "../../contracts/TreasurySplitter.sol";
import {MockAavePool} from "../../contracts/mocks/MockAavePool.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockSwapRouter} from "../../contracts/mocks/MockSwapRouter.sol";

contract VaultFlowTest is Test {
    Vault internal vault;
    StrategySplitter internal strategySplitter;
    TreasurySplitter internal treasurySplitter;
    MockAavePool internal pool;
    MockERC20 internal asset;
    MockERC20 internal reward;
    MockSwapRouter internal router;

    address internal depositor = address(0xBEEF);
    address internal strategyWallet = address(0xA11CE);
    address internal treasuryA = address(0x1010);
    address internal treasuryB = address(0x2020);

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", 18, address(this));
        reward = new MockERC20("Mock Reward", "RWD", 18, address(this));
        pool = new MockAavePool(address(this));
        router = new MockSwapRouter(address(this));

        address[] memory recipients = new address[](2);
        recipients[0] = treasuryA;
        recipients[1] = treasuryB;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 6000;
        weights[1] = 4000;
        treasurySplitter = new TreasurySplitter(address(router), recipients, weights);

        strategySplitter = new StrategySplitter(address(0), address(treasurySplitter), strategyWallet, 5000);
        vault = new Vault(address(asset), address(pool), address(strategySplitter));
        strategySplitter.setVault(address(vault));

        // fund depositor
        asset.mint(depositor, 1_000 ether);
    }

    function testDepositAndRedeemShares() public {
        vm.startPrank(depositor);
        asset.approve(address(vault), 200 ether);
        uint256 mintedShares = vault.deposit(200 ether, depositor);
        vm.stopPrank();

        assertEq(mintedShares, 200 ether, "shares minted");
        assertEq(vault.balanceOf(depositor), 200 ether, "share balance");
        assertEq(pool.balanceOf(address(asset), address(vault)), 200 ether, "aave balance");

        vm.startPrank(depositor);
        uint256 assetsRedeemed = vault.redeem(50 ether, depositor);
        vm.stopPrank();

        assertEq(assetsRedeemed, 50 ether, "assets redeemed");
        assertEq(vault.balanceOf(depositor), 150 ether, "remaining shares");
        assertEq(asset.balanceOf(depositor), 850 ether, "underlying returned");
    }

    function testHarvestsYieldIntoStrategyAndTreasury() public {
        // deposit funds
        vm.startPrank(depositor);
        asset.approve(address(vault), 300 ether);
        vault.deposit(300 ether, depositor);
        vm.stopPrank();

        // simulate yield minted to pool for vault
        asset.mint(address(this), 60 ether);
        asset.approve(address(pool), 60 ether);
        pool.simulateYield(address(asset), address(vault), 60 ether);

        uint256 vaultBalanceBefore = pool.balanceOf(address(asset), address(vault));
        assertEq(vaultBalanceBefore, 360 ether, "yield added");

        uint256 strategyStart = asset.balanceOf(strategyWallet);
        uint256 treasuryStart = asset.balanceOf(address(treasurySplitter));

        uint256 harvested = vault.harvestYield();
        assertEq(harvested, 60 ether, "harvest amount");

        uint256 expectedToStrategy = (60 ether * 5000) / 10_000;
        uint256 expectedToTreasury = 60 ether - expectedToStrategy;

        assertEq(asset.balanceOf(strategyWallet) - strategyStart, expectedToStrategy, "strategy share");
        assertEq(asset.balanceOf(address(treasurySplitter)) - treasuryStart, expectedToTreasury, "treasury share");
        assertEq(pool.balanceOf(address(asset), address(vault)), 300 ether, "principal remains");
    }

    function testTreasurySplitterSwapsAndDistributes() public {
        reward.mint(address(this), 200 ether);
        reward.transfer(address(treasurySplitter), 200 ether);

        // Router rate: 1 reward = 2 asset
        router.setRate(address(reward), address(asset), 2e18);
        asset.mint(address(router), 400 ether);

        uint256 treasuryABefore = asset.balanceOf(treasuryA);
        uint256 treasuryBBefore = asset.balanceOf(treasuryB);

        uint256 output = treasurySplitter.swapAndDistribute(address(reward), address(asset));
        assertEq(output, 400 ether, "swap output");

        assertEq(asset.balanceOf(treasuryA) - treasuryABefore, 240 ether, "treasury A share");
        assertEq(asset.balanceOf(treasuryB) - treasuryBBefore, 160 ether, "treasury B share");
    }

    function testDirectDistributionMaintainsRemainder() public {
        asset.mint(address(treasurySplitter), 100 ether);

        uint256 treasuryABefore = asset.balanceOf(treasuryA);
        uint256 treasuryBBefore = asset.balanceOf(treasuryB);

        treasurySplitter.distributeToken(address(asset));

        assertEq(asset.balanceOf(treasuryA) - treasuryABefore, 60 ether, "treasury A distribution");
        assertEq(asset.balanceOf(treasuryB) - treasuryBBefore, 40 ether, "treasury B distribution");
    }
}
