// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

/*
 * Contains tests which should be excluded from coverage reports, since
 * forge coverage does not use the optimizer to get a better source mapping.
 * Since the current tests cover potential bugs in optimized state,
 * we exclude them from the coverage report.
 */

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Vm} from "forge-std/Test.sol";

import {IVisionForwarder} from "../src/interfaces/IVisionForwarder.sol";
import {VisionForwarder} from "../src/VisionForwarder.sol";
import {VisionTypes} from "../src/interfaces/VisionTypes.sol";
import {IVisionRegistry} from "../src/interfaces/IVisionRegistry.sol";
import {VisionBaseToken} from "../src/VisionBaseToken.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionBaseTest} from "./VisionBaseTest.t.sol";
import {GasDrainingContract} from "./helpers/GasDrainingContract.sol";

contract VisionForwarderNoCoverageTest is VisionBaseTest {
    address public constant VISION_HUB_ADDRESS =
        address(uint160(uint256(keccak256("VisionHubAddress"))));
    address constant VISION_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("VisionTokenAddress"))));

    string constant EIP712_DOMAIN_NAME = "Vision";
    bytes32 constant EIP712_DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain("
            "string name,"
            "string version,"
            "uint256 chainId,"
            "address verifyingContract)"
        );

    VisionForwarder public visionForwarder;
    AccessController public accessController;

    address[] _validators = [
        validatorAddress,
        validatorAddress2,
        validatorAddress3,
        validatorAddress4
    ];

    mapping(address => Vm.Wallet) _validatorWallets;

    uint256 public validatorCount;
    uint256[] public validatorCounts = [1, 2, 3, 4];

    function setUp() public {
        accessController = deployAccessController();
        deployVisionForwarder(accessController);
        setUpValidatorWallets();
    }

    function setUpValidatorWallets() public {
        _validatorWallets[validatorAddress] = validatorWallet;
        _validatorWallets[validatorAddress2] = validatorWallet2;
        _validatorWallets[validatorAddress3] = validatorWallet3;
        _validatorWallets[validatorAddress4] = validatorWallet4;
    }

    function test_SetUpState() external view {
        assertTrue(visionForwarder.paused());
    }

    modifier parameterizedTest(uint256[] memory testSets) {
        uint256 length = testSets.length;
        for (uint256 i = 0; i < length; ) {
            validatorCount = testSets[i];
            setUp();
            i++;
            _;
        }
    }

    function test_verifyAndForwardTransfer_NotEnoughGasFromServiceNodeProvided()
        external
        parameterizedTest(validatorCounts)
    {
        GasDrainingContract gasDrainingContract = new GasDrainingContract(
            1000,
            address(accessController)
        );
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();

        vm.startPrank(SUPER_CRITICAL_OPS);
        gasDrainingContract.setVisionForwarder(address(visionForwarder));
        gasDrainingContract.unpause();
        gasDrainingContract.transfer(request.sender, request.amount);
        vm.stopPrank();
        request.token = address(gasDrainingContract);

        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);

        setupMockAndExpectFor_verifyAndForwardTransferLight(request);
        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert(
            "VisionForwarder: Not enough gas for `visionTransfer` call provided"
        );

        bool succeeded;
        bytes32 tokenData;
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer{
            gas: 116049
        }(request, signature);

        assertFalse(succeeded);
    }

    function test_verifyAndForwardTransferFrom_NotEnoughGasFromServiceNodeProvided()
        external
        parameterizedTest(validatorCounts)
    {
        GasDrainingContract gasDrainingContract = new GasDrainingContract(
            1000,
            address(accessController)
        );
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();

        vm.startPrank(SUPER_CRITICAL_OPS);
        gasDrainingContract.setVisionForwarder(address(visionForwarder));
        gasDrainingContract.unpause();
        gasDrainingContract.transfer(request.sender, request.amount);
        vm.stopPrank();

        request.sourceToken = address(gasDrainingContract);

        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;

        setupMockAndExpectFor_verifyAndForwardTransferFromLight(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert(
            "VisionForwarder: Not enough gas for `visionTransferFrom` call provided"
        );

        bool succeeded;
        bytes32 sourceTokenData;

        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom{gas: 97000}(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );

        assertFalse(succeeded);
    }

    //  All the mock utils here
    function mockAndExpectVisionHub_getPrimaryValidatorNode() public {
        vm.mockCall(
            VISION_HUB_ADDRESS,
            abi.encodeWithSelector(
                IVisionRegistry.getPrimaryValidatorNode.selector
            ),
            abi.encode(validatorAddress)
        );

        vm.expectCall(
            VISION_HUB_ADDRESS,
            abi.encodeWithSelector(
                IVisionRegistry.getPrimaryValidatorNode.selector
            )
        );
    }

    function mockAndExpectVisionHub_getCurrentBlockchainId(
        BlockchainId blockchainId
    ) public {
        vm.mockCall(
            VISION_HUB_ADDRESS,
            abi.encodeWithSelector(
                IVisionRegistry.getCurrentBlockchainId.selector
            ),
            abi.encode(uint256(blockchainId))
        );

        vm.expectCall(
            VISION_HUB_ADDRESS,
            abi.encodeWithSelector(
                IVisionRegistry.getCurrentBlockchainId.selector
            )
        );
    }

    function mockAndExpectVisionBaseToken_visionTransfer(
        address tokenAddress,
        address sender,
        address recipient,
        uint256 amount,
        bool succeeded,
        bytes32 tokenData
    ) public {
        bytes memory abiEncodedWithSelector = abi.encodeWithSelector(
            VisionBaseToken.visionTransfer.selector,
            sender,
            recipient,
            amount
        );
        if (succeeded) {
            vm.mockCall(tokenAddress, abiEncodedWithSelector, abi.encode());
        } else {
            vm.mockCallRevert(
                tokenAddress,
                abiEncodedWithSelector,
                abi.encode(tokenData)
            );
        }
        vm.expectCall(tokenAddress, abiEncodedWithSelector);
    }

    function mockAndExpectVisionBaseToken_visionTransferFrom(
        VisionTypes.TransferFromRequest memory request,
        bool succeeded,
        bytes32 sourceTokenData
    ) public {
        bytes memory abiEncodedWithSelector = abi.encodeWithSelector(
            VisionBaseToken.visionTransferFrom.selector,
            request.sender,
            request.amount
        );
        if (succeeded) {
            vm.mockCall(
                request.sourceToken,
                abiEncodedWithSelector,
                abi.encode()
            );
        } else {
            vm.mockCallRevert(
                request.sourceToken,
                abiEncodedWithSelector,
                abi.encode(sourceTokenData)
            );
        }
        vm.expectCall(request.sourceToken, abiEncodedWithSelector);
    }

    function mockAndExpectVisionBaseToken_visionTransferTo(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public {
        bytes memory abiEncodedWithSelector = abi.encodeWithSelector(
            VisionBaseToken.visionTransferTo.selector,
            recipient,
            amount
        );
        vm.mockCall(tokenAddress, abiEncodedWithSelector, abi.encode());
        vm.expectCall(tokenAddress, abiEncodedWithSelector);
    }

    function setupMockAndExpectFor_verifyAndForwardTransfer(
        VisionTypes.TransferRequest memory request,
        bool succeeded,
        bytes32 tokenData
    ) public {
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectVisionBaseToken_visionTransfer(
            request.token,
            request.sender,
            request.recipient,
            request.amount,
            succeeded,
            tokenData
        );
        mockAndExpectVisionBaseToken_visionTransfer(
            VISION_TOKEN_ADDRESS,
            request.sender,
            request.serviceNode,
            request.fee,
            true,
            ""
        );
    }

    function setupMockAndExpectFor_verifyAndForwardTransferLight(
        VisionTypes.TransferRequest memory request
    ) public {
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectVisionBaseToken_visionTransfer(
            VISION_TOKEN_ADDRESS,
            request.sender,
            request.serviceNode,
            request.fee,
            true,
            ""
        );
    }

    function setupMockAndExpectFor_verifyAndForwardTransferFromLight(
        VisionTypes.TransferFromRequest memory request,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor
    ) public {
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        uint256 totalFactor = sourceBlockchainFactor +
            destinationBlockchainFactor;
        uint256 serviceNodeFee = (sourceBlockchainFactor * request.fee) /
            totalFactor;
        mockAndExpectVisionBaseToken_visionTransfer(
            VISION_TOKEN_ADDRESS,
            request.sender,
            request.serviceNode,
            serviceNodeFee,
            true,
            ""
        );
    }

    function setupMockAndExpectFor_verifyAndForwardTransferFrom(
        VisionTypes.TransferFromRequest memory request,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor,
        bool succeeded,
        bytes32 sourceTokenData
    ) public {
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectVisionBaseToken_visionTransferFrom(
            request,
            succeeded,
            sourceTokenData
        );
        uint256 totalFactor = sourceBlockchainFactor +
            destinationBlockchainFactor;
        uint256 serviceNodeFee = (sourceBlockchainFactor * request.fee) /
            totalFactor;
        mockAndExpectVisionBaseToken_visionTransfer(
            VISION_TOKEN_ADDRESS,
            request.sender,
            request.serviceNode,
            serviceNodeFee,
            true,
            ""
        );
        if (succeeded) {
            uint256 validatorFee = request.fee - serviceNodeFee;
            mockAndExpectVisionBaseToken_visionTransfer(
                VISION_TOKEN_ADDRESS,
                request.sender,
                validatorAddress,
                validatorFee,
                true,
                ""
            );
            mockAndExpectVisionHub_getPrimaryValidatorNode();
        }
    }

    function setupMockAndExpectFor_verifyAndForwardTransferTo(
        VisionTypes.TransferToRequest memory request
    ) public {
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectVisionBaseToken_visionTransferTo(
            request.destinationToken,
            request.recipient,
            request.amount
        );
    }

    // Mocks end here

    function deployVisionForwarder(AccessController accessController_) public {
        visionForwarder = new VisionForwarder(
            MAJOR_PROTOCOL_VERSION,
            address(accessController_)
        );
    }

    function getValidatorNodeAddresses()
        public
        view
        returns (address[] memory)
    {
        address[] memory validatorNodeAddresses = new address[](
            validatorCount
        );
        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            validatorNodeAddresses[i] = _validators[i];
        }
        return validatorNodeAddresses;
    }

    function initializeVisionForwarder() public {
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();
        initializeVisionForwarder(validatorNodeAddresses);
    }

    function initializeVisionForwarder(
        address[] memory validatorNodeAddresses
    ) public {
        // Set the hub, PAN token, and validator addresses
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(
            validatorNodeAddresses.length
        );
        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(visionForwarder));
            emit IVisionForwarder.ValidatorNodeAdded(
                validatorNodeAddresses[i]
            );
            vm.prank(SUPER_CRITICAL_OPS);
            visionForwarder.addValidatorNode(validatorNodeAddresses[i]);
        }

        // Unpause the forwarder contract after initialization
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.unpause();
    }

    function onlyByVisionHubTest(
        address callee,
        bytes memory calldata_
    ) public {
        string
            memory revertMessage = "VisionForwarder: caller is not the VisionHub";
        modifierTest(callee, calldata_, revertMessage);
    }

    function sign(
        Vm.Wallet memory signer,
        bytes32 digest
    ) public returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, digest);
        return abi.encodePacked(r, s, v);
    }

    function signByValidators(bytes32 digest) public returns (bytes[] memory) {
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = new bytes[](signerAddresses.length);

        for (uint256 i = 0; i < signerAddresses.length; i++) {
            signatures[i] = sign(
                _validatorWallets[signerAddresses[i]],
                digest
            );
        }
        return signatures;
    }

    function signByValidatorsAndOneNonValidator(
        bytes32 digest
    ) public returns (bytes[] memory) {
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        signatures[signerAddresses.length - 1] = sign(testWallet, digest);
        return signatures;
    }

    function getDigest(
        VisionTypes.TransferRequest memory request
    ) public view returns (bytes32) {
        return
            _hashTypedData(
                keccak256(
                    abi.encode(
                        keccak256(
                            abi.encodePacked(
                                VisionTypes.TRANSFER_TYPE,
                                VisionTypes.TRANSFER_REQUEST_TYPE
                            )
                        ),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    bytes(VisionTypes.TRANSFER_REQUEST_TYPE)
                                ),
                                request.sender,
                                request.recipient,
                                request.token,
                                request.amount,
                                request.serviceNode,
                                request.fee,
                                request.nonce,
                                request.validUntil
                            )
                        ),
                        uint256(thisBlockchain.blockchainId),
                        VISION_HUB_ADDRESS,
                        address(visionForwarder),
                        VISION_TOKEN_ADDRESS
                    )
                )
            );
    }

    function getDigest(
        VisionTypes.TransferFromRequest memory request
    ) public view returns (bytes32) {
        return
            _hashTypedData(
                keccak256(
                    abi.encode(
                        keccak256(
                            abi.encodePacked(
                                VisionTypes.TRANSFER_FROM_TYPE,
                                VisionTypes.TRANSFER_FROM_REQUEST_TYPE
                            )
                        ),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    bytes(
                                        VisionTypes.TRANSFER_FROM_REQUEST_TYPE
                                    )
                                ),
                                request.destinationBlockchainId,
                                request.sender,
                                keccak256(bytes(request.recipient)),
                                request.sourceToken,
                                keccak256(bytes(request.destinationToken)),
                                request.amount,
                                request.serviceNode,
                                request.fee,
                                request.nonce,
                                request.validUntil
                            )
                        ),
                        uint256(thisBlockchain.blockchainId),
                        VISION_HUB_ADDRESS,
                        address(visionForwarder),
                        VISION_TOKEN_ADDRESS
                    )
                )
            );
    }

    function getDigest(
        VisionTypes.TransferToRequest memory request
    ) public view returns (bytes32) {
        return
            _hashTypedData(
                keccak256(
                    abi.encode(
                        keccak256(
                            abi.encodePacked(
                                VisionTypes.TRANSFER_TO_TYPE,
                                VisionTypes.TRANSFER_TO_REQUEST_TYPE
                            )
                        ),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    bytes(VisionTypes.TRANSFER_TO_REQUEST_TYPE)
                                ),
                                request.sourceBlockchainId,
                                request.sourceTransferId,
                                keccak256(bytes(request.sourceTransactionId)),
                                keccak256(bytes(request.sender)),
                                request.recipient,
                                keccak256(bytes(request.sourceToken)),
                                request.destinationToken,
                                request.amount,
                                request.nonce
                            )
                        ),
                        uint256(thisBlockchain.blockchainId),
                        VISION_HUB_ADDRESS,
                        address(visionForwarder),
                        VISION_TOKEN_ADDRESS
                    )
                )
            );
    }

    function _hashTypedData(
        bytes32 structHash
    ) private view returns (bytes32) {
        string memory name;
        string memory version;
        uint256 chainId;
        address verifyingContract;
        (, name, version, chainId, verifyingContract, , ) = visionForwarder
            .eip712Domain();

        assertEq(name, EIP712_DOMAIN_NAME);
        assertEq(version, Strings.toString(MAJOR_PROTOCOL_VERSION));
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(visionForwarder));

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPE_HASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }
}
