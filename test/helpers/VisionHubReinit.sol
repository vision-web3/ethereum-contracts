// SPDX-License-Identifier: MIT
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {VisionHubStorageExtended} from "./DummyFacet.sol";

contract VisionHubReinit {
    VisionHubStorageExtended internal ps;

    struct Args {
        address newAddress;
        address newMappingAddress;
        uint newUint;
    }

    function init(Args memory args) external {
        // safety check to ensure, reinit is only called once
        require(
            ps.visionHubStorage.initialized == 1,
            "VisionHubRenit: contract is already initialized"
        );
        ps.visionHubStorage.initialized = 2;

        // initialising VisionHubStorage
        ps.newAddress = args.newAddress;
        ps.newMapping[args.newMappingAddress] = true;
        ps.newUint = args.newUint;
    }
}
