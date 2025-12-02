// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    function deposit(uint256 amount) external returns (uint256);

    function withdraw(uint256 amount, address recipient) external returns (uint256);

    function totalAssets() external view returns (uint256);
}
