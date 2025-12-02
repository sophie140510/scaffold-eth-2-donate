// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISwapRouter {
    function swap(address from, address to, uint256 amountIn, address recipient) external returns (uint256 amountOut);
}

contract TreasurySplitter {
    using SafeERC20 for IERC20;

    address public router;
    address[] public recipients;
    uint16[] public bps;

    event RouterUpdated(address indexed router);
    event TreasuryUpdated(address[] recipients, uint16[] bps);
    event RewardsSwapped(address indexed rewardToken, address indexed outputToken, uint256 amountIn, uint256 amountOut);
    event RewardsDistributed(address indexed token, uint256 amount);

    constructor(address _router, address[] memory _recipients, uint16[] memory _bps) {
        _setRouter(_router);
        _setRecipients(_recipients, _bps);
    }

    function swapAndDistribute(address rewardToken, address outputToken) external returns (uint256 amountOut) {
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (balance == 0) return 0;

        IERC20(rewardToken).safeIncreaseAllowance(router, balance);
        amountOut = ISwapRouter(router).swap(rewardToken, outputToken, balance, address(this));
        emit RewardsSwapped(rewardToken, outputToken, balance, amountOut);

        _distribute(outputToken, amountOut);
    }

    function distributeToken(address token) external {
        uint256 balance = IERC20(token).balanceOf(address(this));
        _distribute(token, balance);
    }

    function updateRouter(address _router) external {
        _setRouter(_router);
    }

    function updateRecipients(address[] calldata _recipients, uint16[] calldata _bps) external {
        _setRecipients(_recipients, _bps);
    }

    function _distribute(address token, uint256 amount) internal {
        require(recipients.length > 0, "NO_RECIPIENTS");
        if (amount == 0) return;

        uint256 totalDistributed;
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (amount * bps[i]) / 10_000;
            totalDistributed += share;
            IERC20(token).safeTransfer(recipients[i], share);
        }

        uint256 remainder = amount - totalDistributed;
        if (remainder > 0) {
            IERC20(token).safeTransfer(recipients[0], remainder);
        }

        emit RewardsDistributed(token, amount);
    }

    function _setRouter(address _router) internal {
        require(_router != address(0), "ROUTER_REQUIRED");
        router = _router;
        emit RouterUpdated(_router);
    }

    function _setRecipients(address[] memory _recipients, uint16[] memory _bps) internal {
        require(_recipients.length == _bps.length, "BAD_CONFIG");
        uint256 total;
        for (uint256 i = 0; i < _bps.length; i++) {
            total += _bps[i];
        }
        require(total == 10_000, "INVALID_TOTAL");
        recipients = _recipients;
        bps = _bps;
        emit TreasuryUpdated(_recipients, _bps);
    }
}
