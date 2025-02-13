// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {VisionTypes} from "../../src/interfaces/VisionTypes.sol";
import {IVisionTransferV2} from "./IVisionTransferV2.sol";
import {VisionBaseFacet} from "../../src/facets/VisionBaseFacet.sol";

contract VisionTransferV2Facet is IVisionTransferV2, VisionBaseFacet {
    function transfer(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) external override returns (uint256) {
        (request);
        (signature);
        return s.nextTransferId++;
    }

    function transferFromV2(
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature,
        uint extraParam
    ) external override returns (uint256) {
        (request);
        (signature);
        (extraParam);
        return s.nextTransferId++;
    }

    function transferToV2(
        VisionTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures,
        uint extraParam
    ) external override returns (uint256) {
        (request);
        (signerAddresses);
        (signatures);
        (extraParam);
        return s.nextTransferId++;
    }

    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view override returns (bool) {
        (sender);
        (nonce);
        (s);
        return true;
    }
}
