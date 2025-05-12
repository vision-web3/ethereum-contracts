// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {Constants} from "./Constants.s.sol";
import {VisionBaseScript} from "./VisionBaseScript.s.sol";

abstract contract VisionTokenDeployer is VisionBaseScript {
    function deployVisionToken(
        uint256 initialSupply,
        address defaultAdmin,
        address criticalOps,
        address minter,
        address pauser,
        address upgrader
    ) public returns (VisionToken) {
        // Step 1: Deploy the VisionToken implementation contract
        VisionToken logic = new VisionToken();

        // Step 2: Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            VisionToken.initialize.selector,
            initialSupply,
            defaultAdmin,
            criticalOps,
            minter,
            pauser,
            upgrader
        );

        // Step 3: Deploy the UUPS Proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);

        // wrap proxy into VisionToken for easy access
        VisionToken visionToken = VisionToken(address(proxy));

        console.log(
            "%s deployed; paused=%s; address=%s",
            visionToken.name(),
            visionToken.paused(),
            address(visionToken)
        );
        return visionToken;
    }

    function setBridgeAtVisionToken(
        VisionToken visionToken,
        VisionForwarder visionForwarder
    ) public {
        visionToken.setVisionForwarder(address(visionForwarder));
        visionToken.unpause();
        console.log(
            "Token=%s; Bridge=%s; paused=%s",
            visionToken.name(),
            visionToken.getVisionForwarder(),
            visionToken.paused()
        );
    }
}
