// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {Constants} from "./Constants.s.sol";
import {VisionBaseScript} from "./VisionBaseScript.s.sol";

abstract contract VisionForwarderDeployer is VisionBaseScript {
    function deployVisionForwarder(
        AccessController accessController
    ) public returns (VisionForwarder) {
        VisionForwarder visionForwarder = new VisionForwarder(
            Constants.MAJOR_PROTOCOL_VERSION,
            address(accessController)
        );
        console.log(
            "VisionForwarder deployed; paused=%s; address=%s; "
            "accessController=%s",
            visionForwarder.paused(),
            address(visionForwarder),
            address(accessController)
        );
        return visionForwarder;
    }

    function initializeVisionForwarder(
        VisionForwarder visionForwarder,
        IVisionHub visionHubProxy,
        VisionToken visionToken,
        uint256 minimumValidatorNodeSignatures,
        address[] memory validatorNodeAddresses
    ) public {
        // Set the hub, PAN token, and validator node addresses
        visionForwarder.setVisionHub(address(visionHubProxy));
        console.log(
            "VisionForwarder.setVisionHub(%s)",
            address(visionHubProxy)
        );

        visionForwarder.setVisionToken(address(visionToken));
        console.log(
            "VisionForwarder.setVisionToken(%s)",
            address(visionToken)
        );

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            visionForwarder.addValidatorNode(validatorNodeAddresses[i]);
            console.log(
                "VisionForwarder.addValidatorNode(%s)",
                validatorNodeAddresses[i]
            );
        }

        visionForwarder.setMinimumValidatorNodeSignatures(
            minimumValidatorNodeSignatures
        );
        console.log(
            "VisionForwarder.setMinimumValidatorNodeSignatures(%s)",
            vm.toString(minimumValidatorNodeSignatures)
        );

        // Unpause the forwarder contract after initialization
        visionForwarder.unpause();

        console.log(
            "VisionForwarder initialized; paused=%s",
            visionForwarder.paused()
        );
    }

    function pauseForwarder(VisionForwarder visionForwarder) public {
        if (!visionForwarder.paused()) {
            visionForwarder.pause();
            console.log(
                "VisionForwarder(%s): paused=%s",
                address(visionForwarder),
                visionForwarder.paused()
            );
        }
    }
}
