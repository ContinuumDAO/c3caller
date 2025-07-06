// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

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
