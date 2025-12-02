// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "./IStrategy.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";

/// @notice Basic strategy that deposits into the MockAavePool.
contract AaveV3Strategy is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    MockAavePool public immutable pool;
    address public controller;

    event ControllerUpdated(address indexed newController);

    constructor(address asset_, address pool_, address controller_) {
        asset = IERC20(asset_);
        pool = MockAavePool(pool_);
        controller = controller_;
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

    function deposit(uint256 amount) external override onlyController returns (uint256) {
        asset.safeApprove(address(pool), 0);
        asset.safeApprove(address(pool), amount);
        pool.deposit(address(asset), amount, address(this));
        return amount;
    }

    function withdraw(uint256 amount, address recipient)
        external
        override
        onlyController
        returns (uint256 withdrawn)
    {
        withdrawn = pool.withdraw(address(asset), amount, recipient);
    }

    function totalAssets() external view override returns (uint256) {
        return pool.getBalance(address(asset));
    }
}
