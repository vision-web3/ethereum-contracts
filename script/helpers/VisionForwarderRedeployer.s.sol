// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {VisionWrapper} from "../../src/VisionWrapper.sol";
import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {VisionForwarderDeployer} from "../helpers/VisionForwarderDeployer.s.sol";

interface IOldVisionForwarder {
    function getVisionValidator() external returns (address);
}

abstract contract VisionForwarderRedeployer is VisionForwarderDeployer {
    function tryGetMinimumValidatorNodeSignatures(
        VisionForwarder oldForwarder
    ) public view returns (uint256) {
        uint256 minimumValidatorNodeSignatures;
        try oldForwarder.getMinimumValidatorNodeSignatures() returns (
            uint256 result
        ) {
            minimumValidatorNodeSignatures = result;
        } catch {
            console.log(
                "Method getMinimumValidatorNodeSignatures() not available"
            );
            minimumValidatorNodeSignatures = 1;
        }
        return minimumValidatorNodeSignatures;
    }

    function tryGetValidatorNodes(
        VisionForwarder oldForwarder
    ) public returns (address[] memory) {
        address[] memory validatorNodeAddresses;
        // Trying to call newly added function.
        // If it is not available, catch block will try older version
        try oldForwarder.getValidatorNodes() returns (
            address[] memory result
        ) {
            validatorNodeAddresses = result;
        } catch {
            // delete catch block if all envs updated with new contract
            console.log(
                "Failed to find new method getValidatorNodes(); "
                "will try old method getVisionValidator()"
            );
            validatorNodeAddresses = new address[](1);
            validatorNodeAddresses[0] = IOldVisionForwarder(
                address(oldForwarder)
            ).getVisionValidator();
        }
        return validatorNodeAddresses;
    }

    function migrateForwarderAtHub(
        VisionForwarder visionForwarder,
        IVisionHub visionHub
    ) public {
        require(
            visionHub.paused(),
            "VisionHub should be paused before migrateForwarderAtHub"
        );
        visionHub.setVisionForwarder(address(visionForwarder));
        visionHub.unpause();
        console.log(
            "VisionHub setVisionForwarder(%s); paused=%s",
            address(visionForwarder),
            visionHub.paused()
        );
    }
}
