// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionHubProxy} from "../../src/VisionHubProxy.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";

import {VisionHubDeployer} from "../helpers/VisionHubDeployer.s.sol";
import {VisionBaseAddresses} from "../helpers/VisionBaseAddresses.s.sol";
import {VisionRegistryFacet} from "../../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../../src/facets/VisionTransferFacet.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

/**
 * @title UpgradeHub
 *
 * @notice Deploy and upgrade facets of the Vision Hub.
 *
 * @dev Usage
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/UpgradeHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "deploy()"
 * 2. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/redeploy/UpgradeHub.s.sol --rpc-url <rpc alias> \
 * -vvvv --sig "roleActions()"
 */
contract UpgradeHub is VisionBaseAddresses, SafeAddresses, VisionHubDeployer {
    VisionHubProxy visionHubProxy;
    VisionForwarder visionForwarder;
    VisionToken visionToken;
    AccessController accessController;

    VisionRegistryFacet newRegistryFacet;
    VisionTransferFacet newTransferFacet;

    function deploy() public {
        vm.startBroadcast();
        newRegistryFacet = deployRegistryFacet();
        newTransferFacet = deployTransferFacet();
        vm.stopBroadcast();
        exportUpgradedContractAddresses();
    }

    // this will also read current addresses from <blockchainName>.json -- update it at end of the script
    function roleActions() public {
        importContractAddresses();
        IVisionHub visionHub = IVisionHub(address(visionHubProxy));
        console.log("VisionHub", address(visionHub));

        uint256 commitmentWaitPeriod = visionHub.getCommitmentWaitPeriod();

        // Ensuring VisionHub is paused at the time of diamond cut
        vm.startBroadcast(accessController.pauser());
        pauseVisionHub(visionHub);
        vm.stopBroadcast();

        vm.startBroadcast(accessController.deployer());
        diamondCutUpgradeFacets(
            address(visionHubProxy),
            newRegistryFacet,
            newTransferFacet
        );
        vm.stopBroadcast();

        // this will do nothing if there is nothing new added to the storage slots
        vm.startBroadcast(accessController.superCriticalOps());
        initializeVisionHub(
            visionHub,
            visionForwarder,
            visionToken,
            visionHub.getPrimaryValidatorNode(),
            commitmentWaitPeriod
        );
        vm.stopBroadcast();
        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
    }

    function exportUpgradedContractAddresses() public {
        ContractAddress[] memory contractAddresses = new ContractAddress[](2);
        contractAddresses[0] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(newRegistryFacet)
        );
        contractAddresses[1] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(newTransferFacet)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();
        newRegistryFacet = VisionRegistryFacet(
            getContractAddress(Contract.REGISTRY_FACET, true)
        );
        newTransferFacet = VisionTransferFacet(
            getContractAddress(Contract.TRANSFER_FACET, true)
        );
        visionHubProxy = VisionHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionForwarder = VisionForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );
        visionToken = VisionToken(getContractAddress(Contract.VSN, false));
    }
}
