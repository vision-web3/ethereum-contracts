// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {BitpandaEcosystemToken} from "../../src/BitpandaEcosystemToken.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {VisionBaseScript} from "./VisionBaseScript.s.sol";

abstract contract BitpandaEcosystemTokenDeployer is VisionBaseScript {
    function deployBitpandaEcosystemToken(
        uint256 initialSupply,
        AccessController accessController
    ) public returns (BitpandaEcosystemToken) {
        BitpandaEcosystemToken bitpandaEcosystemToken = new BitpandaEcosystemToken(
                initialSupply,
                address(accessController)
            );
        console2.log(
            "%s deployed; paused=%s; address=%s",
            bitpandaEcosystemToken.name(),
            bitpandaEcosystemToken.paused(),
            address(bitpandaEcosystemToken)
        );
        return bitpandaEcosystemToken;
    }

    function initializeBitpandaEcosystemToken(
        BitpandaEcosystemToken bitpandaEcosystemToken,
        IVisionHub visionHubProxy,
        VisionForwarder visionForwarder
    ) public {
        bitpandaEcosystemToken.setVisionForwarder(address(visionForwarder));

        // Register token at Vision hub
        visionHubProxy.registerToken(address(bitpandaEcosystemToken));

        bitpandaEcosystemToken.unpause();

        console2.log(
            "%s initialized; paused=%s",
            bitpandaEcosystemToken.name(),
            bitpandaEcosystemToken.paused()
        );
    }
}
