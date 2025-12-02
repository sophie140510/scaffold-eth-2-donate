// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal swap mock returning tokens 1:1 minus a fixed fee.
contract MockUniswapV3Router {
    uint256 public immutable feeBps;

    constructor(uint256 feeBps_) {
        feeBps = feeBps_;
    }

    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        amountOut = amountIn - ((amountIn * feeBps) / 10_000);
        IERC20(tokenOut).transfer(recipient, amountOut);
    }
}
