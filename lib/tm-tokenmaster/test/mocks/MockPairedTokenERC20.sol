// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/token/erc20/ERC20.sol";

contract MockPairedTokenERC20 is ERC20 {
    uint8 internal _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}