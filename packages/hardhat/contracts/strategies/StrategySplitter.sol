// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "./IStrategy.sol";

/// @notice Splits deposits across configured strategies according to weights.
contract StrategySplitter {
    using SafeERC20 for IERC20;

    struct StrategyConfig {
        IStrategy strategy;
        uint256 weight;
    }

    StrategyConfig[] public strategies;
    uint256 public totalWeight;
    address public controller;
    IERC20 public immutable asset;

    event ControllerUpdated(address indexed newController);

    constructor(address controller_, address asset_) {
        controller = controller_;
        asset = IERC20(asset_);
    }

    modifier onlyController() {
        require(msg.sender == controller, "ONLY_CONTROLLER");
        _;
    }

    function setController(address newController) external {
        require(newController != address(0), "INVALID_CONTROLLER");
        require(msg.sender == controller || controller == address(0), "FORBIDDEN");
        controller = newController;
        emit ControllerUpdated(newController);
    }

    function setStrategies(StrategyConfig[] calldata configs) external onlyController {
        delete strategies;
        totalWeight = 0;
        for (uint256 i = 0; i < configs.length; i++) {
            strategies.push(configs[i]);
            totalWeight += configs[i].weight;
        }
        require(totalWeight > 0, "NO_WEIGHT");
    }

    function deposit(uint256 amount) external onlyController returns (uint256) {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        uint256 remaining = amount;
        for (uint256 i = 0; i < strategies.length; i++) {
            StrategyConfig memory config = strategies[i];
            uint256 portion = (amount * config.weight) / totalWeight;
            if (i == strategies.length - 1) {
                portion = remaining;
            }
            remaining -= portion;
            if (portion > 0) {
                asset.safeTransfer(address(config.strategy), portion);
                config.strategy.deposit(portion);
            }
        }
        return amount;
    }

    function withdraw(uint256 amount, address recipient) external onlyController returns (uint256) {
        uint256 remaining = amount;
        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            uint256 withdrawn = strategies[i].strategy.withdraw(remaining, recipient);
            if (withdrawn > remaining) {
                remaining = 0;
            } else {
                remaining -= withdrawn;
            }
        }
        require(remaining == 0, "INSUFFICIENT_LIQUIDITY");
        return amount;
    }

    function totalAssets() external view returns (uint256 total) {
        for (uint256 i = 0; i < strategies.length; i++) {
            total += strategies[i].strategy.totalAssets();
        }
    }

    function strategiesLength() external view returns (uint256) {
        return strategies.length;
    }
}
