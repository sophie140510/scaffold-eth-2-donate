// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAaveLikePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function balanceOf(address asset, address user) external view returns (uint256);
}

interface IStrategySplitter {
    function distribute(address asset, uint256 amount) external;
}

contract Vault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IAaveLikePool public immutable pool;
    IStrategySplitter public strategySplitter;
    uint256 public totalDeposits;

    event Deposited(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Redeemed(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event YieldHarvested(uint256 amount);

    constructor(address asset_, address pool_, address splitter_) ERC20("Donation Vault Share", "DVS") {
        asset = IERC20(asset_);
        pool = IAaveLikePool(pool_);
        strategySplitter = IStrategySplitter(splitter_);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "ZERO_ASSETS");
        shares = assets;
        asset.safeTransferFrom(msg.sender, address(this), assets);
        asset.safeIncreaseAllowance(address(pool), assets);
        pool.supply(address(asset), assets, address(this), 0);

        totalDeposits += assets;
        _mint(receiver, shares);

        emit Deposited(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver) external returns (uint256 assetsRedeemed) {
        require(shares > 0, "ZERO_SHARES");
        require(balanceOf(msg.sender) >= shares, "INSUFFICIENT_SHARES");
        assetsRedeemed = shares;
        totalDeposits -= assetsRedeemed;

        _burn(msg.sender, shares);
        pool.withdraw(address(asset), assetsRedeemed, address(this));
        asset.safeTransfer(receiver, assetsRedeemed);

        emit Redeemed(msg.sender, receiver, assetsRedeemed, shares);
    }

    function harvestYield() external returns (uint256 yieldAmount) {
        uint256 currentBalance = pool.balanceOf(address(asset), address(this));
        if (currentBalance <= totalDeposits) return 0;

        yieldAmount = currentBalance - totalDeposits;
        pool.withdraw(address(asset), yieldAmount, address(this));

        asset.safeTransfer(address(strategySplitter), yieldAmount);
        strategySplitter.distribute(address(asset), yieldAmount);

        emit YieldHarvested(yieldAmount);
    }
}
