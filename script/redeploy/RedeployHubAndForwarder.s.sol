// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {VisionHubProxy} from "../../src/VisionHubProxy.sol";
import {VisionHubInit} from "../../src/upgradeInitializers/VisionHubInit.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {VisionRegistryFacet} from "../../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../../src/facets/VisionTransferFacet.sol";
import {VisionWrapper} from "../../src/VisionWrapper.sol";

import {VisionBaseAddresses} from "../helpers/VisionBaseAddresses.s.sol";
import {VisionForwarderRedeployer} from "../helpers/VisionForwarderRedeployer.s.sol";
import {VisionHubRedeployer} from "../helpers/VisionHubRedeployer.s.sol";
import {VisionFacets} from "../helpers/VisionHubDeployer.s.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

/**
 * @title RedeployHubAndForwarder
 *
 * @notice Redeploy the Vision Hub and the Vision Forwarder.
 * To ensure correct functionality of the newly deployed Vision Hub
 * and Vision Forwarder within the Vision protocol, the following
 * steps are incorporated into this script:
 *
 * 1. Retrieve the validator node addresses from the previous Vision Hub
 * and Forwarder and configure it in the new Vision Hub and Forwarder.
 * 2. Retrieve the Vision Forwarder address from the previous Vision Hub and
 * configure it in the new Vision Hub.
 * 3. Retrieve the Vision token address from the previous Vision Hub and
 * configure it in the new Vision Hub and the Vision Forwarder.
 * 4. Configure the new Vision Hub at the Vision Forwarder.
 * 5. Configure the new Vision Forwarder at the Vision Hub.
 * 5. Configure the new Vision Forwarder at Vision, Best and Wrapper tokens.
 * 6. Migrate the tokens owned by the sender account from the old Vision Hub
 * to the new one.
 *
 * @dev Usage
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/RedeployHubAndForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "deploy(address)" <accessControllerAddress>
 * 2. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/redeploy/RedeployHubAndForwarder.s.sol \
 * --rpc-url <rpc alias> --sig "roleActions() -vvvv"
 */
contract RedeployHubAndForwarder is
    VisionBaseAddresses,
    SafeAddresses,
    VisionHubRedeployer,
    VisionForwarderRedeployer
{
    AccessController accessController;
    VisionHubProxy newVisionHubProxy;
    VisionHubInit newVisionHubInit;
    VisionFacets newVisionFacets;
    VisionForwarder newVisionForwarder;
    IVisionHub oldVisionHub;
    VisionWrapper[] tokens;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);

        vm.startBroadcast();
        (
            newVisionHubProxy,
            newVisionHubInit,
            newVisionFacets
        ) = deployVisionHub(accessController);

        newVisionForwarder = deployVisionForwarder(accessController);
        exportRedeployedContractAddresses();
    }

    function roleActions() public {
        importContractAddresses();

        initializeVisionHubRedeployer(oldVisionHub);
        uint256 nextTransferId = oldVisionHub.getNextTransferId();
        uint256 commitmentWaitPeriod = oldVisionHub.getCommitmentWaitPeriod();
        VisionForwarder oldForwarder = VisionForwarder(
            oldVisionHub.getVisionForwarder()
        );

        vm.startBroadcast(accessController.pauser());
        pauseVisionHub(oldVisionHub);
        pauseForwarder(oldForwarder);
        vm.stopBroadcast();

        vm.broadcast(accessController.deployer());
        diamondCutFacets(
            newVisionHubProxy,
            newVisionHubInit,
            newVisionFacets,
            nextTransferId
        );

        IVisionHub newVisionHub = IVisionHub(address(newVisionHubProxy));
        VisionToken visionToken = VisionToken(oldVisionHub.getVisionToken());

        vm.broadcast(accessController.superCriticalOps());
        initializeVisionHub(
            newVisionHub,
            newVisionForwarder,
            visionToken,
            oldVisionHub.getPrimaryValidatorNode(),
            commitmentWaitPeriod
        );

        uint256 minimumValidatorNodeSignatures = tryGetMinimumValidatorNodeSignatures(
                oldForwarder
            );
        address[] memory validatorNodeAddresses = tryGetValidatorNodes(
            oldForwarder
        );

        vm.broadcast(accessController.superCriticalOps());
        initializeVisionForwarder(
            newVisionForwarder,
            newVisionHub,
            visionToken,
            minimumValidatorNodeSignatures,
            validatorNodeAddresses
        );

        // Pause old forwarder
        vm.broadcast(accessController.pauser());
        pauseForwarder(oldForwarder);

        // Migrate
        vm.broadcast(accessController.superCriticalOps());
        migrateTokensFromOldHubToNewHub(newVisionHub);

        // migrate new Forwarder at tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.startBroadcast(accessController.pauser());
            tokens[i].pause();

            vm.broadcast(accessController.superCriticalOps());
            migrateNewForwarderAtToken(newVisionForwarder, tokens[i]);
        }

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
        contractAddresses[5] = ContractAddress(
            Contract.FORWARDER,
            address(newVisionForwarder)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();

        // New items
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

        newVisionForwarder = VisionForwarder(
            payable(getContractAddress(Contract.FORWARDER, true))
        );

        // Old items
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        oldVisionHub = IVisionHub(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );

        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            tokens.push(VisionWrapper(token));
        }
    }
}
