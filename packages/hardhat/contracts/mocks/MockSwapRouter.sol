// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSwapRouter {
    using SafeERC20 for IERC20;

    address public immutable owner;
    mapping(address => mapping(address => uint256)) public rates; // scaled by 1e18

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function setRate(address from, address to, uint256 rate) external onlyOwner {
        rates[from][to] = rate;
    }

    function swap(address from, address to, uint256 amountIn, address recipient) external returns (uint256 amountOut) {
        uint256 rate = rates[from][to];
        require(rate > 0, "NO_RATE");

        IERC20(from).safeTransferFrom(msg.sender, address(this), amountIn);
        amountOut = (amountIn * rate) / 1e18;
        IERC20(to).safeTransfer(recipient, amountOut);
    }
}
