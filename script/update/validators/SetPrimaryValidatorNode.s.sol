// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {IVisionHub} from "../../../src/interfaces/IVisionHub.sol";

import {VisionBaseAddresses} from "./../../helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title SetPrimaryValidatorNode
 *
 * @notice Set the primary validator node at the Vision Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/SetPrimaryValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address)" <newPirmaryValidatorNode>
 */
contract SetPrimaryValidatorNode is VisionBaseAddresses, SafeAddresses {
    AccessController accessController;
    IVisionHub public visionHub;

    function roleActions(address newPirmaryValidatorNode) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionHub = IVisionHub(getContractAddress(Contract.HUB_PROXY, false));

        address oldPrimaryValidatorNode = visionHub.getPrimaryValidatorNode();
        if (oldPrimaryValidatorNode == newPirmaryValidatorNode) {
            console.log(
                "Primary validator node is already set to %s",
                newPirmaryValidatorNode
            );
            revert("Primary validator node is already set to the new value");
        }

        vm.broadcast(accessController.pauser());
        visionHub.pause();
        console.log("Vision hub paused: %s", visionHub.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        visionHub.setPrimaryValidatorNode(newPirmaryValidatorNode);
        visionHub.unpause();
        console.log(
            "Primary validator node set to %s, old value was %s",
            newPirmaryValidatorNode,
            oldPrimaryValidatorNode
        );
        console.log("Vision hub paused: %s", visionHub.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
