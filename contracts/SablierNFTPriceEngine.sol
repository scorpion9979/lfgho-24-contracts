// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";
import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ChainlinkOperator as ERC20PriceEngine } from "./ChainlinkOperator.sol";
import { Types } from "./libraries/Types.sol";

/// @title SablierNFTPriceEngine
/// @notice Provides price data for Sablier NFTs.
/// @dev Assumes that the Sablier streams are non-cancelable.
contract SablierNFTPriceEngine {
    ERC20PriceEngine public immutable erc20PriceEngine;

    /// @notice A whitelist of Sablier lockups.
    mapping(ISablierV2Lockup => bool) public isWhitelisted;

    constructor(ERC20PriceEngine _erc20PriceEngine) {
        erc20PriceEngine = _erc20PriceEngine;
    }

    /// @notice Returns the normalized price of a Sablier NFT.
    /// @param sablierNFT The Sablier NFT to be priced.
    function getNormalizedValue(Types.SablierNFT calldata sablierNFT) public view returns (uint256) {
        IERC20 erc20Asset = IERC20(address(sablierNFT.sablier.getAsset(sablierNFT.id)));
        uint256 normalizedER20Price = erc20PriceEngine.getNormalizedPrice(erc20Asset.symbol());
        uint256 lockedAmount =
            sablierNFT.sablier.getDepositedAmount(sablierNFT.id) - sablierNFT.sablier.getWithdrawnAmount(sablierNFT.id);
        uint256 normalizedNFTValue = (lockedAmount * normalizedER20Price) / 1e18;
        return normalizedNFTValue;
    }

    /// @notice Returns the normalized price of a collection of Sablier NFTs.
    /// @param sablierNFTs The Sablier NFTs to be priced.
    function getNormalizedValueAggregate(Types.SablierNFT[] calldata sablierNFTs) external view returns (uint256) {
        uint256 totalNormalizedValue = 0;
        for (uint256 i = 0; i < sablierNFTs.length; i++) {
            totalNormalizedValue += getNormalizedValue(sablierNFTs[i]);
        }
        return totalNormalizedValue;
    }

    function whitelist(ISablierV2Lockup sablierLockup, bool newStatus) external {
        isWhitelisted[sablierLockup] = newStatus;
    }
}
