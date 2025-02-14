// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {VisionTypes} from "../../src/interfaces/VisionTypes.sol";

interface IVisionTransferV2 {
    function transfer(
        VisionTypes.TransferRequest calldata request,
        bytes memory signature
    ) external returns (uint256);

    function transferFromV2(
        VisionTypes.TransferFromRequest calldata request,
        bytes memory signature,
        uint extraParam
    ) external returns (uint256);

    function transferToV2(
        VisionTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures,
        uint extraParam
    ) external returns (uint256);

    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view returns (bool);
}
