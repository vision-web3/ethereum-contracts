// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";

import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
import {VisionRegistryFacet} from "../src/facets/VisionRegistryFacet.sol";
import {VisionHubInit} from "../src/upgradeInitializers/VisionHubInit.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {VisionHubDeployer} from "./VisionHubDeployer.t.sol";

contract VisionHubInitTest is VisionHubDeployer {
    AccessController accessController;

    function setUp() public {
        accessController = deployAccessController();
        deployVisionHubProxyAndDiamondCutFacet(accessController);
    }

    function test_init() external {
        deployAllFacetsAndDiamondCut();

        checkStateVisionHubAfterDeployment();
    }

    function test_init_Twice() external {
        deployAllFacets();
        visionHubInit = new VisionHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
        // wrap in IVisionHub ABI to support easier calls
        visionHubProxy = IVisionHub(address(visionHubDiamond));

        // Prepare another valid diamond cut
        IDiamondCut.FacetCut[] memory cut2 = new IDiamondCut.FacetCut[](1);
        // VisionRegistryFacet
        visionRegistryFacet = new VisionRegistryFacet();
        cut2[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(visionRegistryFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getVisionRegistrySelectors()
            })
        );

        vm.expectRevert("VisionHubInit: contract is already initialized");
        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut2,
            address(visionHubInit),
            initializerData
        );

        checkStateVisionHubAfterDeployment();
    }

    function test_init_EmptyBlockchainName() external {
        deployAllFacets();
        visionHubInit = new VisionHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        VisionHubInit.Args memory args = getInitializerArgs();
        args.blockchainName = "";
        bytes memory initializerData = prepareInitializerData(args);
        vm.expectRevert("VisionHubInit: blockchain name must not be empty");

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
    }

    function test_init_InvalidFeeFactor() external {
        deployAllFacets();
        visionHubInit = new VisionHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        VisionHubInit.Args memory args = getInitializerArgs();
        args.validatorFeeFactor = 0;
        bytes memory initializerData = prepareInitializerData(args);
        vm.expectRevert("VisionHubInit: validator fee factor must be >= 1");

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
    }

    function test_init_CalledDirectlyBeforeDiamondCut() external {
        deployAllFacets();
        visionHubInit = new VisionHubInit();

        visionHubInit.init(getInitializerArgs());

        // should allow normal init
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
        // wrap in IVisionHub ABI to support easier calls
        visionHubProxy = IVisionHub(address(visionHubDiamond));
        checkStateVisionHubAfterDeployment();
    }

    function test_init_CalledDirectlyAfterDiamondCut() external {
        deployAllFacets();
        visionHubInit = new VisionHubInit();

        // should allow normal init
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(visionHubDiamond)).diamondCut(
            cut,
            address(visionHubInit),
            initializerData
        );
        // wrap in IVisionHub ABI to support easier calls
        visionHubProxy = IVisionHub(address(visionHubDiamond));
        checkStateVisionHubAfterDeployment();

        visionHubInit.init(getInitializerArgs());

        checkStateVisionHubAfterDeployment();
    }
}
