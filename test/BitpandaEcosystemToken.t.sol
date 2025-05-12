// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {console2} from "forge-std/console2.sol";

import {AccessController} from "../src/access/AccessController.sol";
import {IVisionToken} from "../src/interfaces/IVisionToken.sol";
import {VisionBaseTokenUpgradeable} from "../src/VisionBaseTokenUpgradeable.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";

import {VisionBaseTokenTest} from "./VisionBaseToken.t.sol";

contract BitpandaEcosystemTokenTest is VisionBaseTokenTest {
    BitpandaEcosystemTokenHarness bestToken;
    AccessController public accessController;

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
        setBridgeAtToken();

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
        setBridgeAtToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        onlyRoleTest(address(bestToken), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        setBridgeAtToken();

        assertFalse(bestToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        setBridgeAtToken();
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
        setBridgeAtToken();

        assertEq(bestToken.getVisionForwarder(), VISION_FORWARDER_ADDRESS);
    }

    function test_setVisionForwarder_WhenNotpaused() external {
        setBridgeAtToken();
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
        setBridgeAtToken();
        vm.expectEmit();
        emit IVisionToken.VisionForwarderUnset();

        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.exposed_unsetVisionForwarder();

        assertEq(bestToken.getVisionForwarder(), ADDRESS_ZERO);
    }

    function test_supportsInterface() external virtual override {
        setBridgeAtToken();
        assert(token().supportsInterface(bytes4(0x01ffc9a7)));
        assert(token().supportsInterface(type(IVisionToken).interfaceId));
        assert(!token().supportsInterface(0xffffffff));
    }

    function setBridgeAtToken() public override {
        vm.startPrank(SUPER_CRITICAL_OPS);
        bestToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bestToken.unpause();
        vm.stopPrank();
    }

    function token() public view override returns (IVisionToken) {
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
