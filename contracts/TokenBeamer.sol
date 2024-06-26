// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenBeamer
 * @author xtools-at <github.com/xtools-at>
 * @notice A smart contract to facilitate batch token transfers (native, ERC-20, -721, -1155) and -approval checks.
 */
contract TokenBeamer is Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    /**
     *
     * Setup
     *
     */

    // State variables
    address payable internal _tipRecipient;
    bool private _upgradesDisabled;

    // Errors
    error BadInput();
    error UnsupportedTokenType(uint16 type_);
    error UpgradesDisabled();

    // Events
    event TipRecipientSet(address indexed newRecipient);
    event ContractUpgradesDisabled();

    // Modifiers
    /**
     * @dev Throws if upgrades are disabled
     */
    modifier onlyUpgradeable() {
        if (_upgradesDisabled) {
            revert UpgradesDisabled();
        }
        _;
    }

    /**
     *
     * Constructor & Co
     *
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Receiver for native currency. Reverts if currency is sent directly to the contract.
     */
    receive() external payable virtual {
        revert();
    }

    function initialize() external virtual initializer {
        __Ownable_init_unchained(_msgSender());
        __ReentrancyGuard_init_unchained();

        _tipRecipient = payable(_msgSender());
        emit TipRecipientSet(_msgSender());
    }

    /**
     *
     * External/Public functions
     *
     */

    /**
     * @dev Multi-transfer tokens and NFTs to a single or many recipients.
     *
     * @param to Addresses of token recipients. Must have a length of 1 or `tokens.length`.
     * @param tokens Contract addresses of tokens (use 0x0 for native transfers).
     * @param types Types of tokens (supported: 0|20|721|1155).
     * @param ids Identifier numbers of tokens (ERC-721 and -1155 only).
     * @param values Quantities of tokens to transfer.
     */
    function beamTokens(
        address payable[] calldata to,
        address[] calldata tokens,
        uint16[] calldata types,
        uint256[] calldata ids,
        uint256[] calldata values
    ) external payable virtual nonReentrant {
        // check input
        bool multipleRecipients = to.length > 1;
        if (
            to.length == 0 || (multipleRecipients && to.length != tokens.length) || tokens.length == 0
                || tokens.length != types.length || tokens.length != ids.length || tokens.length != values.length
        ) {
            revert BadInput();
        }

        // transfer tokens
        for (uint256 i = 0; i < tokens.length; ++i) {
            _processTransfer(_msgSender(), multipleRecipients ? to[i] : to[0], tokens[i], types[i], ids[i], values[i]);
        }

        // transfer tips sent to the protocol, make sure there are no leftover native funds stuck in the contract
        if (address(this).balance > 0) {
            Address.sendValue(_tipRecipient, address(this).balance);
        }
    }

    /**
     * @dev Sets a new recipient for protocol tips. Owner only.
     *
     * @param newRecipient address of new tip recipient.
     */
    function setTipRecipient(address payable newRecipient) external virtual onlyOwner {
        if (newRecipient == address(0) || newRecipient == _tipRecipient) {
            revert BadInput();
        }

        _tipRecipient = newRecipient;
        emit TipRecipientSet(newRecipient);
    }

    /**
     * @dev Permanently disables upgrades for the contract. Owner only.
     */
    function disableUpgrades() external virtual onlyUpgradeable onlyOwner {
        _upgradesDisabled = true;
        emit ContractUpgradesDisabled();
    }

    /**
     * @dev Recovers funds stuck in the contract. Owner only.
     */
    function recoverFunds(address payable to, address token, uint16 type_, uint256 id, uint256 value)
        external
        virtual
        nonReentrant
        onlyOwner
    {
        _processTransfer(address(this), to, token, type_, id, value);
    }

    /**
     * @dev Checks approval state for tokens for the given `operator` address.
     * This is a gas-intensive convenience method that is meant to be consumed by applications, and should
     * preferably not be called from a smart contract directly.
     *
     * @notice Default behaviour for empty types, ids and values parameters:
     * Types (0 = native, 20 = ERC-20, 721 = ERC-721, 1155 = ERC-1155):
     * - If types are provided, the contract uses them to check the approval state.
     * - If types are not provided, the contract checks if ids are provided to defaut to ERC-721, then
     *   checks for values to default to ERC-20, and if not, defaults to ERC-1155.
     * Ids (only used for ERC-721):
     * - If ids are provided, the contract uses them to check the approval state of corresponding ERC-721 id.
     * - If ids are not provided, the contract defaults to ERC-721.
     * Values (only used for ERC-20):
     * - If values are provided, the contract uses them to check the approval amount of ERC-20.
     * - If values are not provided, the contract defaults the value to 1.
     *
     * @param owner Owner of tokens.
     * @param operator Spender of tokens (e.g. TokenBeamer contract).
     * @param tokens Contract addresses of tokens.
     * @param types Types of tokens (supported: 20|721|1155). Only used for ERC20, can be left empty otherwise.
     * @param ids Identifier of tokens. Only used for ERC721, can be left empty otherwise.
     * @param values Quantities of approved tokens. Only used for ERC20, can be left empty otherwise.
     *
     * @return approvalStates Array of booleans to indicate whether `owner`'s `token` is approved for `operator`.
     */
    function getApprovals(
        address owner,
        address operator,
        address[] calldata tokens,
        uint16[] calldata types,
        uint256[] calldata ids,
        uint256[] calldata values
    ) external view virtual returns (bool[] memory) {
        return _getApprovals(owner, operator, tokens, types, ids, values);
    }

    /**
     * @dev Returns the upgradeability state of the contract.
     */
    function upgradesDisabled() public view virtual returns (bool) {
        return _upgradesDisabled;
    }

    /**
     *
     * Internal/Private functions
     *
     */

    /**
     * @dev Conducts single transfer for native currency, ERC-20, -721 and -1155.
     */
    function _processTransfer(address from, address payable to, address token, uint16 type_, uint256 id, uint256 value)
        internal
        virtual
    {
        // don't allow sending to zero address or qty of 0
        if (to == address(0) || value == 0) {
            revert BadInput();
        }

        // transfer tokens by token type
        if (type_ == 721) {
            // ERC721 transfer
            IERC721(token).safeTransferFrom(from, to, id);
        } else if (type_ == 1155) {
            // ERC1155 transfer
            IERC1155(token).safeTransferFrom(from, to, id, value, "");
        } else if (type_ == 20) {
            // safe ERC20 transfer
            SafeERC20.safeTransferFrom(IERC20(token), from, to, value);
        } else if (type_ == 0) {
            // native transfer
            Address.sendValue(to, value);
        } else {
            // unsupported token type
            revert UnsupportedTokenType(type_);
        }
    }

    /**
     * @dev ERC-1967 proxy auth override for upgradable contract.
     * - ownership required
     * - check for upgrades being disabled permanently
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal virtual override onlyUpgradeable onlyOwner {}

    /**
     * @dev Gets approval states of multiple tokens for a given owner and operator.
     * No types provided defaults to ERC-721 if ids are provided, ERC-20 if values are provided,
     * and ERC-1155 otherwise, in said order. Note that ERC-1155 approval checks for all, not for specific ids.
     */
    function _getApprovals(
        address owner,
        address operator,
        address[] calldata tokens,
        uint16[] calldata types,
        uint256[] calldata ids,
        uint256[] calldata values
    ) internal view virtual returns (bool[] memory approvalStates) {
        // check input
        bool hasTypes = types.length > 0;
        bool hasValues = values.length > 0;
        bool hasIds = ids.length > 0;
        if (
            owner == address(0) || operator == address(0) || tokens.length == 0
                || (hasTypes && tokens.length != types.length) || (hasValues && tokens.length != values.length)
                || (hasIds && tokens.length != ids.length)
        ) {
            revert BadInput();
        }

        // check approvals
        approvalStates = new bool[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            approvalStates[i] = _getApproval(
                owner,
                operator,
                tokens[i],
                hasTypes ? types[i] : (hasIds ? 721 : (hasValues ? 20 : 1155)),
                hasIds ? ids[i] : 0,
                hasValues ? values[i] : 1
            );
        }

        return approvalStates;
    }

    /**
     * @dev Returns the approval state for ERC-20, -721 and -1155.
     */
    function _getApproval(address owner, address operator, address token, uint16 type_, uint256 id, uint256 value)
        internal
        view
        virtual
        returns (bool approved)
    {
        // check approvals by token type
        if (type_ == 1155) {
            // ERC721 & ERC1155 share the same approval lookup method
            return IERC1155(token).isApprovedForAll(owner, operator);
        } else if (type_ == 721) {
            // ERC721
            return owner == operator || IERC721(token).isApprovedForAll(owner, operator)
                || (IERC721(token).getApproved(id) == operator && IERC721(token).ownerOf(id) == owner);
        } else if (type_ == 20) {
            // ERC20
            return IERC20(token).allowance(owner, operator) >= value;
        } else if (type_ == 0) {
            // Native currency, no approval needed - shim to not break bulk lookups
            return true;
        } else {
            revert UnsupportedTokenType(type_);
        }
    }
}
