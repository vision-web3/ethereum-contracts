// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {VisionTokenMigrator} from "../../src/VisionTokenMigrator.sol";

contract VisionTokenMigratorDeployer {
    function deployVisionTokenMigrator(
        address oldTokenAddress,
        address newTokenAddress
    ) public returns (VisionTokenMigrator) {
        VisionTokenMigrator visionTokenMigrator = new VisionTokenMigrator(
            oldTokenAddress,
            newTokenAddress
        );
        return visionTokenMigrator;
    }
}
