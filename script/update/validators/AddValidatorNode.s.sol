// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {VisionForwarder} from "../../../src/VisionForwarder.sol";

import {VisionBaseAddresses} from "./../../helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title AddValidatorNode
 *
 * @notice Add a validator node to the Vision Forwarder.
 *
 * @dev Usage
 * 1. Add a new validator node
 * forge script ./script/update/validators/AddValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address)" <newValidatorNode>
 * 2. Add a new validator node and change the minimum threshold of validator nodes.
 * forge script ./script/update/validators/AddValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,uint256)" <newValidatorNode> <newMinimumThreshold>
 */
contract AddValidatorNode is VisionBaseAddresses, SafeAddresses {
    AccessController accessController;
    VisionForwarder public visionForwarder;

    function roleActions(address newValidatorNode) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        visionForwarder = VisionForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );

        address[] memory validatorNodes = visionForwarder.getValidatorNodes();
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            require(
                validatorNodes[i] != newValidatorNode,
                "Validator node already exists"
            );
        }
        vm.broadcast(accessController.pauser());
        visionForwarder.pause();
        console.log("Vision forwarder paused: %s", visionForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        visionForwarder.addValidatorNode(newValidatorNode);
        visionForwarder.unpause();
        console.log("Validator node %s added", newValidatorNode);
        console.log("Vision forwarder paused: %s", visionForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }

    function roleActions(
        address newValidatorNode,
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
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            require(
                validatorNodes[i] != newValidatorNode,
                "Validator node already exists"
            );
        }
        vm.broadcast(accessController.pauser());
        visionForwarder.pause();
        console.log("Vision forwarder paused: %s", visionForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        visionForwarder.setMinimumValidatorNodeSignatures(newMinimumThreshold);
        visionForwarder.addValidatorNode(newValidatorNode);
        visionForwarder.unpause();
        console.log("Validator node %s added", newValidatorNode);
        console.log("New minimum threshold: %s", newMinimumThreshold);
        console.log("Vision forwarder paused: %s", visionForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
