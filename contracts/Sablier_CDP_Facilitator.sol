// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";
import { SablierNFTPriceEngine } from "./SablierNFTPriceEngine.sol";
import { Types } from "./libraries/Types.sol";
import { GhoToken } from "gho-core/gho/GhoToken.sol";

contract Sablier_CDP_Facilitator {
    /// @notice The maximum number of Sablier NFTs that can be deposited as collateral per user.
    uint256 public constant MAX_COLLATERAL = 10;

    /// @notice The Sablier NFT price engine.
    SablierNFTPriceEngine public immutable sablierNFTPriceEngine;

    /// @notice The GHO token.
    GhoToken public immutable gho;

    /// @notice Keeps track of the Sablier NFTs deposited by each user as collateral.
    mapping(address user => Types.SablierNFT[] nfts) public collateral;

    /// @notice Keeps track of the GHO debt owed by each user.
    mapping(address user => uint256) public debt;

    constructor(SablierNFTPriceEngine _sablierNFTPriceEngine, GhoToken _gho) {
        sablierNFTPriceEngine = _sablierNFTPriceEngine;
        gho = _gho;
    }

    /// @notice Deposit Sablier NFTs into the contract to be used as collateral.
    /// @param sablierLockup The Sablier lockup contract to be used.
    /// @param ids The ids of the Sablier NFTs to be deposited.
    function deposit(ISablierV2Lockup sablierLockup, uint256[] calldata ids) external {
        // Check that `sablierLockup` is whitelisted.
        require(sablierNFTPriceEngine.isWhitelisted(sablierLockup), "Sablier lockup not whitelisted");

        // Check that the Sablier stream is non-cancelable.
        for (uint256 i = 0; i < ids.length; i++) {
            require(!sablierLockup.isCancelable(ids[i]), "Sablier stream is cancelable");
        }

        // Check that MAX_COLLATERAL is not exceeded.
        require(ids.length + collateral[msg.sender].length <= MAX_COLLATERAL, "Too many NFTs deposited");
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
        require(collateralValue >= amount, "Insufficient collateral value");

        // Mint `amount` of GHO to the user.
        gho.mint(msg.sender, amount);
    }

    /// @notice Repay GHO debt.
    /// @param amount The amount of GHO to be repaid.
    function repay(uint256 amount) external {
        // Check that the user has sufficient GHO balance to repay `amount` of GHO.
        gho.transferFrom(msg.sender, address(this), amount);

        // Check that `amount` of GHO is less than or equal to the user's debt.
        require(amount <= debt[msg.sender], "Repaying too much");

        // Burn `amount` of GHO from the user.
        gho.burn(amount);

        // Update the user's debt.
        debt[msg.sender] -= amount;
    }

    /// @notice Withdraw Sablier NFTs from the contract that were used as collateral.
    /// @param idLength The number of Sablier NFTs to be withdrawn.
    function withdraw(uint256 idLength) external {
        // Check that the value of the Sablier NFTs is greater than the debt owed by the user.
        Types.SablierNFT[] memory collateralToWithdraw = new Types.SablierNFT[](idLength);
        for (uint256 i = 0; i < idLength; i++) {
            // Push collateral in reverse order.
            collateralToWithdraw[i] = collateral[msg.sender][collateral[msg.sender].length - i - 1];
        }
        // Get the value of the Sablier NFTs to be withdrawn.
        uint256 collateralValueToWithdraw = sablierNFTPriceEngine.getNormalizedValueAggregate(collateralToWithdraw);

        // Compute new collateral value after withdrawal.
        uint256 newCollateralValue =
            sablierNFTPriceEngine.getNormalizedValueAggregate(collateral[msg.sender]) - collateralValueToWithdraw;

        // Check that the new collateral value is greater than or equal to the debt owed by the user.
        require(newCollateralValue >= debt[msg.sender], "Insufficient collateral value");

        // Transfer the Sablier NFTs from the contract to the user.
        for (uint256 i = 0; i < idLength; i++) {
            collateral[msg.sender].pop();
            collateralToWithdraw[i].sablier.transferFrom(address(this), msg.sender, collateralToWithdraw[i].id);
        }
    }
}
