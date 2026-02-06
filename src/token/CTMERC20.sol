// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {C3GovernDApp} from "../gov/C3GovernDApp.sol";
import {C3CallerUtils, C3ErrorParam} from "../utils/C3CallerUtils.sol";
import {ICTMERC20} from "./ICTMERC20.sol";

abstract contract CTMERC20 is ICTMERC20, ERC20, C3GovernDApp {
    using C3CallerUtils for *;
    using Strings for address;

    /// @notice The supply of the token aggregated across all networks.
    uint256 public globalSupply;

    /// @notice Mapping from chain ID to the address of the instance of this contract deployed to that network.
    mapping(string => string) public peers;

    /**
     * @notice Constructor for CTMERC20 cross-chain token.
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     * @param _c3caller The address of the c3caller contract on the deployed network.
     * @param _dappID The dapp ID that was registered in `C3DAppManager`.
     * @dev The sender is the governance address by default.
     */
    constructor(string memory _name, string memory _symbol, address _c3caller, uint256 _dappID)
        ERC20(_name, _symbol)
        C3GovernDApp(msg.sender, _c3caller, _dappID)
    {}

    /**
     * @notice Transfer tokens from a sender to an account on a peer network.
     * @param _toStr The address of the receiver account on the destination network.
     * @param _amount The amount to transfer between the accounts.
     * @param _toChainIDStr The chain ID of the destination network.
     * @dev Destination account is formatted as string to allow non-EVM compatibility.
     * @dev Burns supply locally and initiates a cross-chain transaction.
     * @dev Only C3Caller can call this function via `execute`.
     */
    function c3transfer(string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        public
        virtual
        returns (bool)
    {
        if (bytes(peers[_toChainIDStr]).length == 0) revert CTMERC20_InvalidChainID(_toChainIDStr);
        if (bytes(_toStr).length == 0) revert CTMERC20_InvalidLength(C3ErrorParam.To);

        address _from = _msgSender();
        _burn(_from, _amount);

        string memory _fromStr = _from.toHexString();
        bytes memory receiveCall = abi.encodeWithSelector(this.c3receive.selector, _fromStr, _toStr, _amount);
        _c3call(peers[_toChainIDStr], _toChainIDStr, receiveCall);

        emit C3Transfer(_from, _toStr, _amount, _toChainIDStr);
        return true;
    }

    /**
     * @notice Transfer tokens from a local address to an account on a peer network.
     * @param _from The address of the sender account on the source network (this network).
     * @param _toStr The address of the receiver account on the destination network.
     * @param _amount The amount to transfer between the accounts.
     * @param _toChainIDStr The chain ID of the destination network.
     * @dev Destination account is formatted as string to allow non-EVM compatibility.
     * @dev Burns supply locally and initiates a cross-chain transaction.
     * @dev Only C3Caller can call this function via `execute`.
     */
    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        public
        virtual
        returns (bool)
    {
        if (bytes(peers[_toChainIDStr]).length == 0) revert CTMERC20_InvalidChainID(_toChainIDStr);
        if (bytes(_toStr).length == 0) revert CTMERC20_InvalidLength(C3ErrorParam.To);

        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);

        string memory _fromStr = _from.toHexString();
        bytes memory receiveCall = abi.encodeWithSelector(this.c3receive.selector, _fromStr, _toStr, _amount);
        _c3call(peers[_toChainIDStr], _toChainIDStr, receiveCall);

        emit C3Transfer(_from, _toStr, _amount, _toChainIDStr);
        return true;
    }

    /**
     * @notice Mint supply locally from a cross-chain `c3transfer` or `c3transferFrom` call.
     * @param _fromStr The address of the sender account on the source network.
     * @param _toStr The address of the receiver account on the destination network (this network).
     * @param _amount The amount to transfer between the accounts.
     * @dev Only C3Caller can call this function via `execute`.
     */
    function c3receive(string memory _fromStr, string memory _toStr, uint256 _amount) external virtual onlyC3Caller {
        address _to = _toStr.toAddress();
        (, string memory _fromChainID,) = _context();
        _mint(_to, _amount);
        emit C3Receive(_fromStr, _to, _amount, _fromChainID);
    }

    /**
     * @notice Set the address of the sister contract on another network, to faciliate interaction.
     * @param _toChainIDStr The chain ID of the network.
     * @param _peerStr The address of the CTMERC20 on the other network.
     * @dev Only governance can call this function.
     * @dev The arguments are formatted as strings to allow non-EVM compatibility.
     */
    function setPeer(string memory _toChainIDStr, string memory _peerStr) external virtual onlyGov {
        peers[_toChainIDStr] = _peerStr;
        emit SetPeer(_toChainIDStr, _peerStr);
    }

    /**
     * @notice Required `c3Fallback` implementation to handle failed cross-chain transactions.
     * @param _selector The selector of the failed function, which will always be the `c3receive` selector, 0x7e071e2a.
     * @param _data The arguments that failed, which will always contain the sender, recipient and amount.
     * @param _reason The returned reason for failure on the target network.
     */
    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        override
        returns (bool)
    {
        if (_selector == this.c3receive.selector) {
            (string memory _fromStr, string memory _toStr, uint256 _amount) =
                abi.decode(_data, (string, string, uint256));
            address _from = _fromStr.toAddress();
            _mint(_from, _amount);
            emit C3Refund(_from, _toStr, _amount, _reason);
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Virtual function to increment the supply that exists locally and across all peer network instances.
     * @param _amount The amount to increment global supply by (the mint amount).
     * @dev Implement this wherever supply is increased, such as constructor for initial mint or function `mint`.
     */
    function _incrementGlobalSupply(uint256 _amount) internal virtual;

    /**
     * @notice Virtual function to decrement the supply that exists locally and across all peer network instances.
     * @param _amount The amount to decrement global supply by (the burn amount).
     * @dev Implement this wherever supply is decreased, such as function `burn`. If global supply is never burned,
     * implement this function with no body.
     */
    function _decrementGlobalSupply(uint256 _amount) internal virtual;
}
