// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

struct Uint256Set {
    uint256[] vals;
    mapping(uint256 => bool) saved;
}

library LibUint256Set {
    function add(Uint256Set storage s, uint256 val) internal {
        if (!s.saved[val]) {
            s.vals.push(val);
            s.saved[val] = true;
        }
    }

    function contains(Uint256Set storage s, uint256 val) internal view returns (bool) {
        return s.saved[val];
    }

    function count(Uint256Set storage s) internal view returns (uint256) {
        return s.vals.length;
    }

    function rand(Uint256Set storage s, uint256 seed) internal view returns (uint256) {
        if (s.vals.length > 0) {
            return s.vals[seed % s.vals.length];
        } else {
            return 0;
        }
    }
}