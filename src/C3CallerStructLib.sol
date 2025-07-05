// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library C3CallerStructLib {
    struct C3EvmMessage {
        bytes32 uuid;
        address to;
        string fromChainID;
        string sourceTx;
        string fallbackTo;
        bytes data;
    }
}
