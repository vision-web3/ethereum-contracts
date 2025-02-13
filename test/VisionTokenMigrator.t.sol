// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

import {VisionTokenMigrator} from "../src/VisionTokenMigrator.sol";

import {VisionBaseTest} from "./VisionBaseTest.t.sol";

contract VisionTokenMigratorTest is VisionBaseTest {
    VisionTokenMigrator visionTokenMigrator;
    address constant OLD_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("OldTokenAddress"))));
    address constant NEW_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("NewTokenAddress"))));

    function setUp() public {
        mockIerc20_totalSupply(OLD_TOKEN_ADDRESS, INITIAL_SUPPLY_VSN);
        mockIerc20_totalSupply(NEW_TOKEN_ADDRESS, INITIAL_SUPPLY_VSN);
        visionTokenMigrator = new VisionTokenMigrator(
            OLD_TOKEN_ADDRESS,
            NEW_TOKEN_ADDRESS
        );
    }

    function test_startTokenMigration() external {
        mockIerc20_transferFrom(
            NEW_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenMigrator),
            INITIAL_SUPPLY_VSN,
            true
        );
        vm.expectEmit();
        emit VisionTokenMigrator.TokenMigrationStarted();
        vm.expectCall(
            OLD_TOKEN_ADDRESS,
            abi.encodeWithSelector(IERC20.totalSupply.selector)
        );
        vm.expectCall(
            NEW_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                deployer(),
                address(visionTokenMigrator),
                INITIAL_SUPPLY_VSN
            )
        );

        visionTokenMigrator.startTokenMigration();

        assertTrue(visionTokenMigrator.isTokenMigrationStarted());
    }

    function test_startTokenMigration_WhenMigrationAlreadyStarted() external {
        startMigration();
        vm.expectRevert(
            "VisionTokenMigrator: token migration already started"
        );

        visionTokenMigrator.startTokenMigration();
    }

    function test_migrateTokens() external {
        startMigration();
        uint256 AMOUNT_TO_MIGRATE = 1_000;
        mockIerc20_balanceOf(OLD_TOKEN_ADDRESS, deployer(), AMOUNT_TO_MIGRATE);
        mockIerc20_transferFrom(
            OLD_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenMigrator),
            AMOUNT_TO_MIGRATE,
            true
        );
        mockIerc20_transfer(
            NEW_TOKEN_ADDRESS,
            deployer(),
            AMOUNT_TO_MIGRATE,
            true
        );
        vm.expectEmit();
        emit VisionTokenMigrator.TokensMigrated(deployer(), AMOUNT_TO_MIGRATE);
        vm.expectCall(
            OLD_TOKEN_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, deployer())
        );
        vm.expectCall(
            OLD_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                deployer(),
                address(visionTokenMigrator),
                AMOUNT_TO_MIGRATE
            )
        );
        vm.expectCall(
            NEW_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                deployer(),
                AMOUNT_TO_MIGRATE
            )
        );

        (bool success, ) = address(visionTokenMigrator).call(
            abi.encodeWithSelector(VisionTokenMigrator.migrateTokens.selector)
        );

        assertTrue(success);
    }

    function test_migrateTokens_WhenMigrationNotYetStarted() external {
        vm.expectRevert(
            "VisionTokenMigrator: token migration not yet started"
        );

        visionTokenMigrator.migrateTokens();
    }

    function test_migrateTokens_WhenSenderDoesNotOwnAnyOldTokens() external {
        startMigration();
        mockIerc20_balanceOf(OLD_TOKEN_ADDRESS, deployer(), 0);
        vm.expectRevert("VisionTokenMigrator: sender does not own any tokens");

        visionTokenMigrator.migrateTokens();
    }

    function test_getOldTokenAddress() external view {
        assertEq(visionTokenMigrator.getOldTokenAddress(), OLD_TOKEN_ADDRESS);
    }

    function test_getNewTokenAddress() external view {
        assertEq(visionTokenMigrator.getNewTokenAddress(), NEW_TOKEN_ADDRESS);
    }

    function test_isTokenMigrationStarted_AfterDeploy() external view {
        assertFalse(visionTokenMigrator.isTokenMigrationStarted());
    }

    function test_isTokenMigrationStarted_WhenStarted() external {
        startMigration();

        assertTrue(visionTokenMigrator.isTokenMigrationStarted());
    }

    function startMigration() public {
        mockIerc20_transferFrom(
            NEW_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenMigrator),
            INITIAL_SUPPLY_VSN,
            true
        );
        visionTokenMigrator.startTokenMigration();
    }
}
