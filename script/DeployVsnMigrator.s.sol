// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VisionToken} from "../src/VisionToken.sol";
import {AccessController} from "../src/access/AccessController.sol";
import {VisionTokenMigrator} from "../src/VisionTokenMigrator.sol";

import {VisionTokenMigratorDeployer} from "./helpers/VisionTokenMigratorDeployer.s.sol";
import {VisionTokenDeployer} from "./helpers/VisionTokenDeployer.s.sol";
import {AccessControllerDeployer} from "./helpers/AccessControllerDeployer.s.sol";
import {VisionBaseAddresses} from "./helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

/**
 * @title Deploy VSN migrator
 *
 * @notice Deploy the VSN migrator along with its dependencies:
 *     The VSN token and the Access Controller.
 *
 * @dev Usage
 * Deploy by any gas paying account:
 * forge script ./script/DeployVsnMigrator.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(address)" <oldTokenAddress>
 */
contract DeployVsnMigrator is
    VisionBaseAddresses,
    SafeAddresses,
    AccessControllerDeployer,
    VisionTokenDeployer,
    VisionTokenMigratorDeployer
{
    AccessController accessController;
    VisionToken visionToken;
    VisionTokenMigrator visionTokenMigrator;

    function deploy(address oldTokenAddress) public {
        vm.startBroadcast();
        readRoleAddresses();
        address pauser = getRoleAddress(Role.PAUSER);
        address deployer = getRoleAddress(Role.DEPLOYER);
        address mediumCriticalOps = getRoleAddress(Role.MEDIUM_CRITICAL_OPS);
        address superCriticalOps = getRoleAddress(Role.SUPER_CRITICAL_OPS);
        accessController = deployAccessController(
            pauser,
            deployer,
            mediumCriticalOps,
            superCriticalOps
        );
        visionToken = deployVisionToken(
            IERC20(oldTokenAddress).totalSupply(),
            superCriticalOps,
            superCriticalOps,
            superCriticalOps,
            superCriticalOps,
            superCriticalOps
        );
        visionTokenMigrator = deployVisionTokenMigrator(
            oldTokenAddress,
            address(visionToken)
        );
        vm.stopBroadcast();

        exportAllContractAddresses();
    }

    function exportAllContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](3);
        contractAddresses[0] = ContractAddress(
            Contract.ACCESS_CONTROLLER,
            address(accessController)
        );
        contractAddresses[1] = ContractAddress(
            Contract.VSN,
            address(visionToken)
        );
        contractAddresses[2] = ContractAddress(
            Contract.VSN_MIGRATOR,
            address(visionTokenMigrator)
        );
        exportContractAddresses(contractAddresses, false);
    }
}
