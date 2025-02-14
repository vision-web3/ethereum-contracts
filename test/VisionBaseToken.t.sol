// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {console2} from "forge-std/console2.sol";

import {IVisionToken} from "../src/interfaces/IVisionToken.sol";
import {VisionBaseToken} from "../src/VisionBaseToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionBaseTest} from "./VisionBaseTest.t.sol";

abstract contract VisionBaseTokenTest is VisionBaseTest {
    address public constant VISION_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("VisionForwarderAddress"))));

    AccessController public accessController;

    function initializeToken() public virtual;

    function token() public view virtual returns (VisionBaseToken);

    function tokenRevertMsgPrefix()
        public
        pure
        virtual
        returns (string memory);

    function test_visionTransferTo() external {
        initializeToken();
        address receiver = address(2);
        uint256 amount = 1_000;
        uint256 receiverBalanceBefore = token().balanceOf(receiver);
        vm.expectEmit();
        emit IERC20.Transfer(ADDRESS_ZERO, receiver, amount);

        vm.prank(VISION_FORWARDER_ADDRESS);
        token().visionTransferTo(receiver, amount);

        uint256 receiverBalanceAfter = token().balanceOf(receiver);
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
    }

    function test_visionTransferTo_NotByVisionForwarder() external {
        initializeToken();
        address receiver = address(2);
        uint256 amount = 1_000;

        string memory revertMsg = string.concat(
            tokenRevertMsgPrefix(),
            " caller is not the VisionForwarder"
        );
        vm.expectRevert(bytes(revertMsg));
        token().visionTransferTo(receiver, amount);
    }

    function test_visionTransferTo_RecieverAddress0() external {
        initializeToken();
        address receiver = address(0);
        uint256 amount = 1_000;

        bytes4 selector = IERC20Errors.ERC20InvalidReceiver.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(VISION_FORWARDER_ADDRESS);

        token().visionTransferTo(receiver, amount);
    }

    function test_visionTransferFrom() external {
        initializeToken();
        address sender = address(1);
        uint256 amount = 1_000_000;
        // topup sender balance
        vm.prank(VISION_FORWARDER_ADDRESS);
        token().visionTransferTo(sender, amount);
        uint256 senderBalanceBefore = token().balanceOf(sender);
        vm.expectEmit();
        emit IERC20.Transfer(sender, ADDRESS_ZERO, amount);

        vm.prank(VISION_FORWARDER_ADDRESS);
        token().visionTransferFrom(sender, amount);

        uint256 senderBalanceAfter = token().balanceOf(sender);
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);
    }

    function test_visionTransferFrom_NotByVisionForwarder() external {
        initializeToken();
        address sender = address(1);
        uint256 amount = 1_000_000;
        string memory revertMsg = string.concat(
            tokenRevertMsgPrefix(),
            " caller is not the VisionForwarder"
        );
        vm.expectRevert(bytes(revertMsg));

        token().visionTransferFrom(sender, amount);
    }

    function test_visionTransferFrom_SenderAddress0() external {
        initializeToken();
        address sender = ADDRESS_ZERO;
        uint256 amount = 1_000_000;

        bytes4 selector = IERC20Errors.ERC20InvalidSender.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(VISION_FORWARDER_ADDRESS);

        token().visionTransferFrom(sender, amount);
    }

    function test_visionTransfer() external {
        initializeToken();
        address sender = address(1);
        address receiver = address(2);
        uint256 amount = 1_000_000;
        // topup sender balance
        vm.prank(VISION_FORWARDER_ADDRESS);
        token().visionTransferTo(sender, amount);
        uint256 senderBalanceBefore = token().balanceOf(sender);
        uint256 receiverBalanceBefore = token().balanceOf(receiver);
        vm.expectEmit();
        emit IERC20.Transfer(sender, receiver, amount);

        vm.prank(VISION_FORWARDER_ADDRESS);
        token().visionTransfer(sender, receiver, amount);

        uint256 receiverBalanceAfter = token().balanceOf(receiver);
        uint256 senderBalanceAfter = token().balanceOf(sender);
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);
    }

    function test_visionTransfer_NotByVisionForwarder() external {
        initializeToken();
        address sender = address(1);
        address receiver = address(2);
        uint256 amount = 1_000_000;

        string memory revertMsg = string.concat(
            tokenRevertMsgPrefix(),
            " caller is not the VisionForwarder"
        );
        vm.expectRevert(bytes(revertMsg));

        token().visionTransfer(sender, receiver, amount);
    }

    function test_visionTransfer_SenderAddress0() external {
        initializeToken();
        address sender = ADDRESS_ZERO;
        address receiver = address(2);
        uint256 amount = 1_000_000;
        bytes4 selector = IERC20Errors.ERC20InvalidSender.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(VISION_FORWARDER_ADDRESS);

        token().visionTransfer(sender, receiver, amount);
    }

    function test_visionTransfer_RecieverAddress0() external {
        initializeToken();
        address sender = address(1);
        address receiver = ADDRESS_ZERO;
        uint256 amount = 1_000_000;
        bytes4 selector = IERC20Errors.ERC20InvalidReceiver.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(VISION_FORWARDER_ADDRESS);

        token().visionTransfer(sender, receiver, amount);
    }

    function test_supportsInterface() external virtual {
        initializeToken();
        bytes4[4] memory interfaceIds = [
            bytes4(0x01ffc9a7),
            type(IVisionToken).interfaceId,
            type(ERC20).interfaceId,
            type(Ownable).interfaceId
        ];
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            bytes4 interfaceId = interfaceIds[i];
            assert(token().supportsInterface(interfaceId));
        }

        assert(!token().supportsInterface(0xffffffff));
    }
}
