// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
import {VisionToken} from "../src/VisionToken.sol";
import {VisionForwarder} from "../src/VisionForwarder.sol";

import {VisionTokenDeployer} from "./helpers/VisionTokenDeployer.s.sol";
import {Constants} from "./helpers/Constants.s.sol";

/**
 * @title VisionTokenStandalone
 *
 * @notice Deploy and manage the VisionToken and related components in a standalone setup.
 * This script is intended for deploying VisionToken in isolated environments or chains where
 * a full Vision protocol stack is not required or not yet deployed.
 *
 * @dev Usage
 *
 * 1. Deploy VisionToken with role assignments
 *    Deploys a new instance of VisionToken with the specified total supply and assigns roles:
 *    - defaultAdmin
 *    - criticalOps
 *    - minter
 *    - pauser
 *    - upgrader
 *
 * forge script ./script/VisionTokenStandalone.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(uint256,address,address,address,address,address)" \
 *     <vsnSupply> <defaultAdmin> <criticalOps> <minter> <pauser> <upgrader>
 *
 * 2. Pause VisionToken (requires `pauser` role)
 *
 * forge script ./script/VisionTokenStandalone.s.sol --rpc-url <rpc alias> \
 *     -vvvv --sig "pause(address)" <visionTokenAddress>
 *
 * 3. Set VisionForwarder address on VisionToken (requires `criticalOps` role)
 *
 * forge script ./script/VisionTokenStandalone.s.sol --rpc-url <rpc alias> \
 *     -vvvv --sig "setVisionForwarder(address,address)" \
 *     <visionTokenAddress> <visionForwarderAddress>
 *
 * 4. Register VisionToken with VisionHub (requires `criticalOps` role)
 *
 * forge script ./script/VisionTokenStandalone.s.sol --rpc-url <rpc alias> \
 *     -vvvv --sig "registerTokenAtVisionHub(address,address)" \
 *     <visionTokenAddress> <visionHubAddress>
 *
 * 5. Deploy new VisionToken logic contract (any account)
 *    Deploys a fresh VisionToken logic contract and writes the address to [chain]-VSN-NEW.json.
 *
 * forge script ./script/VisionTokenStandalone.s.sol --rpc-url <rpc alias> \
 *     --sender <sender> --sig "deployNewVisionTokenLogic()"
 *
 * 6. Upgrade VisionToken proxy to new logic (requires `upgrader` role)
 *    Use this to upgrade the existing proxy to a new implementation.
 *
 * forge script ./script/VisionTokenStandalone.s.sol --rpc-url <rpc alias> \
 *     -vvvv --sig "upgradeToAndCallVisionToken(address,address)" \
 *     <proxyAddress> <newLogicAddress>
 *
 */

contract VisionTokenStandalone is VisionTokenDeployer {
    function deploy(
        uint256 vsnSupply,
        address defaultAdmin,
        address criticalOps,
        address minter,
        address pauser,
        address upgrader
    ) public {
        vm.startBroadcast();
        VisionToken visionToken = deployVisionToken(
            vsnSupply,
            defaultAdmin,
            criticalOps,
            minter,
            pauser,
            upgrader
        );
        vm.stopBroadcast();

        // Store the contract address at [blockchain]_VSN.json
        string memory data;
        data = vm.serializeAddress(data, "vsn", address(visionToken));
        vm.writeJson(
            data,
            string.concat(determineBlockchain().name, "-VSN.json")
        );
    }

    // can be done by pauser account of vision Token
    function pause(address visionTokenAddress) public {
        VisionToken visionToken = VisionToken(visionTokenAddress);
        vm.startBroadcast();
        visionToken.pause();
        vm.stopBroadcast();
    }

    // can be done by criticalOps account of vision Token
    function setVisionForwarder(
        address visionTokenAddress,
        address visionForwarderAddress
    ) public {
        VisionForwarder visionForwarder = VisionForwarder(
            visionForwarderAddress
        );
        VisionToken visionToken = VisionToken(visionTokenAddress);

        vm.startBroadcast();
        setVisionForwarderAtVisionToken(visionToken, visionForwarder);
        vm.stopBroadcast();
    }

    // can be done by criticalOps account of vision Token
    function registerTokenAtVisionHub(
        address visionTokenAddress,
        address visionHubAddress
    ) public {
        IVisionHub visionHub = IVisionHub(visionHubAddress);
        VisionToken visionToken = VisionToken(visionTokenAddress);

        vm.startBroadcast();
        registerVisionTokenAtVisionHub(visionToken, visionHub);
        vm.stopBroadcast();
    }

    // can be called by any gas paying account
    function deployNewVisionTokenLogic() public {
        vm.startBroadcast();
        VisionToken logic = new VisionToken();
        vm.stopBroadcast();

        // Store the contract address at [blockchain]_VSN.json
        string memory data;
        data = vm.serializeAddress(data, "vsn-logic", address(logic));
        vm.writeJson(
            data,
            string.concat(determineBlockchain().name, "-VSN-NEW.json")
        );
    }

    // can be done by upgrader account of vision Token
    function upgradeToAndCallVisionToken(
        address proxyAddress,
        address newLogicAddress
    ) public {
        VisionToken proxy = VisionToken(proxyAddress);
        VisionToken newLogic = VisionToken(newLogicAddress);

        // Prepare the call data for initializing new functionality if needed
        bytes memory data = ""; // If no new storage added, this is not needed

        // Perform the upgrade and call
        vm.startBroadcast();
        proxy.upgradeToAndCall(address(newLogic), data);
        vm.stopBroadcast();
    }
}
