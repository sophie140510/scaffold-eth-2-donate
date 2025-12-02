// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockOneInchRouter {
    function swap(address tokenIn, address tokenOut, address recipient, uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        // OneInch mock swaps at parity.
        amountOut = amountIn;
        IERC20(tokenOut).transfer(recipient, amountOut);
    }
}
