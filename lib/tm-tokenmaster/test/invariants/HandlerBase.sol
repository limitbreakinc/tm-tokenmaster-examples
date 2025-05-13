// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Base.sol";
import "forge-std/StdCheats.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";
import "./AddressSet.sol";
import "./Uint256Set.sol";
import "../Constants.sol";

abstract contract HandlerBase is CommonBase, StdCheats, StdUtils {
    using LibAddressSet for AddressSet;
    using LibUint256Set for Uint256Set;

    mapping(bytes32 => uint256) public calls;

    AddressSet internal _actors;
    address internal currentActor;
    address internal currentActorTo;

    Uint256Set internal _signers;
    uint160 internal currentSignerPk;

    function _isAdditionalRestrictedAccount(address /*account*/) internal virtual view returns (bool) {
        return false;
    }

    modifier createActor() {
        if (msg.sender == address(0) ||
            msg.sender == address(this) ||
            msg.sender == address(0x4e59b44847b379578588920cA78FbF26c0B4956C) ||
            msg.sender == address(0xa0Cb889707d426A7A386870A03bc70d1b0697598) ||
            msg.sender == address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a) ||
            msg.sender == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            msg.sender == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D) ||
            _isAdditionalRestrictedAccount(msg.sender)) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        currentActor = msg.sender;
        _actors.add(msg.sender);
        _;
    }

    modifier addActor(address actor) {
        if (actor == address(this) ||
            actor == address(0x4e59b44847b379578588920cA78FbF26c0B4956C) ||
            actor == address(0xa0Cb889707d426A7A386870A03bc70d1b0697598) ||
            actor == address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a) ||
            actor == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            actor == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D) ||
            _isAdditionalRestrictedAccount(actor)) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        _actors.add(actor);
        _;
    }

    modifier createActorFromPK(uint160 pk) {
        if (pk == 0) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        address actor = vm.addr(pk);
        if (actor == address(this) ||
            actor == address(0x4e59b44847b379578588920cA78FbF26c0B4956C) ||
            actor == address(0xa0Cb889707d426A7A386870A03bc70d1b0697598) ||
            actor == address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a) ||
            actor == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            actor == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D) ||
            _isAdditionalRestrictedAccount(actor)) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        _actors.add(actor);
        _;
    }

    modifier createSignerFromPK(uint160 pk) {
        if (pk == 0) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        address signer = vm.addr(pk);
        if (signer == address(this) ||
            signer == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            signer == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D) ||
            _isAdditionalRestrictedAccount(signer)) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        currentSignerPk = pk;
        _signers.add(pk);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        if (currentActor == address(0) || _isAdditionalRestrictedAccount(currentActor)) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }
        _;
    }

    modifier useSigner(uint256 signerIndexSeed) {
        currentSignerPk = uint160(_signers.rand(signerIndexSeed));
        if (currentSignerPk == 0) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }

        if (vm.addr(currentSignerPk) == address(0) || _isAdditionalRestrictedAccount(vm.addr(currentSignerPk))) {
            assembly ("memory-safe") {
                return(0,0)
            }
        }
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor() {}

    receive() external payable {}

    function forEachActor(function(address) external func) public {
        return _actors.forEach(func);
    }

    function reduceActors(uint256 acc, function(uint256,address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _actors.reduce(acc, func);
    }

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    function callSummary() external virtual view;
}