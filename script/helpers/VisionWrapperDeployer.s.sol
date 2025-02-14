// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {VisionWrapper} from "../../src/VisionWrapper.sol";
import {VisionAvaxWrapper} from "../../src/wrappers/VisionAvaxWrapper.sol";
import {VisionBnbWrapper} from "../../src/wrappers/VisionBnbWrapper.sol";
import {VisionCeloWrapper} from "../../src/wrappers/VisionCeloWrapper.sol";
import {VisionCronosWrapper} from "../../src/wrappers/VisionCronosWrapper.sol";
import {VisionEtherWrapper} from "../../src/wrappers/VisionEtherWrapper.sol";
import {VisionPolWrapper} from "../../src/wrappers/VisionPolWrapper.sol";
import {VisionSWrapper} from "../../src/wrappers/VisionSWrapper.sol";

import {VisionBaseScript} from "./VisionBaseScript.s.sol";

abstract contract VisionWrapperDeployer is VisionBaseScript {
    function deployCoinWrappers(
        AccessController accessController
    ) public returns (VisionWrapper[] memory) {
        VisionWrapper[] memory visionWrappers = new VisionWrapper[](7);
        Blockchain memory blockchain = determineBlockchain();

        bool native = blockchain.blockchainId == BlockchainId.AVALANCHE;
        visionWrappers[0] = new VisionAvaxWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.BNB_CHAIN;
        visionWrappers[1] = new VisionBnbWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.CELO;
        visionWrappers[2] = new VisionCeloWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.CRONOS;
        visionWrappers[3] = new VisionCronosWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.ETHEREUM;
        visionWrappers[4] = new VisionEtherWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.SONIC;
        visionWrappers[5] = new VisionSWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.POLYGON;
        visionWrappers[6] = new VisionPolWrapper(
            native,
            address(accessController)
        );

        console2.log("All %s wrappers deployed", visionWrappers.length);

        return visionWrappers;
    }

    function initializeVisionWrappers(
        IVisionHub visionHubProxy,
        VisionForwarder visionForwarder,
        VisionWrapper[] memory visionWrappers
    ) public {
        for (uint256 i; i < visionWrappers.length; i++) {
            visionWrappers[i].setVisionForwarder(address(visionForwarder));

            visionHubProxy.registerToken(address(visionWrappers[i]));
            visionWrappers[i].unpause();
            console2.log(
                "%s initialized; paused=%s",
                visionWrappers[i].name(),
                visionWrappers[i].paused()
            );
        }
    }
}
