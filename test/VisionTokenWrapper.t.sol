// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {console2} from "forge-std/console2.sol";

import {IVisionToken} from "../src/interfaces/IVisionToken.sol";
import {IVisionWrapper} from "../src/interfaces/IVisionWrapper.sol";
import {VisionWrapper} from "../src/VisionWrapper.sol";
import {VisionTokenWrapper} from "../src/VisionTokenWrapper.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionBaseTest} from "./VisionBaseTest.t.sol";

contract VisionTokenWrapperTest is VisionBaseTest {
    VisionTokenWrapperHarness visionTokenWrapper;
    string constant NAME = "test token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;
    uint256 constant WRAPPED_AMOUNT = 1000;
    address constant WRAPPED_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("wrappedTokenAddress"))));
    address constant VISION_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("VisionForwarderAddress"))));

    AccessController public accessController;

    function setUp() public {
        accessController = deployAccessController();
        visionTokenWrapper = new VisionTokenWrapperHarness(
            NAME,
            SYMBOL,
            DECIMALS,
            WRAPPED_TOKEN_ADDRESS,
            address(accessController)
        );
    }

    function test_pause_AfterInitialization() external {
        initializeVisionTokenWrapper();

        vm.prank(PAUSER);
        visionTokenWrapper.pause();

        assertTrue(visionTokenWrapper.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.pause.selector
        );

        whenNotPausedTest(address(visionTokenWrapper), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializeVisionTokenWrapper();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.pause.selector
        );

        onlyRoleTest(address(visionTokenWrapper), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializeVisionTokenWrapper();

        assertFalse(visionTokenWrapper.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializeVisionTokenWrapper();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.unpause.selector
        );

        whenPausedTest(address(visionTokenWrapper), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.unpause.selector
        );

        onlyRoleTest(address(visionTokenWrapper), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("VisionWrapper: VisionForwarder has not been set")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.unpause();
    }

    function test_setVisionForwarder() external {
        initializeVisionTokenWrapper();

        assertEq(
            visionTokenWrapper.getVisionForwarder(),
            VISION_FORWARDER_ADDRESS
        );
    }

    function test_setVisionForwarder_WhenNotpaused() external {
        initializeVisionTokenWrapper();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        whenPausedTest(address(visionTokenWrapper), calldata_);
    }

    function test_setVisionForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(visionTokenWrapper), calldata_);
    }

    function test_wrap() external {
        initializeVisionTokenWrapper();
        mockIerc20_allowance(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenWrapper),
            WRAPPED_AMOUNT
        );
        mockIerc20_transferFrom(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenWrapper),
            WRAPPED_AMOUNT,
            true
        );
        vm.expectCall(
            WRAPPED_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.allowance.selector,
                deployer(),
                address(visionTokenWrapper)
            )
        );
        vm.expectCall(
            WRAPPED_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                deployer(),
                address(visionTokenWrapper)
            )
        );
        vm.expectEmit();
        emit IERC20.Transfer(address(0), deployer(), WRAPPED_AMOUNT);

        visionTokenWrapper.wrap();

        assertEq(visionTokenWrapper.balanceOf(deployer()), WRAPPED_AMOUNT);
    }

    function test_wrap_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.pause.selector
        );

        whenNotPausedTest(address(visionTokenWrapper), calldata_);
    }

    function test_wrap_WhenNotNative() external {
        VisionTokenWrapper visionTokenWrapper_ = new VisionTokenWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            ADDRESS_ZERO,
            address(accessController)
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionTokenWrapper_.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionTokenWrapper_.unpause();
        vm.stopPrank();

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionTokenWrapper.wrap.selector
        );

        onlyNativeTest(address(visionTokenWrapper_), calldata_);
    }

    function test_wrap_WithNativeCoins() external {
        initializeVisionTokenWrapper();
        vm.expectRevert("VisionTokenWrapper: no native coins accepted");

        visionTokenWrapper.wrap{value: 1}();
    }

    function test_unwrap() external {
        wrap(WRAPPED_AMOUNT);
        mockIerc20_transfer(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            WRAPPED_AMOUNT,
            true
        );
        vm.expectEmit();
        emit IERC20.Transfer(deployer(), ADDRESS_ZERO, WRAPPED_AMOUNT);

        visionTokenWrapper.unwrap(WRAPPED_AMOUNT);

        assertEq(visionTokenWrapper.balanceOf(deployer()), 0);
    }

    function test_unwrap_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.unwrap.selector,
            WRAPPED_AMOUNT
        );

        whenNotPausedTest(address(visionTokenWrapper), calldata_);
    }

    function test_unwrap_WhenNotNative() external {
        VisionTokenWrapper visionTokenWrapper_ = new VisionTokenWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            ADDRESS_ZERO,
            address(accessController)
        );

        vm.startPrank(SUPER_CRITICAL_OPS);
        visionTokenWrapper_.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionTokenWrapper_.unpause();
        vm.stopPrank();

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionTokenWrapper.unwrap.selector,
            WRAPPED_AMOUNT
        );

        onlyNativeTest(address(visionTokenWrapper_), calldata_);
    }

    function test_getWrappedToken() external view {
        assertEq(visionTokenWrapper.getWrappedToken(), WRAPPED_TOKEN_ADDRESS);
    }

    function test_isNative_WhenNative() external view {
        assertEq(visionTokenWrapper.isNative(), true);
    }

    function test_isNative_WhenNotNative() external {
        VisionTokenWrapper visionTokenWrapper_ = new VisionTokenWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            ADDRESS_ZERO,
            address(accessController)
        );

        assertEq(visionTokenWrapper_.isNative(), false);
    }

    function test_decimals() external view {
        assertEq(DECIMALS, visionTokenWrapper.decimals());
    }

    function test_symbol() external view {
        assertEq(SYMBOL, visionTokenWrapper.symbol());
    }

    function test_name() external view {
        assertEq(NAME, visionTokenWrapper.name());
    }

    function test_renounceOwnership() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.renounceOwnership();

        assertEq(visionTokenWrapper.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.expectRevert(
            abi.encodePacked("VisionWrapper: ownership cannot be transferred")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.transferOwnership(address(1));

        assertEq(visionTokenWrapper.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_update_WhenNotPaused() external {
        initializeVisionTokenWrapper();

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionTokenWrapperHarness.exposed_update.selector,
            ADDRESS_ZERO,
            ADDRESS_ZERO,
            0
        );
        (bool success, ) = address(visionTokenWrapper).call(calldata_);

        assertTrue(success);
    }

    function test_update_WhenPaused() external {
        bytes memory revertMessage = abi.encodeWithSelector(
            Pausable.EnforcedPause.selector
        );
        vm.expectRevert(revertMessage);

        visionTokenWrapper.exposed_update(ADDRESS_ZERO, ADDRESS_ZERO, 0);
    }

    function test_supportsInterface() external virtual {
        initializeVisionTokenWrapper();
        bytes4[3] memory interfaceIds = [
            bytes4(0x01ffc9a7),
            type(IVisionWrapper).interfaceId,
            type(IVisionToken).interfaceId
        ];
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            bytes4 interfaceId = interfaceIds[i];
            assert(visionTokenWrapper.supportsInterface(interfaceId));
        }

        assert(!visionTokenWrapper.supportsInterface(0xffffffff));
    }

    function wrap(uint256 amount) public {
        initializeVisionTokenWrapper();
        mockIerc20_allowance(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenWrapper),
            amount
        );
        mockIerc20_transferFrom(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(visionTokenWrapper),
            amount,
            true
        );

        visionTokenWrapper.wrap();
    }

    function initializeVisionTokenWrapper() public {
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionTokenWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionTokenWrapper.unpause();
        vm.stopPrank();
    }
}

contract VisionTokenWrapperHarness is VisionTokenWrapper {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address wrappedToken,
        address accessController
    )
        VisionTokenWrapper(
            name,
            symbol,
            decimals,
            wrappedToken,
            accessController
        )
    {}

    function exposed_update(
        address from,
        address to,
        uint256 amount
    ) external {
        _update(from, to, amount);
    }
}
