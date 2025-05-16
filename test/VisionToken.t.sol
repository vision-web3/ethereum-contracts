// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {console} from "forge-std/console.sol";
import {stdError} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// solhint-disable-next-line max-line-length
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {IVisionToken} from "../src/interfaces/IVisionToken.sol";
import {VisionBaseTokenUpgradeable} from "../src/VisionBaseTokenUpgradeable.sol";
import {VisionToken} from "../src/VisionToken.sol";

import {VisionBaseTokenTest} from "./VisionBaseToken.t.sol";

contract VisionTokenTest is VisionBaseTokenTest {
    VisionToken public visionToken;
    uint256 public constant TOKEN_DECIMALS = 18;
    uint256 public constant TOKEN_UNIT = 10 ** TOKEN_DECIMALS;

    function setUp() public virtual {
        // Step 1: Deploy the VisionToken implementation contract
        VisionToken logic = new VisionToken();

        // Step 2: Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            VisionToken.initialize.selector,
            INITIAL_SUPPLY_VSN,
            roleAdmin,
            criticalOps,
            minter,
            pauser,
            upgrader
        );

        // Step 3: Deploy the UUPS Proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);

        // wrap proxy into VisionToken for easy access
        visionToken = VisionToken(address(proxy));
    }

    function setUser(address account, uint256 balance) internal {
        assertEq(token().balanceOf(account), 0);
        // Mint tokens to account
        if (balance > 0) {
            vm.prank(minter);
            visionToken.mint(account, balance); // Mint 500 tokens to account
        }
    }

    function test_SetUpState() public view virtual {
        assertEq(visionToken.name(), "Vision");
        assertEq(visionToken.symbol(), "VSN");
        assertEq(visionToken.decimals(), TOKEN_DECIMALS);
        assertEq(visionToken.balanceOf(criticalOps), INITIAL_SUPPLY_VSN);
        assertFalse(visionToken.paused());

        assertEq(visionToken.getOwner(), criticalOps);
        assertTrue(
            visionToken.hasRole(visionToken.DEFAULT_ADMIN_ROLE(), roleAdmin)
        );
        assertTrue(
            visionToken.hasRole(visionToken.CRITICAL_OPS_ROLE(), criticalOps)
        );
        assertTrue(visionToken.hasRole(visionToken.MINTER_ROLE(), minter));
        assertTrue(visionToken.hasRole(visionToken.PAUSER_ROLE(), pauser));
        assertTrue(visionToken.hasRole(visionToken.UPGRADER_ROLE(), upgrader));
        bytes32 visionTokenStorage = keccak256(
            abi.encode(
                uint256(keccak256("vision-base-token.contract.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));
        // console.logBytes32(visionTokenStorage);
        assertEq(
            visionTokenStorage,
            0x8a83655261740f09e968720dd5982e8d17ec12a50d4d2f5e59ec427b5095b700
        );
    }

    function test_pause_AfterInitialization() external {
        setBridgeAtToken();

        vm.prank(pauser);
        visionToken.pause();

        assertTrue(visionToken.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(pauser);
        visionToken.pause();

        vm.prank(criticalOps);
        visionToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);

        vm.startPrank(pauser);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.pause.selector
        );
        whenNotPausedTest(address(visionToken), calldata_);
    }

    function test_pause_ByNonPauser() external {
        setBridgeAtToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.pause.selector
        );

        onlyRoleAccessControlTest(
            address(visionToken),
            calldata_,
            visionToken.PAUSER_ROLE()
        );
    }

    function test_pause_ByOtherRolesReverts() public {
        address[4] memory otherRoles = [
            roleAdmin,
            minter,
            upgrader,
            criticalOps
        ];

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector,
                    otherRole,
                    visionToken.PAUSER_ROLE()
                )
            );
            visionToken.pause();

            assertFalse(visionToken.paused());
            vm.stopPrank();
        }
    }

    function test_unpause_AfterDeploy() external {
        setBridgeAtToken();

        assertFalse(visionToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        setBridgeAtToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.unpause.selector
        );

        onlyRoleAccessControlTest(
            address(visionToken),
            calldata_,
            visionToken.CRITICAL_OPS_ROLE()
        );
    }

    function test_unpause_ByNonCriticalOps() external {
        vm.prank(pauser);
        visionToken.pause();

        vm.prank(criticalOps);
        visionToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.unpause.selector
        );

        onlyRoleAccessControlTest(
            address(visionToken),
            calldata_,
            visionToken.CRITICAL_OPS_ROLE()
        );
    }

    function test_unpause_ByOtherRolesReverts() public {
        address[4] memory otherRoles = [roleAdmin, minter, upgrader, pauser];
        vm.prank(pauser);
        visionToken.pause();

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector,
                    otherRole,
                    visionToken.CRITICAL_OPS_ROLE()
                )
            );
            visionToken.unpause();

            assertTrue(visionToken.paused());
            vm.stopPrank();
        }
    }
    function test_unpause_WithNoForwarderSet() external {
        vm.prank(pauser);
        visionToken.pause();

        vm.prank(criticalOps);
        visionToken.unpause();

        assertFalse(visionToken.paused());
    }

    function test_setVisionForwarder() external {
        setBridgeAtToken();

        assertEq(visionToken.getVisionForwarder(), VISION_FORWARDER_ADDRESS);
    }

    function test_setVisionForwarder_WhenNotpaused() external {
        setBridgeAtToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        whenPausedTest(address(visionToken), calldata_);
    }

    function test_setVisionForwarder_ByNonOwner() external {
        vm.prank(pauser);
        visionToken.pause();

        bytes memory calldata_ = abi.encodeWithSelector(
            VisionToken.setVisionForwarder.selector,
            VISION_FORWARDER_ADDRESS
        );

        onlyRoleAccessControlTest(
            address(visionToken),
            calldata_,
            visionToken.CRITICAL_OPS_ROLE()
        );
    }

    function test_decimals() external view {
        assertEq(18, visionToken.decimals());
    }

    function test_symbol() external view {
        assertEq("VSN", visionToken.symbol());
    }

    function test_name() external view {
        assertEq("Vision", visionToken.name());
    }

    function test_transfer_WhenPausedReverts() public {
        // Mint tokens to alice and ensure alice can transfer when not paused
        setUser(alice, 1000 * TOKEN_UNIT);

        // Pause the contract
        vm.startPrank(pauser);
        visionToken.pause();
        vm.stopPrank();

        vm.startPrank(alice);
        // Attempt to transfer tokens while the contract is paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        visionToken.transfer(bob, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate that balances remain unchanged
        assertEq(
            visionToken.balanceOf(alice),
            1000 * TOKEN_UNIT,
            "alice's balance should not change"
        );
        assertEq(
            visionToken.balanceOf(bob),
            0,
            "bob's balance should not change"
        );
    }

    function test_transfer_WhenUnpaused() public {
        // Mint tokens to alice
        setUser(alice, 1000 * TOKEN_UNIT);

        // Pause the contract
        vm.prank(pauser);
        visionToken.pause();

        // Attempt to transfer tokens while paused
        vm.startPrank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        visionToken.transfer(bob, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Unpause the contract
        vm.prank(criticalOps);
        visionToken.unpause();

        // Now that the contract is unpaused, the transfer should work
        vm.startPrank(alice);
        bool success = visionToken.transfer(bob, 100 * TOKEN_UNIT);
        assertTrue(success, "Transfer should be successful after unpause");
        vm.stopPrank();

        // Validate balances after transfer
        assertEq(
            visionToken.balanceOf(alice),
            900 * TOKEN_UNIT,
            "alice's balance should decrease"
        );
        assertEq(
            visionToken.balanceOf(bob),
            100 * TOKEN_UNIT,
            "bob's balance should increase"
        );
    }

    function test_transfer() public {
        // Mint tokens to alice
        vm.startPrank(minter);
        visionToken.mint(alice, 1000 * TOKEN_UNIT); // Mint 1000 tokens to alice
        vm.stopPrank();

        // Alice transfers 100 tokens to bob
        vm.startPrank(alice);
        bool success = visionToken.transfer(bob, 100 * TOKEN_UNIT); // Alice sends 100 tokens
        assertTrue(success, "Transfer should be successful");
        vm.stopPrank();

        assertEq(
            visionToken.balanceOf(alice),
            900 * TOKEN_UNIT,
            "alice balance should decrease by 100 tokens"
        );
        assertEq(
            visionToken.balanceOf(bob),
            100 * TOKEN_UNIT,
            "bob balance should increase by 100 tokens"
        );
    }

    function test_transferFrom_UnapprovedAccountReverts() public {
        // Mint tokens to alice
        vm.startPrank(minter);
        visionToken.mint(alice, 1000 * TOKEN_UNIT); // Mint 1000 tokens to alice
        vm.stopPrank();

        // Bob is not approved to spend alice's tokens, so the transfer should fail
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                bob,
                0,
                100 * TOKEN_UNIT
            )
        );
        visionToken.transferFrom(alice, bob, 100 * TOKEN_UNIT); // Bob tries to transfer from Alice's account
        vm.stopPrank();
    }

    function test_transferFrom_WhenPausedReverts() public {
        // Mint tokens to alice and approve bob to transfer from alice
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);

        vm.prank(alice);
        visionToken.approve(bob, 100 * TOKEN_UNIT);

        // Pause the contract
        vm.prank(pauser);
        visionToken.pause();

        vm.startPrank(bob);
        // Attempt to transferFrom while the contract is paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        visionToken.transferFrom(alice, charlie, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate balances and allowance remain unchanged
        assertEq(
            visionToken.balanceOf(alice),
            1000 * TOKEN_UNIT,
            "alice's balance should not change"
        );
        assertEq(
            visionToken.balanceOf(bob),
            1000 * TOKEN_UNIT,
            "bob's balance should not change"
        );
        assertEq(
            visionToken.allowance(alice, bob),
            100 * TOKEN_UNIT,
            "allowance should remain unchanged"
        );
        assertEq(
            visionToken.balanceOf(charlie),
            0,
            "charlie's balance should not change"
        );
    }

    function test_mint() public {
        uint256 amount = 1000 * TOKEN_UNIT;
        setUser(bob, amount);
        setUser(charlie, amount);
        uint256 initialSupply = visionToken.totalSupply();

        vm.startPrank(minter);
        vm.expectEmit(address(visionToken));
        emit VisionToken.Mint(minter, alice, amount);
        visionToken.mint(alice, amount);
        vm.stopPrank();
        assertEq(visionToken.balanceOf(alice), amount);
        assertEq(visionToken.balanceOf(bob), amount);
        assertEq(visionToken.balanceOf(charlie), amount);
        assertEq(visionToken.totalSupply(), initialSupply + amount);
    }

    function test_mint_OverflowReverts() public {
        uint256 maxUint = type(uint256).max;
        vm.startPrank(minter);
        visionToken.mint(alice, 1 * TOKEN_UNIT);

        uint totalSupplyBefore = visionToken.totalSupply();

        // more minting should overflow
        vm.expectRevert(stdError.arithmeticError);
        visionToken.mint(alice, maxUint);
        vm.stopPrank();

        // Validate alice's balance remains unchanged
        assertEq(
            visionToken.totalSupply(),
            totalSupplyBefore,
            "Total supply should remain unchanged"
        );
        assertEq(
            visionToken.balanceOf(alice),
            1 * TOKEN_UNIT,
            "alice's balance should not change"
        );
    }

    function test_mint_TotalSupplyOverflowReverts() public {
        uint256 maxUint = type(uint256).max;
        vm.startPrank(minter);
        visionToken.mint(alice, maxUint - visionToken.totalSupply());
        uint aliceBalanceBefore = visionToken.balanceOf(alice);
        // any more minting should overflow
        vm.expectRevert(stdError.arithmeticError);
        visionToken.mint(alice, 1);
        vm.stopPrank();

        // Validate alice's balance remains unchanged
        assertEq(
            visionToken.totalSupply(),
            maxUint,
            "Total supply should remain unchanged"
        );
        assertEq(
            visionToken.balanceOf(alice),
            aliceBalanceBefore,
            "alice's balance should not change"
        );
    }

    function test_mint_ToZeroAddressReverts() public {
        uint256 mintAmount = 100 * TOKEN_UNIT;
        vm.startPrank(minter);
        // Expect revert when minting to the zero address
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        visionToken.mint(address(0), mintAmount);
        vm.stopPrank();
    }

    function test_mint_WhenPausedReverts() public {
        vm.prank(pauser);
        visionToken.pause();

        // Attempt to mint new tokens while the contract is paused
        vm.startPrank(minter);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        visionToken.mint(alice, 100 * TOKEN_UNIT);
        vm.stopPrank();

        // Validate alice's balance remains unchanged
        assertEq(
            visionToken.balanceOf(alice),
            0,
            "alice's balance should not change"
        );
    }

    function test_mint_ZeroAmountReverts() public {
        uint totalSupplyBefore = visionToken.totalSupply();
        vm.startPrank(minter);
        vm.expectRevert(abi.encodePacked("VisionToken: Mint amount is zero"));
        visionToken.mint(alice, 0);
        vm.stopPrank();
        assertEq(visionToken.balanceOf(alice), 0);
        assertEq(visionToken.totalSupply(), totalSupplyBefore);
    }

    function test_mint_ByNonMinterRoleReverts() public {
        uint totalSupplyBefore = visionToken.totalSupply();
        uint256 amount = 100 * TOKEN_UNIT;
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                visionToken.MINTER_ROLE()
            )
        );
        visionToken.mint(alice, amount);
        vm.stopPrank();
        assertEq(visionToken.totalSupply(), totalSupplyBefore);
        assertEq(visionToken.balanceOf(alice), 0);
    }

    function test_mint_ByOtherRolesReverts() public {
        uint totalSupplyBefore = visionToken.totalSupply();
        uint256 amount = 100 * TOKEN_UNIT;
        address[4] memory otherRoles = [
            roleAdmin,
            pauser,
            upgrader,
            criticalOps
        ];

        for (uint256 i; i < otherRoles.length; i++) {
            address otherRole = otherRoles[i];
            vm.startPrank(otherRole);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector,
                    otherRole,
                    visionToken.MINTER_ROLE()
                )
            );
            visionToken.mint(alice, amount);
            vm.stopPrank();

            assertEq(visionToken.totalSupply(), totalSupplyBefore);
            assertEq(visionToken.balanceOf(alice), 0);
        }
    }

    function test_mint_AfterRoleRevokedReverts() public {
        uint totalSupplyBefore = visionToken.totalSupply();
        uint256 amount = 100 * TOKEN_UNIT;
        vm.startPrank(roleAdmin);
        visionToken.revokeRole(visionToken.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                visionToken.MINTER_ROLE()
            )
        );
        visionToken.mint(alice, amount);
        vm.stopPrank();
        assertEq(visionToken.totalSupply(), totalSupplyBefore);
        assertEq(visionToken.balanceOf(minter), 0);
    }

    function test_mint_ToMultipleAddresses() public {
        uint totalSupplyBefore = visionToken.totalSupply();
        uint256 aliceMint = 100 * TOKEN_UNIT;
        uint256 bobMint = 200 * TOKEN_UNIT;
        uint256 charlieMint = 200 * TOKEN_UNIT;

        vm.startPrank(minter);
        visionToken.mint(alice, aliceMint);
        visionToken.mint(bob, bobMint);
        visionToken.mint(charlie, charlieMint);
        vm.stopPrank();

        // Validate the total supply and balances
        assertEq(
            visionToken.totalSupply(),
            totalSupplyBefore + aliceMint + bobMint + charlieMint,
            "Total supply should equal the sum of all mints and initial supply"
        );
        assertEq(
            visionToken.balanceOf(alice),
            aliceMint,
            "Alice's balance should match the mint amount"
        );
        assertEq(
            visionToken.balanceOf(bob),
            bobMint,
            "Bob's balance should match the mint amount"
        );
        assertEq(
            visionToken.balanceOf(charlie),
            charlieMint,
            "Charlie's balance should match the mint amount"
        );
    }

    function test_permit() public {
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);
        uint256 nonce = visionToken.nonces(alice);
        uint256 deadline = block.timestamp + 1 days;
        uint256 amount = 100 * TOKEN_UNIT;

        (uint8 v, bytes32 r, bytes32 s) = signPermit(
            alice,
            bob,
            amount,
            nonce,
            deadline,
            visionToken.DOMAIN_SEPARATOR(),
            aliceWallet.privateKey
        );

        // anyone can submit this permit
        visionToken.permit(alice, bob, amount, deadline, v, r, s);

        // Verify that Bob has the allowance after permit
        assertEq(
            visionToken.allowance(alice, bob),
            amount,
            "Allowance should be updated"
        );
    }

    function test_permit_ExpiredReverts() public {
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);
        uint256 nonce = visionToken.nonces(alice);
        uint256 deadline = block.timestamp; // expired deadline
        uint256 amount = TOKEN_UNIT;

        (uint8 v, bytes32 r, bytes32 s) = signPermit(
            alice,
            bob,
            amount,
            nonce,
            deadline,
            visionToken.DOMAIN_SEPARATOR(),
            aliceWallet.privateKey
        );

        vm.warp(block.timestamp + 1 hours);
        // Expect revert if permit is expired
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitUpgradeable.ERC2612ExpiredSignature.selector,
                deadline
            )
        );
        visionToken.permit(alice, bob, amount, deadline, v, r, s);
    }

    function test_permit_AlreadyUsedReverts() public {
        setUser(alice, 1000 * TOKEN_UNIT);
        setUser(bob, 1000 * TOKEN_UNIT);
        uint256 nonce = visionToken.nonces(alice);
        uint256 deadline = block.timestamp + 1 days;
        uint256 amount = 100 * TOKEN_UNIT;

        (uint8 v, bytes32 r, bytes32 s) = signPermit(
            alice,
            bob,
            amount,
            nonce,
            deadline,
            visionToken.DOMAIN_SEPARATOR(),
            aliceWallet.privateKey
        );

        // anyone can submit this permit
        visionToken.permit(alice, bob, amount, deadline, v, r, s);

        // Verify that Bob has the allowance after permit
        assertEq(
            visionToken.allowance(alice, bob),
            amount,
            "Allowance should be updated"
        );

        // Expect revert if permit is used again
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20PermitUpgradeable.ERC2612InvalidSigner.selector,
                0x0753edA9bFb6d40175BD594a9fDF83ce33CCA20a,
                alice
            )
        );
        visionToken.permit(alice, bob, amount, deadline, v, r, s);
    }

    function test_getOwner() external view {
        assertEq(token().getOwner(), criticalOps);
    }

    function test_renounceOwnership() external {
        vm.prank(criticalOps);
        visionToken.renounceOwnership();

        assertEq(visionToken.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.prank(criticalOps);
        visionToken.transferOwnership(address(1));

        assertEq(visionToken.getOwner(), address(1));
    }
    // FIXME add test for changing owner and critical ops together

    // FIXME move to upgradeability test
    function runBasicFunctionalityTests() public {
        // Constants for testing
        uint256 mintAmount = 1000 * TOKEN_UNIT;
        uint256 transferAmount = 100 * TOKEN_UNIT;

        // Fetch current balances dynamically
        uint256 minterStartBalance = visionToken.balanceOf(minter);
        uint256 aliceStartBalance = visionToken.balanceOf(alice);
        uint256 bobStartBalance = visionToken.balanceOf(bob);
        uint256 charlieStartBalance = visionToken.balanceOf(charlie);

        uint256 totalSupplyStart = visionToken.totalSupply();

        // --- Test Minting ---
        vm.startPrank(minter); // Act as the minter
        visionToken.mint(minter, mintAmount);
        assertEq(
            visionToken.balanceOf(minter),
            mintAmount + minterStartBalance,
            "Minting failed"
        );
        visionToken.transfer(alice, transferAmount); // top up alice
        assertEq(
            visionToken.balanceOf(alice),
            transferAmount + aliceStartBalance,
            "transfer failed"
        );
        vm.stopPrank();

        // --- Test Transfers ---
        vm.startPrank(alice); // Alice transfers tokens to Bob
        visionToken.transfer(bob, transferAmount);
        assertEq(
            visionToken.balanceOf(bob),
            transferAmount + bobStartBalance,
            "Transfer failed"
        );
        assertEq(
            visionToken.balanceOf(alice),
            aliceStartBalance,
            "Transfer did not deduct from sender"
        );
        vm.stopPrank();

        // --- Test Pausing and Transfers ---
        vm.startPrank(pauser); // Act as the pauser
        visionToken.pause();
        assertTrue(visionToken.paused(), "Contract is not paused");
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        visionToken.transfer(charlie, transferAmount); // Should revert while paused
        vm.stopPrank();

        vm.startPrank(pauser);
        visionToken.unpause();
        assertFalse(visionToken.paused(), "Contract is still paused");
        vm.stopPrank();

        vm.startPrank(bob);
        visionToken.transfer(charlie, transferAmount); // Should succeed after unpausing
        assertEq(
            visionToken.balanceOf(charlie),
            transferAmount + charlieStartBalance,
            "Transfer to Charlie failed"
        );
        assertEq(visionToken.balanceOf(bob), bobStartBalance);
        vm.stopPrank();

        // --- Final State Assertions ---
        assertEq(
            visionToken.totalSupply(),
            totalSupplyStart + mintAmount,
            "Total supply mismatch"
        );
        assertEq(
            visionToken.balanceOf(alice),
            aliceStartBalance + transferAmount,
            "balance mismatch alice"
        );
    }

    function setBridgeAtToken() public override {
        vm.prank(pauser);
        visionToken.pause();

        vm.startPrank(criticalOps);
        visionToken.setVisionForwarder(VISION_FORWARDER_ADDRESS);
        visionToken.unpause();
        vm.stopPrank();
    }

    function token() public view override returns (IVisionToken) {
        return visionToken;
    }

    function tokenRevertMsgPrefix()
        public
        pure
        override
        returns (string memory)
    {
        return "VisionBaseToken:";
    }
}
