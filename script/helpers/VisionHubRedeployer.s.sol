// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {VisionTypes} from "../../src/interfaces/VisionTypes.sol";
import {IVisionHub} from "../../src/interfaces/IVisionHub.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {VisionHubDeployer} from "../helpers/VisionHubDeployer.s.sol";

abstract contract VisionHubRedeployer is VisionHubDeployer {
    bool private _initialized;
    /// @dev Mapping of BlockchainId enum to map of tokens to external tokens addresses
    mapping(address => mapping(BlockchainId => VisionTypes.ExternalTokenRecord))
        private _ownedToExternalTokens;
    VisionToken[] private _ownedTokens;
    IVisionHub private _oldVisionHub;
    VisionToken private _visionToken;

    modifier onlyVisionHubRedeployerInitialized() {
        require(_initialized, "VisionHubRedeployer: not initialized");
        _;
    }

    function initializeVisionHubRedeployer(IVisionHub oldVisionHub) public {
        _initialized = true;
        _oldVisionHub = oldVisionHub;
        _visionToken = VisionToken(_oldVisionHub.getVisionToken());
        readOwnedAndExternalTokensFromOldVisionHub(_oldVisionHub);
    }

    function readOwnedAndExternalTokensFromOldVisionHub(
        IVisionHub visionHubProxy
    ) private {
        Blockchain memory blockchain = determineBlockchain();
        address[] memory tokens = visionHubProxy.getTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            VisionToken token = VisionToken(tokens[i]);
            if (token.owner() == msg.sender) {
                console2.log("adding %s to owned tokens", token.symbol());
                _ownedTokens.push(token);
                for (
                    uint256 blockchainId;
                    blockchainId < getBlockchainsLength();
                    blockchainId++
                ) {
                    Blockchain memory otherBlockchain = getBlockchainById(
                        BlockchainId(blockchainId)
                    );
                    if (
                        otherBlockchain.blockchainId !=
                        blockchain.blockchainId &&
                        !otherBlockchain.skip
                    ) {
                        VisionTypes.ExternalTokenRecord
                            memory externalTokenRecord = visionHubProxy
                                .getExternalTokenRecord(
                                    tokens[i],
                                    blockchainId
                                );
                        _ownedToExternalTokens[tokens[i]][
                            BlockchainId(blockchainId)
                        ] = externalTokenRecord;
                    }
                }
            } else {
                console2.log(
                    "skipped adding %s to owned tokens; owner: %s;"
                    " address: %s",
                    token.symbol(),
                    token.owner(),
                    address(token)
                );
            }
        }
    }

    function migrateTokensFromOldHubToNewHub(
        IVisionHub newVisionHub
    ) public onlyVisionHubRedeployerInitialized {
        console2.log(
            "Migrating %d tokens from the old VisionHub to the new one",
            _ownedTokens.length
        );

        for (uint256 i = 0; i < _ownedTokens.length; i++) {
            if (address(_ownedTokens[i]) != address(_visionToken)) {
                registerTokenAtNewHub(newVisionHub, _ownedTokens[i]);
            }
            for (
                uint256 blockchainId;
                blockchainId < getBlockchainsLength();
                blockchainId++
            ) {
                Blockchain memory blockchain = getBlockchainById(
                    BlockchainId(blockchainId)
                );
                if (!blockchain.skip) {
                    VisionTypes.ExternalTokenRecord
                        memory externalTokenRecord = _ownedToExternalTokens[
                            address(_ownedTokens[i])
                        ][BlockchainId(blockchainId)];
                    if (externalTokenRecord.active) {
                        registerExternalTokenAtNewHub(
                            newVisionHub,
                            _ownedTokens[i],
                            blockchainId,
                            externalTokenRecord.externalToken
                        );
                    }
                }
            }
        }
        // unregister tokens from old hub after all registered at new hub
        unregisterTokensFromOldHub();
    }

    function registerTokenAtNewHub(
        IVisionHub newVisionHub,
        VisionToken token
    ) public onlyVisionHubRedeployerInitialized {
        VisionTypes.TokenRecord memory tokenRecord = newVisionHub
            .getTokenRecord(address(token));
        if (!tokenRecord.active) {
            newVisionHub.registerToken(address(token));
            console2.log("New VisionHub.registerToken(%s)", address(token));
        } else {
            console2.log(
                "Token already registered; skipping registerToken(%s)",
                address(token)
            );
        }
    }

    function registerExternalTokenAtNewHub(
        IVisionHub newVisionHub,
        VisionToken token,
        uint256 blockchainId,
        string memory externalToken
    ) public onlyVisionHubRedeployerInitialized {
        VisionTypes.ExternalTokenRecord
            memory externalTokenRecord = newVisionHub.getExternalTokenRecord(
                address(token),
                blockchainId
            );

        if (!externalTokenRecord.active) {
            newVisionHub.registerExternalToken(
                address(token),
                blockchainId,
                externalToken
            );
            console2.log(
                "New VisionHub.registerExternalToken(%s, %d, %s)",
                address(token),
                blockchainId,
                externalToken
            );
        } else {
            console2.log(
                "External token already registered;"
                "skipping VisionHub.registerExternalToken(%s, %d, %s)",
                address(token),
                blockchainId,
                externalToken
            );
        }
    }

    function unregisterTokensFromOldHub()
        public
        onlyVisionHubRedeployerInitialized
    {
        console2.log(
            "Unregistering %d tokens from the old VisionHub",
            _ownedTokens.length
        );
        for (uint256 i = 0; i < _ownedTokens.length; i++) {
            VisionTypes.TokenRecord memory tokenRecord = _oldVisionHub
                .getTokenRecord(address(_ownedTokens[i]));
            if (tokenRecord.active) {
                _oldVisionHub.unregisterToken(address(_ownedTokens[i]));
                console2.log(
                    "Unregistered token %s from the old VisionHub",
                    address(_ownedTokens[i])
                );
            } else {
                console2.log(
                    "Already unregistered token %s from the old VisionHub",
                    address(_ownedTokens[i])
                );
            }
        }
    }
}
