// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewardSource {
    function claim(address to) external returns (uint256);
}

/// @notice Splits rewards among recipients and supports swapping through mocks.
contract TreasurySplitter {
    struct Recipient {
        address account;
        uint256 weight;
    }

    Recipient[] public recipients;
    uint256 public totalWeight;

    address public rewardToken;
    address public controller;
    address public uniswapRouter;
    address public oneInchRouter;

    uint256 public totalRewardsClaimed;

    event RecipientsUpdated(Recipient[] recipients, uint256 totalWeight);
    event Swapped(address tokenIn, address tokenOut, uint256 amountOut);
    event RewardClaimed(uint256 amount);
    event ControllerUpdated(address indexed controller);

    constructor(address controller_, address rewardToken_) {
        controller = controller_;
        rewardToken = rewardToken_;
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

    function setRouters(address uniswapRouter_, address oneInchRouter_) external onlyController {
        uniswapRouter = uniswapRouter_;
        oneInchRouter = oneInchRouter_;
    }

    function setRecipients(Recipient[] calldata updated) external onlyController {
        delete recipients;
        totalWeight = 0;
        for (uint256 i = 0; i < updated.length; i++) {
            recipients.push(updated[i]);
            totalWeight += updated[i].weight;
        }
        require(totalWeight > 0, "NO_RECIPIENTS");
        emit RecipientsUpdated(updated, totalWeight);
    }

    function claimRewards(address rewardSource) external onlyController returns (uint256 amount) {
        amount = IRewardSource(rewardSource).claim(address(this));
        totalRewardsClaimed += amount;
        emit RewardClaimed(amount);
    }

    function swapWithUniswap(address tokenIn, address tokenOut, uint256 amountIn) external onlyController returns (uint256 amountOut) {
        require(uniswapRouter != address(0), "ROUTER_UNSET");
        IERC20(tokenIn).approve(uniswapRouter, amountIn);
        (bool success, bytes memory data) = uniswapRouter.call(
            abi.encodeWithSignature("exactInputSingle(address,address,address,uint256)", tokenIn, tokenOut, address(this), amountIn)
        );
        require(success, "SWAP_FAIL");
        amountOut = abi.decode(data, (uint256));
        rewardToken = tokenOut;
        emit Swapped(tokenIn, tokenOut, amountOut);
    }

    function swapWithOneInch(address tokenIn, address tokenOut, uint256 amountIn) external onlyController returns (uint256 amountOut) {
        require(oneInchRouter != address(0), "ROUTER_UNSET");
        IERC20(tokenIn).approve(oneInchRouter, amountIn);
        (bool success, bytes memory data) = oneInchRouter.call(
            abi.encodeWithSignature("swap(address,address,address,uint256)", tokenIn, tokenOut, address(this), amountIn)
        );
        require(success, "SWAP_FAIL");
        amountOut = abi.decode(data, (uint256));
        rewardToken = tokenOut;
        emit Swapped(tokenIn, tokenOut, amountOut);
    }

    function distribute() external onlyController {
        require(totalWeight > 0, "NO_WEIGHT");
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        for (uint256 i = 0; i < recipients.length; i++) {
            Recipient memory r = recipients[i];
            uint256 share = (balance * r.weight) / totalWeight;
            if (share > 0) {
                IERC20(rewardToken).transfer(r.account, share);
            }
        }
    }

    function treasuryBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
