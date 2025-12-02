// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {DOUGH} from "./DOUGH.sol";
import {StrategySplitter} from "./strategies/StrategySplitter.sol";
import {TreasurySplitter} from "./treasury/TreasurySplitter.sol";

/// @notice Controller for DOUGH lifecycle and accounting.
contract Controller {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    DOUGH public immutable dough;
    StrategySplitter public immutable strategySplitter;
    TreasurySplitter public immutable treasurySplitter;

    uint256 public immutable treasuryFeeBps;
    uint256 public totalDeposits;
    uint256 public totalNonRedeemable;

    mapping(address => uint256) public userDeposits;

    event Deposited(address indexed user, uint256 amount, uint256 minted);
    event Redeemed(address indexed user, uint256 amount, uint256 burned);

    constructor(
        address asset_,
        address dough_,
        address strategySplitter_,
        address treasurySplitter_,
        uint256 treasuryFeeBps_
    ) {
        asset = IERC20(asset_);
        dough = DOUGH(dough_);
        strategySplitter = StrategySplitter(strategySplitter_);
        treasurySplitter = TreasurySplitter(treasurySplitter_);
        treasuryFeeBps = treasuryFeeBps_;
    }

    /// @notice Deposit underlying, mint DOUGH, and invest into strategies.
    function deposit(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        asset.safeTransferFrom(msg.sender, address(this), amount);

        uint256 fee = (amount * treasuryFeeBps) / 10_000;
        uint256 investAmount = amount - fee;

        if (fee > 0) {
            asset.safeIncreaseAllowance(address(treasurySplitter), fee);
            asset.safeTransfer(address(treasurySplitter), fee);
            totalNonRedeemable += fee;
        }

        asset.safeIncreaseAllowance(address(strategySplitter), investAmount);
        strategySplitter.deposit(investAmount);

        dough.mint(msg.sender, investAmount);
        userDeposits[msg.sender] += investAmount;
        totalDeposits += investAmount;
        emit Deposited(msg.sender, amount, investAmount);
    }

    /// @notice Burn DOUGH for the underlying backing.
    function redeem(uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        dough.burnFrom(msg.sender, amount);
        strategySplitter.withdraw(amount, msg.sender);
        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        emit Redeemed(msg.sender, amount, amount);
    }

    /// @notice Current backing (including strategies and idle asset).
    function totalBacking() public view returns (uint256) {
        return asset.balanceOf(address(this)) + strategySplitter.totalAssets();
    }

    /// @notice Redeemable balance for an account.
    function redeemableOf(address account) external view returns (uint256) {
        return userDeposits[account];
    }

    /// @notice View helper for treasury balances.
    function treasuryBalance(address token) external view returns (uint256) {
        return treasurySplitter.treasuryBalance(token);
    }

    /// @notice Convenience getter for DOUGH supply and burned supply.
    function doughAccounting() external view returns (uint256 totalSupply, uint256 burnedSupply) {
        totalSupply = dough.totalSupply();
        burnedSupply = dough.burnedSupply();
    }

    /// @notice Getter for reward accounting exposed by the treasury.
    function totalRewardsClaimed() external view returns (uint256) {
        return treasurySplitter.totalRewardsClaimed();
    }
}
