// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {console2} from "forge-std/console2.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {IVisionToken} from "../src/interfaces/IVisionToken.sol";
import {VisionBaseToken} from "../src/VisionBaseToken.sol";
import {VisionToken} from "../src/VisionToken.sol";

import {VisionBaseTokenTest} from "./VisionBaseToken.t.sol";

contract VisionTokenTest is VisionBaseTokenTest {
    VisionTokenHarness public visionToken;

    function setUp() public {
        accessController = deployAccessController();
        visionToken = new VisionTokenHarness(
            INITIAL_SUPPLY_VSN,
            address(accessController)
        );
    }

    function test_SetUpState() external view {
        assertEq(
            visionToken.balanceOf(SUPER_CRITICAL_OPS),
            INITIAL_SUPPLY_VSN
        );
        assertTrue(visionToken.paused());
        assertEq(visionToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_pause_AfterInitialization() external {
        initializeToken();

        vm.prank(PAUSER);
        visionToken.pause();

        assertTrue(visionToken.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.pause.selector
        );

        whenNotPausedTest(address(visionToken), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.pause.selector
        );

        onlyRoleTest(address(visionToken), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializeToken();

        assertFalse(visionToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.unpause.selector
        );

        whenPausedTest(address(visionToken), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.unpause.selector
        );

        onlyRoleTest(address(visionToken), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("VisionToken: VisionForwarder has not been set")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionToken.unpause();
    }

    function test_setVisionForwarder() external {
        initializeToken();

        assertEq(visionToken.getVisionForwarder(), VISION_FORWARDER_ADDRESS);
    }

    function test_setVisionForwarder_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        whenPausedTest(address(visionToken), calldata_);
    }

    function test_setVisionForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(visionToken), calldata_);
    }

    function test_decimals() external view {
        assertEq(8, visionToken.decimals());
    }

    function test_symbol() external view {
        assertEq("VSN", visionToken.symbol());
    }

    function test_name() external view {
        assertEq("Vision", visionToken.name());
    }

    function test_getOwner() external view {
        assertEq(token().getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_renounceOwnership() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionToken.renounceOwnership();

        assertEq(visionToken.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.expectRevert(
            abi.encodePacked("VisionToken: ownership cannot be transferred")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionToken.transferOwnership(address(1));

        assertEq(visionToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_unsetVisionForwarder() external {
        initializeToken();
        vm.expectEmit();
        emit IVisionToken.VisionForwarderUnset();

        vm.prank(SUPER_CRITICAL_OPS);
        visionToken.exposed_unsetVisionForwarder();

        assertEq(visionToken.getVisionForwarder(), ADDRESS_ZERO);
    }

    function test_supportsInterface() external override {
        initializeToken();
        bytes4[6] memory interfaceIds = [
            bytes4(0x01ffc9a7),
            type(IVisionToken).interfaceId,
            type(ERC20).interfaceId,
            type(Ownable).interfaceId,
            type(ERC20Capped).interfaceId,
            type(ERC20Pausable).interfaceId
        ];
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            bytes4 interfaceId = interfaceIds[i];
            assert(token().supportsInterface(interfaceId));
        }

        assert(!token().supportsInterface(0xffffffff));
    }

    function initializeToken() public override {
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionToken.unpause();
        vm.stopPrank();
    }

    function token() public view override returns (VisionBaseToken) {
        return visionToken;
    }

    function tokenRevertMsgPrefix()
        public
        pure
        override
        returns (string memory)
    {
        return "VisionToken:";
    }
}

contract VisionTokenHarness is VisionToken {
    constructor(
        uint256 initialSupply,
        address accessController
    )
        VisionToken(
            initialSupply,
            address(0),
            address(0),
            address(0),
            address(0)
        )
    {}

    function exposed_unsetVisionForwarder() external {
        _unsetVisionForwarder();
    }
}
