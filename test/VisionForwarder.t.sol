// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

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

contract VisionForwarderTest is VisionBaseTest {
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

    function test_pause_AfterInitialization()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();

        vm.prank(PAUSER);
        visionForwarder.pause();

        assertTrue(visionForwarder.paused());
    }

    function test_pause_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.pause.selector
        );

        whenNotPausedTest(address(visionForwarder), calldata_);
    }

    function test_pause_ByNonPauser()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.pause.selector
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_unpause_AfterDeploy()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();

        assertFalse(visionForwarder.paused());
    }

    function test_unpause_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.unpause.selector
        );

        whenPausedTest(address(visionForwarder), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.unpause.selector
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_unpause_WithNoVisionHubSet() external {
        vm.expectRevert("VisionForwarder: VisionHub has not been set");

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.unpause();
    }

    function test_unpause_WithNoVisionTokenSet() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.expectRevert("VisionForwarder: VisionToken has not been set");

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.unpause();
    }

    function test_unpause_WithNoValidatorSet() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.expectRevert("VisionForwarder: not enough validator nodes added");

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.unpause();
    }

    function test_unpause_WithLessThanMinValidatorSet() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(3);
        visionForwarder.addValidatorNode(validatorAddress);
        visionForwarder.addValidatorNode(validatorAddress2);
        vm.expectRevert("VisionForwarder: not enough validator nodes added");

        visionForwarder.unpause();
    }

    function test_setVisionHub() external {
        vm.expectEmit(address(visionForwarder));
        emit IVisionForwarder.VisionHubSet(VISION_HUB_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);

        assertEq(visionForwarder.getVisionHub(), VISION_HUB_ADDRESS);
    }

    function test_setVisionHubMultipleTimes() external {
        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit(address(visionForwarder));
            emit IVisionForwarder.VisionHubSet(VISION_HUB_ADDRESS);

            vm.prank(SUPER_CRITICAL_OPS);
            visionForwarder.setVisionHub(VISION_HUB_ADDRESS);

            assertEq(visionForwarder.getVisionHub(), VISION_HUB_ADDRESS);
        }
    }

    function test_setVisionHub_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.setVisionHub.selector,
            VISION_HUB_ADDRESS
        );

        whenPausedTest(address(visionForwarder), calldata_);
    }

    function test_setVisionHub_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.setVisionHub.selector,
            VISION_HUB_ADDRESS
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_setVisionHub_WithAddress0() external {
        vm.expectRevert(
            "VisionForwarder: VisionHub must not be the zero account"
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(ADDRESS_ZERO);
    }

    function test_setVisionToken() external {
        vm.expectEmit(address(visionForwarder));
        emit IVisionForwarder.VisionTokenSet(VISION_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);

        assertEq(visionForwarder.getVisionToken(), VISION_TOKEN_ADDRESS);
    }

    function test_setVisionToken_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.setVisionToken.selector,
            VISION_TOKEN_ADDRESS
        );

        whenPausedTest(address(visionForwarder), calldata_);
    }

    function test_setVisionToken_ByNonDeployer() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.setVisionToken.selector,
            VISION_TOKEN_ADDRESS
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_setVisionToken_WithAddress0() external {
        vm.expectRevert(
            "VisionForwarder: VisionToken must not be the zero account"
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(ADDRESS_ZERO);
    }

    function test_setMinimumValidatorNodeSignatures() external {
        vm.expectEmit(address(visionForwarder));
        emit IVisionForwarder.MinimumValidatorNodeSignaturesUpdated(1);

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(1);

        assertEq(visionForwarder.getMinimumValidatorNodeSignatures(), 1);
    }

    function test_setMinimumValidatorNodeSignatures_With0() external {
        vm.expectRevert("VisionForwarder: at least one signature required");

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(0);

        assertNotEq(visionForwarder.getMinimumValidatorNodeSignatures(), 0);
    }

    function test_setMinimumValidatorNodeSignatures_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.setMinimumValidatorNodeSignatures.selector,
            validatorCount
        );

        whenPausedTest(address(visionForwarder), calldata_);
    }

    function test_setMinimumValidatorNodeSignatures_ByNonSuperCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.setMinimumValidatorNodeSignatures.selector,
            1
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_addValidatorNode_Single() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(1);
        vm.expectEmit(address(visionForwarder));
        emit IVisionForwarder.ValidatorNodeAdded(validatorAddress);

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.addValidatorNode(validatorAddress);

        address[] memory actualValidatorNodes = visionForwarder
            .getValidatorNodes();
        assertEq(actualValidatorNodes[0], validatorAddress);
    }

    function test_addValidatorNode_Multiple()
        external
        parameterizedTest(validatorCounts)
    {
        address[] memory validatorNodes = getValidatorNodeAddresses();

        initializeVisionForwarder();

        address[] memory actualValidatorNodes = visionForwarder
            .getValidatorNodes();
        for (uint i = 0; i < validatorNodes.length; i++)
            assertEq(actualValidatorNodes[i], validatorNodes[i]);
        assertSortedAscending(actualValidatorNodes);
    }

    function test_addValidatorNode_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.addValidatorNode.selector,
            validatorAddress
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_addValidatorNode_WhenNotPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(1);
        visionForwarder.addValidatorNode(validatorAddress);
        visionForwarder.unpause();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.addValidatorNode.selector,
            validatorAddress2
        );

        whenPausedTest(address(visionForwarder), calldata_);
    }

    function test_addValidatorNode_0Address() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(1);
        vm.expectRevert(
            "VisionForwarder: validator node address must not be zero"
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.addValidatorNode(ADDRESS_ZERO);
    }

    function test_addValidatorNode_SameAddressTwice() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionHub(VISION_HUB_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.setMinimumValidatorNodeSignatures(3);
        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.addValidatorNode(validatorAddress);
        vm.expectRevert("VisionForwarder: validator node already added");

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.addValidatorNode(validatorAddress);
    }

    function test_addValidatorNode_SameAddressesTwice()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            vm.expectRevert("VisionForwarder: validator node already added");
            vm.prank(SUPER_CRITICAL_OPS);
            visionForwarder.addValidatorNode(validatorNodeAddresses[i]);
        }
    }

    function test_removeValidatorNode()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();
        address validatorNodeAddress = validatorNodeAddresses[
            validatorNodeAddresses.length - 1
        ];
        vm.expectEmit(address(visionForwarder));
        emit IVisionForwarder.ValidatorNodeRemoved(validatorNodeAddress);

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.removeValidatorNode(validatorNodeAddress);

        address[] memory finalValidatorNodeAddresses = visionForwarder
            .getValidatorNodes();
        assertEq(
            finalValidatorNodeAddresses.length,
            validatorNodeAddresses.length - 1
        );
        if (finalValidatorNodeAddresses.length > 0) {
            for (uint i; i < finalValidatorNodeAddresses.length - 1; i++) {
                assertEq(
                    finalValidatorNodeAddresses[i],
                    validatorNodeAddresses[i]
                );
            }
        }
        assertSortedAscending(finalValidatorNodeAddresses);
    }

    function test_removeValidatorNode_RemoveAll()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();

        for (uint i; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(visionForwarder));
            emit IVisionForwarder.ValidatorNodeRemoved(
                validatorNodeAddresses[i]
            );
            vm.prank(SUPER_CRITICAL_OPS);
            visionForwarder.removeValidatorNode(validatorNodeAddresses[i]);
        }

        address[] memory finalValidatorNodeAddresses = visionForwarder
            .getValidatorNodes();
        assertEq(finalValidatorNodeAddresses.length, 0);
    }

    function test_removeValidatorNode_RemoveAllAndAddAgain()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();
        for (uint i; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(visionForwarder));
            emit IVisionForwarder.ValidatorNodeRemoved(
                validatorNodeAddresses[i]
            );
            vm.prank(SUPER_CRITICAL_OPS);
            visionForwarder.removeValidatorNode(validatorNodeAddresses[i]);
        }
        address[] memory finalValidatorNodeAddresses = visionForwarder
            .getValidatorNodes();
        assertEq(finalValidatorNodeAddresses.length, 0);

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(visionForwarder));
            emit IVisionForwarder.ValidatorNodeAdded(
                validatorNodeAddresses[i]
            );
            vm.prank(SUPER_CRITICAL_OPS);
            visionForwarder.addValidatorNode(validatorNodeAddresses[i]);
        }

        finalValidatorNodeAddresses = visionForwarder.getValidatorNodes();
        assertEq(
            finalValidatorNodeAddresses.length,
            validatorNodeAddresses.length
        );
        assertSortedAscending(finalValidatorNodeAddresses);
    }

    function test_removeValidatorNode_0Address()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        vm.expectRevert(
            "VisionForwarder: validator node address must not be zero"
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.removeValidatorNode(ADDRESS_ZERO);
    }

    function test_removeValidatorNode_NotExisting()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        vm.expectRevert("VisionForwarder: validator node not added");

        vm.prank(SUPER_CRITICAL_OPS);
        visionForwarder.removeValidatorNode(testWallet.addr);
    }

    function test_removeValidatorNode_ByNonSuperCriticalOps()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        vm.prank(PAUSER);
        visionForwarder.pause();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.removeValidatorNode.selector,
            validatorAddress
        );

        onlyRoleTest(address(visionForwarder), calldata_);
    }

    function test_removeValidatorNode_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.removeValidatorNode.selector,
            validatorAddress
        );

        whenPausedTest(address(visionForwarder), calldata_);
    }

    function test_verifyAndForwardTransfer()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request, true, "");
        vm.prank(VISION_HUB_ADDRESS);

        bool succeeded;
        bytes32 tokenData;
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer(
            request,
            signature
        );

        assertTrue(succeeded);
        assertEq(tokenData, "");
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

    function test_verifyAndForwardTransfer_PandasTokenFailure()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(
            request,
            false,
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.prank(VISION_HUB_ADDRESS);

        bool succeeded;
        bytes32 tokenData;
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer(
            request,
            signature
        );

        assertFalse(succeeded);
        assertEq(tokenData, PANDAS_TOKEN_FAILURE_DATA);
    }

    function test_verifyAndForwardTransfer_NotByVisionHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.verifyAndForwardTransfer.selector,
            request,
            signature
        );

        onlyByVisionHubTest(address(visionForwarder), calldata_);
    }

    function test_verifyAndForwardTransfer_ReusingNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request, true, "");

        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransfer(request, signature);
        vm.expectRevert("VisionForwarder: sender nonce invalid");

        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_SameNonceDifferentSender()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request, true, "");
        bool succeeded;
        bytes32 tokenData;

        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer(
            request,
            signature
        );
        assertTrue(succeeded);
        assertEq(tokenData, "");

        request.sender = transferSender2;
        digest = getDigest(request);
        signature = sign(testWallet2, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request, true, "");
        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer(
            request,
            signature
        );
        assertTrue(succeeded);
        assertEq(tokenData, "");
    }

    function test_verifyAndForwardTransfer_SameSenderDifferentNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request, true, "");
        bool succeeded;
        bytes32 tokenData;

        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer(
            request,
            signature
        );
        assertTrue(succeeded);
        assertEq(tokenData, "");

        request.nonce = 99;
        digest = getDigest(request);
        signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request, true, "");
        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, tokenData) = visionForwarder.verifyAndForwardTransfer(
            request,
            signature
        );
        assertTrue(succeeded);
        assertEq(tokenData, "");
    }

    function test_verifyAndForwardTransfer_ValidUntilExpired()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        request.validUntil = block.timestamp - 1;
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert("VisionForwarder: validity period has expired");

        visionForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_ValidSignatureNotBySender()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet2, digest);

        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.prank(VISION_HUB_ADDRESS);
        string memory revertMsg = string.concat(
            "VisionForwarder: invalid signature by ",
            Strings.toHexString(transferSender)
        );
        vm.expectRevert(bytes(revertMsg));

        visionForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransferFrom()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            true,
            ""
        );
        vm.prank(VISION_HUB_ADDRESS);

        bool succeeded;
        bytes32 sourceTokenData;
        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );

        assertTrue(succeeded);
        assertEq(sourceTokenData, "");
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

    function test_verifyAndForwardTransferFrom_PandasTokenFailure()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            false,
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.prank(VISION_HUB_ADDRESS);

        bool succeeded;
        bytes32 sourceTokenData;
        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );

        assertFalse(succeeded);
        assertEq(sourceTokenData, PANDAS_TOKEN_FAILURE_DATA);
    }

    function test_verifyAndForwardTransferFrom_NotByVisionHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.verifyAndForwardTransferFrom.selector,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );

        onlyByVisionHubTest(address(visionForwarder), calldata_);
    }

    function test_verifyAndForwardTransferFrom_ReusingNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            true,
            ""
        );
        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
        vm.expectRevert("VisionForwarder: sender nonce invalid");

        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_SameNonceDifferentSender()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        bool succeeded;
        bytes32 sourceTokenData;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            true,
            ""
        );
        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        assertTrue(succeeded);
        assertEq(sourceTokenData, "");

        request.sender = transferSender2;
        digest = getDigest(request);
        signature = sign(testWallet2, digest);
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            true,
            ""
        );

        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        assertTrue(succeeded);
        assertEq(sourceTokenData, "");
    }

    function test_verifyAndForwardTransferFrom_SameSenderDifferentNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        bool succeeded;
        bytes32 sourceTokenData;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            true,
            ""
        );
        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        assertTrue(succeeded);
        assertEq(sourceTokenData, "");

        request.nonce = 99;
        digest = getDigest(request);
        signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            true,
            ""
        );

        vm.prank(VISION_HUB_ADDRESS);
        (succeeded, sourceTokenData) = visionForwarder
            .verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        assertTrue(succeeded);
        assertEq(sourceTokenData, "");
    }

    function test_verifyAndForwardTransferFrom_ValidUntilExpired()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        request.validUntil = block.timestamp - 1;
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;

        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert("VisionForwarder: validity period has expired");

        visionForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_ValidSignatureNotBySender()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet2, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.prank(VISION_HUB_ADDRESS);
        string memory revertMsg = string.concat(
            "VisionForwarder: invalid signature by ",
            Strings.toHexString(transferSender)
        );
        vm.expectRevert(bytes(revertMsg));

        visionForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferTo()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.prank(VISION_HUB_ADDRESS);

        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_NotByVisionHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionForwarder.verifyAndForwardTransferTo.selector,
            request,
            signerAddresses,
            signatures
        );

        onlyByVisionHubTest(address(visionForwarder), calldata_);
    }

    function test_verifyAndForwardTransferTo_ReusingNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
        vm.expectRevert("VisionForwarder: validator node nonce invalid");
        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_DifferentNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );

        request.nonce = 99;
        digest = getDigest(request);
        signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.prank(VISION_HUB_ADDRESS);
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_SignedByOneNonValidator()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidatorsAndOneNonValidator(digest);
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.prank(VISION_HUB_ADDRESS);
        string memory revertMsg = string.concat(
            "VisionForwarder: invalid signature by ",
            Strings.toHexString(signerAddresses[signerAddresses.length - 1])
        );
        vm.expectRevert(bytes(revertMsg));
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_OneSignerAndSignatureMissing()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        address[] memory signerAddressesLess = new address[](
            signerAddresses.length - 1
        );
        bytes[] memory signaturesLess = new bytes[](signatures.length - 1);
        for (uint i = 0; i < signaturesLess.length; i++) {
            signerAddressesLess[i] = signerAddresses[i];
            signatures[i] = signaturesLess[i];
        }

        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert("VisionForwarder: insufficient number of signatures");
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddressesLess,
            signaturesLess
        );
    }

    function test_verifyAndForwardTransferTo_OneSignatureMissing()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        bytes[] memory signaturesLess = new bytes[](signatures.length - 1);
        for (uint i = 0; i < signaturesLess.length; i++) {
            signatures[i] = signaturesLess[i];
        }

        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert(
            "VisionForwarder: numbers of signers and signatures must match"
        );
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signaturesLess
        );
    }

    function test_verifyAndForwardTransferTo_OneSignerMissing()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        address[] memory signerAddressesLess = new address[](
            signerAddresses.length - 1
        );
        for (uint i = 0; i < signerAddressesLess.length; i++) {
            signerAddressesLess[i] = signerAddresses[i];
        }

        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert(
            "VisionForwarder: numbers of signers and signatures must match"
        );
        visionForwarder.verifyAndForwardTransferTo(
            request,
            signerAddressesLess,
            signatures
        );
    }

    function test_verifyTransfer()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        mockAndExpectVisionHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.prank(VISION_HUB_ADDRESS);

        visionForwarder.verifyTransfer(request, signature);
    }

    function test_verifyTransferZeroAmount()
        external
        parameterizedTest(validatorCounts)
    {
        initializeVisionForwarder();
        VisionTypes.TransferRequest memory request = transferRequest();
        request.amount = 0;
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        vm.prank(VISION_HUB_ADDRESS);
        vm.expectRevert("VisionForwarder: amount must be greater than 0");

        visionForwarder.verifyTransfer(request, signature);
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
