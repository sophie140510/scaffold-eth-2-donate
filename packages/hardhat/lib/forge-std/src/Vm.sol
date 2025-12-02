// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface Vm {
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function startPrank(address msgSender, address txOrigin) external;
    function stopPrank() external;
    function deal(address who, uint256 newBalance) external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool, bool, bool, bool) external;
    function addr(uint256) external returns (address payable);
}
