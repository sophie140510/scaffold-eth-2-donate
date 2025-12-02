// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StrategySplitter {
    using SafeERC20 for IERC20;

    address public vault;
    address public treasurySplitter;
    address public strategyRecipient;
    uint16 public strategyBps; // out of 10_000

    event SplitUpdated(address indexed strategyRecipient, uint16 strategyBps, address indexed treasurySplitter);
    event HarvestSplit(address indexed asset, uint256 toStrategy, uint256 toTreasury);
    event VaultSet(address indexed vault);

    constructor(address _vault, address _treasurySplitter, address _strategyRecipient, uint16 _strategyBps) {
        require(_strategyBps <= 10_000, "INVALID_BPS");
        vault = _vault;
        treasurySplitter = _treasurySplitter;
        strategyRecipient = _strategyRecipient;
        strategyBps = _strategyBps;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "ONLY_VAULT");
        _;
    }

    function setVault(address _vault) external {
        require(vault == address(0), "VAULT_SET");
        require(_vault != address(0), "INVALID_VAULT");
        vault = _vault;
        emit VaultSet(_vault);
    }

    function updateSplit(address _strategyRecipient, uint16 _strategyBps, address _treasurySplitter) external onlyVault {
        require(_strategyBps <= 10_000, "INVALID_BPS");
        strategyRecipient = _strategyRecipient;
        strategyBps = _strategyBps;
        treasurySplitter = _treasurySplitter;
        emit SplitUpdated(_strategyRecipient, _strategyBps, _treasurySplitter);
    }

    function distribute(address asset, uint256 amount) external onlyVault {
        if (amount == 0) return;

        uint256 toStrategy = (amount * strategyBps) / 10_000;
        uint256 toTreasury = amount - toStrategy;

        if (toStrategy > 0) {
            IERC20(asset).safeTransfer(strategyRecipient, toStrategy);
        }

        if (toTreasury > 0) {
            IERC20(asset).safeTransfer(treasurySplitter, toTreasury);
        }

        emit HarvestSplit(asset, toStrategy, toTreasury);
    }
}
