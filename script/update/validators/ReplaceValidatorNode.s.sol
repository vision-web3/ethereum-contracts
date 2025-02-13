// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {VisionForwarder} from "../../../src/VisionForwarder.sol";

import {VisionBaseAddresses} from "./../../helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title ReplaceValidatorNode
 *
 * @notice Replace a validator node at the Vision Forwarder.
 *
 * @dev Usage
 * forge script ./script/update/validators/ReplaceValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,address)" <oldValidatorNode> <newValidatorNode>
 */
contract ReplaceValidatorNode is VisionBaseAddresses, SafeAddresses {
    AccessController accessController;
    VisionForwarder public visionForwarder;

    function roleActions(
        address oldValidatorNode,
        address newValidatorNode
    ) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionForwarder = VisionForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );

        address[] memory validatorNodes = visionForwarder.getValidatorNodes();
        bool found = false;
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            require(
                validatorNodes[i] != newValidatorNode,
                "New validator node already exists"
            );
            if (validatorNodes[i] == oldValidatorNode) {
                found = true;
                break;
            }
        }
        if (!found) {
            console.log("Old validator node %s not found", oldValidatorNode);
            revert("Validator node not found");
        }
        vm.broadcast(accessController.pauser());
        visionForwarder.pause();
        console.log("Vision forwarder paused: %s", visionForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        visionForwarder.addValidatorNode(newValidatorNode);
        visionForwarder.removeValidatorNode(oldValidatorNode);
        visionForwarder.unpause();
        console.log("Validator node %s added", newValidatorNode);
        console.log("Old validator node %s removed", oldValidatorNode);
        console.log("Vision forwarder paused: %s", visionForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
