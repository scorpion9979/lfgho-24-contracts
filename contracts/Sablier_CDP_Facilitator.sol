// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";
import { SablierNFTPriceEngine } from "./SablierNFTPriceEngine.sol";
import { Types } from "./libraries/Types.sol";

contract Sablier_CDP_Facilitator {
    /// @notice The maximum number of Sablier NFTs that can be deposited as collateral per user.
    uint256 public constant MAX_COLLATERAL = 10;

    /// @notice The Sablier NFT price engine.
    SablierNFTPriceEngine public immutable sablierNFTPriceEngine;

    /// @notice Keeps track of the Sablier NFTs deposited by each user as collateral.
    mapping(address user => Types.SablierNFT[] nfts) public collateral;

    constructor(SablierNFTPriceEngine _sablierNFTPriceEngine) {
        sablierNFTPriceEngine = _sablierNFTPriceEngine;
    }

    /// @notice Deposit Sablier NFTs into the contract to be used as collateral.
    /// @param sablierLockup The Sablier lockup contract to be used.
    /// @param ids The ids of the Sablier NFTs to be deposited.
    function deposit(ISablierV2Lockup sablierLockup, uint256[] calldata ids) external {
        // TODO: check that `sablierLockup` is whitelisted.
        // TODO: check that the Sablier stream is non-cancelable.
        // TODO: check that MAX_COLLATERAL is not exceeded.
        for (uint256 i = 0; i < ids.length; i++) {
            // Effect: transfer the NFT from the user to the contract.
            sablierLockup.transferFrom(msg.sender, address(this), ids[i]);
            // Effect: update the collateral bookkeeping.
            collateral[msg.sender].push(Types.SablierNFT(sablierLockup, ids[i]));
        }
    }

    /// @notice Borrow GHO against the Sablier NFTs deposited as collateral.
    /// @param amount The amount of GHO to be borrowed.
    function borrow(uint256 amount) external {
        // Check that the user has sufficient collateral value to borrow `amount` of GHO.
        uint256 collateralValue = sablierNFTPriceEngine.getNormalizedValueAggregate(collateral[msg.sender]);

        // TODO: mint `amount` of GHO to the user.
    }

    /// @notice Repay GHO debt.
    /// @param amount The amount of GHO to be repaid.
    function repay(uint256 amount) external {
        // TODO: check that the user has sufficient GHO balance to repay `amount` of GHO.
        // TODO: check that `amount` of GHO is less than or equal to the user's debt.
        // TODO: burn `amount` of GHO from the user.
    }

    /// @notice Withdraw Sablier NFTs from the contract that were used as collateral.
    /// @param idLength The number of Sablier NFTs to be withdrawn.
    function withdraw(uint256 idLength) external {
        // TODO: check that the NFT(s) to be withdrawn all exist in the contract.
        // TODO: check that the NFT(s) to be withdrawn were originally deposited by the user.
        // TODO: check that the value of the Sablier NFTs is greater than the debt owed by the user.
        for (uint256 i = 0; i < idLength; i++) {
            // Effect: transfer the NFT from the contract to the user.
            collateral[msg.sender][i].sablier.transferFrom(address(this), msg.sender, collateral[msg.sender][i].id);
            // Effect: update the collateral bookkeeping.
            collateral[msg.sender].pop();
        }
    }
}
