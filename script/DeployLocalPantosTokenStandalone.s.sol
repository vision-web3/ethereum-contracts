// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {VisionToken} from "../src/VisionToken.sol";
import {VisionForwarder} from "../src/VisionForwarder.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionTokenDeployer} from "./helpers/VisionTokenDeployer.s.sol";
import {Constants} from "./helpers/Constants.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

contract DeployLocalVisionTokenStandalone is
    VisionTokenDeployer,
    SafeAddresses
{
    function deploy(address accessControllerAddress) public {
        vm.startBroadcast();
        deployVisionToken(
            Constants.INITIAL_SUPPLY_VSN,
            AccessController(accessControllerAddress)
        );
        vm.stopBroadcast();
    }

    function roleActions(
        address accessControllerAddress,
        address visionTokenAddress,
        address visionForwarderAddress
    ) external {
        AccessController accessController = AccessController(
            accessControllerAddress
        );
        VisionForwarder visionForwarder = VisionForwarder(
            visionForwarderAddress
        );
        VisionToken visionToken = VisionToken(visionTokenAddress);

        vm.startBroadcast(accessController.superCriticalOps());
        initializeVisionToken(visionToken, visionForwarder);
        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
