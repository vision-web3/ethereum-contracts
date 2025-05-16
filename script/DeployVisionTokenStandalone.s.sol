// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
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
        VisionToken token = deployVisionToken(
            vsnSupply,
            defaultAdmin,
            criticalOps,
            minter,
            pauser,
            upgrader
        );
        vm.stopBroadcast();

        //TODO: Store the contract address somewhere 

    }

    // can be done by pauser account of vision Token
    function pause(address visionTokenAddress) public {
        VisionToken visionToken = VisionToken(visionTokenAddress);
        vm.startBroadcast();
        visionToken.pause();
        vm.stopBroadcast();
    }

    // can be done by criticalOps account of vision Token
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

    // can be done by criticalOps account of vision Token
    function registerToken(
        address visionTokenAddress,
        address visionHubAddress
    ) public {
        IVisionHub visionHub = IVisionHub(visionHubAddress);
        VisionToken visionToken = VisionToken(visionTokenAddress);

        vm.startBroadcast();
        registerTokenAtVisionHub(visionToken, visionHub);
        vm.stopBroadcast();
    }
}
