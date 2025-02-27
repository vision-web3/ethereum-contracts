// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VisionTypes} from "../src/interfaces/VisionTypes.sol";
import {IVisionForwarder} from "../src/interfaces/IVisionForwarder.sol";
import {IVisionRegistry} from "../src/interfaces/IVisionRegistry.sol";
import {IVisionTransfer} from "../src/interfaces/IVisionTransfer.sol";
import {VisionBaseToken} from "../src/VisionBaseToken.sol";
import {VisionForwarder} from "../src/VisionForwarder.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionHubDeployer} from "./VisionHubDeployer.t.sol";

contract VisionHubTest is VisionHubDeployer {
    address constant PANDAS_TOKEN_OWNER =
        address(uint160(uint256(keccak256("PandasTokenOwner"))));
    AccessController public accessController;

    bytes32 constant DUMMY_COMMIT_HASH = keccak256("commit");

    function setUp() public {
        vm.warp(BLOCK_TIMESTAMP);
        accessController = deployAccessController();
        deployVisionHub(accessController);
    }

    function test_SetUpState() external view {
        checkStateVisionHubAfterDeployment();
    }

    function test_VisionHubInitialization() external {
        initializeVisionHub();
        checkStateVisionHubAfterInit();
    }

    function test_pause_AfterInitialization() external {
        initializeVisionHub();
        vm.expectEmit(address(visionHubProxy));
        emit IVisionRegistry.Paused(PAUSER);

        vm.prank(PAUSER);
        visionHubProxy.pause();

        assertTrue(visionHubProxy.paused());
    }

    function test_pause_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.pause.selector
        );

        whenNotPausedTest(address(visionHubProxy), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.pause.selector
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        _initializeVisionHubValues();
        vm.expectEmit(address(visionHubProxy));
        emit IVisionRegistry.Unpaused(SUPER_CRITICAL_OPS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unpause();

        assertFalse(visionHubProxy.paused());
    }

    function test_unpause_WhenNotPaused() external {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.unpause.selector
        );

        whenPausedTest(address(visionHubProxy), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.unpause.selector
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("VisionHub: VisionForwarder has not been set")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unpause();
    }

    function test_unpause_WithNoVisionTokenSet() external {
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        vm.expectRevert(
            abi.encodePacked("VisionHub: VisionToken has not been set")
        );

        visionHubProxy.unpause();
    }

    function test_unpause_WithNoPrimaryValidatorNodeSet() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        mockPandasToken_getOwner(VISION_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getVisionForwarder(
            VISION_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.expectRevert(
            abi.encodePacked(
                "VisionHub: primary validator node has not been set"
            )
        );

        visionHubProxy.unpause();
        vm.stopPrank();
    }

    function test_setVisionForwarder() external {
        vm.expectEmit(address(visionHubProxy));
        emit IVisionRegistry.VisionForwarderSet(VISION_FORWARDER_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);

        assertEq(
            visionHubProxy.getVisionForwarder(),
            VISION_FORWARDER_ADDRESS
        );
    }

    function test_setVisionForwarder_WhenNotPaused() public {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        whenPausedTest(address(visionHubProxy), calldata_);
    }

    function test_setVisionForwarder_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_setVisionForwarder_WithForwarderAddress0() external {
        vm.expectRevert(
            abi.encodePacked(
                "VisionHub: VisionForwarder must not be the zero account"
            )
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(ADDRESS_ZERO);
    }

    function test_setVisionToken() external {
        mockPandasToken_getOwner(VISION_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getVisionForwarder(
            VISION_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        vm.expectEmit(address(visionHubProxy));
        emit IVisionRegistry.VisionTokenSet(VISION_TOKEN_ADDRESS);

        visionHubProxy.setVisionToken(VISION_TOKEN_ADDRESS);

        assertEq(visionHubProxy.getVisionToken(), VISION_TOKEN_ADDRESS);
    }

    function test_setVisionToken_WhenNotPaused() external {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setVisionToken.selector,
            VISION_TOKEN_ADDRESS
        );

        whenPausedTest(address(visionHubProxy), calldata_);
    }

    function test_setVisionToken_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setVisionToken.selector,
            VISION_TOKEN_ADDRESS
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_setVisionToken_WithVisionToken0() external {
        vm.expectRevert("VisionHub: VisionToken must not be the zero account");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionToken(ADDRESS_ZERO);
    }

    function test_setVisionToken_AlreadySet() external {
        mockPandasToken_getOwner(VISION_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getVisionForwarder(
            VISION_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionHubProxy.setVisionToken(VISION_TOKEN_ADDRESS);
        vm.expectRevert("VisionHub: VisionToken already set");

        visionHubProxy.setVisionToken(VISION_TOKEN_ADDRESS);
    }

    function test_setPrimaryValidatorNode() external {
        vm.expectEmit(address(visionHubProxy));
        emit IVisionRegistry.PrimaryValidatorNodeUpdated(validatorAddress);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setPrimaryValidatorNode(validatorAddress);

        assertEq(visionHubProxy.getPrimaryValidatorNode(), validatorAddress);
    }

    function test_setPrimaryValidatorNode_WhenNotPaused() public {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setPrimaryValidatorNode.selector,
            validatorAddress
        );

        whenPausedTest(address(visionHubProxy), calldata_);
    }

    function test_setPrimaryValidatorNode_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setPrimaryValidatorNode.selector,
            validatorAddress
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_setProtocolVersion() external {
        vm.expectEmit(address(visionHubProxy));
        emit IVisionRegistry.ProtocolVersionUpdated(PROTOCOL_VERSION);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.setProtocolVersion(PROTOCOL_VERSION);

        assertEq(visionHubProxy.getProtocolVersion(), PROTOCOL_VERSION);
    }

    function test_setProtocolVersion_WhenNotPaused() public {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setProtocolVersion.selector,
            PROTOCOL_VERSION
        );

        whenPausedTest(address(visionHubProxy), calldata_);
    }

    function test_setProtocolVersion_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.setProtocolVersion.selector,
            PROTOCOL_VERSION
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_registerBlockchain() external {
        vm.expectEmit();
        emit IVisionRegistry.BlockchainRegistered(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.feeFactor
        );

        registerOtherBlockchainAtVisionHub();

        VisionTypes.BlockchainRecord
            memory otherBlockchainRecord = visionHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        VisionTypes.UpdatableUint256
            memory otherBlockchainValidatorFeeFactor = visionHubProxy
                .getValidatorFeeFactor(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(visionHubProxy.getNumberBlockchains(), 2);
        assertEq(visionHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            otherBlockchainValidatorFeeFactor.currentValue,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(otherBlockchainValidatorFeeFactor.updateTime, 0);
    }

    function test_registerBlockchain_AgainAfterUnregistration() external {
        registerOtherBlockchainAtVisionHub();
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IVisionRegistry.BlockchainRegistered(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.feeFactor
        );

        registerOtherBlockchainAtVisionHub();

        VisionTypes.BlockchainRecord
            memory otherBlockchainRecord = visionHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        VisionTypes.UpdatableUint256
            memory otherBlockchainValidatorFeeFactor = visionHubProxy
                .getValidatorFeeFactor(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(visionHubProxy.getNumberBlockchains(), 2);
        assertEq(visionHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            otherBlockchainValidatorFeeFactor.currentValue,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(otherBlockchainValidatorFeeFactor.updateTime, 0);
    }

    function test_registerBlockchain_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.registerBlockchain.selector,
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.name,
            otherBlockchain.feeFactor
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_registerBlockchain_WithEmptyName() external {
        vm.expectRevert("VisionHub: blockchain name must not be empty");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerBlockchain(
            uint256(otherBlockchain.blockchainId),
            "",
            otherBlockchain.feeFactor
        );
    }

    function test_registerBlockchain_AlreadyRegistered() external {
        registerOtherBlockchainAtVisionHub();
        vm.expectRevert("VisionHub: blockchain already registered");

        registerOtherBlockchainAtVisionHub();
    }

    function test_unregisterBlockchain() external {
        registerOtherBlockchainAtVisionHub();
        vm.expectEmit();
        emit IVisionRegistry.BlockchainUnregistered(
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );

        VisionTypes.BlockchainRecord
            memory otherBlockchainRecord = visionHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        assertEq(visionHubProxy.getNumberActiveBlockchains(), 1);
        assertEq(visionHubProxy.getNumberBlockchains(), 2);
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, false);
    }

    function test_unregisterBlockchain_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.unregisterBlockchain.selector,
            uint256(otherBlockchain.blockchainId)
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_unregisterBlockchain_WithCurrentBlockchain() external {
        vm.expectRevert(
            "VisionHub: blockchain ID must not be the current blockchain ID"
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(thisBlockchain.blockchainId)
        );
    }

    function test_unregisterBlockchain_WhenBlockchainNotRegistered() external {
        vm.expectRevert("VisionHub: blockchain must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(type(BlockchainId).max) + 1
        );
    }

    function test_unregisterBlockchain_AlreadyUnregistered() external {
        registerOtherBlockchainAtVisionHub();
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("VisionHub: blockchain must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_updateBlockchainName() external {
        string memory newBlockchainName = "new name";
        vm.expectEmit();
        emit IVisionRegistry.BlockchainNameUpdated(
            uint256(thisBlockchain.blockchainId)
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.updateBlockchainName(
            uint256(thisBlockchain.blockchainId),
            newBlockchainName
        );

        assertEq(
            visionHubProxy
                .getBlockchainRecord(uint256(thisBlockchain.blockchainId))
                .name,
            newBlockchainName
        );
    }

    function test_updateBlockchainName_WhenNotPaused() external {
        initializeVisionHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.updateBlockchainName.selector,
            uint256(thisBlockchain.blockchainId),
            "new name"
        );

        whenPausedTest(address(visionHubProxy), calldata_);
    }

    function test_updateBlockchainName_ByNonMediumCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.updateBlockchainName.selector,
            uint256(thisBlockchain.blockchainId),
            "new name"
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_updateBlockchainName_WithEmptyName() external {
        vm.expectRevert("VisionHub: blockchain name must not be empty");

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.updateBlockchainName(
            uint256(thisBlockchain.blockchainId),
            ""
        );
    }

    function test_updateBlockchainName_WhenBlockchainNotRegistered() external {
        vm.expectRevert("VisionHub: blockchain must be active");

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.updateBlockchainName(
            uint256(type(BlockchainId).max) + 1,
            "new name"
        );
    }

    function test_updateBlockchainName_WhenBlockchainUnregistered() external {
        registerOtherBlockchainAtVisionHub();
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("VisionHub: blockchain must be active");

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.updateBlockchainName(
            uint256(otherBlockchain.blockchainId),
            "new name"
        );
    }

    function test_initiateValidatorFeeFactorUpdate() external {
        initializeVisionHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        uint256 currentValue = thisBlockchain.feeFactor;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IVisionRegistry.ValidatorFeeFactorUpdateInitiated(
            blockchainId,
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            newValue
        );

        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateValidatorFeeFactorUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.initiateValidatorFeeFactorUpdate.selector,
            uint256(thisBlockchain.blockchainId),
            thisBlockchain.feeFactor + 1
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_initiateValidatorFeeFactorUpdate_ZeroFeeFactor() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: new validator fee factor must be >= 1");

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateValidatorFeeFactorUpdate(
            uint256(thisBlockchain.blockchainId),
            0
        );
    }

    function test_initiateValidatorFeeFactorUpdate_InactiveBlockchain()
        external
    {
        initializeVisionHub();
        vm.expectRevert("VisionHub: blockchain must be active");

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateValidatorFeeFactorUpdate(
            uint256(type(BlockchainId).max) + 1,
            thisBlockchain.feeFactor + 1
        );
    }

    function test_executeValidatorFeeFactorUpdate() external {
        initializeVisionHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        uint256 currentValue = thisBlockchain.feeFactor;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            newValue
        );
        vm.warp(updateTime);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IVisionRegistry.ValidatorFeeFactorUpdateExecuted(
            blockchainId,
            newValue
        );

        visionHubProxy.executeValidatorFeeFactorUpdate(blockchainId);

        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeValidatorFeeFactorUpdate_InactiveBlockchain()
        external
    {
        initializeVisionHub();
        vm.expectRevert("VisionHub: blockchain must be active");

        visionHubProxy.executeValidatorFeeFactorUpdate(
            uint256(type(BlockchainId).max) + 1
        );
    }

    function test_executeValidatorFeeFactorUpdate_NoUpdateTime() external {
        initializeVisionHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeValidatorFeeFactorUpdate(blockchainId);
    }

    function test_executeValidatorFeeFactorUpdate_NoUpdatedValue() external {
        initializeVisionHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            thisBlockchain.feeFactor
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeValidatorFeeFactorUpdate(blockchainId);
    }

    function test_executeValidatorFeeFactorUpdate_TooEarly() external {
        initializeVisionHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            thisBlockchain.feeFactor + 1
        );

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubValidatorFeeFactor(blockchainId);
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("VisionHub: update time not reached");

        visionHubProxy.executeValidatorFeeFactorUpdate(blockchainId);
    }

    function test_initiateUnbondingPeriodServiceNodeDepositUpdate() external {
        initializeVisionHub();
        uint256 currentValue = SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IVisionRegistry.UnbondingPeriodServiceNodeDepositUpdateInitiated(
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            newValue
        );

        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateUnbondingPeriodServiceNodeDepositUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry
                .initiateUnbondingPeriodServiceNodeDepositUpdate
                .selector,
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD + 1
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate() external {
        initializeVisionHub();
        uint256 currentValue = SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            newValue
        );
        vm.warp(updateTime);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IVisionRegistry.UnbondingPeriodServiceNodeDepositUpdateExecuted(
            newValue
        );

        visionHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();

        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate_NoUpdateTime()
        external
    {
        initializeVisionHub();
        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate_NoUpdatedValue()
        external
    {
        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate_TooEarly()
        external
    {
        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD + 1
        );

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubUnbondingPeriodServiceNodeDeposit();
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("VisionHub: update time not reached");

        visionHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
    }

    function test_initiateMinimumServiceNodeDepositUpdate() external {
        initializeVisionHub();
        uint256 currentValue = MINIMUM_SERVICE_NODE_DEPOSIT;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IVisionRegistry.MinimumServiceNodeDepositUpdateInitiated(
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(newValue);

        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateMinimumServiceNodeDepositUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.initiateMinimumServiceNodeDepositUpdate.selector,
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_executeMinimumServiceNodeDepositUpdate() external {
        initializeVisionHub();
        uint256 currentValue = MINIMUM_SERVICE_NODE_DEPOSIT;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(newValue);
        vm.warp(updateTime);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IVisionRegistry.MinimumServiceNodeDepositUpdateExecuted(newValue);

        visionHubProxy.executeMinimumServiceNodeDepositUpdate();

        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeMinimumServiceNodeDepositUpdate_NoUpdateTime()
        external
    {
        initializeVisionHub();
        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
    }

    function test_executeMinimumServiceNodeDepositUpdate_NoUpdatedValue()
        external
    {
        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
    }

    function test_executeMinimumServiceNodeDepositUpdate_TooEarly() external {
        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubMinimumServiceNodeDeposit();
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("VisionHub: update time not reached");

        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
    }

    function test_initiateParameterUpdateDelayUpdate() external {
        initializeVisionHub();
        uint256 currentValue = PARAMETER_UPDATE_DELAY;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IVisionRegistry.ParameterUpdateDelayUpdateInitiated(
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateParameterUpdateDelayUpdate(newValue);

        storedStruct = loadVisionHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateParameterUpdateDelayUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.initiateParameterUpdateDelayUpdate.selector,
            PARAMETER_UPDATE_DELAY + 1
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_executeParameterUpdateDelayUpdate() external {
        initializeVisionHub();
        uint256 currentValue = PARAMETER_UPDATE_DELAY;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateParameterUpdateDelayUpdate(newValue);
        vm.warp(updateTime);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IVisionRegistry.ParameterUpdateDelayUpdateExecuted(newValue);

        visionHubProxy.executeParameterUpdateDelayUpdate();

        storedStruct = loadVisionHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeParameterUpdateDelayUpdate_NoUpdateTime() external {
        initializeVisionHub();
        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubParameterUpdateDelay();
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeParameterUpdateDelayUpdate();
    }

    function test_executeParameterUpdateDelayUpdate_NoUpdatedValue() external {
        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateParameterUpdateDelayUpdate(
            PARAMETER_UPDATE_DELAY
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubParameterUpdateDelay();
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("VisionHub: no pending update");

        visionHubProxy.executeParameterUpdateDelayUpdate();
    }

    function test_executeParameterUpdateDelayUpdate_TooEarly() external {
        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateParameterUpdateDelayUpdate(
            PARAMETER_UPDATE_DELAY + 1
        );

        VisionTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadVisionHubParameterUpdateDelay();
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("VisionHub: update time not reached");

        visionHubProxy.executeParameterUpdateDelayUpdate();
    }

    function test_registerToken() external {
        initializeVisionHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        assertFalse(inArray(PANDAS_TOKEN_ADDRESS, loadVisionHubTokens()));
        vm.expectEmit();
        emit IVisionRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
        assertTrue(inArray(PANDAS_TOKEN_ADDRESS, loadVisionHubTokens()));
        checkTokenIndices();
    }

    function test_registerToken_BySuperCriticalOps() external {
        initializeVisionHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        assertFalse(inArray(PANDAS_TOKEN_ADDRESS, loadVisionHubTokens()));
        vm.expectEmit();
        emit IVisionRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
        assertTrue(inArray(PANDAS_TOKEN_ADDRESS, loadVisionHubTokens()));
        checkTokenIndices();
    }

    function test_registerToken_BySuperCriticalOpsWhenPaused() external {
        initializeVisionHub();
        vm.prank(PAUSER);
        visionHubProxy.pause();

        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        assertFalse(inArray(PANDAS_TOKEN_ADDRESS, loadVisionHubTokens()));
        vm.expectEmit();
        emit IVisionRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
        assertTrue(inArray(PANDAS_TOKEN_ADDRESS, loadVisionHubTokens()));
        checkTokenIndices();
    }

    function test_registerToken_ByNonSuperCriticalOpsWhenPaused() external {
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.registerToken.selector,
            PANDAS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_registerToken_WithToken0() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: token must not be the zero account");

        visionHubProxy.registerToken(ADDRESS_ZERO);
    }

    function test_registerToken_ByNonTokenOwner() external {
        initializeVisionHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, address(111));

        vm.expectRevert("VisionHub: caller is not the token owner");

        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WithNonMatchingForwarder() external {
        address nonMatchingForwarderAddress = VISION_TOKEN_ADDRESS;
        assertNotEq(nonMatchingForwarderAddress, VISION_FORWARDER_ADDRESS);
        initializeVisionHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            nonMatchingForwarderAddress
        );

        vm.expectRevert("VisionHub: VisionForwarder must match");

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WhenTokenAlreadyRegistered() external {
        registerToken();
        vm.expectRevert("VisionHub: token must not be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WhenTokenAlreadyRegisteredBySuperCriticalOps()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.expectRevert("VisionHub: token must not be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        vm.expectEmit();
        emit IVisionRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IVisionRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        address[] memory tokens = visionHubProxy.getTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], VISION_TOKEN_ADDRESS);
        assertFalse(tokenRecord.active);
        assertFalse(externalTokenRecord.active);
        checkTokenIndices();
    }

    function test_unregisterToken_BySuperCriticalOps() external {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        vm.expectEmit();
        emit IVisionRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IVisionRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        address[] memory tokens = visionHubProxy.getTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], VISION_TOKEN_ADDRESS);
        assertFalse(tokenRecord.active);
        assertFalse(externalTokenRecord.active);
        checkTokenIndices();
    }

    function test_unregisterToken_BySuperCriticalOpsWhenPaused() external {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);

        vm.prank(PAUSER);
        visionHubProxy.pause();

        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        vm.expectEmit();
        emit IVisionRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IVisionRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        address[] memory tokens = visionHubProxy.getTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], VISION_TOKEN_ADDRESS);
        assertFalse(tokenRecord.active);
        assertFalse(externalTokenRecord.active);
        checkTokenIndices();
    }

    function test_unregisterToken_ByNonSuperCriticalOpsWhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.unregisterToken.selector,
            PANDAS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_unregisterToken_WhenTokenNotRegistered() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: token must be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenNotRegisteredBySuperCriticalOps()
        external
    {
        initializeVisionHub();
        vm.expectRevert("VisionHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenNotRegisteredBySuperCriticalOpsWhenPaused()
        external
    {
        vm.expectRevert("VisionHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegistered() external {
        registerToken();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);

        vm.startPrank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.expectRevert("VisionHub: token must be active");

        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.stopPrank();
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegisteredBySuperCriticalOps()
        external
    {
        registerTokenBySuperCriticalOps();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);

        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.expectRevert("VisionHub: token must be active");

        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.stopPrank();
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegistered_BySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.prank(PAUSER);
        visionHubProxy.pause();

        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);

        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.expectRevert("VisionHub: token must be active");

        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }
    function test_unregisterToken_ByNonTokenOwner() external {
        registerToken();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, address(123));

        vm.expectRevert("VisionHub: caller is not the token owner");

        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_unregisterToken() external {
        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = PANDAS_TOKEN_ADDRESS;
        tokenAddresses[1] = PANDAS_TOKEN_ADDRESS_1;
        tokenAddresses[2] = PANDAS_TOKEN_ADDRESS_2;
        bool[] memory tokenRegistered = new bool[](3);
        tokenRegistered[0] = false;
        tokenRegistered[1] = false;
        tokenRegistered[2] = false;

        initializeVisionHub();
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        tokenRegistered[0] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS_1, PANDAS_TOKEN_OWNER);
        tokenRegistered[1] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS_2, PANDAS_TOKEN_OWNER);
        tokenRegistered[2] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS_1);
        tokenRegistered[1] = false;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS_1, PANDAS_TOKEN_OWNER);
        tokenRegistered[1] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        tokenRegistered[0] = false;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS_2);
        tokenRegistered[2] = false;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        tokenRegistered[0] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);
    }

    function test_registerExternalToken() external {
        registerToken();

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertTrue(externalTokenRecord.active);
        assertEq(
            externalTokenRecord.externalToken,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_BySuperCriticalOps() external {
        registerTokenBySuperCriticalOps();

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );

        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertTrue(externalTokenRecord.active);
        assertEq(
            externalTokenRecord.externalToken,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_BySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.prank(PAUSER);
        visionHubProxy.pause();

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );

        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertTrue(externalTokenRecord.active);
        assertEq(
            externalTokenRecord.externalToken,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_ByNonDeployerWhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.registerExternalToken.selector,
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_registerExternalToken_WithCurrentBlockchainId() external {
        initializeVisionHub();
        vm.expectRevert(
            "VisionHub: blockchain must not be the current blockchain"
        );

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(thisBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WithInactiveBlockchainId() external {
        initializeVisionHub();
        vm.expectRevert(
            "VisionHub: blockchain of external token must be active"
        );

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(type(BlockchainId).max) + 1,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WithEmptyAddress() external {
        initializeVisionHub();
        vm.expectRevert(
            "VisionHub: external token address must not be empty or more than 22 bytes with leading 0x"
        );

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            ""
        );
    }

    function test_registerExternalToken_WithShortAddress() external {
        initializeVisionHub();
        vm.expectRevert(
            "VisionHub: external token address must not be empty or more than 22 bytes with leading 0x"
        );

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            "00112233445566778899"
        );
    }

    function test_registerExternalToken_WithLongAddress() external {
        initializeVisionHub();
        vm.expectRevert(
            "VisionHub: external token address must not be empty or more than 22 bytes with leading 0x"
        );

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            "001122334455667788990011223344556677889900112233445566778899"
        );
    }

    function test_registerExternalToken_NoLeading0X() external {
        initializeVisionHub();
        vm.expectRevert(
            "VisionHub: external token address must not be empty or more than 22 bytes with leading 0x"
        );

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            "0A0000000000000000000000000000000000000000"
        );
    }

    function test_registerExternalToken_WithInactiveToken() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: token must be active");

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_ByNonTokenOwner() external {
        registerToken();
        vm.mockCall(
            PANDAS_TOKEN_ADDRESS,
            abi.encodeWithSelector(VisionBaseToken.getOwner.selector),
            abi.encode(address(321))
        );
        vm.expectRevert("VisionHub: caller is not the token owner");

        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WhenAlreadyRegistered() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        vm.expectRevert("VisionHub: external token must not be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WhenAlreadyRegisteredBySuperCriticalOps()
        external
    {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);
        vm.expectRevert("VisionHub: external token must not be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WhenAlreadyRegisteredBySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);

        vm.prank(PAUSER);
        visionHubProxy.pause();

        vm.expectRevert("VisionHub: external token must not be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_unregisterExternalToken() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        vm.expectEmit();
        emit IVisionRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertFalse(externalTokenRecord.active);
    }

    function test_unregisterExternalToken_BySuperCriticalOps() external {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);
        vm.expectEmit();
        emit IVisionRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertFalse(externalTokenRecord.active);
    }

    function test_unregisterExternalToken_BySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);

        vm.prank(PAUSER);
        visionHubProxy.pause();

        vm.expectEmit();
        emit IVisionRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertFalse(externalTokenRecord.active);
    }

    function test_unregisterExternalToken_ByNonDeployerWhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.unregisterExternalToken.selector,
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        onlyRoleTest(address(visionHubProxy), calldata_);
    }

    function test_unregisterExternalToken_WithInactiveToken() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: token must be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveTokenBySuperCriticalOps()
        external
    {
        initializeVisionHub();
        vm.expectRevert("VisionHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveTokenBySuperCriticalOpsWhenPaused()
        external
    {
        initializeVisionHub();

        vm.prank(PAUSER);
        visionHubProxy.pause();

        vm.expectRevert("VisionHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_ByNonTokenOwner() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        vm.mockCall(
            PANDAS_TOKEN_ADDRESS,
            abi.encodeWithSelector(VisionBaseToken.getOwner.selector),
            abi.encode(address(321))
        );
        vm.expectRevert("VisionHub: caller is not the token owner");

        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveExternalToken()
        external
    {
        registerToken();
        vm.expectRevert("VisionHub: external token must be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveExternalTokenBySuperCriticalOps()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.expectRevert("VisionHub: external token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveExternalTokenBySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.prank(PAUSER);
        visionHubProxy.pause();
        vm.expectRevert("VisionHub: external token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_commitHash() external {
        initializeVisionHub();

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectEmit();
        emit IVisionRegistry.HashCommited(
            SERVICE_NODE_ADDRESS,
            DUMMY_COMMIT_HASH
        );
        visionHubProxy.commitHash(DUMMY_COMMIT_HASH);
    }

    function test_registerServiceNode() external {
        initializeVisionHub();
        mockIerc20_transferFrom(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_ADDRESS,
            address(visionHubProxy),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                SERVICE_NODE_URL,
                SERVICE_NODE_ADDRESS
            )
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectEmit();
        emit IVisionRegistry.ServiceNodeRegistered(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                SERVICE_NODE_ADDRESS,
                address(visionHubProxy),
                MINIMUM_SERVICE_NODE_DEPOSIT
            )
        );

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = visionHubProxy.getServiceNodes();
        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
        checkServiceNodeIndices();
    }

    function test_registerServiceNode_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.registerServiceNode.selector,
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );

        whenNotPausedTest(address(visionHubProxy), calldata_);
    }

    function test_registerServiceNode_ByUnauthorizedAddress() external {
        initializeVisionHub();
        vm.prank(address(123));
        vm.expectRevert(
            "VisionHub: caller is not the service "
            "node or the withdrawal address"
        );

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithoutCommitment() external {
        initializeVisionHub();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node must have made a commitment");

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithWrongRevealData() external {
        initializeVisionHub();

        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.commitHash(DUMMY_COMMIT_HASH);

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: Commitment does not match");

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_CommitmentPhaseNotElapsed() external {
        initializeVisionHub();

        vm.prank(SERVICE_NODE_ADDRESS);
        bytes32 commit = calculateCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                SERVICE_NODE_URL,
                SERVICE_NODE_ADDRESS
            )
        );
        visionHubProxy.commitHash(commit);

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: Commitment period has not elapsed");
        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithEmptyUrl() external {
        initializeVisionHub();

        string memory emptyUrl = "";

        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                emptyUrl,
                SERVICE_NODE_ADDRESS
            )
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node URL must not be empty");

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            emptyUrl,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithNotUniqueUrl() external {
        registerServiceNode();

        address newSERVICE_NODE_ADDRESS = address(123);

        vm.prank(newSERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                newSERVICE_NODE_ADDRESS,
                newSERVICE_NODE_ADDRESS,
                SERVICE_NODE_URL,
                newSERVICE_NODE_ADDRESS
            )
        );

        vm.prank(newSERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node URL must be unique");

        visionHubProxy.registerServiceNode(
            newSERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            newSERVICE_NODE_ADDRESS
        );
    }

    function test_registerServiceNode_WithNotEnoughDeposit() external {
        initializeVisionHub();

        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                SERVICE_NODE_URL,
                SERVICE_NODE_ADDRESS
            )
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "VisionHub: deposit must be >= minimum service node deposit"
        );

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT - 1,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WhenServiceNodeAlreadyRegistered()
        external
    {
        registerServiceNode();

        string memory newUrl = string.concat(SERVICE_NODE_URL, "/new/path/");

        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                newUrl,
                SERVICE_NODE_ADDRESS
            )
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node already registered");

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            newUrl,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithDifferentUrlWhenNotWithdrawn()
        external
    {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);

        string memory newUrl = string.concat(SERVICE_NODE_URL, "extra");
        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                newUrl,
                SERVICE_NODE_ADDRESS
            )
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "VisionHub: service node must withdraw its "
            "deposit or cancel the unregistration"
        );

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            newUrl,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithSameUrlWhenNotWithdrawn() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);

        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(
                SERVICE_NODE_ADDRESS,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                SERVICE_NODE_URL,
                SERVICE_NODE_ADDRESS
            )
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node URL must be unique");

        visionHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_unregisterServiceNode() external {
        registerServiceNode();
        vm.expectEmit();
        emit IVisionRegistry.ServiceNodeUnregistered(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL
        );
        vm.prank(SERVICE_NODE_ADDRESS);

        visionHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = visionHubProxy.getServiceNodes();
        assertFalse(serviceNodeRecord.active);
        assertEq(
            serviceNodeRecord.withdrawalTime,
            BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(serviceNodes.length, 0);
        checkServiceNodeIndices();
    }

    function test_unregisterServiceNode_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IVisionRegistry.unregisterServiceNode.selector,
            SERVICE_NODE_ADDRESS
        );

        whenNotPausedTest(address(visionHubProxy), calldata_);
    }

    function test_unregisterServiceNode_ByUnauthorizedAddress() external {
        initializeVisionHub();
        vm.prank(address(123));
        vm.expectRevert(
            "VisionHub: caller is not the service "
            "node or the withdrawal address"
        );

        visionHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }

    function test_unregisterServiceNode_WhenItWasNeverRegistered() external {
        initializeVisionHub();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node must be active");

        visionHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }

    function test_registerServiceNode_unregisterServiceNode() external {
        address[] memory serviceNodeAddresses = new address[](3);
        serviceNodeAddresses[0] = SERVICE_NODE_ADDRESS;
        serviceNodeAddresses[1] = SERVICE_NODE_ADDRESS_1;
        serviceNodeAddresses[2] = SERVICE_NODE_ADDRESS_2;
        bool[] memory serviceNodeRegistered = new bool[](3);
        serviceNodeRegistered[0] = false;
        serviceNodeRegistered[1] = false;
        serviceNodeRegistered[2] = false;

        initializeVisionHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(0);
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        visionHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        registerServiceNode(SERVICE_NODE_ADDRESS, SERVICE_NODE_URL);
        serviceNodeRegistered[0] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        registerServiceNode(SERVICE_NODE_ADDRESS_1, SERVICE_NODE_URL_1);
        serviceNodeRegistered[1] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        registerServiceNode(SERVICE_NODE_ADDRESS_2, SERVICE_NODE_URL_2);
        serviceNodeRegistered[2] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        unregisterServiceNode(SERVICE_NODE_ADDRESS_1);
        serviceNodeRegistered[1] = false;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS_1);

        registerServiceNode(SERVICE_NODE_ADDRESS_1, SERVICE_NODE_URL_1);
        serviceNodeRegistered[1] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        unregisterServiceNode(SERVICE_NODE_ADDRESS);
        serviceNodeRegistered[0] = false;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        unregisterServiceNode(SERVICE_NODE_ADDRESS_2);
        serviceNodeRegistered[2] = false;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        registerServiceNode(SERVICE_NODE_ADDRESS, SERVICE_NODE_URL);
        serviceNodeRegistered[0] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );
    }

    function test_withdrawServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        unregisterServiceNode();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                MINIMUM_SERVICE_NODE_DEPOSIT
            )
        );

        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodeRecord.deposit, 0);
    }

    function test_withdrawServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        unregisterServiceNode();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                MINIMUM_SERVICE_NODE_DEPOSIT
            )
        );

        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodeRecord.deposit, 0);
    }

    function test_withdrawServiceNodeDeposit_WhenAlreadyWithdrawn() external {
        registerServiceNode();
        unregisterServiceNode();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node has no deposit to withdraw");

        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_ByUnauthorizedParty() external {
        registerServiceNode();
        unregisterServiceNode();
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(address(123));
        vm.expectRevert(
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );

        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_WhenUnbondingPeriodIsNotElapsed()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: the unbonding period has not elapsed");

        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_NoUnbondingPeriodBypass()
        external
    {
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        uint256 withdrawalTime;

        registerServiceNode();
        VisionTypes.ServiceNodeRecord memory storedStruct;
        storedStruct = loadVisionHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertTrue(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, 0);

        // Service node is unregistered for the first time
        unregisterServiceNode();
        withdrawalTime =
            BLOCK_TIMESTAMP +
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        storedStruct = loadVisionHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, withdrawalTime);

        // Unbonding period has passed
        vm.warp(withdrawalTime);

        // Service node unregistration is canceled
        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);
        storedStruct = loadVisionHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertTrue(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, 0);

        // Service node is unregistered immediately again
        unregisterServiceNode();
        withdrawalTime += SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        storedStruct = loadVisionHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, withdrawalTime);

        // Service node deposit cannot be withdrawn without the
        // unbonding period having passed again
        vm.expectRevert("VisionHub: the unbonding period has not elapsed");
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
        storedStruct = loadVisionHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, withdrawalTime);

        // Unbonding period has passed again
        vm.warp(withdrawalTime);

        // Service node deposit can be withdrawn now
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
        storedStruct = loadVisionHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, 0);
    }

    function test_cancelServiceNodeUnregistration_ByWithdrawalAddress()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        vm.expectEmit();
        emit IVisionRegistry.ServiceNodeRegistered(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);

        visionHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = visionHubProxy.getServiceNodes();
        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
        checkServiceNodeIndices();
    }

    function test_cancelServiceNodeUnregistration_ByServiceNode() external {
        registerServiceNode();
        unregisterServiceNode();
        vm.expectEmit();
        emit IVisionRegistry.ServiceNodeRegistered(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        vm.prank(SERVICE_NODE_ADDRESS);

        visionHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = visionHubProxy.getServiceNodes();
        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
        checkServiceNodeIndices();
    }

    function test_cancelServiceNodeUnregistration_WhenServiceNodeNotUnbonding()
        external
    {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "VisionHub: service node is not in the unbonding period"
        );

        visionHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);
    }

    function test_cancelServiceNodeUnregistration_ByUnauthorizedParty()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        vm.expectRevert(
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );

        visionHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);
    }

    function test_increaseServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        mockIerc20_transferFrom(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            address(visionHubProxy),
            1,
            true
        );
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                address(visionHubProxy),
                1
            )
        );

        visionHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT + 1);
    }

    function test_increaseServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        mockIerc20_transferFrom(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_ADDRESS,
            address(visionHubProxy),
            1,
            true
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                SERVICE_NODE_ADDRESS,
                address(visionHubProxy),
                1
            )
        );

        visionHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT + 1);
    }

    function test_increaseServiceNodeDeposit_ByUnauthorizedParty() external {
        registerServiceNode();
        vm.expectRevert(
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );

        visionHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_increaseServiceNodeDeposit_WhenServiceNodeNotActive()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node must be active");

        visionHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_increaseServiceNodeDeposit_WithDeposit0() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "VisionHub: additional deposit must be greater than 0"
        );

        visionHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 0);
    }

    function test_increaseServiceNodeDeposit_WithNotEnoughDeposit() external {
        registerServiceNode();
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT + 2
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "VisionHub: new deposit must be at least the minimum "
            "service node deposit"
        );

        visionHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_decreaseServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            1,
            true
        );
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT - 1
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                1
            )
        );

        visionHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT - 1);
    }

    function test_decreaseServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            1,
            true
        );
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT - 1
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                1
            )
        );

        visionHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT - 1);
    }

    function test_decreaseServiceNodeDeposit_ByUnauthorizedParty() external {
        registerServiceNode();
        vm.expectRevert(
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );

        visionHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_decreaseServiceNodeDeposit_WhenServiceNodeNotActive()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: service node must be active");

        visionHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_decreaseServiceNodeDeposit_WithDeposit0() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("VisionHub: reduced deposit must be greater than 0");

        visionHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 0);
    }

    function test_decreaseServiceNodeDeposit_WithNotEnoughDeposit() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "VisionHub: new deposit must be at least the minimum "
            "service node deposit"
        );

        visionHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_updateServiceNodeUrl() external {
        string memory newSERVICE_NODE_URL = "new service node url";
        registerServiceNode();

        vm.prank(SERVICE_NODE_ADDRESS);
        submitCommitHash(
            abi.encodePacked(newSERVICE_NODE_URL, SERVICE_NODE_ADDRESS)
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectEmit();
        emit IVisionRegistry.ServiceNodeUrlUpdated(
            SERVICE_NODE_ADDRESS,
            newSERVICE_NODE_URL
        );

        visionHubProxy.updateServiceNodeUrl(newSERVICE_NODE_URL);

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.url, newSERVICE_NODE_URL);
    }

    function test_updateServiceNodeUrl_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            visionHubProxy.updateServiceNodeUrl.selector,
            "new service node url"
        );

        whenNotPausedTest(address(visionHubProxy), calldata_);
    }

    function test_updateServiceNodeUrlL_WithEmptyUrl() external {
        registerServiceNode();
        vm.expectRevert("VisionHub: service node URL must not be empty");

        visionHubProxy.updateServiceNodeUrl("");
    }

    function test_updateServiceNodeUrl_WithNonUniqueUrl() external {
        registerServiceNode();
        vm.expectRevert("VisionHub: service node URL must be unique");

        visionHubProxy.updateServiceNodeUrl(SERVICE_NODE_URL);
    }

    function test_updateServiceNodeUrl_WithDifferentUrlWhenNotActive()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        vm.expectRevert("VisionHub: service node must be active");

        visionHubProxy.updateServiceNodeUrl(
            string.concat(SERVICE_NODE_URL, "extra")
        );
    }

    function test_updateServiceNodeUrl_WithoutCommitment() external {
        registerServiceNode();
        vm.expectRevert("VisionHub: service node must have made a commitment");

        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.updateServiceNodeUrl(
            string.concat(SERVICE_NODE_URL, "extra")
        );
    }

    function test_updateServiceNodeUrl_WithWrongRevealData() external {
        registerServiceNode();

        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.commitHash(DUMMY_COMMIT_HASH);

        vm.expectRevert("VisionHub: Commitment does not match");
        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.updateServiceNodeUrl(
            string.concat(SERVICE_NODE_URL, "extra")
        );
    }

    function test_updateServiceNodeUrl_WithCommitmentWaitPeriodNotElapsed()
        external
    {
        registerServiceNode();
        string memory newUrl = string.concat(SERVICE_NODE_URL, "extra");

        bytes32 commitment = calculateCommitHash(
            abi.encodePacked(newUrl, SERVICE_NODE_ADDRESS)
        );

        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.commitHash(commitment);

        vm.expectRevert("VisionHub: Commitment period has not elapsed");
        vm.prank(SERVICE_NODE_ADDRESS);
        visionHubProxy.updateServiceNodeUrl(newUrl);
    }

    function test_updateServiceNodeUrl_WithSameUrlWhenNotActive() external {
        registerServiceNode();

        vm.expectRevert("VisionHub: service node URL must be unique");

        visionHubProxy.updateServiceNodeUrl(SERVICE_NODE_URL);
    }

    function test_transfer() external {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyAndForwardTransfer(
            VISION_FORWARDER_ADDRESS,
            transferRequest(),
            "",
            true,
            ""
        );
        vm.expectEmit();
        emit IVisionTransfer.TransferSucceeded(
            NEXT_TRANSFER_ID,
            transferRequest(),
            ""
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IVisionForwarder.verifyAndForwardTransfer.selector,
                transferRequest(),
                ""
            )
        );

        uint256 transferId = visionHubProxy.transfer(transferRequest(), "");
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(visionHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transfer_PandasTokenFailure() external {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyAndForwardTransfer(
            VISION_FORWARDER_ADDRESS,
            transferRequest(),
            "",
            false,
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.expectEmit();
        emit IVisionTransfer.TransferFailed(
            NEXT_TRANSFER_ID,
            transferRequest(),
            "",
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IVisionForwarder.verifyAndForwardTransfer.selector,
                transferRequest(),
                ""
            )
        );

        uint256 transferId = visionHubProxy.transfer(transferRequest(), "");
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(visionHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transfer_ByUnauthorizedParty() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: caller must be the service node");

        visionHubProxy.transfer(transferRequest(), "");
    }

    function test_transferFrom() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyAndForwardTransferFrom(
            VISION_FORWARDER_ADDRESS,
            thisBlockchain.feeFactor,
            otherBlockchain.feeFactor,
            transferFromRequest(),
            "",
            true,
            ""
        );
        vm.expectEmit();
        emit IVisionTransfer.TransferFromSucceeded(
            NEXT_TRANSFER_ID,
            transferFromRequest(),
            ""
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IVisionForwarder.verifyAndForwardTransferFrom.selector,
                thisBlockchain.feeFactor,
                otherBlockchain.feeFactor,
                transferFromRequest(),
                ""
            )
        );

        uint256 transferId = visionHubProxy.transferFrom(
            transferFromRequest(),
            ""
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(visionHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferFrom_PandasTokenFailure() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyAndForwardTransferFrom(
            VISION_FORWARDER_ADDRESS,
            thisBlockchain.feeFactor,
            otherBlockchain.feeFactor,
            transferFromRequest(),
            "",
            false,
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.expectEmit();
        emit IVisionTransfer.TransferFromFailed(
            NEXT_TRANSFER_ID,
            transferFromRequest(),
            "",
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IVisionForwarder.verifyAndForwardTransferFrom.selector,
                thisBlockchain.feeFactor,
                otherBlockchain.feeFactor,
                transferFromRequest(),
                ""
            )
        );

        uint256 transferId = visionHubProxy.transferFrom(
            transferFromRequest(),
            ""
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(visionHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferFrom_ByUnauthorizedParty() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: caller must be the service node");

        visionHubProxy.transferFrom(transferFromRequest(), "");
    }

    function test_transferTo_WhenSourceAndDestinatioBlockchainsDiffer()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyAndForwardTransferTo(
            VISION_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.expectEmit();
        emit IVisionTransfer.TransferToSucceeded(
            NEXT_TRANSFER_ID,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.prank(validatorAddress);
        vm.expectCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IVisionForwarder.verifyAndForwardTransferTo.selector,
                transferToRequest(),
                new address[](0),
                new bytes[](0)
            )
        );

        uint256 transferId = visionHubProxy.transferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(visionHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferTo_WhenSourceAndDestinationBlockchainAreEqual()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyAndForwardTransferTo(
            VISION_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        VisionTypes.TransferToRequest
            memory transferToRequest_ = transferToRequest();
        transferToRequest_.sourceBlockchainId = uint256(
            thisBlockchain.blockchainId
        );
        vm.expectEmit();
        emit IVisionTransfer.TransferToSucceeded(
            NEXT_TRANSFER_ID,
            transferToRequest_,
            new address[](0),
            new bytes[](0)
        );
        vm.prank(validatorAddress);
        vm.expectCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IVisionForwarder.verifyAndForwardTransferTo.selector,
                transferToRequest_,
                new address[](0),
                new bytes[](0)
            )
        );

        uint256 transferId = visionHubProxy.transferTo(
            transferToRequest_,
            new address[](0),
            new bytes[](0)
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(visionHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferTo_ByUnauthorizedParty() external {
        initializeVisionHub();
        vm.expectRevert("VisionHub: caller is not the primary validator node");

        visionHubProxy.transferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
    }

    function test_isServiceNodeInTheUnbondingPeriod_WhenInUnbondingPeriod()
        external
    {
        registerServiceNode();
        unregisterServiceNode();

        assertTrue(
            visionHubProxy.isServiceNodeInTheUnbondingPeriod(
                SERVICE_NODE_ADDRESS
            )
        );
    }

    function test_isServiceNodeInTheUnbondingPeriod_WhenAlreadyWithdrawn()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
        mockIerc20_transfer(
            VISION_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        visionHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        assertFalse(
            visionHubProxy.isServiceNodeInTheUnbondingPeriod(
                SERVICE_NODE_ADDRESS
            )
        );
    }

    function test_isServiceNodeInTheUnbondingPeriod_WhenNeverRegistered()
        external
        view
    {
        assertFalse(
            visionHubProxy.isServiceNodeInTheUnbondingPeriod(
                SERVICE_NODE_ADDRESS
            )
        );
    }

    function test_isValidValidatorNodeNonce_WhenValid() external {
        initializeVisionHub();
        mockVisionForwarder_isValidValidatorNodeNonce(
            VISION_FORWARDER_ADDRESS,
            0,
            true
        );

        assertTrue(visionHubProxy.isValidValidatorNodeNonce(0));
    }

    function test_isValidValidatorNodeNonce_WhenNotValid() external {
        initializeVisionHub();
        vm.mockCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                VisionForwarder.isValidValidatorNodeNonce.selector
            ),
            abi.encode(false)
        );

        assertFalse(visionHubProxy.isValidValidatorNodeNonce(0));
    }

    function test_isValidSenderNodeNonce_WhenValid() external {
        initializeVisionHub();
        mockVisionForwarder_isValidSenderNonce(
            VISION_FORWARDER_ADDRESS,
            transferSender,
            0,
            true
        );

        assertTrue(visionHubProxy.isValidSenderNonce(transferSender, 0));
    }

    function test_isValidSenderNodeNonce_WhenNotValid() external {
        initializeVisionHub();
        vm.mockCall(
            VISION_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                VisionForwarder.isValidSenderNonce.selector
            ),
            abi.encode(false)
        );

        assertFalse(visionHubProxy.isValidSenderNonce(transferSender, 0));
    }

    function test_verifyTransfer() external {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT
        );
        mockIerc20_balanceOf(
            VISION_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_FEE
        );
        mockVisionForwarder_verifyTransfer(
            VISION_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenTokenNotRegistered() external {
        vm.expectRevert("VisionHub: token must be registered");

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenTokenHasNotSetTheRightForwarder()
        external
    {
        registerToken();
        mockPandasToken_getVisionForwarder(PANDAS_TOKEN_ADDRESS, address(123));
        vm.expectRevert(
            "VisionHub: Forwarder of Hub and transferred token must match"
        );

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenServiceNodeIsNotRegistered() external {
        registerToken();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.expectRevert("VisionHub: service node must be registered");

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenServiceNodeHasNotEnoughDeposit()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.prank(MEDIUM_CRITICAL_OPS);
        visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        visionHubProxy.executeMinimumServiceNodeDepositUpdate();
        vm.expectRevert("VisionHub: service node must have enough deposit");

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WithPAN_WhenInsufficientPANbalance()
        external
    {
        registerToken();
        registerServiceNode();
        VisionTypes.TransferRequest
            memory transferRequest_ = transferRequest();
        transferRequest_.token = VISION_TOKEN_ADDRESS;
        mockPandasToken_getVisionForwarder(
            VISION_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyTransfer(
            VISION_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        mockIerc20_balanceOf(
            VISION_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT + TRANSFER_FEE - 1
        );
        vm.expectRevert("VisionHub: insufficient balance of sender");

        visionHubProxy.verifyTransfer(transferRequest_, "");
    }

    function test_verifyTransfer_WithPANDAS_WhenInsufficientPANbalance()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyTransfer(
            VISION_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT
        );
        mockIerc20_balanceOf(
            VISION_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_FEE - 1
        );
        vm.expectRevert(
            "VisionHub: insufficient balance of sender for fee payment"
        );

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WithPANDAS_WhenInsufficientPANDASbalance()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyTransfer(
            VISION_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT - 1
        );
        vm.expectRevert("VisionHub: insufficient balance of sender");

        visionHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransferFrom() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT
        );
        mockIerc20_balanceOf(
            VISION_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_FEE
        );
        mockVisionForwarder_verifyTransferFrom(
            VISION_FORWARDER_ADDRESS,
            transferFromRequest(),
            ""
        );

        visionHubProxy.verifyTransferFrom(transferFromRequest(), "");
    }

    function test_verifyTransferFrom_WithSameSourceAndDestinationBlockchain()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        VisionTypes.TransferFromRequest
            memory transferFromRequest_ = transferFromRequest();
        transferFromRequest_.destinationBlockchainId = uint256(
            thisBlockchain.blockchainId
        );
        vm.expectRevert(
            "VisionHub: source and destination blockchains must not be equal"
        );

        visionHubProxy.verifyTransferFrom(transferFromRequest_, "");
    }

    function test_verifyTransferFrom_WithInactiveDestinationBlockchain()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("VisionHub: blockchain must be active");

        visionHubProxy.verifyTransferFrom(transferFromRequest(), "");
    }

    function test_verifyTransferFrom_WithNotRegisteredExternalToken()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.expectRevert("VisionHub: external token must be registered");

        visionHubProxy.verifyTransferFrom(transferFromRequest(), "");
    }

    function test_verifyTransferFrom_WithUnmatchingExternalToken() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        VisionTypes.TransferFromRequest
            memory transferFromRequest_ = transferFromRequest();
        transferFromRequest_.destinationToken = "123";
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        vm.expectRevert("VisionHub: incorrect external token");

        visionHubProxy.verifyTransferFrom(transferFromRequest_, "");
    }

    function test_verifyTransferTo_WhenSourceAndDestinatioBlockchainsDiffer()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyTransferTo(
            VISION_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );

        visionHubProxy.verifyTransferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
    }

    function test_verifyTransferTo_WhenSourceAndDestinationBlockchainAreEqual()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        VisionTypes.TransferToRequest
            memory transferToRequest_ = transferToRequest();
        transferToRequest_.sourceBlockchainId = uint256(
            thisBlockchain.blockchainId
        );
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyTransferTo(
            VISION_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );

        visionHubProxy.verifyTransferTo(
            transferToRequest_,
            new address[](0),
            new bytes[](0)
        );
    }

    function test_verifyTransferTo_WhenSourceTransferIdAlreadyUsed() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getVisionForwarder(
            PANDAS_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );
        mockVisionForwarder_verifyTransferTo(
            VISION_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.prank(validatorAddress);
        visionHubProxy.transferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.expectRevert("VisionHub: source transfer ID already used");

        visionHubProxy.verifyTransferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
    }

    function test_getVisionForwarder() external {
        initializeVisionHub();

        assertEq(
            VISION_FORWARDER_ADDRESS,
            visionHubProxy.getVisionForwarder()
        );
    }

    function test_getVisionToken() external {
        initializeVisionHub();

        assertEq(VISION_TOKEN_ADDRESS, visionHubProxy.getVisionToken());
    }

    function test_getPrimaryValidatorNode() external {
        initializeVisionHub();

        assertEq(validatorAddress, visionHubProxy.getPrimaryValidatorNode());
    }

    function test_getProtocolVersion() external {
        initializeVisionHub();

        assertEq(PROTOCOL_VERSION, visionHubProxy.getProtocolVersion());
    }

    function test_getNumberBlockchains() external view {
        assertEq(
            uint256(type(BlockchainId).max),
            visionHubProxy.getNumberBlockchains()
        );
    }

    function test_getNumberActiveBlockchains() external view {
        assertEq(
            uint256(type(BlockchainId).max),
            visionHubProxy.getNumberActiveBlockchains()
        );
    }

    function test_getCurrentBlockchainId() external view {
        assertEq(
            uint256(thisBlockchain.blockchainId),
            visionHubProxy.getCurrentBlockchainId()
        );
    }

    function test_getBlockchainRecord() external view {
        VisionTypes.BlockchainRecord
            memory thisBlockchainRecord = visionHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );

        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertTrue(thisBlockchainRecord.active);
    }

    function test_getCurrentMinimumServiceNodeDeposit() external view {
        assertEq(
            visionHubProxy.getCurrentMinimumServiceNodeDeposit(),
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
    }

    function test_getMinimumServiceNodeDeposit() external view {
        VisionTypes.UpdatableUint256
            memory minimumServiceNodeDeposit = visionHubProxy
                .getMinimumServiceNodeDeposit();
        assertEq(
            minimumServiceNodeDeposit.currentValue,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        assertEq(minimumServiceNodeDeposit.pendingValue, 0);
        assertEq(minimumServiceNodeDeposit.updateTime, 0);
    }

    function test_getCurrentUnbondingPeriodServiceNodeDeposit() external view {
        assertEq(
            visionHubProxy.getCurrentUnbondingPeriodServiceNodeDeposit(),
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
    }

    function test_getUnbondingPeriodServiceNodeDeposit() external view {
        VisionTypes.UpdatableUint256
            memory unbondingPeriodServiceNodeDeposit = visionHubProxy
                .getUnbondingPeriodServiceNodeDeposit();
        assertEq(
            unbondingPeriodServiceNodeDeposit.currentValue,
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(unbondingPeriodServiceNodeDeposit.pendingValue, 0);
        assertEq(unbondingPeriodServiceNodeDeposit.updateTime, 0);
    }

    function test_getTokens_WhenOnlyVisionTokenRegistered() external {
        initializeVisionHub();

        address[] memory tokens = visionHubProxy.getTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], VISION_TOKEN_ADDRESS);
    }

    function test_getTokens_WhenPandasTokenRegistered() external {
        registerToken();

        address[] memory tokens = visionHubProxy.getTokens();

        assertEq(tokens.length, 2);
        assertEq(tokens[0], VISION_TOKEN_ADDRESS);
        assertEq(tokens[1], PANDAS_TOKEN_ADDRESS);
    }

    function test_getTokenRecord_WhenTokenRegistered() external {
        registerToken();

        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);

        assertTrue(tokenRecord.active);
    }

    function test_getTokenRecord_WhenTokenNotRegistered() external view {
        VisionTypes.TokenRecord memory tokenRecord = visionHubProxy
            .getTokenRecord(address(123));

        assertFalse(tokenRecord.active);
    }

    function test_getExternalTokenRecord_WhenExternalTokenRegistered()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);

        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );

        assertTrue(externalTokenRecord.active);
        assertEq(
            externalTokenRecord.externalToken,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_getExternalTokenRecord_WhenExternalTokenNotRegistered()
        external
        view
    {
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                address(123),
                uint256(otherBlockchain.blockchainId)
            );

        assertFalse(externalTokenRecord.active);
        assertEq(externalTokenRecord.externalToken, "");
    }

    function test_getServiceNodes_WhenServiceNodeRegistered() external {
        registerServiceNode();

        address[] memory serviceNodes = visionHubProxy.getServiceNodes();

        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
    }

    function test_getServiceNodes_WhenServiceNodeNotRegistered()
        external
        view
    {
        address[] memory serviceNodes = visionHubProxy.getServiceNodes();

        assertEq(serviceNodes.length, 0);
    }

    function test_getServiceNodeRecord_WhenServiceNodeRegistered() external {
        registerServiceNode();

        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);

        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.withdrawalTime, 0);
    }

    function test_getServiceNodeRecord_WhenServiceNodeNotRegistered()
        external
        view
    {
        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = visionHubProxy
            .getServiceNodeRecord(address(123));

        assertFalse(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, "");
        assertEq(serviceNodeRecord.deposit, 0);
        assertEq(serviceNodeRecord.withdrawalAddress, ADDRESS_ZERO);
        assertEq(serviceNodeRecord.withdrawalTime, 0);
    }

    function test_getNextTransferId() external view {
        assertEq(visionHubProxy.getNextTransferId(), 0);
    }

    function test_getCurrentValidatorFeeFactor() external view {
        assertEq(
            visionHubProxy.getCurrentValidatorFeeFactor(
                uint256(thisBlockchain.blockchainId)
            ),
            thisBlockchain.feeFactor
        );
    }

    function test_getValidatorFeeFactor() external view {
        VisionTypes.UpdatableUint256 memory validatorFeeFactor = visionHubProxy
            .getValidatorFeeFactor(uint256(thisBlockchain.blockchainId));
        assertEq(validatorFeeFactor.currentValue, thisBlockchain.feeFactor);
        assertEq(validatorFeeFactor.pendingValue, 0);
        assertEq(validatorFeeFactor.updateTime, 0);
    }

    function test_getCurrentParameterUpdateDelay() external view {
        assertEq(
            visionHubProxy.getCurrentParameterUpdateDelay(),
            PARAMETER_UPDATE_DELAY
        );
    }

    function test_getParameterUpdateDelay() external view {
        VisionTypes.UpdatableUint256
            memory parameterUpdateDelay = visionHubProxy
                .getParameterUpdateDelay();
        assertEq(parameterUpdateDelay.currentValue, PARAMETER_UPDATE_DELAY);
        assertEq(parameterUpdateDelay.pendingValue, 0);
        assertEq(parameterUpdateDelay.updateTime, 0);
    }

    function whenPausedTest(
        address callee,
        bytes memory calldata_
    ) public override {
        string memory revertMessage = "VisionHub: not paused";
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenNotPausedTest(
        address callee,
        bytes memory calldata_
    ) public override {
        string memory revertMessage = "VisionHub: paused";
        modifierTest(callee, calldata_, revertMessage);
    }

    function mockVisionForwarder_verifyTransfer(
        address visionForwarder,
        VisionTypes.TransferRequest memory request,
        bytes memory signature
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.verifyTransfer.selector,
                request,
                signature
            ),
            abi.encode()
        );
    }

    function mockVisionForwarder_verifyTransferFrom(
        address visionForwarder,
        VisionTypes.TransferFromRequest memory request,
        bytes memory signature
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.verifyTransferFrom.selector,
                request,
                signature
            ),
            abi.encode()
        );
    }

    function mockVisionForwarder_verifyTransferTo(
        address visionForwarder,
        VisionTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.verifyTransferTo.selector,
                request,
                signerAddresses,
                signatures
            ),
            abi.encode()
        );
    }

    function mockVisionForwarder_verifyAndForwardTransfer(
        address visionForwarder,
        VisionTypes.TransferRequest memory request,
        bytes memory signature,
        bool succeeded,
        bytes32 tokenData
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.verifyAndForwardTransfer.selector,
                request,
                signature
            ),
            abi.encode(succeeded, tokenData)
        );
    }

    function mockVisionForwarder_verifyAndForwardTransferFrom(
        address visionForwarder,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor,
        VisionTypes.TransferFromRequest memory request,
        bytes memory signature,
        bool succeeded,
        bytes32 sourceTokenData
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.verifyAndForwardTransferFrom.selector,
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            ),
            abi.encode(succeeded, sourceTokenData)
        );
    }

    function mockVisionForwarder_verifyAndForwardTransferTo(
        address visionForwarder,
        VisionTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.verifyAndForwardTransferTo.selector,
                request,
                signerAddresses,
                signatures
            ),
            abi.encode()
        );
    }

    function mockVisionForwarder_isValidValidatorNodeNonce(
        address visionForwarder,
        uint256 nonce,
        bool success
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.isValidValidatorNodeNonce.selector,
                nonce
            ),
            abi.encode(success)
        );
    }

    function mockVisionForwarder_isValidSenderNonce(
        address visionForwarder,
        address sender,
        uint256 nonce,
        bool success
    ) public {
        vm.mockCall(
            visionForwarder,
            abi.encodeWithSelector(
                VisionForwarder.isValidSenderNonce.selector,
                sender,
                nonce
            ),
            abi.encode(success)
        );
    }

    function calculateCommitHash(
        bytes memory data
    ) public pure returns (bytes32) {
        return keccak256(data);
    }

    function submitCommitHash(bytes memory data) public {
        bytes32 commit = calculateCommitHash(data);
        visionHubProxy.commitHash(commit);
        vm.roll(block.number + COMMIT_WAIT_PERIOD);
    }

    function registerToken(address tokenAddress, address tokenOwner) public {
        initializeVisionHub();
        mockPandasToken_getOwner(tokenAddress, tokenOwner);
        mockPandasToken_getVisionForwarder(
            tokenAddress,
            VISION_FORWARDER_ADDRESS
        );
        vm.prank(tokenOwner);
        visionHubProxy.registerToken(tokenAddress);
    }

    function registerToken() public {
        registerToken(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
    }

    function registerTokenBySuperCriticalOps() public {
        registerToken(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
    }

    function registerTokenAndExternalToken(address tokenOwner) public {
        registerToken(PANDAS_TOKEN_ADDRESS, tokenOwner);
        vm.prank(tokenOwner);
        visionHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function registerServiceNode(
        address serviceNodeAddress,
        string memory serviceNodeUrl
    ) public {
        initializeVisionHub();
        mockIerc20_transferFrom(
            VISION_TOKEN_ADDRESS,
            serviceNodeAddress,
            address(visionHubProxy),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );

        bytes32 commitHash = calculateCommitHash(
            abi.encodePacked(
                serviceNodeAddress,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                serviceNodeUrl,
                serviceNodeAddress
            )
        );

        vm.prank(serviceNodeAddress);
        visionHubProxy.commitHash(commitHash);

        vm.roll(block.number + COMMIT_WAIT_PERIOD);
        vm.prank(serviceNodeAddress);
        visionHubProxy.registerServiceNode(
            serviceNodeAddress,
            serviceNodeUrl,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function registerServiceNode() public {
        registerServiceNode(SERVICE_NODE_ADDRESS, SERVICE_NODE_URL);
    }

    function unregisterServiceNode(address serviceNodeAddress) public {
        initializeVisionHub();
        vm.prank(serviceNodeAddress);
        visionHubProxy.unregisterServiceNode(serviceNodeAddress);
    }

    function unregisterServiceNode() public {
        unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }

    function checkTokenIndices() private view {
        address[] memory tokenAddresses = loadVisionHubTokens();
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            assertEq(i, loadVisionHubTokenIndex(tokenAddress));
        }
    }

    function checkTokenRegistrations(
        address[] memory tokenAddresses,
        bool[] memory tokenRegistered
    ) private view {
        assertEq(tokenAddresses.length, tokenRegistered.length);
        address[] memory registeredTokenAddresses = loadVisionHubTokens();
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            VisionTypes.TokenRecord
                memory tokenRecord = loadVisionHubTokenRecord(tokenAddress);
            if (tokenRegistered[i]) {
                assertTrue(inArray(tokenAddress, registeredTokenAddresses));
                assertTrue(tokenRecord.active);
            } else {
                assertFalse(inArray(tokenAddress, registeredTokenAddresses));
                assertFalse(tokenRecord.active);
            }
        }
        checkTokenIndices();
    }

    function checkServiceNodeIndices() private view {
        address[] memory serviceNodeAddresses = loadVisionHubServiceNodes();
        for (uint256 i = 0; i < serviceNodeAddresses.length; i++) {
            address serviceNodeAddress = serviceNodeAddresses[i];
            assertEq(i, loadVisionHubServiceNodeIndex(serviceNodeAddress));
        }
    }

    function checkServiceNodeRegistrations(
        address[] memory serviceNodeAddresses,
        bool[] memory serviceNodeRegistered
    ) private view {
        assertEq(serviceNodeAddresses.length, serviceNodeRegistered.length);
        address[]
            memory registeredServiceNodeAddresses = loadVisionHubServiceNodes();
        for (uint256 i = 0; i < serviceNodeAddresses.length; i++) {
            address serviceNodeAddress = serviceNodeAddresses[i];
            VisionTypes.ServiceNodeRecord
                memory serviceNodeRecord = loadVisionHubServiceNodeRecord(
                    serviceNodeAddress
                );
            if (serviceNodeRegistered[i]) {
                assertTrue(
                    inArray(serviceNodeAddress, registeredServiceNodeAddresses)
                );
                assertTrue(serviceNodeRecord.active);
            } else {
                assertFalse(
                    inArray(serviceNodeAddress, registeredServiceNodeAddresses)
                );
                assertFalse(serviceNodeRecord.active);
            }
        }
        checkServiceNodeIndices();
    }

    function onlyRoleTest(
        address callee,
        bytes memory calldata_
    ) public override {
        vm.startPrank(address(111));
        bytes memory revertMessage = "VisionHub: caller doesn't have role";
        modifierTest(callee, calldata_, revertMessage);
    }
}
