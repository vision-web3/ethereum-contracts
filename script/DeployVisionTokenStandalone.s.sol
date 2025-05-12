// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {VisionToken} from "../src/VisionToken.sol";
import {VisionForwarder} from "../src/VisionForwarder.sol";

import {VisionTokenDeployer} from "./helpers/VisionTokenDeployer.s.sol";
import {Constants} from "./helpers/Constants.s.sol";

contract DeployVisionTokenStandalone is VisionTokenDeployer {
    function deploy(
        uint256 vsnSupply,
        address defaultAdmin,
        address criticalOps,
        address minter,
        address pauser,
        address upgrader
    ) public {
        vm.startBroadcast();
        deployVisionToken(
            vsnSupply,
            defaultAdmin,
            criticalOps,
            minter,
            pauser,
            upgrader
        );
        vm.stopBroadcast();
    }

    function pause(address visionTokenAddress) public {
        VisionToken visionToken = VisionToken(visionTokenAddress);
        vm.startBroadcast();
        visionToken.pause();
        vm.stopBroadcast();
    }

    function setBridge(
        address visionTokenAddress,
        address visionForwarderAddress
    ) public {
        VisionForwarder visionForwarder = VisionForwarder(
            visionForwarderAddress
        );
        VisionToken visionToken = VisionToken(visionTokenAddress);

        vm.startBroadcast();
        setBridgeAtVisionToken(visionToken, visionForwarder);
        vm.stopBroadcast();
    }
}
