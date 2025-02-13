// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {VisionHubStorage} from "../../src/VisionHubStorage.sol";
import {VisionBaseFacet} from "../../src/facets/VisionBaseFacet.sol";

// This is just for testing purpose, new fields should be directly added to
// VisionHubStorage at the end.
struct VisionHubStorageExtended {
    VisionHubStorage visionHubStorage;
    address newAddress;
    mapping(address => bool) newMapping;
    uint newUint;
}

contract DummyFacet {
    // Extended App Storage
    VisionHubStorageExtended internal s;

    function setNewAddress(address addr) public {
        s.newAddress = addr;
    }

    function setNewMapping(address addr) public {
        s.newMapping[addr] = true;
    }

    function setNewUint(uint num) public {
        s.newUint = num;
    }

    function getNewAddress() public view returns (address) {
        return s.newAddress;
    }

    function isNewMappingEntryForAddress(
        address addr
    ) public view returns (bool) {
        return s.newMapping[addr];
    }

    function getNewUint() public view returns (uint) {
        return s.newUint;
    }
}
