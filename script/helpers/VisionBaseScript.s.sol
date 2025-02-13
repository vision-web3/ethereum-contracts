// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

abstract contract VisionBaseScript is Script {
    enum BlockchainId {
        ETHEREUM, // 0
        BNB_CHAIN, // 1
        BITCOIN_RSK, // 2 : Decommissioned
        AVALANCHE, // 3
        SOLANA, // 4 : Inactive & Non EVM
        POLYGON, // 5
        CRONOS, // 6
        // Renamed from "FANTOM" to "SONIC" on 2024-10-16 due to
        // network renaming
        SONIC, // 7
        CELO, // 8
        AURORA // 9 : Decommissioned
    }

    struct Blockchain {
        BlockchainId blockchainId;
        string name;
        uint256 feeFactor;
        bool skip; // inactive/decommisioned/non evm chains
    }

    /// @dev Mapping of BlockchainId enum to Blockchain
    mapping(BlockchainId => Blockchain) private _blockchains;

    /// @dev Mapping of real chain id to Vision defined chain id enum
    mapping(uint256 => BlockchainId)
        private _chainIdToVisionBlockchainIdMapping;

    constructor() {
        _blockchains[BlockchainId.ETHEREUM] = Blockchain(
            BlockchainId.ETHEREUM,
            "ETHEREUM",
            98414000,
            false
        );
        _blockchains[BlockchainId.BNB_CHAIN] = Blockchain(
            BlockchainId.BNB_CHAIN,
            "BNB_CHAIN",
            896000,
            false
        );
        _blockchains[BlockchainId.BITCOIN_RSK] = Blockchain(
            BlockchainId.BITCOIN_RSK,
            "BITCOIN_RSK",
            0,
            true // Decommissioned
        );
        _blockchains[BlockchainId.AVALANCHE] = Blockchain(
            BlockchainId.AVALANCHE,
            "AVALANCHE",
            376000,
            false
        );
        _blockchains[BlockchainId.SOLANA] = Blockchain(
            BlockchainId.SOLANA,
            "SOLANA",
            0,
            true // Inactive & Non EVM
        );
        _blockchains[BlockchainId.POLYGON] = Blockchain(
            BlockchainId.POLYGON,
            "POLYGON",
            120000,
            false
        );
        _blockchains[BlockchainId.CRONOS] = Blockchain(
            BlockchainId.CRONOS,
            "CRONOS",
            120000,
            false
        );
        _blockchains[BlockchainId.SONIC] = Blockchain(
            BlockchainId.SONIC,
            "SONIC",
            24000,
            false
        );
        _blockchains[BlockchainId.CELO] = Blockchain(
            BlockchainId.CELO,
            "CELO",
            1000,
            false
        );
        _blockchains[BlockchainId.AURORA] = Blockchain(
            BlockchainId.AURORA,
            "AURORA",
            0,
            true
        ); // Inactive

        // Actual chain id mapping with Vision Hub defined chain id
        _chainIdToVisionBlockchainIdMapping[1] = BlockchainId.ETHEREUM; // Ethereum mainnet
        _chainIdToVisionBlockchainIdMapping[17000] = BlockchainId.ETHEREUM; // Ethereum testnet holesky
        _chainIdToVisionBlockchainIdMapping[31337] = BlockchainId.ETHEREUM; // Local Ethereum dev

        _chainIdToVisionBlockchainIdMapping[56] = BlockchainId.BNB_CHAIN; // Bsc mainnet
        _chainIdToVisionBlockchainIdMapping[97] = BlockchainId.BNB_CHAIN; // Bsc testnet
        _chainIdToVisionBlockchainIdMapping[31338] = BlockchainId.BNB_CHAIN; // Local Bnb dev

        _chainIdToVisionBlockchainIdMapping[43114] = BlockchainId.AVALANCHE; // Avax mainnet
        _chainIdToVisionBlockchainIdMapping[43113] = BlockchainId.AVALANCHE; // Avax testnet
        _chainIdToVisionBlockchainIdMapping[31339] = BlockchainId.AVALANCHE; // Local Avax dev

        _chainIdToVisionBlockchainIdMapping[137] = BlockchainId.POLYGON; // Polygon mainnet
        _chainIdToVisionBlockchainIdMapping[80002] = BlockchainId.POLYGON; // Polygon Amoy testnet
        _chainIdToVisionBlockchainIdMapping[31340] = BlockchainId.POLYGON; // Local Polygon dev

        _chainIdToVisionBlockchainIdMapping[25] = BlockchainId.CRONOS; // Cronos mainnet
        _chainIdToVisionBlockchainIdMapping[338] = BlockchainId.CRONOS; // Cronos testnet
        _chainIdToVisionBlockchainIdMapping[31341] = BlockchainId.CRONOS; // Local Cronos dev

        _chainIdToVisionBlockchainIdMapping[146] = BlockchainId.SONIC; // Sonic mainnet
        _chainIdToVisionBlockchainIdMapping[57054] = BlockchainId.SONIC; // Sonic testnet
        _chainIdToVisionBlockchainIdMapping[31342] = BlockchainId.SONIC; // Local Sonic dev

        _chainIdToVisionBlockchainIdMapping[42220] = BlockchainId.CELO; // Celo mainnet
        _chainIdToVisionBlockchainIdMapping[44787] = BlockchainId.CELO; // Celo testnet
        _chainIdToVisionBlockchainIdMapping[31343] = BlockchainId.CELO; // Local Celo dev

        Blockchain memory blockchain = determineBlockchain();

        console2.log(
            "Script will broadcast to chain id: %d; Vision blockchain:%s",
            getChainId(),
            blockchain.name
        );

        require(
            !blockchain.skip,
            "Deployement to this blockchain is marked as skipped!!"
        );
    }

    function getBlockchainById(
        BlockchainId id
    ) public view returns (Blockchain memory) {
        return _blockchains[id];
    }

    function determineBlockchain() public returns (Blockchain memory) {
        return _blockchains[_chainIdToVisionBlockchainIdMapping[getChainId()]];
    }

    function getChainId() public returns (uint256) {
        bytes memory chainByte = vm.rpc("eth_chainId", "[]");
        return vm.parseUint(vm.toString(chainByte));
    }

    function getBlockchainsLength() public pure returns (uint256) {
        return uint256(type(BlockchainId).max) + 1;
    }
}
