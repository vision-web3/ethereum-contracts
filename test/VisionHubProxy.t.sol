// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {console2} from "forge-std/console2.sol";

import {IVisionRegistry} from "../src/interfaces/IVisionRegistry.sol";
import {IVisionTransfer} from "../src/interfaces/IVisionTransfer.sol";
import {VisionRegistryFacet} from "../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../src/facets/VisionTransferFacet.sol";
import {VisionHubInit} from "../src/upgradeInitializers/VisionHubInit.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionHubDeployer} from "./VisionHubDeployer.t.sol";
import {DummyFacet} from "./helpers/DummyFacet.sol";
import {IVisionTransferV2} from "./helpers/IVisionTransferV2.sol";
import {VisionTransferV2Facet} from "./helpers/VisionTransferV2Facet.sol";
import {VisionHubReinit} from "./helpers/VisionHubReinit.sol";

contract VisionHubProxyTest is VisionHubDeployer {
    event Response(bool success, bytes data);

    DummyFacet dummyFacet;
    AccessController accessController;

    function setUp() public {
        accessController = deployAccessController();
        deployVisionHubProxyAndDiamondCutFacet(accessController);
    }

    function test_fallback_sendEthToVisionHubUsingCall() external {
        (bool success, bytes memory result) = address(visionHubDiamond).call{
            value: 100
        }("");
        assertFalse(success);
        assertEq(getRevertMsg(result), "VisionHub: Function does not exist");
    }

    function test_fallback_sendEthToVisionHubUsingTransfer() external {
        vm.expectRevert();
        payable(address(visionHubDiamond)).transfer(10000);
    }

    function test_fallback_sendEthToVisionHubUsingSend() external {
        bool success = payable(address(visionHubDiamond)).send(100);
        assertFalse(success);
    }

    function test_fallback_setVisionForwarderWithEth() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();
        (bool success, bytes memory result) = address(visionHubDiamond).call{
            value: 100
        }(
            abi.encodeWithSignature(
                "setVisionForwarder(address)",
                VISION_FORWARDER_ADDRESS
            )
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "");
    }

    function test_fallback_callNonExistingMethod() external {
        (bool success, bytes memory result) = address(visionHubDiamond).call(
            abi.encodeWithSignature(
                "NonExistingMethod(address)",
                VISION_FORWARDER_ADDRESS
            )
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "VisionHub: Function does not exist");
    }

    function test_fallback_callNonExistingMethodAfterInitVisionHub() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();
        checkStateVisionHubAfterInit();

        (bool success, bytes memory result) = address(visionHubDiamond).call(
            abi.encodeWithSignature(
                "NonExistingMethod(address)",
                VISION_FORWARDER_ADDRESS
            )
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "VisionHub: Function does not exist");
    }

    function test_fallback_setVisionForwarderWithWrongParamType() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();
        (bool success, bytes memory result) = address(visionHubDiamond).call(
            abi.encodeWithSignature("setVisionForwarder(uint256)", 999)
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "VisionHub: Function does not exist");
    }

    function test_diamondCut_allFacets() external {
        deployAllFacetsAndDiamondCut();

        checkStateVisionHubAfterDeployment();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_diamondCut_ByNonDeployer() external {
        dLoupe = new DiamondLoupeFacet();
        visionRegistryFacet = new VisionRegistryFacet();
        visionTransferFacet = new VisionTransferFacet();

        visionHubInit = new VisionHubInit();

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.expectRevert("VisionHub: caller doesn't have role");
        // upgrade visionHub diamond with facets using diamondCut
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
    }

    function test_diamondCut_ByNonDeployerWithoutInit() external {
        dLoupe = new DiamondLoupeFacet();
        visionRegistryFacet = new VisionRegistryFacet();
        visionTransferFacet = new VisionTransferFacet();

        visionHubInit = new VisionHubInit();

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();

        vm.expectRevert("VisionHub: caller doesn't have role");
        // upgrade visionHub diamond with facets using diamondCut
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_NonExistingFacet() external {
        visionHubInit = new VisionHubInit();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(999),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.expectRevert("LibDiamondCut: New facet has no code");
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
    }

    function test_diamondCut_NonExistingFacetWithoutInit() external {
        visionHubInit = new VisionHubInit();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(999),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );

        vm.expectRevert("LibDiamondCut: New facet has no code");
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_ReplaceFacetSameInterface() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializeVisionHub();
        checkStateVisionHubAfterInit();

        reDeployRegistryAndTransferFacetsAndDiamondCut();

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStateVisionHubAfterInit();
    }

    function test_diamondCut_ReplaceFacetSameInterfaceBeforeVisionHubInit()
        external
    {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStateVisionHubAfterDeployment();

        reDeployRegistryAndTransferFacetsAndDiamondCut();

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStateVisionHubAfterDeployment();
    }

    function test_diamondCut_ReplaceFacetUpdatedInterfaceUsingRemoveAdd()
        external
    {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);

        // prepare diamond cut to replace a facet with updated interface
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);

        // new TransferFacetV2
        VisionTransferV2Facet visionTransferV2Facet = new VisionTransferV2Facet();
        bytes4[] memory transferFacetSelectors = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetFunctionSelectors(address(visionTransferFacet));

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: transferFacetSelectors
            })
        );

        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionTransferV2Facet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getVisionTransferV2Selectors()
            })
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();

        checkFacetsAfterTransferFacetV2Update(facets, visionTransferV2Facet);
    }

    function test_diamondCut_ReplaceFacetUpdatedInterfaceUsingReplace()
        external
    {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);

        initializeVisionHub();
        // prepare diamond cut to replace a facet with updated interface
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // new TransferFacetV2
        VisionTransferV2Facet visionTransferV2Facet = new VisionTransferV2Facet();

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: getVisionTransferV2SelectorsToRemove()
            })
        );

        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionTransferV2Facet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getVisionTransferV2SelectorsToAdd()
            })
        );

        cut[2] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionTransferV2Facet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getVisionTransferV2SelectorsToReplace()
            })
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();

        assertEq(facets[3].facetAddress, address(visionTransferV2Facet));
        assertEq(facets[3].functionSelectors.length, 4);
        // order of functionSelectors are not preserved
    }

    function test_diamondCut_addNewFacet() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializeVisionHub();
        checkStateVisionHubAfterInit();

        deployNewDummyFacetsAndDiamondCut();
        DummyFacet wrappedDummyFacet = DummyFacet(address(visionHubDiamond));
        wrappedDummyFacet.setNewAddress(address(999));
        wrappedDummyFacet.setNewUint(999);
        wrappedDummyFacet.setNewMapping(address(999));

        // checking storage state integrity after modifying new fields
        assertEq(wrappedDummyFacet.getNewAddress(), address(999));
        assertTrue(
            wrappedDummyFacet.isNewMappingEntryForAddress(address(999))
        );
        assertEq(wrappedDummyFacet.getNewUint(), 999);
        checkStateVisionHubAfterInit();

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());
    }

    function test_diamondCut_addNewFacetUsingReinitilizer() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializeVisionHub();
        checkStateVisionHubAfterInit();

        deployNewDummyFacetsAndDiamondCutUsingReinitializer();
        DummyFacet wrappedDummyFacet = DummyFacet(address(visionHubDiamond));

        // checking storage state integrity
        assertEq(wrappedDummyFacet.getNewAddress(), address(9999));
        assertTrue(
            wrappedDummyFacet.isNewMappingEntryForAddress(address(9998))
        );
        assertEq(wrappedDummyFacet.getNewUint(), 9997);
        checkStateVisionHubAfterInit();

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());
    }

    function test_diamondCut_addNewFacetUsingReinitilizerTwice() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializeVisionHub();
        checkStateVisionHubAfterInit();

        deployNewDummyFacetsAndDiamondCutUsingReinitializer();
        DummyFacet wrappedDummyFacet = DummyFacet(address(visionHubDiamond));

        // reusing reinit
        dummyFacet = new DummyFacet();

        // prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dummyFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getDummyFacetSelectors()
            })
        );

        VisionHubReinit visionHubReinit = new VisionHubReinit();

        VisionHubReinit.Args memory args = VisionHubReinit.Args({
            newAddress: address(8888),
            newMappingAddress: address(8888),
            newUint: 8888
        });

        bytes memory initializerData = abi.encodeCall(
            VisionHubReinit.init,
            (args)
        );

        vm.expectRevert("VisionHubRenit: contract is already initialized");
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubReinit),
            initializerData
        );

        // checking storage state integrity
        assertEq(wrappedDummyFacet.getNewAddress(), address(9999));
        assertTrue(
            wrappedDummyFacet.isNewMappingEntryForAddress(address(9998))
        );
        assertEq(wrappedDummyFacet.getNewUint(), 9997);
        checkStateVisionHubAfterInit();

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());
    }

    function test_diamondCut_removeFacet() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        initializeVisionHub();
        deployNewDummyFacetsAndDiamondCut();
        checkStateVisionHubAfterInit();
        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());

        // prepare diamond cut to remove a facet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: getDummyFacetSelectors()
            })
        );
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");

        facets = IDiamondLoupe(address(visionHubDiamond)).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStateVisionHubAfterInit();
    }

    function test_loupe_facets_ByDeployer() external {
        deployAllFacetsAndDiamondCut();

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();

        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_loupe_facets_BeforeVisionHubInit() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();

        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_loupe_facets_AfterVisionHubInit() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(visionHubDiamond)
        ).facets();

        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_loupe_facetFunctionSelectors() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        bytes4[] memory facetFunctionSelectors = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetFunctionSelectors(address(visionRegistryFacet));

        assertEq(facetFunctionSelectors, getVisionRegistrySelectors());
    }

    function test_loupe_facetFunctionSelectors_InvalidFacet() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        bytes4[] memory facetFunctionSelectors = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetFunctionSelectors(address(111));
        assertEq(facetFunctionSelectors.length, 0);
    }

    function test_loupe_facetFunctionSelectors_0Facet() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        bytes4[] memory facetFunctionSelectors = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetFunctionSelectors(address(0));
        assertEq(facetFunctionSelectors.length, 0);
    }

    function test_loupe_facetAddresses() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        address[] memory facetAddresses = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetAddresses();

        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddresses_ByDeployer() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        address[] memory facetAddresses = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetAddresses();
        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddresses_BeforeVisionHubInit() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        address[] memory facetAddresses = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetAddresses();
        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddresses_AfterVisionHubInit() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();

        address[] memory facetAddresses = IDiamondLoupe(
            address(visionHubDiamond)
        ).facetAddresses();
        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddress_BeforeVisionHubInit() external {
        deployAllFacetsAndDiamondCut();

        address facetAddress = IDiamondLoupe(address(visionHubDiamond))
            .facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(facetAddress, address(dCutFacet));

        bytes4[] memory selectors = getDiamondLoupeSelectors();
        checkLoupeFacetAddressForSelectors(selectors, address(dLoupe));

        selectors = getVisionRegistrySelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(visionRegistryFacet)
        );

        selectors = getVisionTransferSelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(visionTransferFacet)
        );
    }

    function test_loupe_facetAddress_AfterVisionHubInit() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();

        address facetAddress = IDiamondLoupe(address(visionHubDiamond))
            .facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(facetAddress, address(dCutFacet));

        bytes4[] memory selectors = getDiamondLoupeSelectors();
        checkLoupeFacetAddressForSelectors(selectors, address(dLoupe));

        selectors = getVisionRegistrySelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(visionRegistryFacet)
        );

        selectors = getVisionTransferSelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(visionTransferFacet)
        );
    }

    function test_loupe_facetAddress_UnknownSelector() external {
        deployAllFacetsAndDiamondCut();
        initializeVisionHub();

        address facetAddress = IDiamondLoupe(address(visionHubDiamond))
            .facetAddress(DummyFacet.getNewAddress.selector);
        assertEq(facetAddress, address(0));
    }

    function deployNewDummyFacetsAndDiamondCut() public {
        dummyFacet = new DummyFacet();

        // prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dummyFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDummyFacetSelectors()
            })
        );

        vm.prank(DEPLOYER);
        // upgrade visionHub diamond with facets using diamondCut
        IDiamondCut(address(visionHubDiamond)).diamondCut(cut, address(0), "");
    }

    function deployNewDummyFacetsAndDiamondCutUsingReinitializer() public {
        dummyFacet = new DummyFacet();

        // prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dummyFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDummyFacetSelectors()
            })
        );

        VisionHubReinit visionHubReinit = new VisionHubReinit();

        VisionHubReinit.Args memory args = VisionHubReinit.Args({
            newAddress: address(9999),
            newMappingAddress: address(9998),
            newUint: 9997
        });

        bytes memory initializerData = abi.encodeCall(
            VisionHubReinit.init,
            (args)
        );
        vm.prank(DEPLOYER);
        // upgrade visionHub diamond with facets using diamondCut
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubReinit),
            initializerData
        );
    }

    function checkInitialCutFacetAdresses(
        address[] memory facetAddresses
    ) public view {
        assertEq(facetAddresses.length, 4);
        assertEq(facetAddresses[0], address(dCutFacet));
        assertEq(facetAddresses[1], address(dLoupe));
        assertEq(facetAddresses[2], address(visionRegistryFacet));
        assertEq(facetAddresses[3], address(visionTransferFacet));
    }

    function checkLoupeFacetAddressForSelectors(
        bytes4[] memory selectors,
        address expecterFacetAddress
    ) public view {
        for (uint256 i; i < selectors.length; i++) {
            address facetAddress = IDiamondLoupe(address(visionHubDiamond))
                .facetAddress(selectors[i]);
            assertEq(facetAddress, expecterFacetAddress);
        }
    }

    function checkInitialCutFacets(
        IDiamondLoupe.Facet[] memory facets
    ) public view {
        assertEq(facets[0].facetAddress, address(dCutFacet));
        assertEq(facets[1].facetAddress, address(dLoupe));
        assertEq(facets[2].facetAddress, address(visionRegistryFacet));
        assertEq(facets[3].facetAddress, address(visionTransferFacet));

        assertEq(facets[0].functionSelectors.length, 1);
        assertEq(
            facets[0].functionSelectors[0],
            IDiamondCut.diamondCut.selector
        );

        assertEq(facets[1].functionSelectors, getDiamondLoupeSelectors());
        assertEq(facets[2].functionSelectors, getVisionRegistrySelectors());
        assertEq(facets[3].functionSelectors, getVisionTransferSelectors());
    }

    function checkFacetsAfterTransferFacetV2Update(
        IDiamondLoupe.Facet[] memory facets,
        VisionTransferV2Facet transferFacetV2
    ) public view {
        assertEq(facets[0].facetAddress, address(dCutFacet));
        assertEq(facets[1].facetAddress, address(dLoupe));
        assertEq(facets[2].facetAddress, address(visionRegistryFacet));
        assertEq(facets[3].facetAddress, address(transferFacetV2));

        assertEq(facets[0].functionSelectors.length, 1);
        assertEq(
            facets[0].functionSelectors[0],
            IDiamondCut.diamondCut.selector
        );

        assertEq(facets[1].functionSelectors, getDiamondLoupeSelectors());
        assertEq(facets[2].functionSelectors, getVisionRegistrySelectors());
        assertEq(facets[3].functionSelectors, getVisionTransferV2Selectors());
    }

    function getDummyFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = DummyFacet.setNewAddress.selector;
        selectors[1] = DummyFacet.setNewMapping.selector;
        selectors[2] = DummyFacet.setNewUint.selector;
        selectors[3] = DummyFacet.getNewAddress.selector;
        selectors[4] = DummyFacet.isNewMappingEntryForAddress.selector;
        selectors[5] = DummyFacet.getNewUint.selector;
        return selectors;
    }

    function getVisionTransferV2Selectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IVisionTransferV2.transfer.selector;
        selectors[1] = IVisionTransferV2.transferFromV2.selector;
        selectors[2] = IVisionTransferV2.transferToV2.selector;
        selectors[3] = IVisionTransferV2.isValidSenderNonce.selector;

        return selectors;
    }

    function getVisionTransferV2SelectorsToAdd()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IVisionTransferV2.transferFromV2.selector;
        selectors[1] = IVisionTransferV2.transferToV2.selector;
        return selectors;
    }

    function getVisionTransferV2SelectorsToRemove()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = IVisionTransfer.transferFrom.selector;
        selectors[1] = IVisionTransfer.transferTo.selector;
        selectors[2] = IVisionTransfer.verifyTransfer.selector;
        selectors[3] = IVisionTransfer.verifyTransferFrom.selector;
        selectors[4] = IVisionTransfer.verifyTransferTo.selector;
        selectors[5] = IVisionTransfer.getNextTransferId.selector;
        return selectors;
    }

    function getVisionTransferV2SelectorsToReplace()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IVisionTransferV2.transfer.selector;
        selectors[1] = IVisionTransferV2.isValidSenderNonce.selector;
        return selectors;
    }
}
