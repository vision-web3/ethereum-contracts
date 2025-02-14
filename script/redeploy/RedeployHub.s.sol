// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {AccessController} from "../../src/access/AccessController.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionHubInit} from "../../src/upgradeInitializers/VisionHubInit.sol";
import {VisionHubProxy} from "../../src/VisionHubProxy.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {VisionTypes} from "../../src/interfaces/VisionTypes.sol";

import {VisionRegistryFacet} from "../../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../../src/facets/VisionTransferFacet.sol";

import {VisionBaseAddresses} from "../helpers/VisionBaseAddresses.s.sol";
import {VisionHubRedeployer} from "../helpers/VisionHubRedeployer.s.sol";
import {VisionFacets} from "../helpers/VisionHubDeployer.s.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

/**
 * @title RedeployHub
 *
 * @notice Redeploy the Vision Hub.
 * To ensure correct functionality of the newly deployed Vision Hub within the
 * Vision protocol, the following steps are incorporated into this script:
 *
 * 1. Retrieve the primary validator node address from the previous
 * Vision Hub and configure it in the new Vision Hub.
 * 2. Retrieve the Vision Forwarder address from the previous Vision Hub and
 * configure it in the new Vision Hub.
 * 3. Retrieve the Vision token address from the previous Vision Hub and
 * configure it in the new Vision Hub.
 * 4. Configure the new Vision Hub at the Vision Forwarder.
 * 5. Migrate the tokens owned by the sender account from the old Vision Hub
 * to the new one.
 *
 * @dev Usage
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/RedeployHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "deploy(address)" <accessControllerAddress>
 * 2. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/redeploy/RedeployHub.s.sol --rpc-url <rpc alias> \
 *     --sig "roleActions() -vvvv"
 */
contract RedeployHub is
    VisionBaseAddresses,
    SafeAddresses,
    VisionHubRedeployer
{
    AccessController accessController;
    VisionHubProxy newVisionHubProxy;
    VisionHubInit newVisionHubInit;
    VisionFacets newVisionFacets;
    IVisionHub oldVisionHub;

    function migrateHubAtForwarder(
        VisionForwarder visionForwarder
    ) public onlyVisionHubRedeployerInitialized {
        visionForwarder.setVisionHub(address(newVisionHubProxy));
        visionForwarder.unpause();
        console.log(
            "VisionForwarder.setVisionHub(%s); paused=%s",
            address(newVisionHubProxy),
            visionForwarder.paused()
        );
    }

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);

        vm.startBroadcast();
        (
            newVisionHubProxy,
            newVisionHubInit,
            newVisionFacets
        ) = deployVisionHub(accessController);
        exportRedeployedContractAddresses();
    }

    function roleActions() public {
        importContractAddresses();
        initializeVisionHubRedeployer(oldVisionHub);

        uint256 nextTransferId = oldVisionHub.getNextTransferId();
        uint256 commitmentWaitPeriod = oldVisionHub.getCommitmentWaitPeriod();

        vm.startBroadcast(accessController.pauser());
        pauseVisionHub(oldVisionHub);
        vm.stopBroadcast();

        vm.startBroadcast(accessController.deployer());
        diamondCutFacets(
            newVisionHubProxy,
            newVisionHubInit,
            newVisionFacets,
            nextTransferId
        );
        vm.stopBroadcast();

        IVisionHub newVisionHub = IVisionHub(address(newVisionHubProxy));
        VisionForwarder visionForwarder = VisionForwarder(
            oldVisionHub.getVisionForwarder()
        );

        vm.startBroadcast(accessController.superCriticalOps());
        initializeVisionHub(
            newVisionHub,
            visionForwarder,
            VisionToken(oldVisionHub.getVisionToken()),
            oldVisionHub.getPrimaryValidatorNode(),
            commitmentWaitPeriod
        );
        vm.stopBroadcast();

        if (!visionForwarder.paused()) {
            vm.broadcast(accessController.pauser());
            visionForwarder.pause();
        }

        vm.startBroadcast(accessController.superCriticalOps());
        migrateHubAtForwarder(visionForwarder);
        migrateTokensFromOldHubToNewHub(newVisionHub);
        vm.stopBroadcast();

        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
    }

    function exportRedeployedContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](6);
        contractAddresses[0] = ContractAddress(
            Contract.HUB_PROXY,
            address(newVisionHubProxy)
        );
        contractAddresses[1] = ContractAddress(
            Contract.HUB_INIT,
            address(newVisionHubInit)
        );
        contractAddresses[2] = ContractAddress(
            Contract.DIAMOND_CUT_FACET,
            address(newVisionFacets.dCut)
        );
        contractAddresses[3] = ContractAddress(
            Contract.DIAMOND_LOUPE_FACET,
            address(newVisionFacets.dLoupe)
        );
        contractAddresses[4] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(newVisionFacets.registry)
        );
        contractAddresses[5] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(newVisionFacets.transfer)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();

        // New contracts
        newVisionHubProxy = VisionHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, true))
        );

        newVisionHubInit = VisionHubInit(
            getContractAddress(Contract.HUB_INIT, true)
        );
        newVisionFacets = VisionFacets(
            DiamondCutFacet(
                getContractAddress(Contract.DIAMOND_CUT_FACET, true)
            ),
            DiamondLoupeFacet(
                getContractAddress(Contract.DIAMOND_LOUPE_FACET, true)
            ),
            VisionRegistryFacet(
                getContractAddress(Contract.REGISTRY_FACET, true)
            ),
            VisionTransferFacet(
                getContractAddress(Contract.TRANSFER_FACET, true)
            )
        );
        // Old contracts
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        oldVisionHub = IVisionHub(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
    }
}
