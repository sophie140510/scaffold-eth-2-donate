// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title DOUGH ERC20 token
/// @notice Minted and burned by the Controller to represent redeemable deposits.
contract DOUGH is ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _burnedSupply;

    constructor(address admin_) ERC20("DOUGH", "DOUGH") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /// @notice Mint tokens to a receiver. Restricted to minters.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice Burn tokens from a holder. Restricted to burners.
    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, amount);
        _burnedSupply += amount;
    }

    /// @notice Burn caller balance. Restricted to burners.
    function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
        super.burn(amount);
        _burnedSupply += amount;
    }

    /// @notice Total amount of tokens ever burned.
    function burnedSupply() external view returns (uint256) {
        return _burnedSupply;
    }
}
