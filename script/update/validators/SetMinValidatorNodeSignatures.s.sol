// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {VisionForwarder} from "../../../src/VisionForwarder.sol";

import {VisionBaseAddresses} from "./../../helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title SetMinValidatorNodeSignatures
 *
 * @notice Set the minimum number of required validator node signatures.
 *
 * @dev Usage
 * forge script ./script/update/parameters/SetMinValidatorNodeSignatures.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(uint256)" <newMinimumThreshold>
 */
contract SetMinValidatorNodeSignatures is VisionBaseAddresses, SafeAddresses {
    AccessController accessController;
    VisionForwarder public visionForwarder;

    function roleActions(uint256 newMinimumThreshold) public {
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
        uint256 oldThreshold = visionForwarder
            .getMinimumValidatorNodeSignatures();
        require(
            oldThreshold != newMinimumThreshold,
            "New threshold is the same as the old one"
        );
        address[] memory validatorNodes = visionForwarder.getValidatorNodes();
        require(
            newMinimumThreshold <= validatorNodes.length,
            "New threshold is higher than the number of validator nodes"
        );

        vm.broadcast(accessController.pauser());
        visionForwarder.pause();
        console.log("Vision forwarder paused: %s", visionForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        visionForwarder.setMinimumValidatorNodeSignatures(newMinimumThreshold);
        visionForwarder.unpause();
        console.log(
            "Minimum validator node signatures set to %s, old value was %s",
            newMinimumThreshold,
            oldThreshold
        );
        console.log("Vision forwarder paused: %s", visionForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
