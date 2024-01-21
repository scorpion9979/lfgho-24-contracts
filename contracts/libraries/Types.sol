// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";

contract Types {
    struct SablierNFT {
        ISablierV2Lockup sablier;
        uint256 id;
    }
}
