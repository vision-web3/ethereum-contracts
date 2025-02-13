// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {VisionTypes} from "../src/interfaces/VisionTypes.sol";
import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
import {IVisionTransfer} from "../src/interfaces/IVisionTransfer.sol";
import {IVisionRegistry} from "../src/interfaces/IVisionRegistry.sol";
import {VisionRegistryFacet} from "../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../src/facets/VisionTransferFacet.sol";
import {VisionHubInit} from "../src/upgradeInitializers/VisionHubInit.sol";
import {VisionHubProxy} from "../src/VisionHubProxy.sol";
import {VisionBaseToken} from "../src/VisionBaseToken.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionBaseTest} from "./VisionBaseTest.t.sol";

abstract contract VisionHubDeployer is VisionBaseTest {
    address constant VISION_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("VisionForwarderAddress"))));
    address constant VISION_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("VisionTokenAddress"))));
    address constant SERVICE_NODE_WITHDRAWAL_ADDRESS =
        address(uint160(uint256(keccak256("ServiceNodeWithdrawalAddress"))));
    address constant TRANSFER_SENDER =
        address(uint160(uint256(keccak256("TransferSender"))));
    bytes32 constant COMMITMENT_HASH = keccak256("commitmentHash");
    uint256 constant COMMIT_WAIT_PERIOD = 10;

    bool initialized = false;
    VisionHubProxy visionHubDiamond;
    IVisionHub public visionHubProxy;
    DiamondCutFacet public dCutFacet;
    DiamondLoupeFacet public dLoupe;
    VisionRegistryFacet public visionRegistryFacet;
    VisionTransferFacet public visionTransferFacet;
    VisionHubInit public visionHubInit;

    function deployVisionHub(AccessController accessController) public {
        deployVisionHubProxyAndDiamondCutFacet(accessController);
        deployAllFacetsAndDiamondCut();
    }

    // deploy VisionHubProxy (diamond proxy) with diamondCut facet
    function deployVisionHubProxyAndDiamondCutFacet(
        AccessController accessController
    ) public {
        dCutFacet = new DiamondCutFacet();
        visionHubDiamond = new VisionHubProxy(
            address(dCutFacet),
            address(accessController)
        );
    }

    function deployAllFacets() public {
        dLoupe = new DiamondLoupeFacet();
        visionRegistryFacet = new VisionRegistryFacet();
        visionTransferFacet = new VisionTransferFacet();
    }

    function deployAllFacetsAndDiamondCut() public {
        deployAllFacets();

        visionHubInit = new VisionHubInit();

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        // upgrade visionHub diamond with facets using diamondCut
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );

        // wrap in IVisionHub ABI to support easier calls
        visionHubProxy = IVisionHub(address(visionHubDiamond));
    }

    // Prepare cut struct for all the facets
    function prepareFacetCuts()
        public
        view
        returns (IDiamondCut.FacetCut[] memory)
    {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // DiamondLoupeFacet
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dLoupe),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );

        // VisionRegistryFacet
        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionRegistryFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getVisionRegistrySelectors()
            })
        );

        // VisionTransferFacet
        cut[2] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionTransferFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getVisionTransferSelectors()
            })
        );
        return cut;
    }

    function getInitializerArgs()
        public
        view
        returns (VisionHubInit.Args memory)
    {
        VisionHubInit.Args memory args = VisionHubInit.Args({
            blockchainId: uint256(thisBlockchain.blockchainId),
            blockchainName: thisBlockchain.name,
            minimumServiceNodeDeposit: MINIMUM_SERVICE_NODE_DEPOSIT,
            unbondingPeriodServiceNodeDeposit: SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD,
            validatorFeeFactor: thisBlockchain.feeFactor,
            parameterUpdateDelay: PARAMETER_UPDATE_DELAY,
            nextTransferId: 0
        });
        return args;
    }

    // initializing VisionHub storage using one-off helper contract
    function prepareInitializerData(
        VisionHubInit.Args memory args
    ) public pure returns (bytes memory) {
        bytes memory initializerData = abi.encodeCall(
            VisionHubInit.init,
            (args)
        );
        return initializerData;
    }

    function registerOtherBlockchainAtVisionHub() public {
        vm.prank(SUPER_CRITICAL_OPS);
        visionHubProxy.registerBlockchain(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.name,
            otherBlockchain.feeFactor
        );
    }

    function initializeVisionHub() public {
        if (!initialized) {
            _initializeVisionHubValues();

            vm.prank(SUPER_CRITICAL_OPS);
            // Unpause the hub contract after initialization
            visionHubProxy.unpause();
            initialized = true;
        }
    }

    function _initializeVisionHubValues() public {
        mockPandasToken_getOwner(VISION_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getVisionForwarder(
            VISION_TOKEN_ADDRESS,
            VISION_FORWARDER_ADDRESS
        );

        // Set the forwarder, PAN token, and primary validator addresses
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionHubProxy.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionHubProxy.setPrimaryValidatorNode(validatorAddress);
        visionHubProxy.setVisionToken(VISION_TOKEN_ADDRESS);
        visionHubProxy.setProtocolVersion(PROTOCOL_VERSION);
        visionHubProxy.setCommitmentWaitPeriod(COMMIT_WAIT_PERIOD);
        vm.stopPrank();

        registerOtherBlockchainAtVisionHub();
    }

    function reDeployRegistryAndTransferFacetsAndDiamondCut() public {
        visionRegistryFacet = new VisionRegistryFacet();
        visionTransferFacet = new VisionTransferFacet();

        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
        // VisionRegistryFacet
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionRegistryFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getVisionRegistrySelectors()
            })
        );

        // VisionTransferFacet
        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionTransferFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getVisionTransferSelectors()
            })
        );

        // upgrade visionHub diamond with facets using diamondCut
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");

        // wrap in IVisionHub ABI to support easier calls
        visionHubProxy = IVisionHub(address(visionHubDiamond));
    }

    function mockPandasToken_getOwner(
        address tokenAddress,
        address owner
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(VisionBaseToken.getOwner.selector),
            abi.encode(owner)
        );
    }

    function mockPandasToken_getVisionForwarder(
        address tokenAddress,
        address visionForwarderAddress
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(
                VisionBaseToken.getVisionForwarder.selector
            ),
            abi.encode(visionForwarderAddress)
        );
    }

    function checkSupportedInterfaces() public view {
        IERC165 ierc165 = IERC165(address(visionHubDiamond));
        assertTrue(ierc165.supportsInterface(type(IERC165).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IDiamondCut).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IDiamondLoupe).interfaceId));
    }

    function checkStateVisionHub(
        bool paused,
        uint256 numberBlockchains,
        uint256 numberActiveBlockchains
    ) private view {
        checkSupportedInterfaces();
        assertEq(visionHubProxy.paused(), paused);
        assertEq(visionHubProxy.getNumberBlockchains(), numberBlockchains);
        assertEq(
            visionHubProxy.getNumberActiveBlockchains(),
            numberActiveBlockchains
        );

        VisionTypes.BlockchainRecord
            memory thisBlockchainRecord = visionHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );
        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertTrue(thisBlockchainRecord.active);
        assertEq(
            visionHubProxy.getCurrentBlockchainId(),
            uint256(thisBlockchain.blockchainId)
        );

        VisionTypes.UpdatableUint256
            memory thisBlockchainValidatorFeeFactor = visionHubProxy
                .getValidatorFeeFactor(uint256(thisBlockchain.blockchainId));
        assertEq(
            thisBlockchainValidatorFeeFactor.currentValue,
            thisBlockchain.feeFactor
        );
        assertEq(thisBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(thisBlockchainValidatorFeeFactor.updateTime, 0);

        VisionTypes.UpdatableUint256
            memory minimumServiceNodeDeposit = visionHubProxy
                .getMinimumServiceNodeDeposit();
        assertEq(
            minimumServiceNodeDeposit.currentValue,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        assertEq(minimumServiceNodeDeposit.pendingValue, 0);
        assertEq(minimumServiceNodeDeposit.updateTime, 0);

        VisionTypes.UpdatableUint256
            memory parameterUpdateDelay = visionHubProxy
                .getParameterUpdateDelay();
        assertEq(parameterUpdateDelay.currentValue, PARAMETER_UPDATE_DELAY);
        assertEq(parameterUpdateDelay.pendingValue, 0);
        assertEq(parameterUpdateDelay.updateTime, 0);

        VisionTypes.UpdatableUint256
            memory unbondingPeriodServiceNodeDeposit = visionHubProxy
                .getUnbondingPeriodServiceNodeDeposit();
        assertEq(
            unbondingPeriodServiceNodeDeposit.currentValue,
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(unbondingPeriodServiceNodeDeposit.pendingValue, 0);
        assertEq(unbondingPeriodServiceNodeDeposit.updateTime, 0);

        assertEq(visionHubProxy.getNextTransferId(), 0);
    }

    // checks pre InitVisionHub state
    function checkStateVisionHubAfterDeployment() public view {
        checkStateVisionHub(true, 1, 1);
    }

    // checks state after InitVisionHub
    function checkStateVisionHubAfterInit() public view {
        checkStateVisionHub(false, 2, 2);

        assertEq(visionHubProxy.getVisionToken(), VISION_TOKEN_ADDRESS);
        assertEq(
            visionHubProxy.getVisionForwarder(),
            VISION_FORWARDER_ADDRESS
        );
        assertEq(visionHubProxy.getPrimaryValidatorNode(), validatorAddress);

        VisionTypes.BlockchainRecord
            memory otherBlockchainRecord = visionHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertTrue(otherBlockchainRecord.active);

        VisionTypes.UpdatableUint256
            memory otherBlockchainValidatorFeeFactor = visionHubProxy
                .getValidatorFeeFactor(uint256(otherBlockchain.blockchainId));
        assertEq(
            otherBlockchainValidatorFeeFactor.currentValue,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(otherBlockchainValidatorFeeFactor.updateTime, 0);
    }

    function getVisionRegistrySelectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](55);
        uint i = 0;

        selectors[i++] = IVisionRegistry.setVisionForwarder.selector;
        selectors[i++] = IVisionRegistry.setVisionToken.selector;
        selectors[i++] = IVisionRegistry.setPrimaryValidatorNode.selector;
        selectors[i++] = IVisionRegistry.setProtocolVersion.selector;
        selectors[i++] = IVisionRegistry.registerBlockchain.selector;
        selectors[i++] = IVisionRegistry.unregisterBlockchain.selector;
        selectors[i++] = IVisionRegistry.updateBlockchainName.selector;
        selectors[i++] = IVisionRegistry
            .initiateValidatorFeeFactorUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .executeValidatorFeeFactorUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .initiateUnbondingPeriodServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .executeUnbondingPeriodServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .initiateMinimumServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .executeMinimumServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .initiateParameterUpdateDelayUpdate
            .selector;
        selectors[i++] = IVisionRegistry
            .executeParameterUpdateDelayUpdate
            .selector;
        selectors[i++] = IVisionRegistry.registerToken.selector;
        selectors[i++] = IVisionRegistry.unregisterToken.selector;
        selectors[i++] = IVisionRegistry.registerExternalToken.selector;
        selectors[i++] = IVisionRegistry.unregisterExternalToken.selector;
        selectors[i++] = IVisionRegistry.registerServiceNode.selector;
        selectors[i++] = IVisionRegistry.unregisterServiceNode.selector;
        selectors[i++] = IVisionRegistry.withdrawServiceNodeDeposit.selector;
        selectors[i++] = IVisionRegistry
            .cancelServiceNodeUnregistration
            .selector;
        selectors[i++] = IVisionRegistry.increaseServiceNodeDeposit.selector;
        selectors[i++] = IVisionRegistry.decreaseServiceNodeDeposit.selector;
        selectors[i++] = IVisionRegistry.updateServiceNodeUrl.selector;

        selectors[i++] = IVisionRegistry.getVisionForwarder.selector;
        selectors[i++] = IVisionRegistry.getVisionToken.selector;
        selectors[i++] = IVisionRegistry.getPrimaryValidatorNode.selector;
        selectors[i++] = IVisionRegistry.getProtocolVersion.selector;
        selectors[i++] = IVisionRegistry.getNumberBlockchains.selector;
        selectors[i++] = IVisionRegistry.getNumberActiveBlockchains.selector;
        selectors[i++] = IVisionRegistry.getCurrentBlockchainId.selector;
        selectors[i++] = IVisionRegistry.getBlockchainRecord.selector;
        selectors[i++] = IVisionRegistry
            .isServiceNodeInTheUnbondingPeriod
            .selector;
        selectors[i++] = IVisionRegistry.isValidValidatorNodeNonce.selector;
        selectors[i++] = IVisionRegistry
            .getCurrentMinimumServiceNodeDeposit
            .selector;
        selectors[i++] = IVisionRegistry.getMinimumServiceNodeDeposit.selector;
        selectors[i++] = IVisionRegistry
            .getCurrentUnbondingPeriodServiceNodeDeposit
            .selector;
        selectors[i++] = IVisionRegistry
            .getUnbondingPeriodServiceNodeDeposit
            .selector;
        selectors[i++] = IVisionRegistry.getTokens.selector;
        selectors[i++] = IVisionRegistry.getTokenRecord.selector;
        selectors[i++] = IVisionRegistry.getExternalTokenRecord.selector;
        selectors[i++] = IVisionRegistry.getServiceNodes.selector;
        selectors[i++] = IVisionRegistry.getServiceNodeRecord.selector;
        selectors[i++] = IVisionRegistry.getCurrentValidatorFeeFactor.selector;
        selectors[i++] = IVisionRegistry.getValidatorFeeFactor.selector;
        selectors[i++] = IVisionRegistry
            .getCurrentParameterUpdateDelay
            .selector;
        selectors[i++] = IVisionRegistry.getParameterUpdateDelay.selector;

        selectors[i++] = IVisionRegistry.pause.selector;
        selectors[i++] = IVisionRegistry.unpause.selector;
        selectors[i++] = IVisionRegistry.paused.selector;
        selectors[i++] = IVisionRegistry.commitHash.selector;
        selectors[i++] = IVisionRegistry.setCommitmentWaitPeriod.selector;
        selectors[i++] = IVisionRegistry.getCommitmentWaitPeriod.selector;

        require(
            _calculateInterfaceId(selectors) ==
                type(IVisionRegistry).interfaceId,
            " Interface has changed, update getVisionRegistrySelectors()"
        );

        return selectors;
    }

    function getVisionTransferSelectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = IVisionTransfer.transfer.selector;
        selectors[1] = IVisionTransfer.transferFrom.selector;
        selectors[2] = IVisionTransfer.transferTo.selector;
        selectors[3] = IVisionTransfer.isValidSenderNonce.selector;
        selectors[4] = IVisionTransfer.verifyTransfer.selector;
        selectors[5] = IVisionTransfer.verifyTransferFrom.selector;
        selectors[6] = IVisionTransfer.verifyTransferTo.selector;
        selectors[7] = IVisionTransfer.getNextTransferId.selector;

        require(
            _calculateInterfaceId(selectors) ==
                type(IVisionTransfer).interfaceId,
            " Interface has changed, update getVisionTransferSelectors()"
        );

        return selectors;
    }

    function getDiamondLoupeSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facetAddress.selector;
        selectors[1] = IDiamondLoupe.facetAddresses.selector;
        selectors[2] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[3] = IDiamondLoupe.facets.selector;
        selectors[4] = IERC165.supportsInterface.selector;
        return selectors;
    }

    function loadVisionHubInitialized() internal view returns (uint64) {
        bytes32 slotValue = loadVisionHubSlotValue(0);
        return uint64(uint256(slotValue));
    }

    function loadVisionHubPaused() internal view returns (bool) {
        bytes32 slotValue = loadVisionHubSlotValue(0);
        return toBool(slotValue >> 64);
    }

    function loadVisionHubVisionForwarder() internal view returns (address) {
        bytes32 slotValue = loadVisionHubSlotValue(0);
        return toAddress(slotValue >> 72);
    }

    function loadVisionHubVisionToken() internal view returns (address) {
        bytes32 slotValue = loadVisionHubSlotValue(1);
        return toAddress(slotValue);
    }

    function loadVisionHubPrimaryValidatorNodeAddress()
        internal
        view
        returns (address)
    {
        bytes32 slotValue = loadVisionHubSlotValue(2);
        return toAddress(slotValue);
    }

    function loadVisionHubNumberBlockchains() internal view returns (uint256) {
        bytes32 slotValue = loadVisionHubSlotValue(3);
        return uint256(slotValue);
    }

    function loadVisionHubNumberActiveBlockchains()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadVisionHubSlotValue(4);
        return uint256(slotValue);
    }

    function loadVisionHubCurrentBlockchainId()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadVisionHubSlotValue(5);
        return uint256(slotValue);
    }

    function loadVisionHubBlockchainRecord(
        uint256 blockchainId
    ) internal view returns (VisionTypes.BlockchainRecord memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(blockchainId, 6)));
        bytes32 slotValue = loadVisionHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 1);
        string memory name = string(abi.encodePacked(slotValue));
        return VisionTypes.BlockchainRecord(active, name);
    }

    function loadVisionHubMinimumServiceNodeDeposit()
        internal
        view
        returns (VisionTypes.UpdatableUint256 memory)
    {
        return loadVisionHubUpdatableUint256(7);
    }

    function loadVisionHubTokens() internal view returns (address[] memory) {
        bytes32 slotValue = loadVisionHubSlotValue(10);
        uint256 arrayLength = uint256(slotValue);
        address[] memory tokenAddresses = new address[](arrayLength);
        uint256 startSlot = uint256(keccak256(abi.encodePacked(uint256(10))));
        for (uint256 i = 0; i < arrayLength; i++) {
            slotValue = loadVisionHubSlotValue(startSlot + i);
            tokenAddresses[i] = toAddress(slotValue);
        }
        return tokenAddresses;
    }

    function loadVisionHubTokenIndex(
        address tokenAddress
    ) internal view returns (uint256) {
        uint256 slot = uint256(keccak256(abi.encode(tokenAddress, 11)));
        bytes32 slotValue = loadVisionHubSlotValue(slot);
        return uint256(slotValue);
    }

    function loadVisionHubTokenRecord(
        address tokenAddress
    ) internal view returns (VisionTypes.TokenRecord memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(tokenAddress, 12)));
        bytes32 slotValue = loadVisionHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        return VisionTypes.TokenRecord(active);
    }

    function loadVisionHubExternalTokenRecord(
        address tokenAddress,
        uint256 blockchainId
    ) internal view returns (VisionTypes.ExternalTokenRecord memory) {
        uint256 startSlot = uint256(
            keccak256(
                abi.encode(
                    blockchainId,
                    keccak256(abi.encode(tokenAddress, 13))
                )
            )
        );
        bytes32 slotValue = loadVisionHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 1);
        string memory externalTokenAddress = string(
            abi.encodePacked(slotValue)
        );
        return VisionTypes.ExternalTokenRecord(active, externalTokenAddress);
    }

    function loadVisionHubServiceNodes()
        internal
        view
        returns (address[] memory)
    {
        bytes32 slotValue = loadVisionHubSlotValue(14);
        uint256 arrayLength = uint256(slotValue);
        address[] memory serviceNodeAddresses = new address[](arrayLength);
        uint256 startSlot = uint256(keccak256(abi.encodePacked(uint256(14))));
        for (uint256 i = 0; i < arrayLength; i++) {
            slotValue = loadVisionHubSlotValue(startSlot + i);
            serviceNodeAddresses[i] = toAddress(slotValue);
        }
        return serviceNodeAddresses;
    }

    function loadVisionHubServiceNodeIndex(
        address serviceNodeAddress
    ) internal view returns (uint256) {
        uint256 slot = uint256(keccak256(abi.encode(serviceNodeAddress, 15)));
        bytes32 slotValue = loadVisionHubSlotValue(slot);
        return uint256(slotValue);
    }

    function loadVisionHubServiceNodeRecord(
        address serviceNodeAddress
    ) internal view returns (VisionTypes.ServiceNodeRecord memory) {
        uint256 startSlot = uint256(
            keccak256(abi.encode(serviceNodeAddress, 16))
        );
        bytes32 slotValue = loadVisionHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 1);
        string memory url = string(abi.encodePacked(slotValue));
        slotValue = loadVisionHubSlotValue(startSlot + 2);
        uint256 deposit = uint256(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 3);
        address withdrawalAddress = toAddress(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 4);
        uint256 withdrawalTime = uint256(slotValue);
        return
            VisionTypes.ServiceNodeRecord(
                active,
                url,
                deposit,
                withdrawalAddress,
                withdrawalTime
            );
    }

    function loadVisionHubNextTransferId() internal view returns (uint256) {
        bytes32 slotValue = loadVisionHubSlotValue(17);
        return uint256(slotValue);
    }

    function loadVisionHubUsedSourceTransferId(
        uint256 blockchainId,
        uint256 sourceTransferId
    ) internal view returns (bool) {
        uint256 slot = uint256(
            keccak256(
                abi.encode(
                    sourceTransferId,
                    keccak256(abi.encode(blockchainId, 18))
                )
            )
        );
        bytes32 slotValue = loadVisionHubSlotValue(slot);
        return toBool(slotValue);
    }

    function loadVisionHubValidatorFeeFactor(
        uint256 blockchainId
    ) internal view returns (VisionTypes.UpdatableUint256 memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(blockchainId, 19)));
        return loadVisionHubUpdatableUint256(startSlot);
    }

    function loadVisionHubParameterUpdateDelay()
        internal
        view
        returns (VisionTypes.UpdatableUint256 memory)
    {
        return loadVisionHubUpdatableUint256(20);
    }

    function loadVisionHubUnbondingPeriodServiceNodeDeposit()
        internal
        view
        returns (VisionTypes.UpdatableUint256 memory)
    {
        return loadVisionHubUpdatableUint256(23);
    }

    function loadVisionHubIsServiceNodeUrlUsed(
        bytes32 serviceNodeUrlHash
    ) internal view returns (bool) {
        uint256 slot = uint256(keccak256(abi.encode(serviceNodeUrlHash, 26)));
        bytes32 slotValue = loadVisionHubSlotValue(slot);
        return toBool(slotValue);
    }

    function loadVisionHubSlotValue(
        uint256 slot
    ) private view returns (bytes32) {
        return vm.load(address(visionHubProxy), bytes32(slot));
    }

    function loadVisionHubUpdatableUint256(
        uint256 startSlot
    ) private view returns (VisionTypes.UpdatableUint256 memory) {
        bytes32 slotValue = loadVisionHubSlotValue(startSlot);
        uint256 currentValue = uint256(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 1);
        uint256 pendingValue = uint256(slotValue);
        slotValue = loadVisionHubSlotValue(startSlot + 2);
        uint256 updateTime = uint256(slotValue);
        return
            VisionTypes.UpdatableUint256(
                currentValue,
                pendingValue,
                updateTime
            );
    }

    function _calculateInterfaceId(
        bytes4[] memory selectors
    ) private pure returns (bytes4) {
        bytes4 id = bytes4(0);
        for (uint i; i < selectors.length; i++) {
            id = id ^ selectors[i];
        }
        return id;
    }
}
