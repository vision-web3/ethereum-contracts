// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
// solhint-disable func-name-mixedcase

import {Vm} from "forge-std/Test.sol";

import {VisionTokenTest} from "./VisionToken.t.sol";
import {VisionTokenV2} from "./helpers/VisionTokenV2.sol";

contract VisionTokenUpgradeTest is VisionTokenTest {
    VisionTokenV2 public tokenV2;
    Vm.Wallet public extraRoleWallet = vm.createWallet("extraRole");
    address public extraRole = extraRoleWallet.addr;

    function setUp() public override {
        super.setUp();

        vm.startPrank(upgrader);
        // Deploy new implementation contract
        VisionTokenV2 newLogic = new VisionTokenV2();
        address[] memory extraArray = new address[](3);
        extraArray[0] = address(1);
        extraArray[1] = address(2);
        extraArray[2] = address(3);

        // Prepare the call data for initializing new functionality
        bytes memory data = abi.encodeWithSelector(
            VisionTokenV2.initializeV2.selector,
            "ExtraStr99",
            99,
            true,
            address(99),
            extraArray
        );

        // Perform the upgrade and call
        visionToken.upgradeToAndCall(address(newLogic), data);
        // wrap in V2 abi for easy access to new methods
        tokenV2 = VisionTokenV2(address(visionToken));

        vm.stopPrank();

        vm.startPrank(roleAdmin);
        tokenV2.grantRole(tokenV2.EXTRA_ROLE(), extraRole);
        vm.stopPrank();
    }

    function test_SetUpState() public view virtual override {
        super.test_SetUpState();
    }

    function test_ExtraStr() public {
        assertEq(tokenV2.getExtraStr(), "ExtraStr99");
        vm.prank(extraRole);
        tokenV2.setExtraStr("ExtraStr99Updated");

        assertEq(tokenV2.getExtraStr(), "ExtraStr99Updated");
    }

    function test_extraUint() public {
        assertEq(tokenV2.getExtraUint(), 99);
        vm.prank(extraRole);
        tokenV2.setExtraUint(77);

        assertEq(tokenV2.getExtraUint(), 77);
    }

    function test_extraBool() public {
        assertTrue(tokenV2.getExtraBool());
        vm.prank(extraRole);
        tokenV2.setExtraBool(false);

        assertFalse(tokenV2.getExtraBool());
    }

    function test_extraArray() public {
        // Get the initial value (it should be empty or predefined)
        address[] memory initial = tokenV2.getExtraArray();
        assertEq(initial.length, 3);
        assertEq(initial[0], address(1));
        assertEq(initial[1], address(2));
        assertEq(initial[2], address(3));

        address[] memory newArray = new address[](3);
        newArray[0] = address(100);
        newArray[1] = address(200);
        newArray[2] = address(300);

        vm.prank(extraRole);
        tokenV2.setExtraArray(newArray);

        address[] memory updated = tokenV2.getExtraArray();
        assertEq(updated.length, 3);
        assertEq(updated[0], address(100));
        assertEq(updated[1], address(200));
        assertEq(updated[2], address(300));
    }
}
