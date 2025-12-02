// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Extremely small Aave v3 style pool mock with linear interest.
contract MockAavePool {
    struct ReserveData {
        uint256 balance;
        uint256 lastUpdate;
        uint256 rateBps; // annual rate
    }

    mapping(address => ReserveData) public reserves;

    uint256 private constant SECONDS_PER_YEAR = 365 days;

    event Deposit(address indexed asset, address indexed user, uint256 amount);
    event Withdraw(address indexed asset, address indexed user, uint256 amount);
    event RateChanged(address indexed asset, uint256 rateBps);

    function setRate(address asset, uint256 rateBps) external {
        _accrue(asset);
        reserves[asset].rateBps = rateBps;
        emit RateChanged(asset, rateBps);
    }

    function deposit(address asset, uint256 amount, address onBehalfOf) external {
        _accrue(asset);
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        reserves[asset].balance += amount;
        emit Deposit(asset, onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        _accrue(asset);
        ReserveData storage reserve = reserves[asset];
        uint256 available = reserve.balance;
        if (amount > available) {
            amount = available;
        }
        reserve.balance -= amount;
        IERC20(asset).transfer(to, amount);
        emit Withdraw(asset, to, amount);
        return amount;
    }

    function getBalance(address asset) external view returns (uint256) {
        ReserveData memory reserve = _accruedView(asset);
        return reserve.balance;
    }

    function _accrue(address asset) internal {
        ReserveData storage reserve = reserves[asset];
        if (reserve.lastUpdate == 0) {
            reserve.lastUpdate = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - reserve.lastUpdate;
        if (elapsed == 0 || reserve.balance == 0 || reserve.rateBps == 0) {
            reserve.lastUpdate = block.timestamp;
            return;
        }
        uint256 interest = (reserve.balance * reserve.rateBps * elapsed) / (SECONDS_PER_YEAR * 10_000);
        reserve.balance += interest;
        reserve.lastUpdate = block.timestamp;
    }

    function _accruedView(address asset) internal view returns (ReserveData memory reserve) {
        reserve = reserves[asset];
        if (reserve.lastUpdate == 0 || reserve.balance == 0 || reserve.rateBps == 0) {
            return reserve;
        }
        uint256 elapsed = block.timestamp - reserve.lastUpdate;
        uint256 interest = (reserve.balance * reserve.rateBps * elapsed) / (SECONDS_PER_YEAR * 10_000);
        reserve.balance += interest;
        reserve.lastUpdate = block.timestamp;
    }
}
