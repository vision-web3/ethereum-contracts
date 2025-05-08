// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {Constants} from "./Constants.s.sol";
import {VisionBaseScript} from "./VisionBaseScript.s.sol";

abstract contract VisionTokenDeployer is VisionBaseScript {
    function deployVisionToken(
        uint256 initialSupply,
        AccessController accessController
    ) public returns (VisionToken) {
        VisionToken visionToken = new VisionToken(
            initialSupply,
            address(0), // FIXME
            address(0),
            address(0),
            address(0)
        );
        console2.log(
            "%s deployed; paused=%s; address=%s",
            visionToken.name(),
            visionToken.paused(),
            address(visionToken)
        );
        return visionToken;
    }

    function initializeVisionToken(
        VisionToken visionToken,
        VisionForwarder visionForwarder
    ) public {
        visionToken.setVisionForwarder(address(visionForwarder));
        visionToken.unpause();
        console2.log(
            "%s initialized;  paused=%s",
            visionToken.name(),
            visionToken.paused()
        );
    }
}
