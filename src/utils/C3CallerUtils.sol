// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

enum Uint {
    ChainID,
    Calldata,
    DAppID,
    FeePerByte,
    AppDomain,
    Email,
    Address,
    PubKey,
    Token
}

enum Account {
    Sender,
    C3Caller,
    To,
    Valid,
    Admin,
    GovOrAdmin,
    GovOrOperator,
    Operator,
    Gov
}

contract C3CallerUtils {}
