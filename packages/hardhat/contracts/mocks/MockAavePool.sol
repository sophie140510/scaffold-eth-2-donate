// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockAavePool {
    using SafeERC20 for IERC20;

    address public immutable admin;
    mapping(address => mapping(address => uint256)) private balances;

    constructor(address _admin) {
        admin = _admin;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        balances[asset][onBehalfOf] += amount;
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        uint256 balance = balances[asset][msg.sender];
        require(balance >= amount, "INSUFFICIENT_BALANCE");
        balances[asset][msg.sender] = balance - amount;
        IERC20(asset).safeTransfer(to, amount);
        return amount;
    }

    function balanceOf(address asset, address user) external view returns (uint256) {
        return balances[asset][user];
    }

    function simulateYield(address asset, address user, uint256 amount) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        balances[asset][user] += amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }
}
