// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockRewardSource {
    IERC20 public immutable rewardToken;

    constructor(address rewardToken_) {
        rewardToken = IERC20(rewardToken_);
    }

    function fund(uint256 amount) external {
        rewardToken.transferFrom(msg.sender, address(this), amount);
    }

    function claim(address to) external returns (uint256) {
        uint256 balance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(to, balance);
        return balance;
    }
}
