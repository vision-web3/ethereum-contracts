// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VisionTypes} from "../interfaces/VisionTypes.sol";
import {IVisionForwarder} from "../interfaces/IVisionForwarder.sol";
import {IVisionToken} from "../interfaces/IVisionToken.sol";
import {IVisionTransfer} from "../interfaces/IVisionTransfer.sol";

import {VisionBaseFacet} from "./VisionBaseFacet.sol";

/**
 * @title Vision Transfer facet
 *
 * @notice See {IVisionTransfer}.
 */
contract VisionTransferFacet is IVisionTransfer, VisionBaseFacet {
    /**
     * @dev See {IVisionTransfer-transfer}.
     */
    function transfer(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused returns (uint256) {
        // Caller must be the service node in the transfer request
        require(
            msg.sender == request.serviceNode,
            "VisionHub: caller must be the service node"
        );
        // Verify the token and service node
        _verifyTransfer(request);
        // Assign a new transfer ID
        uint256 transferId = s.nextTransferId++;
        // Forward the transfer request
        bool succeeded;
        bytes32 tokenData;
        // slither-disable-next-line reentrancy-events
        (succeeded, tokenData) = IVisionForwarder(s.visionForwarder)
            .verifyAndForwardTransfer(request, signature);
        if (succeeded) {
            emit TransferSucceeded(transferId, request, signature);
        } else {
            emit TransferFailed(transferId, request, signature, tokenData);
        }
        return transferId;
    }

    /**
     * @dev See {IVisionTransfer-transferFrom}.
     */
    function transferFrom(
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused returns (uint256) {
        // Caller must be the service node in the transfer request
        require(
            msg.sender == request.serviceNode,
            "VisionHub: caller must be the service node"
        );
        // Verify the destination blockchain, token, and service node
        _verifyTransferFrom(request);
        // Assign a new transfer ID
        uint256 sourceTransferId = s.nextTransferId++;
        // Forward the transfer request
        uint256 sourceBlockchainFactor = s
            .validatorFeeFactors[s.currentBlockchainId]
            .currentValue;
        uint256 destinationBlockchainFactor = s
            .validatorFeeFactors[request.destinationBlockchainId]
            .currentValue;
        bool succeeded;
        bytes32 sourceTokenData;
        // slither-disable-next-line reentrancy-events
        (succeeded, sourceTokenData) = IVisionForwarder(s.visionForwarder)
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        if (succeeded) {
            emit TransferFromSucceeded(sourceTransferId, request, signature);
        } else {
            emit TransferFromFailed(
                sourceTransferId,
                request,
                signature,
                sourceTokenData
            );
        }
        return sourceTransferId;
    }

    /**
     * @dev See {IVisionTransfer-transferTo}.
     */
    function transferTo(
        VisionTypes.TransferToRequest calldata request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    )
        external
        override
        whenNotPaused
        onlyPrimaryValidatorNode
        returns (uint256)
    {
        // Verify the source blockchain and token
        _verifyTransferTo(request);
        // Mark the source transfer ID as used
        s.usedSourceTransferIds[request.sourceBlockchainId][
            request.sourceTransferId
        ] = true;
        // Assign a new transfer ID
        uint256 destinationTransferId = s.nextTransferId++;
        emit TransferToSucceeded(
            destinationTransferId,
            request,
            signerAddresses,
            signatures
        );
        // Forward the transfer request
        IVisionForwarder(s.visionForwarder).verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
        return destinationTransferId;
    }

    /**
     * @dev See {IVisionTransfer-isValidSenderNonce}.
     */
    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view override returns (bool) {
        return
            IVisionForwarder(s.visionForwarder).isValidSenderNonce(
                sender,
                nonce
            );
    }

    /**
     * @dev See {IVisionTransfer-verifyTransfer}.
     */
    function verifyTransfer(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) external view override {
        // Verify the token and service node
        _verifyTransfer(request);
        // Verify the remaining transfer request (including the signature)
        IVisionForwarder(s.visionForwarder).verifyTransfer(request, signature);
        // Verify the sender's balance
        _verifyTransferBalance(
            request.sender,
            request.token,
            request.amount,
            request.fee
        );
    }

    /**
     * @dev See {IVisionTransfer-verifyTransferFrom}.
     */
    function verifyTransferFrom(
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external view override {
        // Verify the destination blockchain, token, and service node
        _verifyTransferFrom(request);
        // Verify the remaining transfer request (including the signature)
        IVisionForwarder(s.visionForwarder).verifyTransferFrom(
            request,
            signature
        );
        // Verify the sender's balance
        _verifyTransferBalance(
            request.sender,
            request.sourceToken,
            request.amount,
            request.fee
        );
    }

    /**
     * @dev See {IVisionTransfer-verifyTransferTo}.
     */
    function verifyTransferTo(
        VisionTypes.TransferToRequest calldata request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external view override {
        // Verify the source blockchain and token
        _verifyTransferTo(request);
        // Verify the remaining transfer request (including the signatures)
        IVisionForwarder(s.visionForwarder).verifyTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function getNextTransferId() public view returns (uint256) {
        return s.nextTransferId;
    }

    function _verifyTransfer(
        VisionTypes.TransferRequest calldata request
    ) private view {
        // Verify the token
        _verifyTransferToken(request.token);
        // Verify if the service node is active
        _verifyTransferServiceNode(request.serviceNode);
    }

    function _verifyTransferFrom(
        VisionTypes.TransferFromRequest calldata request
    ) private view {
        // Verify the destination blockchain
        require(
            request.destinationBlockchainId != s.currentBlockchainId,
            "VisionHub: source and destination blockchains must not be equal"
        );
        _verifyTransferBlockchain(request.destinationBlockchainId);
        // Verify the source and destination token
        _verifyTransferToken(request.sourceToken);
        _verifyTransferExternalToken(
            request.sourceToken,
            request.destinationBlockchainId,
            request.destinationToken
        );
        // Verify if the service node is active
        _verifyTransferServiceNode(request.serviceNode);
    }

    function _verifyTransferTo(
        VisionTypes.TransferToRequest calldata request
    ) private view {
        if (request.sourceBlockchainId != s.currentBlockchainId) {
            _verifyTransferBlockchain(request.sourceBlockchainId);
            _verifyTransferExternalToken(
                request.destinationToken,
                request.sourceBlockchainId,
                request.sourceToken
            );
        }
        _verifyTransferToken(request.destinationToken);
        _verifySourceTransferId(
            request.sourceBlockchainId,
            request.sourceTransferId
        );
    }

    function _verifyTransferBlockchain(uint256 blockchainId) private view {
        // Blockchain must be active
        VisionTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "VisionHub: blockchain must be active"
        );
    }

    function _verifyTransferToken(address token) private view {
        VisionTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "VisionHub: token must be registered");
        require(
            IVisionToken(token).getVisionForwarder() == s.visionForwarder,
            "VisionHub: Forwarder of Hub and transferred token must match"
        );
    }

    function _verifyTransferExternalToken(
        address token,
        uint256 blockchainId,
        string memory externalToken
    ) private view {
        // External token must be active
        VisionTypes.ExternalTokenRecord storage externalTokenRecord = s
            .externalTokenRecords[token][blockchainId];
        require(
            externalTokenRecord.active,
            "VisionHub: external token must be registered"
        );
        // Registered external token must match the external token of the
        // transfer
        require(
            keccak256(bytes(externalTokenRecord.externalToken)) ==
                keccak256(bytes(externalToken)),
            "VisionHub: incorrect external token"
        );
    }

    function _verifyTransferServiceNode(address serviceNode) private view {
        // Service node must be active
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNode];
        require(
            serviceNodeRecord.active,
            "VisionHub: service node must be registered"
        );
        // Service node must have enough deposit
        require(
            serviceNodeRecord.deposit >=
                s.minimumServiceNodeDeposit.currentValue,
            "VisionHub: service node must have enough deposit"
        );
    }

    function _verifyTransferBalance(
        address sender,
        address token,
        uint256 amount,
        uint256 fee
    ) private view {
        if (token == s.visionToken) {
            require(
                (amount + fee) <= IERC20(s.visionToken).balanceOf(sender),
                "VisionHub: insufficient balance of sender"
            );
        } else {
            require(
                amount <= IERC20(token).balanceOf(sender),
                "VisionHub: insufficient balance of sender"
            );
            require(
                fee <= IERC20(s.visionToken).balanceOf(sender),
                "VisionHub: insufficient balance of sender for fee payment"
            );
        }
    }

    function _verifySourceTransferId(
        uint256 sourceBlockchainId,
        uint256 sourceTransferId
    ) private view {
        // Source transfer ID must not have been used before
        require(
            !s.usedSourceTransferIds[sourceBlockchainId][sourceTransferId],
            "VisionHub: source transfer ID already used"
        );
    }
}
