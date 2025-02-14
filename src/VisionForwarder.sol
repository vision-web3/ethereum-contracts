// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ExcessivelySafeCall} from "@excessivelysafecall/ExcessivelySafeCall.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {VisionRBAC} from "./access/VisionRBAC.sol";
import {VisionRoles} from "./access/VisionRoles.sol";
import {VisionTypes} from "./interfaces/VisionTypes.sol";
import {IVisionForwarder} from "./interfaces/IVisionForwarder.sol";
import {IVisionHub} from "./interfaces/IVisionHub.sol";
import {IVisionToken} from "./interfaces/IVisionToken.sol";

uint256 constant DEFAULT_MINIMUM_VALIDATOR_NODE_SIGNATURES = 3;
uint constant INVALID_VALIDATOR_NODE_INDEX = type(uint).max;

string constant EIP712_DOMAIN_NAME = "Vision";

bytes32 constant TRANSFER_REQUEST_TYPE_HASH = keccak256(
    bytes(VisionTypes.TRANSFER_REQUEST_TYPE)
);
bytes32 constant TRANSFER_TYPE_HASH = keccak256(
    abi.encodePacked(
        VisionTypes.TRANSFER_TYPE,
        VisionTypes.TRANSFER_REQUEST_TYPE
    )
);
bytes32 constant TRANSFER_FROM_REQUEST_TYPE_HASH = keccak256(
    bytes(VisionTypes.TRANSFER_FROM_REQUEST_TYPE)
);
bytes32 constant TRANSFER_FROM_TYPE_HASH = keccak256(
    abi.encodePacked(
        VisionTypes.TRANSFER_FROM_TYPE,
        VisionTypes.TRANSFER_FROM_REQUEST_TYPE
    )
);
bytes32 constant TRANSFER_TO_REQUEST_TYPE_HASH = keccak256(
    bytes(VisionTypes.TRANSFER_TO_REQUEST_TYPE)
);
bytes32 constant TRANSFER_TO_TYPE_HASH = keccak256(
    abi.encodePacked(
        VisionTypes.TRANSFER_TO_TYPE,
        VisionTypes.TRANSFER_TO_REQUEST_TYPE
    )
);

uint256 constant PANDAS_TOKEN_TRANSFER_GAS = 70000;
uint256 constant PANDAS_TOKEN_TRANSFER_FROM_GAS = 50000;

/**
 * @title Vision Forwarder
 *
 * @notice See {IVisionForwarder}.
 *
 * @dev See {IVisionForwarder}.
 */
contract VisionForwarder is IVisionForwarder, EIP712, Pausable, VisionRBAC {
    using ExcessivelySafeCall for address;

    uint8 private immutable _majorProtocolVersion;

    address private _visionHub;

    address private _visionToken;

    uint256 private _minimumValidatorNodeSignatures =
        DEFAULT_MINIMUM_VALIDATOR_NODE_SIGNATURES;

    // Validator node addresses ordered from lowest to highest
    address[] private _validatorNodeAddresses;

    // Used validator node nonces (to prevent replay attacks)
    mapping(uint256 => bool) private _usedValidatorNodeNonces;

    // Used nonces of senders (to prevent replay attacks)
    mapping(address => mapping(uint256 => bool)) private _usedSenderNonces;

    constructor(
        uint8 majorProtocolVersion,
        address accessControllerAddress
    )
        EIP712(EIP712_DOMAIN_NAME, Strings.toString(majorProtocolVersion))
        VisionRBAC(accessControllerAddress)
    {
        _majorProtocolVersion = majorProtocolVersion;
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @notice Modifier making sure that the function can only be called by the
     * Vision Hub.
     */
    modifier onlyVisionHub() {
        require(
            msg.sender == _visionHub,
            "VisionForwarder: caller is not the VisionHub"
        );
        _;
    }

    /**
     * @dev See {Pausable-_pause}.
     */
    function pause() external whenNotPaused onlyRole(VisionRoles.PAUSER) {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause}.
     */
    function unpause()
        external
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS)
    {
        require(
            _visionHub != address(0),
            "VisionForwarder: VisionHub has not been set"
        );
        require(
            _visionToken != address(0),
            "VisionForwarder: VisionToken has not been set"
        );
        require(
            _validatorNodeAddresses.length >= _minimumValidatorNodeSignatures,
            "VisionForwarder: not enough validator nodes added"
        );
        _unpause();
    }

    /**
     * @notice Used by the owner of the Vision Forwarder to set a new Vision
     * Hub address
     *
     * @param visionHub The new Vision Hub address
     *
     * @dev The function is only callable by the owner of the Vision Forwarder
     * contract and can only be called when the contract is paused.
     */
    function setVisionHub(
        address visionHub
    ) external whenPaused onlyRole(VisionRoles.SUPER_CRITICAL_OPS) {
        require(
            visionHub != address(0),
            "VisionForwarder: VisionHub must not be the zero account"
        );
        _visionHub = visionHub;
        emit VisionHubSet(visionHub);
    }

    /**
     * @notice Used by the owner of the Vision Forwarder to set a new Vision
     * Token address
     *
     * @param visionToken The new Vision Token address
     *
     * @dev The function is only callable by the owner of the Vision Forwarder
     * contract and can only be called when the contract is paused.
     */
    function setVisionToken(
        address visionToken
    ) external whenPaused onlyRole(VisionRoles.SUPER_CRITICAL_OPS) {
        require(
            visionToken != address(0),
            "VisionForwarder: VisionToken must not be the zero account"
        );
        _visionToken = visionToken;
        emit VisionTokenSet(visionToken);
    }

    /**
     * @notice Update the minimum number of validator node signatures
     * for validating a cross-chain transfer.
     *
     * @param minimumValidatorNodeSignatures The minimum number of
     * signatures.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function setMinimumValidatorNodeSignatures(
        uint256 minimumValidatorNodeSignatures
    ) external whenPaused onlyRole(VisionRoles.SUPER_CRITICAL_OPS) {
        require(
            minimumValidatorNodeSignatures > 0,
            "VisionForwarder: at least one signature required"
        );
        _minimumValidatorNodeSignatures = minimumValidatorNodeSignatures;
        emit MinimumValidatorNodeSignaturesUpdated(
            minimumValidatorNodeSignatures
        );
    }

    /**
     * @notice Add a new node to the validator network.
     *
     * @param validatorNodeAddress The address of the validator node.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function addValidatorNode(
        address validatorNodeAddress
    ) external whenPaused onlyRole(VisionRoles.SUPER_CRITICAL_OPS) {
        require(
            validatorNodeAddress != address(0),
            "VisionForwarder: validator node address must not be zero"
        );
        _validatorNodeAddresses.push(validatorNodeAddress);
        uint newNumberValidatorNodes = _validatorNodeAddresses.length;
        // Keep the ordering from the lowest to the highest address
        if (newNumberValidatorNodes > 1) {
            address otherValidatorNodeAddress;
            for (uint i = newNumberValidatorNodes - 1; i > 0; i--) {
                otherValidatorNodeAddress = _validatorNodeAddresses[i - 1];
                require(
                    otherValidatorNodeAddress != validatorNodeAddress,
                    "VisionForwarder: validator node already added"
                );
                if (otherValidatorNodeAddress < validatorNodeAddress) {
                    break;
                }
                _validatorNodeAddresses[i] = otherValidatorNodeAddress;
                _validatorNodeAddresses[i - 1] = validatorNodeAddress;
            }
        }
        emit ValidatorNodeAdded(validatorNodeAddress);
    }

    /**
     * @notice Remove a node from the validator network.
     *
     * @param validatorNodeAddress The address of the validator node.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function removeValidatorNode(
        address validatorNodeAddress
    ) external whenPaused onlyRole(VisionRoles.SUPER_CRITICAL_OPS) {
        require(
            validatorNodeAddress != address(0),
            "VisionForwarder: validator node address must not be zero"
        );
        uint validatorNodeIndex = _getValidatorNodeIndex(validatorNodeAddress);
        require(
            validatorNodeIndex != INVALID_VALIDATOR_NODE_INDEX,
            "VisionForwarder: validator node not added"
        );
        uint newNumberValidatorNodes = _validatorNodeAddresses.length - 1;
        // Keep the ordering from the lowest to the highest address
        for (uint i = validatorNodeIndex; i < newNumberValidatorNodes; i++) {
            _validatorNodeAddresses[i] = _validatorNodeAddresses[i + 1];
        }
        _validatorNodeAddresses.pop();
        emit ValidatorNodeRemoved(validatorNodeAddress);
    }

    /**
     * @dev See {IVisionForwarder-verifyAndForwardTransfer}.
     */
    function verifyAndForwardTransfer(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused onlyVisionHub returns (bool, bytes32) {
        // Verify the nonce and signature
        verifyTransfer(request, signature);
        // Mark the nonce as used
        _usedSenderNonces[request.sender][request.nonce] = true;
        // Transfer the fee to the service node
        IVisionToken(_visionToken).visionTransfer(
            request.sender,
            request.serviceNode,
            request.fee
        );
        // Transfer the tokens from the sender to the recipient
        // The transaction is not supposed to be reverted if the token
        // transfer fails to ensure that the service node gets paid
        bool succeeded;
        bytes memory tokenData;
        require(
            gasleft() * 63 >= 64 * PANDAS_TOKEN_TRANSFER_GAS,
            "VisionForwarder: Not enough gas for `visionTransfer` call provided"
        );
        (succeeded, tokenData) = request.token.excessivelySafeCall(
            PANDAS_TOKEN_TRANSFER_GAS,
            0,
            32,
            abi.encodeWithSelector(
                IVisionToken.visionTransfer.selector,
                request.sender,
                request.recipient,
                request.amount
            )
        );
        return (succeeded, bytes32(tokenData));
    }

    /**
     * @dev See {IVisionForwarder-verifyAndForwardTransferFrom}.
     */
    function verifyAndForwardTransferFrom(
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor,
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused onlyVisionHub returns (bool, bytes32) {
        // Verify the nonce and signature
        verifyTransferFrom(request, signature);
        // Mark the nonce as used
        _usedSenderNonces[request.sender][request.nonce] = true;
        // Split the transfer fee
        uint256 serviceNodeFee;
        uint256 validatorNodeFee;
        (serviceNodeFee, validatorNodeFee) = _splitTransferFromFee(
            request.fee,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
        // Transfer the fee to the service node
        IVisionToken(_visionToken).visionTransfer(
            request.sender,
            request.serviceNode,
            serviceNodeFee
        );
        // Transfer the tokens from the sender
        // The transaction is not supposed to be reverted if the token
        // transfer fails to ensure that the service node gets paid
        bool succeeded;
        bytes memory sourceTokenData;
        require(
            gasleft() * 63 >= 64 * PANDAS_TOKEN_TRANSFER_GAS,
            "VisionForwarder: Not enough gas for `visionTransferFrom` call provided"
        );
        (succeeded, sourceTokenData) = request.sourceToken.excessivelySafeCall(
            PANDAS_TOKEN_TRANSFER_FROM_GAS,
            0,
            32,
            abi.encodeWithSelector(
                IVisionToken.visionTransferFrom.selector,
                request.sender,
                request.amount
            )
        );
        // Transfer the fee to the primary validator node
        if (succeeded) {
            IVisionToken(_visionToken).visionTransfer(
                request.sender,
                IVisionHub(_visionHub).getPrimaryValidatorNode(),
                validatorNodeFee
            );
        }
        return (succeeded, bytes32(sourceTokenData));
    }

    /**
     * @dev See {IVisionForwarder-verifyAndForwardTransferTo}.
     */
    function verifyAndForwardTransferTo(
        VisionTypes.TransferToRequest calldata request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external override whenNotPaused onlyVisionHub {
        // Verify the nonce and signatures
        verifyTransferTo(request, signerAddresses, signatures);
        // Mark the nonce as used
        _usedValidatorNodeNonces[request.nonce] = true;
        // Transfer the tokens to the recipient
        IVisionToken(request.destinationToken).visionTransferTo(
            request.recipient,
            request.amount
        );
    }

    /**
     * @dev See {IVisionForwarder-getMajorProtocolVersion}.
     */
    function getMajorProtocolVersion() public view override returns (uint8) {
        return _majorProtocolVersion;
    }

    /**
     * @dev See {IVisionForwarder-getVisionHub}.
     */
    function getVisionHub() public view override returns (address) {
        return _visionHub;
    }

    /**
     * @dev See {IVisionForwarder-getVisionToken}.
     */
    function getVisionToken() public view override returns (address) {
        return _visionToken;
    }

    /**
     * @dev See {IVisionForwarder-getMinimumValidatorNodeSignatures}.
     */
    function getMinimumValidatorNodeSignatures()
        external
        view
        override
        returns (uint256)
    {
        return _minimumValidatorNodeSignatures;
    }

    /**
     * @dev See {IVisionForwarder-getValidatorNodes}.
     */
    function getValidatorNodes()
        external
        view
        override
        returns (address[] memory)
    {
        return _validatorNodeAddresses;
    }

    /**
     * @dev See {IVisionForwarder-isValidValidatorNodeNonce}.
     */
    function isValidValidatorNodeNonce(
        uint256 nonce
    ) external view override returns (bool) {
        return !_usedValidatorNodeNonces[nonce];
    }

    /**
     * @dev See {IVisionForwarder-isValidSenderNonce}.
     */
    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) public view override returns (bool) {
        return !_usedSenderNonces[sender][nonce];
    }

    /**
     * @dev See {IVisionForwarder-verifyTransfer}.
     */
    function verifyTransfer(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) public view override {
        // Token and service node are verified by the VisionHub
        // In a token transfer within a single blockchain, the sender and
        // recipient addresses must not be identical
        require(
            request.sender != request.recipient,
            "VisionForwarder: sender and recipient must not be identical"
        );
        // Verify the amount, sender nonce, validity period, and signature
        _verifyAmount(request.amount);
        _verifySenderNonce(request.sender, request.nonce);
        _verifyValidUntil(request.validUntil);
        _verifyTransferSignature(request, signature);
    }

    /**
     * @dev See {IVisionForwarder-verifyTransferFrom}.
     */
    function verifyTransferFrom(
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) public view override {
        // Destination blockchain, token, and service node are verified by the
        // VisionHub
        // Verify the amount, sender nonce, validity period, and signature
        _verifyAmount(request.amount);
        _verifySenderNonce(request.sender, request.nonce);
        _verifyValidUntil(request.validUntil);
        _verifyTransferFromSignature(request, signature);
    }

    /**
     * @dev See {IVisionForwarder-verifyTransferTo}.
     */
    function verifyTransferTo(
        VisionTypes.TransferToRequest calldata request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) public view override {
        // Source blockchain and token are verified by the VisionHub
        // Verify the amount, validator nonce, and signatures
        _verifyAmount(request.amount);
        _verifyValidatorNodeNonce(request.nonce);
        _verifyTransferToSignatures(request, signerAddresses, signatures);
    }

    function _getValidatorNodeIndex(
        address validatorNodeAddress
    ) private view returns (uint) {
        return _getValidatorNodeIndex(validatorNodeAddress, 0);
    }

    function _getValidatorNodeIndex(
        address validatorNodeAddress,
        uint startIndex
    ) private view returns (uint) {
        uint numberValidatorNodes = _validatorNodeAddresses.length;
        for (uint i = startIndex; i < numberValidatorNodes; i++) {
            if (_validatorNodeAddresses[i] == validatorNodeAddress) {
                return i;
            }
        }
        return INVALID_VALIDATOR_NODE_INDEX;
    }

    function _verifyAmount(uint256 amount) private pure {
        require(amount > 0, "VisionForwarder: amount must be greater than 0");
    }

    function _verifyValidatorNodeNonce(uint256 nonce) private view {
        require(
            !_usedValidatorNodeNonces[nonce],
            "VisionForwarder: validator node nonce invalid"
        );
    }

    function _verifySenderNonce(address sender, uint256 nonce) private view {
        require(
            !_usedSenderNonces[sender][nonce],
            "VisionForwarder: sender nonce invalid"
        );
    }

    function _verifyValidUntil(uint256 validUntil) private view {
        // slither-disable-next-line timestamp
        require(
            block.timestamp <= validUntil,
            "VisionForwarder: validity period has expired"
        );
    }

    function _verifyTransferSignature(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) private view {
        bytes32 structHash = _hashTransferStruct(request);
        // Verify that the sender signed the message
        _verifySignature(structHash, request.sender, signature);
    }

    function _verifyTransferFromSignature(
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) private view {
        bytes32 structHash = _hashTransferFromStruct(request);
        // Verify that the sender signed the message
        _verifySignature(structHash, request.sender, signature);
    }

    function _verifyTransferToSignatures(
        VisionTypes.TransferToRequest calldata request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) private view {
        bytes32 structHash = _hashTransferToStruct(request);
        // Verify that enough validator nodes signed the message
        uint numberSigners = signerAddresses.length;
        require(
            numberSigners == signatures.length,
            "VisionForwarder: numbers of signers and signatures must match"
        );
        require(
            numberSigners >= _minimumValidatorNodeSignatures,
            "VisionForwarder: insufficient number of signatures"
        );
        address previousSignerAddress = address(0);
        address currentSignerAddress;
        uint validatorNodeIndex = 0;
        for (uint i = 0; i < numberSigners; i++) {
            currentSignerAddress = signerAddresses[i];
            // Ensure that the signer address is unique and non-zero
            require(
                currentSignerAddress > previousSignerAddress,
                string.concat(
                    "VisionForwarder: invalid signer ",
                    Strings.toHexString(currentSignerAddress)
                )
            );
            // Search only from the given start index to improve the gas
            // efficiency (which is possible due to the ordering of the
            // validator node addresses)
            validatorNodeIndex = _getValidatorNodeIndex(
                currentSignerAddress,
                validatorNodeIndex
            );
            require(
                validatorNodeIndex != INVALID_VALIDATOR_NODE_INDEX,
                string.concat(
                    "VisionForwarder: non-validator signer ",
                    Strings.toHexString(currentSignerAddress)
                )
            );
            _verifySignature(structHash, currentSignerAddress, signatures[i]);
            previousSignerAddress = currentSignerAddress;
            validatorNodeIndex++;
        }
    }

    function _verifySignature(
        bytes32 structHash,
        address signerAddress,
        bytes memory signature
    ) private view {
        // Hash of the fully encoded EIP712 message
        bytes32 messageHash = _hashTypedDataV4(structHash);
        // Recover the signer's address from the signature
        address recoveredSignerAddress = ECDSA.recover(messageHash, signature);
        require(
            recoveredSignerAddress == signerAddress,
            string.concat(
                "VisionForwarder: invalid signature by ",
                Strings.toHexString(signerAddress)
            )
        );
    }

    function _splitTransferFromFee(
        uint256 totalFee,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor
    ) private pure returns (uint256 serviceNodeFee, uint256 validatorNodeFee) {
        uint256 totalFactor = sourceBlockchainFactor +
            destinationBlockchainFactor;
        serviceNodeFee = (sourceBlockchainFactor * totalFee) / totalFactor;
        validatorNodeFee = totalFee - serviceNodeFee;
    }

    function _hashString(
        string calldata string_
    ) private pure returns (bytes32) {
        return keccak256(bytes(string_));
    }

    function _hashTransferRequestStruct(
        VisionTypes.TransferRequest calldata request
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRANSFER_REQUEST_TYPE_HASH,
                    request.sender,
                    request.recipient,
                    request.token,
                    request.amount,
                    request.serviceNode,
                    request.fee,
                    request.nonce,
                    request.validUntil
                )
            );
    }

    function _hashTransferStruct(
        VisionTypes.TransferRequest calldata request
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRANSFER_TYPE_HASH,
                    _hashTransferRequestStruct(request),
                    IVisionHub(_visionHub).getCurrentBlockchainId(),
                    _visionHub,
                    address(this),
                    _visionToken
                )
            );
    }

    function _hashTransferFromRequestStruct(
        VisionTypes.TransferFromRequest calldata request
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRANSFER_FROM_REQUEST_TYPE_HASH,
                    request.destinationBlockchainId,
                    request.sender,
                    _hashString(request.recipient),
                    request.sourceToken,
                    _hashString(request.destinationToken),
                    request.amount,
                    request.serviceNode,
                    request.fee,
                    request.nonce,
                    request.validUntil
                )
            );
    }

    function _hashTransferFromStruct(
        VisionTypes.TransferFromRequest calldata request
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRANSFER_FROM_TYPE_HASH,
                    _hashTransferFromRequestStruct(request),
                    IVisionHub(_visionHub).getCurrentBlockchainId(),
                    _visionHub,
                    address(this),
                    _visionToken
                )
            );
    }

    function _hashTransferToRequestStruct(
        VisionTypes.TransferToRequest calldata request
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRANSFER_TO_REQUEST_TYPE_HASH,
                    request.sourceBlockchainId,
                    request.sourceTransferId,
                    _hashString(request.sourceTransactionId),
                    _hashString(request.sender),
                    request.recipient,
                    _hashString(request.sourceToken),
                    request.destinationToken,
                    request.amount,
                    request.nonce
                )
            );
    }

    function _hashTransferToStruct(
        VisionTypes.TransferToRequest calldata request
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRANSFER_TO_TYPE_HASH,
                    _hashTransferToRequestStruct(request),
                    IVisionHub(_visionHub).getCurrentBlockchainId(),
                    _visionHub,
                    address(this),
                    _visionToken
                )
            );
    }
}
