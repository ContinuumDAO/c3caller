// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IC3Governor } from "../../gov/IC3Governor.sol";

import { C3ErrorParam } from "../../utils/C3CallerUtils.sol";
import { C3CallerUtils } from "../../utils/C3CallerUtils.sol";

import { C3GovernDappUpgradeable } from "./C3GovernDappUpgradeable.sol";

contract C3GovernorUpgradeable is IC3Governor, C3GovernDappUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using C3CallerUtils for string;

    mapping(bytes32 => Proposal) private _proposal;
    bytes32 public proposalId;

    function initialize(address _gov, address _c3CallerProxy, address _txSender, uint256 _dappID)
        external
        initializer
    {
        __C3GovernDapp_init(_gov, _c3CallerProxy, _txSender, _dappID);
    }

    function chainID() internal view returns (uint256) {
        return block.chainid;
    }

    function sendParams(bytes memory _data, bytes32 _nonce) external onlyGov {
        if (_data.length == 0) {
            revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
        }

        _proposal[_nonce].data.push(_data);
        _proposal[_nonce].hasFailed.push(false);

        emit NewProposal(_nonce);

        _c3gov(_nonce, 0);
    }

    function sendMultiParams(bytes[] memory _data, bytes32 _nonce) external onlyGov {
        if (_data.length == 0) {
            revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
        }

        for (uint256 i = 0; i < _data.length; i++) {
            if (_data[i].length == 0) {
                revert C3Governor_InvalidLength(C3ErrorParam.Calldata);
            }
            _proposal[_nonce].data.push(_data[i]);
            _proposal[_nonce].hasFailed.push(false);
        }

        emit NewProposal(_nonce);

        for (uint256 i = 0; i < _data.length; i++) {
            _c3gov(_nonce, i);
        }
    }

    function doGov(bytes32 _nonce, uint256 _offset) external onlyGov {
        if (_offset >= _proposal[_nonce].data.length) {
            revert C3Governor_OutOfBounds();
        }
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

    function _authorizeUpgrade(address newImplementation) internal override onlyGov { }
}
