// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {VisionTypes} from "../../src/interfaces/VisionTypes.sol";
import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {IVisionRegistry} from "../../src/interfaces/IVisionRegistry.sol";
import {IVisionTransfer} from "../../src/interfaces/IVisionTransfer.sol";
import {VisionRegistryFacet} from "../../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../../src/facets/VisionTransferFacet.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {VisionHubProxy} from "../../src/VisionHubProxy.sol";
import {VisionHubInit} from "../../src/upgradeInitializers/VisionHubInit.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {VisionBaseScript} from "./VisionBaseScript.s.sol";
import {Constants} from "./Constants.s.sol";

struct VisionFacets {
    DiamondCutFacet dCut;
    DiamondLoupeFacet dLoupe;
    VisionRegistryFacet registry;
    VisionTransferFacet transfer;
}

abstract contract VisionHubDeployer is VisionBaseScript {
    function deployRegistryFacet() public returns (VisionRegistryFacet) {
        VisionRegistryFacet registryFacet = new VisionRegistryFacet();
        console.log(
            "VisionRegistryFacet deployed; address=%s",
            address(registryFacet)
        );
        return registryFacet;
    }

    function deployTransferFacet() public returns (VisionTransferFacet) {
        VisionTransferFacet transferFacet = new VisionTransferFacet();
        console.log(
            "VisionTransferFacet deployed; address=%s",
            address(transferFacet)
        );
        return transferFacet;
    }

    function deployVisionHub(
        AccessController accessController
    ) public returns (VisionHubProxy, VisionHubInit, VisionFacets memory) {
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        console.log(
            "DiamondCutFacet deployed; address=%s",
            address(dCutFacet)
        );

        VisionHubProxy visionHubDiamond = new VisionHubProxy(
            address(dCutFacet),
            address(accessController)
        );
        console.log(
            "VisionHubProxy deployed; address=%s; accessController=%s",
            address(visionHubDiamond),
            address(accessController)
        );

        // deploying all other facets
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        console.log("DiamondLoupeFacet deployed; address=%s", address(dLoupe));
        VisionRegistryFacet registryFacet = deployRegistryFacet();
        VisionTransferFacet transferFacet = deployTransferFacet();

        VisionFacets memory visionFacets = VisionFacets({
            dCut: dCutFacet,
            dLoupe: dLoupe,
            registry: registryFacet,
            transfer: transferFacet
        });

        // deploy initializer
        VisionHubInit visionHubInit = new VisionHubInit();
        console.log(
            "VisionHubInit deployed; address=%s",
            address(visionHubInit)
        );
        return (visionHubDiamond, visionHubInit, visionFacets);
    }

    // VisionRoles.DEPLOYER_ROLE
    function diamondCutFacets(
        VisionHubProxy visionHubProxy,
        VisionHubInit visionHubInit,
        VisionFacets memory visionFacets,
        uint256 nextTransferId
    ) public {
        // // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts(visionFacets);
        bytes memory initializerData = prepareInitializerData(nextTransferId);

        // upgrade visionHub diamond with facets using diamondCut
        IDiamondCut(address(visionHubProxy)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );

        // wrap in IVisionHub ABI to support easier calls
        IVisionHub visionHub = IVisionHub(address(visionHubProxy));

        console.log(
            "diamondCut VisionHubProxy; paused=%s; cut(s) count=%s",
            visionHub.paused(),
            cut.length
        );
    }

    // Prepare cut struct for all the facets
    function prepareFacetCuts(
        VisionFacets memory facets
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // DiamondLoupeFacet
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facets.dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeSelectors()
        });

        // VisionRegistryFacet
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(facets.registry),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getVisionRegistrySelectors()
        });

        // VisionTransferFacet
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(facets.transfer),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getVisionTransferSelectors()
        });
        return cut;
    }

    // initializing VisionHub storage using one-off helper contract
    function prepareInitializerData(
        uint nextTransferId
    ) public returns (bytes memory) {
        Blockchain memory blockchain = determineBlockchain();
        VisionHubInit.Args memory args = VisionHubInit.Args({
            blockchainId: uint256(blockchain.blockchainId),
            blockchainName: blockchain.name,
            minimumServiceNodeDeposit: Constants.MINIMUM_SERVICE_NODE_DEPOSIT,
            unbondingPeriodServiceNodeDeposit: Constants
                .SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD,
            validatorFeeFactor: blockchain.feeFactor,
            parameterUpdateDelay: Constants.PARAMETER_UPDATE_DELAY,
            nextTransferId: nextTransferId
        });
        bytes memory initializerData = abi.encodeCall(
            VisionHubInit.init,
            (args)
        );
        return initializerData;
    }

    // VisionRoles.SUPER_CRITICAL_OPS_ROLE  and expects VisionHub is paused
    function initializeVisionHub(
        IVisionHub visionHub,
        VisionForwarder visionForwarder,
        VisionToken visionToken,
        address primaryValidatorNodeAddress,
        uint256 commitmentWaitPeriod
    ) public {
        require(
            visionHub.paused(),
            "VisionHub should be paused before initializeVisionHub"
        );

        // Set the forwarder, PAN token, and primary validator node
        // addresses
        address currentForwarder = visionHub.getVisionForwarder();
        if (currentForwarder != address(visionForwarder)) {
            visionHub.setVisionForwarder(address(visionForwarder));
            console.log(
                "VisionHub.setVisionForwarder(%s)",
                address(visionForwarder)
            );
        } else {
            console.log(
                "VisionHub: VisionForwarder already set, "
                "skipping setVisionForwarder(%s)",
                address(visionForwarder)
            );
        }

        address currentVisionToken = visionHub.getVisionToken();
        if (currentVisionToken != address(visionToken)) {
            // Note: before initializeVisionHub, visionToken owner should call setVisionForwarder,
            // if we decide visionToken to do it later, this check needs to be done at later stages
            if (visionToken.getVisionForwarder() != address(visionForwarder)) {
                revert(
                    "VisionHub: The VisionToken's forwarder is not set to "
                    "the same address as the VisionHub's forwarder"
                );
            }
            visionHub.setVisionToken(address(visionToken));
            console.log("VisionHub.setVisionToken(%s)", address(visionToken));
        } else {
            console.log(
                "VisionHub: VisionToken already set, "
                "skipping setVisionToken(%s)",
                address(visionToken)
            );
        }

        address currentPrimaryNode = visionHub.getPrimaryValidatorNode();
        if (currentPrimaryNode != primaryValidatorNodeAddress) {
            visionHub.setPrimaryValidatorNode(primaryValidatorNodeAddress);
            console.log(
                "VisionHub.setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        } else {
            console.log(
                "VisionHub: Primary Validator already set, "
                "skipping setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        }

        bytes32 protocolVersion = bytes32(
            abi.encodePacked(
                string.concat(
                    vm.toString(Constants.MAJOR_PROTOCOL_VERSION),
                    ".",
                    vm.toString(Constants.MINOR_PROTOCOL_VERSION),
                    ".",
                    vm.toString(Constants.PATCH_PROTOCOL_VERSION)
                )
            )
        );
        bytes32 currentProtocolVersion = visionHub.getProtocolVersion();
        if (currentProtocolVersion != protocolVersion) {
            visionHub.setProtocolVersion(protocolVersion);
            console.log(
                "VisionHub.setProtocolVersion(%s)",
                vm.toString(protocolVersion)
            );
        } else {
            console.log(
                "VisionHub: protocol version already set, "
                "skipping setProtocolVersion(%s)",
                vm.toString(protocolVersion)
            );
        }

        uint256 currentCommitWaitPeriod = visionHub.getCommitmentWaitPeriod();
        if (currentCommitWaitPeriod != commitmentWaitPeriod) {
            visionHub.setCommitmentWaitPeriod(commitmentWaitPeriod);
            console.log(
                "VisionHub.setCommitmentWaitPeriod(%s)",
                vm.toString(commitmentWaitPeriod)
            );
        } else {
            console.log(
                "VisionHub: commitment wait period already set, "
                "skipping setCommitmentWaitPeriod(%s)",
                vm.toString(commitmentWaitPeriod)
            );
        }

        Blockchain memory blockchain = determineBlockchain();

        // Register the other blockchains
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );

            if (
                otherBlockchain.blockchainId != blockchain.blockchainId &&
                !otherBlockchain.skip
            ) {
                VisionTypes.BlockchainRecord
                    memory blockchainRecord = visionHub.getBlockchainRecord(
                        uint256(otherBlockchain.blockchainId)
                    );
                if (!blockchainRecord.active) {
                    visionHub.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor
                    );
                    console.log(
                        "VisionHub.registerBlockchain(%s) on %s",
                        otherBlockchain.name,
                        blockchain.name
                    );
                } else if (
                    keccak256(abi.encodePacked(blockchainRecord.name)) !=
                    keccak256(abi.encodePacked(otherBlockchain.name))
                ) {
                    console.log(
                        "VisionHub: blockchain names do not match. "
                        "Unregister and register again "
                        "Old name: %s New name: %s",
                        blockchainRecord.name,
                        otherBlockchain.name
                    );
                    visionHub.unregisterBlockchain(
                        uint256(otherBlockchain.blockchainId)
                    );
                    visionHub.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor
                    );
                    console.log(
                        "VisionHub.unregisterBlockchain(%s), "
                        "VisionHub.registerBlockchain(%s), ",
                        uint256(otherBlockchain.blockchainId),
                        uint256(otherBlockchain.blockchainId)
                    );
                } else {
                    console.log(
                        "VisionHub: Blockchain %s already registered "
                        "Skipping registerBlockchain(%s)",
                        otherBlockchain.name,
                        uint256(otherBlockchain.blockchainId)
                    );
                }
            }
        }
        // Unpause the hub contract after initialization
        visionHub.unpause();
        console.log("VisionHub initialized; paused=%s", visionHub.paused());
    }

    // VisionRoles.DEPLOYER_ROLE and expects VisionHub is paused already
    function diamondCutUpgradeFacets(
        address visionHubProxyAddress,
        VisionRegistryFacet registryFacet,
        VisionTransferFacet transferFacet
    ) public {
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = prepareVisionHubUpgradeFacetCuts(
            visionHubProxyAddress,
            registryFacet,
            transferFacet
        );

        IVisionHub visionHub = IVisionHub(visionHubProxyAddress);
        // Ensuring VisionHub is paused at the time of diamond cut
        require(
            visionHub.paused(),
            "VisionHub should be paused before diamondCut"
        );

        // upgrade visionHub diamond with facets using diamondCut
        IDiamondCut(visionHubProxyAddress).diamondCut(cut, address(0), "");

        console.log(
            "diamondCut VisionHubProxy; paused=%s; cut(s) count=%s;",
            visionHub.paused(),
            cut.length
        );
    }

    function getUpgradeFacetCut(
        address newFacetAddress,
        bytes4[] memory newSelectors,
        bytes4[] memory oldSelectors
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        bytes4 oldInterfaceId = _calculateInterfaceId(oldSelectors);
        bytes4 newInterfaceId = _calculateInterfaceId(newSelectors);

        if (oldInterfaceId == newInterfaceId) {
            console.log(
                "No interface change in new facet address=%s; Using Replace"
                " cut",
                newFacetAddress
            );
            IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
            cut[0] = IDiamondCut.FacetCut({
                facetAddress: address(newFacetAddress),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: newSelectors
            });
            return cut;
        } else {
            console.log(
                "Interface change detected in new facet address=%s;"
                " Using Remove/Add cut",
                newFacetAddress
            );

            IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
            cut[0] = IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: oldSelectors
            });
            cut[1] = IDiamondCut.FacetCut({
                facetAddress: address(newFacetAddress),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: newSelectors
            });
            return cut;
        }
    }

    /**
     * @dev This method tries to get old facet address via loupe by using one of
     * the existing function selector. If used function selector is getting
     * replaced, then use any other existing function selector.
     */
    function prepareVisionHubUpgradeFacetCuts(
        address visionHubProxyAddress,
        VisionRegistryFacet _visionRegistryFacet,
        VisionTransferFacet _visionTransferFacet
    ) private view returns (IDiamondCut.FacetCut[] memory) {
        address registryAddressOld = IDiamondLoupe(visionHubProxyAddress)
            .facetAddress(IVisionRegistry.registerBlockchain.selector);
        require(
            registryAddressOld != address(0),
            "Failed to find registry facet of provided selector."
            " Provide a selector which is present in the current facet."
        );
        console.log(
            "Found current registry facet address=%s;",
            registryAddressOld
        );

        bytes4[] memory regiatrySelectorsOld = IDiamondLoupe(
            visionHubProxyAddress
        ).facetFunctionSelectors(registryAddressOld);
        bytes4[] memory registrySelectorsNew = getVisionRegistrySelectors();

        IDiamondCut.FacetCut[] memory cutRegistry = getUpgradeFacetCut(
            address(_visionRegistryFacet),
            registrySelectorsNew,
            regiatrySelectorsOld
        );

        address transferAddressOld = IDiamondLoupe(visionHubProxyAddress)
            .facetAddress(IVisionTransfer.transfer.selector);
        require(
            transferAddressOld != address(0),
            "Failed to find transfer facet of provided selector"
        );

        console.log(
            "Found current transfer facet address=%s;",
            transferAddressOld
        );

        bytes4[] memory transferSelectorsOld = IDiamondLoupe(
            visionHubProxyAddress
        ).facetFunctionSelectors(transferAddressOld);
        bytes4[] memory transferSelectorsNew = getVisionTransferSelectors();

        IDiamondCut.FacetCut[] memory cutTransfer = getUpgradeFacetCut(
            address(_visionTransferFacet),
            transferSelectorsNew,
            transferSelectorsOld
        );

        // combining cuts for both facets in a single array
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](
            cutRegistry.length + cutTransfer.length
        );

        for (uint i; i < cutRegistry.length; i++) {
            cut[i] = cutRegistry[i];
        }

        for (uint i; i < cutTransfer.length; i++) {
            cut[cutRegistry.length + i] = cutTransfer[i];
        }
        return cut;
    }

    function pauseVisionHub(IVisionHub visionHub) public {
        if (!visionHub.paused()) {
            visionHub.pause();
            console.log(
                "VisionHub(%s): paused=%s",
                address(visionHub),
                visionHub.paused()
            );
        }
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
}
