// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionRegistryFacet} from "../../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../../src/facets/VisionTransferFacet.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionHubProxy} from "../../src/VisionHubProxy.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {VisionWrapper} from "../../src/VisionWrapper.sol";

import {VisionBaseAddresses} from "../helpers/VisionBaseAddresses.s.sol";
import {VisionHubDeployer} from "../helpers/VisionHubDeployer.s.sol";
import {VisionForwarderRedeployer} from "../helpers/VisionForwarderRedeployer.s.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

/**
 * @title UpgradeHubAndRedeployForwarder
 *
 * @notice Deploy and upgrade facets of the Vision Hub and redeploys the
 * Vision Forwarder. To ensure correct functionality of the newly deployed
 * Vision Forwarder within the Vision protocol, the following steps are
 * incorporated into this script:
 *
 * 1. Retrieve the validator address from the Vision Hub and
 * configure it in the new Vision Forwarder.
 * 2. Retrieve the Vision token address from the Vision Hub and
 * configure it in the new Vision Forwarder.
 * 3. Configure the new Vision Forwarder at the Vision Hub.
 * @dev Usage
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/UpgradeHubAndRedeployForwarder.s.sol \
 *  --account <account> --sender <sender> --rpc-url <rpc alias> --slow \
 *          --sig "deploy(address)" <accessControllerAddress> --force
 * 2. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/redeploy/UpgradeHubAndRedeployForwarder.s.sol \
 *   --rpc-url <rpc alias> --sig "roleActions() -vvvv"
 */
contract UpgradeHubAndRedeployForwarder is
    VisionBaseAddresses,
    SafeAddresses,
    VisionHubDeployer,
    VisionForwarderRedeployer
{
    VisionHubProxy visionHubProxy;
    VisionToken visionToken;
    AccessController accessController;
    VisionForwarder oldForwarder;
    VisionWrapper[] tokens;

    VisionRegistryFacet newRegistryFacet;
    VisionTransferFacet newTransferFacet;
    VisionForwarder newVisionForwarder;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);

        vm.startBroadcast();
        newRegistryFacet = deployRegistryFacet();
        newTransferFacet = deployTransferFacet();
        newVisionForwarder = deployVisionForwarder(accessController);
        vm.stopBroadcast();

        exportUpgradedContractAddresses();
    }

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

        // this will migrate new forwarder at visionHub
        vm.startBroadcast(accessController.superCriticalOps());
        initializeVisionHub(
            visionHub,
            newVisionForwarder,
            visionToken,
            visionHub.getPrimaryValidatorNode(),
            commitmentWaitPeriod
        );
        vm.stopBroadcast();

        uint256 minimumValidatorNodeSignatures = tryGetMinimumValidatorNodeSignatures(
                oldForwarder
            );
        address[] memory validatorNodeAddresses = tryGetValidatorNodes(
            oldForwarder
        );

        vm.startBroadcast(accessController.superCriticalOps());
        initializeVisionForwarder(
            newVisionForwarder,
            visionHub,
            visionToken,
            minimumValidatorNodeSignatures,
            validatorNodeAddresses
        );
        vm.stopBroadcast();

        // Pause old forwarder
        vm.startBroadcast(accessController.pauser());
        pauseForwarder(oldForwarder);
        vm.stopBroadcast();

        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
    }

    function exportUpgradedContractAddresses() public {
        ContractAddress[] memory contractAddresses = new ContractAddress[](3);
        contractAddresses[0] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(newRegistryFacet)
        );
        contractAddresses[1] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(newTransferFacet)
        );
        contractAddresses[2] = ContractAddress(
            Contract.FORWARDER,
            address(newVisionForwarder)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();

        // New items
        newRegistryFacet = VisionRegistryFacet(
            getContractAddress(Contract.REGISTRY_FACET, true)
        );
        newTransferFacet = VisionTransferFacet(
            getContractAddress(Contract.TRANSFER_FACET, true)
        );
        newVisionForwarder = VisionForwarder(
            payable(getContractAddress(Contract.FORWARDER, true))
        );

        // Old items
        visionToken = VisionToken(getContractAddress(Contract.VSN, false));

        visionHubProxy = VisionHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        oldForwarder = VisionForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );
        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            tokens.push(VisionWrapper(token));
        }
    }
}
