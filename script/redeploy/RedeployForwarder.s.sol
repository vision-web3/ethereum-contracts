// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import {AccessController} from "../../src/access/AccessController.sol";
import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {IVisionToken} from "../../src/interfaces/IVisionToken.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {VisionWrapper} from "../../src/VisionWrapper.sol";

import {VisionForwarder} from "../../src/VisionForwarder.sol";

import {VisionBaseAddresses} from "../helpers/VisionBaseAddresses.s.sol";
import {VisionForwarderRedeployer} from "../helpers/VisionForwarderRedeployer.s.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

/**
 * @title RedeployForwarder
 *
 * @notice Redeploy the Vision Forwarder
 * To ensure correct functionality of the newly deployed Vision Forwarder
 * within the Vision protocol, the following steps are incorporated into
 * this script:
 *
 * 1. Retrieve the validator node addresses from the previous Vision
 * Forwarder and configure it in the new Vision Forwarder.
 * 2. Retrieve the Vision token address from the Vision Hub and
 * configure it in the new Vision Forwarder.
 * 3. Configure the new Vision Forwarder at the Vision Hub.
 * 4. Configure the new Vision Forwarder at Vision, Best and Wrapper tokens.
 *
 * @dev Usage
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/RedeployForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "deploy(address)" <accessControllerAddress>
 * 2. Simulate roleActions to be later signed by appropriate roles
 *  forge script ./script/redeploy/RedeployForwarder.s.sol \
 *     --rpc-url <rpc alias> --sig "roleActions() -vvvv"
 */
contract RedeployForwarder is
    VisionBaseAddresses,
    SafeAddresses,
    VisionForwarderRedeployer
{
    AccessController accessController;
    VisionForwarder newVisionForwarder;
    IVisionHub visionHub;
    VisionWrapper[] tokens;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);
        vm.startBroadcast();
        newVisionForwarder = deployVisionForwarder(accessController);
        vm.stopBroadcast();

        exportRedeployedContractAddresses();
    }

    function roleActions() public {
        importContractAddresses();
        VisionForwarder oldForwarder = VisionForwarder(
            visionHub.getVisionForwarder()
        );

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
            VisionToken(visionHub.getVisionToken()),
            minimumValidatorNodeSignatures,
            validatorNodeAddresses
        );
        vm.stopBroadcast();

        // Pause vision Hub and old forwarder
        vm.startBroadcast(accessController.pauser());
        pauseForwarder(oldForwarder);
        visionHub.pause();
        vm.stopBroadcast();

        vm.startBroadcast(accessController.superCriticalOps());
        migrateForwarderAtHub(newVisionForwarder, visionHub);
        vm.stopBroadcast();

        // migrate new Forwarder at tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.broadcast(accessController.pauser());
            tokens[i].pause();

            vm.startBroadcast(accessController.superCriticalOps());
            migrateNewForwarderAtToken(newVisionForwarder, tokens[i]);
            vm.stopBroadcast();
        }
        // update json with new forwarder
        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
    }

    function exportRedeployedContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](1);
        contractAddresses[0] = ContractAddress(
            Contract.FORWARDER,
            address(newVisionForwarder)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();

        // New items
        newVisionForwarder = VisionForwarder(
            payable(getContractAddress(Contract.FORWARDER, true))
        );

        // Old items
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        visionHub = IVisionHub(
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
