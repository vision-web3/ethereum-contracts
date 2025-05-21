// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {AccessController} from "../src/access/AccessController.sol";
import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
import {VisionTypes} from "../src/interfaces/VisionTypes.sol";
import {VisionBaseScript} from "./helpers/VisionBaseScript.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title RegisterExternalVisionTokens
 *
 * @notice Register external Vision tokens at the Vision hub on an
 * Ethereum-compatible blockchain.
 *
 * @dev Usage
 * forge script ./script/RegisterExternalVisionTokens.s.sol \
 * --rpc-url <rpc alias> --sig "roleActions(address, address)" \
 * <hubAddress> <accessControllerAddress> -vvvv
 *
 * This scripts expect the address json files to be available at project
 * root dir. The JSON file name should be <BLOCKCHAIN_NAME>-VSN.json
 * where <BLOCKCHAIN_NAME> is the name of the blockchain (e.g. "ETHEREUM").
 *
 */
contract RegisterExternalVisionTokens is VisionBaseScript, SafeAddresses {
    IVisionHub public visionHubProxy;
    AccessController public accessController;
    string private _jsonFileNameExtension = "-VSN.json";

    function readVisionAddress(
        Blockchain memory blockchain
    ) public view returns (address) {
        string memory path = string.concat(
            blockchain.name,
            _jsonFileNameExtension
        );
        console2.log("Reading %s", path);
        string memory json = vm.readFile(path);

        address token_address = vm.parseJsonAddress(json, ".vsn");
        return token_address;
    }

    function registerExternalToken(
        address _visionTokenAddress,
        Blockchain memory otherBlockchain,
        address _externalVisionTokenAddress
    ) private {
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = visionHubProxy.getExternalTokenRecord(
                _visionTokenAddress,
                uint256(otherBlockchain.blockchainId)
            );
        if (!externalTokenRecord.active) {
            visionHubProxy.registerExternalToken(
                _visionTokenAddress,
                uint256(otherBlockchain.blockchainId),
                Strings.toHexString(
                    uint256(uint160(_externalVisionTokenAddress)),
                    20
                )
            );
            console2.log(
                "Vision externally registered on chain=%s; externalTokenAddress=%s",
                otherBlockchain.name,
                _externalVisionTokenAddress
            );
        } else {
            //  Check if already registered token matches with one in the json
            if (
                keccak256(
                    abi.encodePacked(externalTokenRecord.externalToken)
                ) != keccak256(abi.encodePacked(_externalVisionTokenAddress))
            ) {
                console2.log(
                    "(Mismatch) Vision already registered; chain=%s ; externalToken=%s",
                    otherBlockchain.name,
                    externalTokenRecord.externalToken
                );

                visionHubProxy.unregisterExternalToken(
                    _visionTokenAddress,
                    uint256(otherBlockchain.blockchainId)
                );
                console2.log(
                    "VisionHub.unregisterExternalToken(%s, %s)",
                    _visionTokenAddress,
                    uint256(otherBlockchain.blockchainId)
                );

                visionHubProxy.registerExternalToken(
                    _visionTokenAddress,
                    uint256(otherBlockchain.blockchainId),
                    Strings.toHexString(
                        uint256(uint160(_externalVisionTokenAddress)),
                        20
                    )
                );
                console2.log(
                    "VisionHub.registerExternalToken(%s, %s, %s)",
                    _visionTokenAddress,
                    uint256(otherBlockchain.blockchainId),
                    _externalVisionTokenAddress
                );
            } else {
                console2.log(
                    "Vision already registered; chain=%s ; externalToken=%s, "
                    "skipping registerExternalToken",
                    otherBlockchain.name,
                    externalTokenRecord.externalToken
                );
            }
        }
    }

    function roleActions(
        address _hubAddress,
        address _accessController
    ) public {
        visionHubProxy = IVisionHub(_hubAddress);
        accessController = AccessController(_accessController);

        Blockchain memory currentBlockchain = determineBlockchain();
        address currentVisionTokenAddress = readVisionAddress(
            currentBlockchain
        );
        console2.log(
            "Current Vision token address: %s",
            currentVisionTokenAddress
        );
        address externalVisionTokenAddress;

        address superCriticalOps = accessController.superCriticalOps();
        vm.startBroadcast(superCriticalOps);

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));

            if (
                i == uint256(currentBlockchain.blockchainId) || blockchain.skip
            ) {
                console2.log(
                    "Skipping registration from %s on %s",
                    blockchain.name,
                    currentBlockchain.name
                );
                continue;
            }

            console2.log(
                "Registering external Vision token from %s on %s",
                blockchain.name,
                currentBlockchain.name
            );
            externalVisionTokenAddress = readVisionAddress(blockchain);

            registerExternalToken(
                currentVisionTokenAddress,
                blockchain,
                externalVisionTokenAddress
            );
        }
        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
