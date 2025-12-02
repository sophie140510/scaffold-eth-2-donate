// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Lightweight Aave-like pool mock supporting linear interest accrual and admin yield top ups.
contract MockAavePool {
    using SafeERC20 for IERC20;

    struct ReserveData {
        uint256 totalBalance;
        uint256 lastUpdate;
        uint256 rateBps; // annual rate out of 10_000
        uint256 index; // ray-style accumulator (1e18 == 1x)
    }

    address public immutable admin;
    mapping(address => ReserveData) public reserves;
    mapping(address => mapping(address => uint256)) private userBalances;
    mapping(address => mapping(address => uint256)) private userIndex;

    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant RAY = 1e18;

    event Deposit(address indexed asset, address indexed user, uint256 amount);
    event Withdraw(address indexed asset, address indexed user, uint256 amount);
    event RateChanged(address indexed asset, uint256 rateBps);

    constructor(address _admin) {
        admin = _admin;
    }

    // --- rate management ---

    function setRate(address asset, uint256 rateBps) external {
        _accrue(asset);
        reserves[asset].rateBps = rateBps;
        emit RateChanged(asset, rateBps);
    }

    // --- deposit/supply ---

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        _deposit(asset, amount, onBehalfOf);
    }

    /// @dev Convenience alias mirroring some pool ABIs.
    function deposit(address asset, uint256 amount, address onBehalfOf) external {
        _deposit(asset, amount, onBehalfOf);
    }

    function _deposit(address asset, uint256 amount, address onBehalfOf) internal {
        require(amount > 0, "ZERO_AMOUNT");
        _accrueUser(asset, onBehalfOf);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        userBalances[asset][onBehalfOf] += amount;
        reserves[asset].totalBalance += amount;

        emit Deposit(asset, onBehalfOf, amount);
    }

    // --- withdrawal ---

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        _accrueUser(asset, msg.sender);

        uint256 balance = userBalances[asset][msg.sender];
        require(balance >= amount, "INSUFFICIENT_BALANCE");

        userBalances[asset][msg.sender] = balance - amount;
        reserves[asset].totalBalance -= amount;
        IERC20(asset).safeTransfer(to, amount);

        emit Withdraw(asset, to, amount);
        return amount;
    }

    // --- views ---

    function balanceOf(address asset, address user) external view returns (uint256) {
        return _accruedUserView(asset, user);
    }

    function getBalance(address asset) external view returns (uint256) {
        ReserveData memory reserve = _accruedView(asset);
        return reserve.totalBalance;
    }

    // --- testing helpers ---

    function simulateYield(address asset, address user, uint256 amount) external {
        require(msg.sender == admin, "ONLY_ADMIN");
        _accrueUser(asset, user);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        userBalances[asset][user] += amount;
        reserves[asset].totalBalance += amount;
    }

    // --- accrual helpers ---

    function _accrue(address asset) internal {
        ReserveData storage reserve = reserves[asset];
        if (reserve.index == 0) {
            reserve.index = RAY;
            reserve.lastUpdate = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - reserve.lastUpdate;
        if (elapsed == 0 || reserve.totalBalance == 0 || reserve.rateBps == 0) {
            reserve.lastUpdate = block.timestamp;
            return;
        }

        uint256 interestFactor = (reserve.index * reserve.rateBps * elapsed) / (SECONDS_PER_YEAR * 10_000);
        reserve.index += interestFactor;
        reserve.lastUpdate = block.timestamp;
    }

    function _accrueUser(address asset, address user) internal {
        _accrue(asset);
        uint256 currentIndex = reserves[asset].index;
        uint256 storedIndex = userIndex[asset][user];
        if (storedIndex == 0) {
            userIndex[asset][user] = currentIndex;
            return;
        }
        if (currentIndex == storedIndex) return;

        uint256 balance = userBalances[asset][user];
        if (balance == 0) {
            userIndex[asset][user] = currentIndex;
            return;
        }

        uint256 accrued = (balance * (currentIndex - storedIndex)) / RAY;
        if (accrued > 0) {
            userBalances[asset][user] = balance + accrued;
            reserves[asset].totalBalance += accrued;
        }
        userIndex[asset][user] = currentIndex;
    }

    function _accruedView(address asset) internal view returns (ReserveData memory reserve) {
        reserve = reserves[asset];
        if (reserve.index == 0 || reserve.totalBalance == 0 || reserve.rateBps == 0) {
            return reserve;
        }

        uint256 elapsed = block.timestamp - reserve.lastUpdate;
        uint256 interestFactor = (reserve.index * reserve.rateBps * elapsed) / (SECONDS_PER_YEAR * 10_000);
        reserve.index += interestFactor;
        reserve.lastUpdate = block.timestamp;
    }

    function _accruedUserView(address asset, address user) internal view returns (uint256) {
        ReserveData memory reserve = _accruedView(asset);
        uint256 storedIndex = userIndex[asset][user];
        if (storedIndex == 0) return userBalances[asset][user];
        uint256 currentIndex = reserve.index;
        if (currentIndex == storedIndex) return userBalances[asset][user];

        uint256 balance = userBalances[asset][user];
        uint256 accrued = (balance * (currentIndex - storedIndex)) / RAY;
        return balance + accrued;
    }
}
