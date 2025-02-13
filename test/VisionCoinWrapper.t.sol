// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

import {VisionWrapper} from "../src/VisionWrapper.sol";
import {VisionCoinWrapper} from "../src/VisionCoinWrapper.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {FailingContract} from "./helpers/FailingContract.sol";
import {VisionBaseTest} from "./VisionBaseTest.t.sol";

contract VisionCoinWrapperTest is VisionBaseTest {
    VisionCoinWrapper visionCoinWrapper;
    address constant VISION_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("VisionForwarderAddress"))));
    uint256 constant WRAPPED_AMOUNT = 1000;
    string constant NAME = "test token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;

    AccessController public accessController;

    function setUp() public {
        accessController = deployAccessController();
        visionCoinWrapper = new VisionCoinWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            true,
            address(accessController)
        );
    }

    function test_wrap() external {
        initializeVisionCoinWrapper();
        uint256 initialBalance = deployer().balance;
        vm.expectEmit();
        emit IERC20.Transfer(ADDRESS_ZERO, deployer(), WRAPPED_AMOUNT);

        visionCoinWrapper.wrap{value: WRAPPED_AMOUNT}();

        assertEq(visionCoinWrapper.balanceOf(deployer()), WRAPPED_AMOUNT);
        assertEq(deployer().balance, initialBalance - WRAPPED_AMOUNT);
    }

    function test_wrap_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionCoinWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.pause.selector
        );

        whenNotPausedTest(address(visionCoinWrapper), calldata_);
    }

    function test_wrap_WhenNotNative() external {
        VisionCoinWrapper visionCoinWrapper_ = new VisionCoinWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            false,
            address(accessController)
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionCoinWrapper_.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionCoinWrapper_.unpause();
        vm.stopPrank();

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionCoinWrapper.wrap.selector
        );

        onlyNativeTest(address(visionCoinWrapper_), calldata_);
    }

    function test_unwrap() external {
        wrap(WRAPPED_AMOUNT);
        uint256 initialBalance = deployer().balance;
        vm.expectEmit();
        emit IERC20.Transfer(deployer(), ADDRESS_ZERO, WRAPPED_AMOUNT);

        visionCoinWrapper.unwrap(WRAPPED_AMOUNT);

        assertEq(visionCoinWrapper.balanceOf(deployer()), 0);
        assertEq(deployer().balance, initialBalance + WRAPPED_AMOUNT);
    }

    function test_unwrap_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        visionCoinWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionWrapper.pause.selector
        );

        whenNotPausedTest(address(visionCoinWrapper), calldata_);
    }

    function test_unwrap_WhenNotNative() external {
        VisionCoinWrapper visionCoinWrapper_ = new VisionCoinWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            false,
            address(accessController)
        );

        vm.startPrank(SUPER_CRITICAL_OPS);
        visionCoinWrapper_.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionCoinWrapper_.unpause();
        vm.stopPrank();

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionCoinWrapper.wrap.selector
        );

        onlyNativeTest(address(visionCoinWrapper_), calldata_);
    }

    function test_unwrap_TransferFailed() external {
        initializeVisionCoinWrapper();
        FailingContract failingContract = new FailingContract();
        vm.deal(address(failingContract), 1 ether);
        vm.startPrank(address(failingContract));
        visionCoinWrapper.wrap{value: WRAPPED_AMOUNT}();
        vm.expectRevert(
            abi.encodePacked("VisionCoinWrapper: transfer failed")
        );

        visionCoinWrapper.unwrap(WRAPPED_AMOUNT);
        vm.stopPrank();
    }

    function wrap(uint256 amount) public {
        initializeVisionCoinWrapper();
        visionCoinWrapper.wrap{value: amount}();
    }

    function initializeVisionCoinWrapper() public {
        vm.startPrank(SUPER_CRITICAL_OPS);
        visionCoinWrapper.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionCoinWrapper.unpause();
        vm.stopPrank();
    }

    // necessary to be able to receive native coins when calling unwrap
    receive() external payable {}
}
