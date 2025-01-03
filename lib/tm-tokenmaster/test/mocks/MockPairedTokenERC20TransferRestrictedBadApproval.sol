// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/token/erc20/ERC20.sol";

contract MockPairedTokenERC20TransferRestrictedBadApproval is ERC20 {
    uint8 internal _decimals;
    address immutable allowedTransferBy;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address allowedTransferBy_) ERC20(name_, symbol_) {
        _decimals = decimals_;
        allowedTransferBy = allowedTransferBy_;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (msg.sender != allowedTransferBy) {
            revert();
        }
        bool returnValue = super.transferFrom(from, to, amount);
        StorageERC20.data().allowances[_getAllowanceKey(from, msg.sender)] = 0;
        emit Approval(from, msg.sender, 0);
        return returnValue;
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