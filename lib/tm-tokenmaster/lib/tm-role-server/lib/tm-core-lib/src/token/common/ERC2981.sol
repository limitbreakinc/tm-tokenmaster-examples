pragma solidity ^0.8.4;

import "./IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    struct StorageERC2981 {
        RoyaltyInfo defaultRoyaltyInfo;
        mapping(uint256 tokenId => RoyaltyInfo) tokenRoyaltyInfo;
    }

    bytes32 private constant ERC2981_STORAGE_SLOT = keccak256("storage.ERC2981");

    function storageERC2981() internal pure returns (StorageERC2981 storage ptr) {
        bytes32 slot = ERC2981_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    address private immutable _staticRoyaltyFeeRecipient;
    uint96 private immutable _staticRoyaltyBps;
    bool private immutable _canSetPerTokenRoyalties;

    error ERC2981InvalidDefaultRoyalty(uint256 numerator, uint256 denominator);
    error ERC2981InvalidDefaultRoyaltyReceiver(address receiver);
    error ERC2981InvalidTokenRoyalty(uint256 tokenId, uint256 numerator, uint256 denominator);
    error ERC2981InvalidTokenRoyaltyReceiver(uint256 tokenId, address receiver);
    error ERC2981TokenRoyaltiesDisabled();

    constructor(address staticRoyaltyFeeRecipient, uint96 staticRoyaltyBps, bool canSetPerTokenRoyalties) {
        _staticRoyaltyFeeRecipient = staticRoyaltyFeeRecipient;
        _staticRoyaltyBps = staticRoyaltyBps;
        _canSetPerTokenRoyalties = canSetPerTokenRoyalties;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view virtual returns (address royaltyReceiver, uint256 royaltyAmount) {
        royaltyReceiver = staticRoyaltyFeeRecipient();
        uint96 royaltyFraction = staticRoyaltyBps();

        if (royaltyReceiver == address(0)) {
            if (canSetPerTokenRoyalties()) {
                RoyaltyInfo storage _royaltyInfo = storageERC2981().tokenRoyaltyInfo[tokenId];
                royaltyReceiver = _royaltyInfo.receiver;
                royaltyFraction = _royaltyInfo.royaltyFraction;
            }

            if (royaltyReceiver == address(0)) {
                royaltyReceiver = storageERC2981().defaultRoyaltyInfo.receiver;
                royaltyFraction = storageERC2981().defaultRoyaltyInfo.royaltyFraction;
            }
        }

        royaltyAmount = (salePrice * royaltyFraction) / _feeDenominator();
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        uint256 denominator = _feeDenominator();
        if (feeNumerator > denominator) {
            // Royalty fee will exceed the sale price
            revert ERC2981InvalidDefaultRoyalty(feeNumerator, denominator);
        }
        if (receiver == address(0)) {
            revert ERC2981InvalidDefaultRoyaltyReceiver(address(0));
        }

        storageERC2981().defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) internal virtual {
        if (!canSetPerTokenRoyalties()) {
            revert ERC2981TokenRoyaltiesDisabled();
        }

        uint256 denominator = _feeDenominator();
        if (feeNumerator > denominator) {
            // Royalty fee will exceed the sale price
            revert ERC2981InvalidTokenRoyalty(tokenId, feeNumerator, denominator);
        }
        if (receiver == address(0)) {
            revert ERC2981InvalidTokenRoyaltyReceiver(tokenId, address(0));
        }

        storageERC2981().tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    function staticRoyaltyFeeRecipient() public view virtual returns (address) {
        return _staticRoyaltyFeeRecipient;
    }

    function staticRoyaltyBps() public view virtual returns (uint96) {
        return _staticRoyaltyBps;
    }
    
    function canSetPerTokenRoyalties() public view virtual returns (bool) {
        return _canSetPerTokenRoyalties;
    }
}