// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
import {VisionForwarder} from "../src/VisionForwarder.sol";
import {VisionToken} from "../src/VisionToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";
import {VisionWrapper} from "../src/VisionWrapper.sol";
import {AccessController} from "../src/access/AccessController.sol";
import {VisionHubProxy} from "../src/VisionHubProxy.sol";
import {VisionHubInit} from "../src/upgradeInitializers/VisionHubInit.sol";
import {VisionRegistryFacet} from "../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../src/facets/VisionTransferFacet.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {VisionTokenMigrator} from "../src/VisionTokenMigrator.sol";

import {VisionHubDeployer, VisionFacets} from "./helpers/VisionHubDeployer.s.sol";
import {VisionForwarderDeployer} from "./helpers/VisionForwarderDeployer.s.sol";
import {VisionWrapperDeployer} from "./helpers/VisionWrapperDeployer.s.sol";
import {VisionTokenDeployer} from "./helpers/VisionTokenDeployer.s.sol";
import {BitpandaEcosystemTokenDeployer} from "./helpers/BitpandaEcosystemTokenDeployer.s.sol";
import {AccessControllerDeployer} from "./helpers/AccessControllerDeployer.s.sol";
import {VisionBaseAddresses} from "./helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

/**
 * @title DeployContracts
 *
 * @notice Deploy and initialize the Vision smart contracts on an
 * Ethereum-compatible single blockchain.
 *
 * @dev Usage
 * 1. Deploy by any gas paying account (on chains where
 *    the old PAN does not exist):
 * forge script ./script/DeployContracts.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(uint256,uint256)" <vsnSupply> <bestSupply>
 *
 * 2. Deploy the remaining contracts from any gas paying account
 *    (on chains where the old VSN, new VSN, Access Controller,
 *    and the VSN migrator exist)
 * forge script ./script/DeployContracts.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(uint256)" <bestSupply>
 *
 * 3. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/DeployContracts.s.sol --rpc-url <rpc alias> \
 *          -vvvv --sig "roleActions(uint256,uint256,address,address[])" \
 *          <nextTransferId> <minimumValidatorNodeSignatures> \
 *          <primaryValidator> <otherValidators>
 */
contract DeployContracts is
    VisionBaseAddresses,
    SafeAddresses,
    VisionHubDeployer,
    VisionForwarderDeployer,
    VisionWrapperDeployer,
    VisionTokenDeployer,
    BitpandaEcosystemTokenDeployer,
    AccessControllerDeployer
{
    AccessController accessController;
    VisionHubProxy visionHubProxy;
    VisionHubInit visionHubInit;
    VisionFacets visionFacets;
    VisionForwarder visionForwarder;
    VisionToken visionToken;
    BitpandaEcosystemToken bitpandaEcosystemToken;
    VisionWrapper[] visionWrappers;
    VisionTokenMigrator visionTokenMigrator;

    function deploy(uint256 vsnSupply, uint256 bestSupply) public {
        vm.startBroadcast();
        readRoleAddresses();
        address pauser = getRoleAddress(Role.PAUSER);
        address deployer = getRoleAddress(Role.DEPLOYER);
        address mediumCriticalOps = getRoleAddress(Role.MEDIUM_CRITICAL_OPS);
        address superCriticalOps = getRoleAddress(Role.SUPER_CRITICAL_OPS);
        accessController = deployAccessController(
            pauser,
            deployer,
            mediumCriticalOps,
            superCriticalOps
        );
        (visionHubProxy, visionHubInit, visionFacets) = deployVisionHub(
            accessController
        );
        // FIXME move vsn out and take it as input param
        visionToken = deployVisionToken(
            vsnSupply,
            superCriticalOps,
            superCriticalOps,
            superCriticalOps,
            superCriticalOps,
            superCriticalOps
        );
        visionForwarder = deployVisionForwarder(accessController);
        bitpandaEcosystemToken = deployBitpandaEcosystemToken(
            bestSupply,
            accessController
        );
        visionWrappers = deployCoinWrappers(accessController);
        vm.stopBroadcast();

        exportAllContractAddresses(false);
    }

    function deploy(uint256 bestSupply) public {
        vm.startBroadcast();
        importMigratorAndDependencies();
        visionForwarder = deployVisionForwarder(accessController);
        bitpandaEcosystemToken = deployBitpandaEcosystemToken(
            bestSupply,
            accessController
        );
        visionWrappers = deployCoinWrappers(accessController);
        vm.stopBroadcast();

        exportAllContractAddresses(true);
    }

    function roleActions(
        uint256 nextTransferId,
        uint256 commitmentWaitPeriod,
        uint256 minimumValidatorNodeSignatures,
        address primaryValidator,
        address[] memory otherValidators
    ) public {
        importAllContractAddresses();
        vm.broadcast(accessController.deployer());
        diamondCutFacets(
            visionHubProxy,
            visionHubInit,
            visionFacets,
            nextTransferId
        );

        IVisionHub visionHub = IVisionHub(address(visionHubProxy));

        vm.startBroadcast(accessController.superCriticalOps());
        setBridgeAtVisionToken(visionToken, visionForwarder); // FIXME move vsn configuration out
        initializeVisionHub(
            visionHub,
            visionForwarder,
            visionToken,
            primaryValidator,
            commitmentWaitPeriod
        );

        // all validator node addresses
        address[] memory validatorNodeAddresses = new address[](
            otherValidators.length + 1
        );
        validatorNodeAddresses[0] = primaryValidator;
        for (uint i; i < otherValidators.length; i++) {
            validatorNodeAddresses[i + 1] = otherValidators[i];
        }

        initializeVisionForwarder(
            visionForwarder,
            visionHub,
            visionToken,
            minimumValidatorNodeSignatures,
            validatorNodeAddresses
        );
        initializeBitpandaEcosystemToken(
            bitpandaEcosystemToken,
            visionHub,
            visionForwarder
        );
        initializeVisionWrappers(visionHub, visionForwarder, visionWrappers);
        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }

    function exportAllContractAddresses(
        bool isMigratorIncludedInExport
    ) internal {
        uint256 length = isMigratorIncludedInExport
            ? 11 + visionWrappers.length
            : 10 + visionWrappers.length;
        ContractAddress[] memory contractAddresses = new ContractAddress[](
            length
        );
        contractAddresses[0] = ContractAddress(
            Contract.ACCESS_CONTROLLER,
            address(accessController)
        );
        contractAddresses[1] = ContractAddress(
            Contract.HUB_PROXY,
            address(visionHubProxy)
        );
        contractAddresses[2] = ContractAddress(
            Contract.HUB_INIT,
            address(visionHubInit)
        );
        contractAddresses[3] = ContractAddress(
            Contract.DIAMOND_CUT_FACET,
            address(visionFacets.dCut)
        );
        contractAddresses[4] = ContractAddress(
            Contract.DIAMOND_LOUPE_FACET,
            address(visionFacets.dLoupe)
        );
        contractAddresses[5] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(visionFacets.registry)
        );
        contractAddresses[6] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(visionFacets.transfer)
        );
        contractAddresses[7] = ContractAddress(
            Contract.FORWARDER,
            address(visionForwarder)
        );
        contractAddresses[8] = ContractAddress(
            Contract.VSN,
            address(visionToken)
        );
        contractAddresses[9] = ContractAddress(
            Contract.BEST,
            address(bitpandaEcosystemToken)
        );
        for (uint i; i < visionWrappers.length; i++) {
            contractAddresses[i + 10] = ContractAddress(
                _keysToContracts[visionWrappers[i].symbol()],
                address(visionWrappers[i])
            );
        }
        if (isMigratorIncludedInExport) {
            contractAddresses[length - 1] = ContractAddress(
                Contract.VSN_MIGRATOR,
                address(visionTokenMigrator)
            );
        }
        exportContractAddresses(contractAddresses, false);
    }

    function importAllContractAddresses() internal {
        readContractAddresses(determineBlockchain());

        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionHubProxy = VisionHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
        visionHubInit = VisionHubInit(
            getContractAddress(Contract.HUB_INIT, false)
        );
        visionFacets = VisionFacets(
            DiamondCutFacet(
                getContractAddress(Contract.DIAMOND_CUT_FACET, false)
            ),
            DiamondLoupeFacet(
                getContractAddress(Contract.DIAMOND_LOUPE_FACET, false)
            ),
            VisionRegistryFacet(
                getContractAddress(Contract.REGISTRY_FACET, false)
            ),
            VisionTransferFacet(
                getContractAddress(Contract.TRANSFER_FACET, false)
            )
        );
        visionForwarder = VisionForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );
        visionToken = VisionToken(getContractAddress(Contract.VSN, false));
        bitpandaEcosystemToken = BitpandaEcosystemToken(
            getContractAddress(Contract.BEST, false)
        );
        visionWrappers = new VisionWrapper[](7);
        visionWrappers[0] = VisionWrapper(
            getContractAddress(Contract.VSN_AVAX, false)
        );
        visionWrappers[1] = VisionWrapper(
            getContractAddress(Contract.VSN_BNB, false)
        );
        visionWrappers[2] = VisionWrapper(
            getContractAddress(Contract.VSN_CELO, false)
        );
        visionWrappers[3] = VisionWrapper(
            getContractAddress(Contract.VSN_CRO, false)
        );
        visionWrappers[4] = VisionWrapper(
            getContractAddress(Contract.VSN_ETH, false)
        );
        visionWrappers[5] = VisionWrapper(
            getContractAddress(Contract.VSN_S, false)
        );
        visionWrappers[6] = VisionWrapper(
            getContractAddress(Contract.VSN_POL, false)
        );
    }

    function importMigratorAndDependencies() internal {
        readContractAddresses(determineBlockchain());

        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionToken = VisionToken(getContractAddress(Contract.VSN, false));
        visionTokenMigrator = VisionTokenMigrator(
            getContractAddress(Contract.VSN_MIGRATOR, false)
        );
    }
}
