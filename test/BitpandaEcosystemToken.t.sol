// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {console2} from "forge-std/console2.sol";

import {IVisionToken} from "../src/interfaces/IVisionToken.sol";
import {VisionBaseToken} from "../src/VisionBaseToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";

import {VisionBaseTokenTest} from "./VisionBaseToken.t.sol";

contract BitpandaEcosystemTokenTest is VisionBaseTokenTest {
    BitpandaEcosystemTokenHarness bestToken;

    function setUp() public {
        accessController = deployAccessController();
        bestToken = new BitpandaEcosystemTokenHarness(
            INITIAL_SUPPLY_BEST,
            address(accessController)
        );
    }

    function test_SetUpState() external view {
        assertEq(bestToken.balanceOf(SUPER_CRITICAL_OPS), INITIAL_SUPPLY_BEST);
        assertTrue(bestToken.paused());
        assertEq(bestToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_pause_AfterInitialization() external {
        initializeToken();

        vm.prank(PAUSER);
        bestToken.pause();

        assertTrue(bestToken.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        whenNotPausedTest(address(bestToken), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        onlyRoleTest(address(bestToken), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializeToken();

        assertFalse(bestToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.unpause.selector
        );

        whenPausedTest(address(bestToken), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.unpause.selector
        );

        onlyRoleTest(address(bestToken), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked(
                "BitpandaEcosystemToken: VisionForwarder has not been set"
            )
        );

        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.unpause();
    }

    function test_setVisionForwarder() external {
        initializeToken();

        assertEq(bestToken.getVisionForwarder(), VISION_FORWARDER_ADDRESS);
    }

    function test_setVisionForwarder_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        whenPausedTest(address(bestToken), calldata_);
    }

    function test_setVisionForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(bestToken), calldata_);
    }

    function test_decimals() external view {
        assertEq(8, bestToken.decimals());
    }

    function test_symbol() external view {
        assertEq("BEST", bestToken.symbol());
    }

    function test_name() external view {
        assertEq("Bitpanda Ecosystem Token", bestToken.name());
    }

    function test_getOwner() external view {
        assertEq(token().getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_renounceOwnership() external {
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.renounceOwnership();

        assertEq(bestToken.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.expectRevert(
            abi.encodePacked(
                "BitpandaEcosystemToken: ownership cannot be transferred"
            )
        );
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.transferOwnership(address(1));

        assertEq(bestToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_unsetVisionForwarder() external {
        initializeToken();
        vm.expectEmit();
        emit IVisionToken.VisionForwarderUnset();

        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.exposed_unsetVisionForwarder();

        assertEq(bestToken.getVisionForwarder(), ADDRESS_ZERO);
    }

    function initializeToken() public override {
        vm.startPrank(SUPER_CRITICAL_OPS);
        bestToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bestToken.unpause();
        vm.stopPrank();
    }

    function token() public view override returns (VisionBaseToken) {
        return bestToken;
    }

    function tokenRevertMsgPrefix()
        public
        pure
        override
        returns (string memory)
    {
        return "BitpandaEcosystemToken:";
    }
}

contract BitpandaEcosystemTokenHarness is BitpandaEcosystemToken {
    constructor(
        uint256 initialSupply,
        address accessController
    ) BitpandaEcosystemToken(initialSupply, accessController) {}

    function exposed_unsetVisionForwarder() external {
        _unsetVisionForwarder();
    }
}
