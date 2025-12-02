// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "./Vm.sol";

contract Test {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(address a, address b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(bool a, bool b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertGt(uint256 a, uint256 b, string memory err) internal pure {
        require(a > b, err);
    }

    function assertApproxEqAbs(uint256 a, uint256 b, uint256 maxDelta, string memory err) internal pure {
        uint256 diff = a > b ? a - b : b - a;
        require(diff <= maxDelta, err);
    }
}
