// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {AccessController} from "../src/access/AccessController.sol";
import {VisionTypes} from "../src/interfaces/VisionTypes.sol";
import {IVisionHub} from "../src/interfaces/IVisionHub.sol";
import {VisionBaseAddresses} from "./helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

/**
 * @title RegisterExternalTokens
 *
 * @notice Register newly deployed external tokens at the Vision hub of an
 * Ethereum-compatible blockchain.
 *
 * @dev Usage
 * forge script ./script/RegisterExternalTokens.s.sol --rpc-url <rpc alias> \
 * --sig "roleActions()" -vvvv
 *
 * This scripts expect all the address json files to be available at project
 * root dir.
 */
contract RegisterExternalTokens is VisionBaseAddresses, SafeAddresses {
    AccessController accessController;
    IVisionHub public visionHubProxy;

    function registerExternalToken(Blockchain memory otherBlockchain) private {
        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            if (
                keccak256(abi.encodePacked(tokenSymbols[i])) ==
                keccak256(abi.encodePacked("vsn"))
            ) {
                console2.log(
                    "(Skipping) %s; chain=%s",
                    tokenSymbols[i],
                    otherBlockchain.name
                );
                continue;
            }

            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            string memory externalToken = getContractAddressAsString(
                contract_,
                otherBlockchain.blockchainId
            );

            VisionTypes.ExternalTokenRecord
                memory externalTokenRecord = visionHubProxy
                    .getExternalTokenRecord(
                        token,
                        uint256(otherBlockchain.blockchainId)
                    );

            if (!externalTokenRecord.active) {
                visionHubProxy.registerExternalToken(
                    token,
                    uint256(otherBlockchain.blockchainId),
                    externalToken
                );
                console2.log(
                    "%s externally registered on chain=%s; externalToken=%s",
                    tokenSymbols[i],
                    otherBlockchain.name,
                    externalToken
                );
            } else {
                //  Check if already registered token matches with one in the json
                if (
                    keccak256(
                        abi.encodePacked(externalTokenRecord.externalToken)
                    ) != keccak256(abi.encodePacked(externalToken))
                ) {
                    console2.log(
                        "(Mismatch) %s already registered; chain=%s ; externalToken=%s",
                        tokenSymbols[i],
                        otherBlockchain.name,
                        externalTokenRecord.externalToken
                    );

                    visionHubProxy.unregisterExternalToken(
                        token,
                        uint256(otherBlockchain.blockchainId)
                    );
                    console2.log(
                        "VisionHub.unregisterExternalToken(%s, %s)",
                        token,
                        uint256(otherBlockchain.blockchainId)
                    );

                    visionHubProxy.registerExternalToken(
                        token,
                        uint256(otherBlockchain.blockchainId),
                        externalToken
                    );
                    console2.log(
                        "VisionHub.registerExternalToken(%s, %s, %s)",
                        token,
                        uint256(otherBlockchain.blockchainId),
                        externalToken
                    );
                } else {
                    console2.log(
                        "%s already registered; chain=%s ; externalToken=%s, "
                        "skipping registerExternalToken",
                        tokenSymbols[i],
                        otherBlockchain.name,
                        externalTokenRecord.externalToken
                    );
                }
            }
        }
    }

    function registerExternalTokens() private {
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );

            if (
                otherBlockchain.blockchainId !=
                determineBlockchain().blockchainId &&
                !otherBlockchain.skip
            ) {
                registerExternalToken(otherBlockchain);
            }
        }
    }

    function roleActions() public {
        readContractAddressesAllChains();

        visionHubProxy = IVisionHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        vm.startBroadcast(accessController.superCriticalOps());
        registerExternalTokens();

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
