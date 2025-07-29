// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { C3CallerUtils, Uint } from "../utils/C3CallerUtils.sol";
import { C3GovernDapp } from "./C3GovernDapp.sol";
import { IC3Governor } from "./IC3Governor.sol";

contract C3Governor is IC3Governor, C3GovernDapp {
    using Strings for *;
    using C3CallerUtils for string;

    struct Proposal {
        bytes[] data;
        bool[] hasFailed;
    }

    mapping(bytes32 => Proposal) private _proposal;
    bytes32 public proposalId;

    // TODO: make the upgradeable contract work with this non-upgradeable contract
    constructor(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID) {
        __C3GovernDapp_init(_gov, _c3CallerProxy, _txSender, _dappID);
    }

    function chainID() internal view returns (uint256) {
        return block.chainid;
    }

    // TODO: gen nonce
    function sendParams(bytes memory _data, bytes32 _nonce) external /*onlyGov*/ {
        // require(_data.length > 0, "C3Governor: No data to sendParams");
        if (_data.length == 0) {
            revert C3Governor_InvalidLength(Uint.Calldata);
        }

        _proposal[_nonce].data.push(_data);
        _proposal[_nonce].hasFailed.push(false);

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external /*onlyGov*/ {
        // require(_data.length > 0, "C3Governor: No data to sendParams");
        if (_data.length == 0) {
            revert C3Governor_InvalidLength(Uint.Calldata);
        }

        for (uint256 _index = 0; _index < _data.length; _index++) {
            // require(_data[index].length > 0, "C3Governor: No data passed to sendParams");
            if (_data.length == 0) {
                revert C3Governor_InvalidLength(Uint.Calldata);
            }
            _proposal[_nonce].data.push(_data[_index]);
            _proposal[_nonce].hasFailed.push(false);

            _c3gov(_nonce, _index);
        }
        emit NewProposal(_nonce);
    }

    // Anyone can resend one of the cross chain calls in proposalId if it failed
    function doGov(bytes32 _nonce, uint256 _offset) external {
        // require(offset < _proposal[_nonce].data.length, "C3Governor: Reading beyond the length of the offset array");
        if (_offset >= _proposal[_nonce].data.length) {
            revert C3Governor_OutOfBounds();
        }
        // require(_proposal[_nonce].hasFailed[offset] == true, "C3Governor: Do not resend if it did not fail");
        if (!_proposal[_nonce].hasFailed[_offset]) {
            revert C3Governor_HasNotFailed();
        }

        _c3gov(_nonce, _offset);
    }

    function getProposalData(bytes32 _nonce, uint256 _offset) external view returns (bytes memory, bool) {
        return (_proposal[_nonce].data[_offset], _proposal[_nonce].hasFailed[_offset]);
    }

    function _c3gov(bytes32 _nonce, uint256 _offset) internal {
        uint256 _chainId;
        string memory _target;
        bytes memory _remoteData;

        bytes memory _rawData = _proposal[_nonce].data[_offset];
        // TODO add flag which config using gov to send or operator
        (_chainId, _target, _remoteData) = abi.decode(_rawData, (uint256, string, bytes));

        if (_chainId == chainID()) {
            address _to = _target.toAddress();
            (bool _success,) = _to.call(_remoteData);
            if (_success) {
                _proposal[_nonce].hasFailed[_offset] = true;
            }
        } else {
            _proposal[_nonce].hasFailed[_offset] = true;
            emit C3GovernorLog(_nonce, _chainId, _target, _remoteData);
        }
    }

    function version() public pure returns (uint256) {
        return (1);
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        override
        returns (bool)
    {
        uint256 _len = proposalLength();

        _proposal[proposalId].hasFailed[_len - 1] = true;

        emit LogFallback(_selector, _data, _reason);
        return true;
    }

    // The number of cross chain invocations in proposalId
    function proposalLength() public view returns (uint256) {
        uint256 _len = _proposal[proposalId].data.length;
        return (_len);
    }
}
