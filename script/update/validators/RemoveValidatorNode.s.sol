// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {VisionForwarder} from "../../../src/VisionForwarder.sol";

import {VisionBaseAddresses} from "./../../helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title RemoveValidatorNode
 *
 * @notice Remove a validator node from the Vision Forwarder.
 *
 * @dev Usage
 * 1. Remove a validator node.
 * forge script ./script/update/validators/RemoveValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address)" <validatorNode>
 * 2. Remove a validator node and change the minimum threshold of validator nodes.
 * forge script ./script/update/validators/RemoveValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,uint256)" <validatorNode> <newMinimumThreshold>
 */
contract RemoveValidatorNode is VisionBaseAddresses, SafeAddresses {
    AccessController accessController;
    VisionForwarder public visionForwarder;

    function roleActions(address validatorNode) public {
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
            if (validatorNodes[i] == validatorNode) {
                found = true;
                break;
            }
        }
        if (!found) {
            console.log("Validator node %s not found", validatorNode);
            revert("Validator node not found");
        }

        vm.broadcast(accessController.pauser());
        visionForwarder.pause();

        vm.startBroadcast(accessController.superCriticalOps());
        visionForwarder.removeValidatorNode(validatorNode);
        visionForwarder.unpause();
        console.log("Validator node %s removed", validatorNode);
        console.log("Vision forwarder paused: %s", visionForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }

    function roleActions(
        address validatorNode,
        uint256 newMinimumThreshold
    ) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionForwarder = VisionForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );

        require(
            newMinimumThreshold > 0,
            "Minimum threshold must be greater than 0"
        );
        address[] memory validatorNodes = visionForwarder.getValidatorNodes();
        bool found = false;
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            if (validatorNodes[i] == validatorNode) {
                found = true;
                break;
            }
        }
        if (!found) {
            console.log("Validator node %s not found", validatorNode);
            revert("Validator node not found");
        }

        vm.broadcast(accessController.pauser());
        visionForwarder.pause();

        vm.startBroadcast(accessController.superCriticalOps());
        visionForwarder.setMinimumValidatorNodeSignatures(newMinimumThreshold);
        visionForwarder.removeValidatorNode(validatorNode);
        visionForwarder.unpause();
        console.log("Validator node %s removed", validatorNode);
        console.log("New minimum threshold: %s", newMinimumThreshold);
        console.log("Vision forwarder paused: %s", visionForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
