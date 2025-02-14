// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {VisionForwarder} from "../../src/VisionForwarder.sol";
import {VisionToken} from "../../src/VisionToken.sol";
import {BitpandaEcosystemToken} from "../../src/BitpandaEcosystemToken.sol";
import {VisionWrapper} from "../../src/VisionWrapper.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {VisionTypes} from "../../src/interfaces/VisionTypes.sol";
import {VisionHubProxy} from "../../src/VisionHubProxy.sol";
import {VisionHubInit} from "../../src/upgradeInitializers/VisionHubInit.sol";
import {VisionRegistryFacet} from "../../src/facets/VisionRegistryFacet.sol";
import {VisionTransferFacet} from "../../src/facets/VisionTransferFacet.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";

import {VisionFacets} from "../helpers/VisionHubDeployer.s.sol";

import {VisionBaseScript} from "./VisionBaseScript.s.sol";

abstract contract VisionBaseAddresses is VisionBaseScript {
    enum Contract {
        GENERIC,
        HUB_PROXY,
        HUB_INIT,
        DIAMOND_CUT_FACET,
        DIAMOND_LOUPE_FACET,
        REGISTRY_FACET,
        TRANSFER_FACET,
        FORWARDER,
        ACCESS_CONTROLLER,
        BEST,
        VSN,
        VSN_MIGRATOR,
        VSN_AVAX,
        VSN_BNB,
        VSN_CELO,
        VSN_CRO,
        VSN_ETH,
        VSN_POL,
        VSN_S
    }

    struct ContractInfo {
        string key;
        address address_;
        bool isToken;
    }

    struct CurrentChainContractInfo {
        ContractInfo contractInfo;
        address newAddress;
    }

    struct ContractAddress {
        Contract contract_;
        address address_;
    }

    string private constant _addressesJsonExtention = ".json";
    string private constant _redeployedAddressesJsonExtention =
        "-REDEPLOY.json";

    string private constant _contractSerializer = "address";

    mapping(BlockchainId => mapping(Contract => ContractInfo))
        internal _otherChaincontractInfo;
    mapping(Contract => CurrentChainContractInfo)
        internal _currentChainContractInfo;
    mapping(string => Contract) internal _keysToContracts;

    Blockchain private thisBlockchain;

    function getContractAddress(
        Contract contract_,
        bool isRedeployed
    ) public view returns (address) {
        address contractAddress;
        if (isRedeployed) {
            contractAddress = _currentChainContractInfo[contract_].newAddress;
        } else {
            contractAddress = _currentChainContractInfo[contract_]
                .contractInfo
                .address_;
        }
        require(contractAddress != address(0), "Error: Address is zero");
        return contractAddress;
    }

    function getContractAddress(
        Contract contract_,
        BlockchainId otherBlockchainId
    ) public view returns (address) {
        require(
            otherBlockchainId != thisBlockchain.blockchainId,
            "Error: Same blockchain"
        );
        address contractAddress = _otherChaincontractInfo[otherBlockchainId][
            contract_
        ].address_;
        require(contractAddress != address(0), "Error: Address is zero");
        return contractAddress;
    }

    function getContractAddressAsString(
        Contract contract_,
        BlockchainId otherBlockchainId
    ) public view returns (string memory) {
        return vm.toString(getContractAddress(contract_, otherBlockchainId));
    }

    function readContractAddresses(Blockchain memory blockchain) public {
        string memory path = string.concat(
            blockchain.name,
            _addressesJsonExtention
        );
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        for (uint256 i = 0; i < keys.length; i++) {
            address address_ = vm.parseJsonAddress(
                json,
                string.concat(".", keys[i])
            );
            if (blockchain.blockchainId == thisBlockchain.blockchainId) {
                _currentChainContractInfo[_keysToContracts[keys[i]]]
                    .contractInfo
                    .address_ = address_;
            } else {
                _otherChaincontractInfo[blockchain.blockchainId][
                    _keysToContracts[keys[i]]
                ].address_ = address_;
            }
        }
    }

    function readRedeployedContractAddresses() public {
        string memory path = string.concat(
            thisBlockchain.name,
            _redeployedAddressesJsonExtention
        );
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        for (uint256 i = 0; i < keys.length; i++) {
            address address_ = vm.parseJsonAddress(
                json,
                string.concat(".", keys[i])
            );
            _currentChainContractInfo[_keysToContracts[keys[i]]]
                .newAddress = address_;
        }
    }

    function readContractAddressesAllChains() public {
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                readContractAddresses(blockchain);
            }
        }
    }

    function exportContractAddresses(
        ContractAddress[] memory contractAddresses,
        bool isRedeployed
    ) public {
        // this makes sense only for old addresses
        string memory blockchainName = thisBlockchain.name;
        string memory addresses;
        for (uint256 i; i < contractAddresses.length - 1; i++) {
            CurrentChainContractInfo
                memory currentChainContractInfo = _currentChainContractInfo[
                    contractAddresses[i].contract_
                ];
            vm.serializeAddress(
                _contractSerializer,
                currentChainContractInfo.contractInfo.key,
                contractAddresses[i].address_
            );
        }
        CurrentChainContractInfo
            memory currentChainContractInfo_ = _currentChainContractInfo[
                contractAddresses[contractAddresses.length - 1].contract_
            ];
        addresses = vm.serializeAddress(
            _contractSerializer,
            currentChainContractInfo_.contractInfo.key,
            contractAddresses[contractAddresses.length - 1].address_
        );
        string memory jsonExtention = isRedeployed
            ? _redeployedAddressesJsonExtention
            : _addressesJsonExtention;
        vm.writeJson(addresses, string.concat(blockchainName, jsonExtention));
    }

    function overrideWithRedeployedAddresses() public {
        string memory path = string.concat(
            thisBlockchain.name,
            _addressesJsonExtention
        );
        string memory redeployPath = string.concat(
            thisBlockchain.name,
            _redeployedAddressesJsonExtention
        );
        string memory jsonRedeploy = vm.readFile(redeployPath);
        string[] memory redeployKeys = vm.parseJsonKeys(jsonRedeploy, "$");
        for (uint256 i = 0; i < redeployKeys.length; i++) {
            string memory key = string.concat(".", redeployKeys[i]);
            string memory address_ = vm.parseJsonString(jsonRedeploy, key);
            vm.writeJson(address_, path, key);
        }
    }

    function getTokenSymbols() public view returns (string[] memory) {
        uint256 length = getContractsLength();
        string[] memory tokenSymbols = new string[](length);
        uint256 count = 0;
        for (uint256 i = 0; i < length; i++) {
            CurrentChainContractInfo
                memory currentContractInfo = _currentChainContractInfo[
                    Contract(i)
                ];
            if (currentContractInfo.contractInfo.isToken) {
                tokenSymbols[count] = currentContractInfo.contractInfo.key;
                count++;
            }
        }
        // Resize the array to the actual number of token symbols
        string[] memory result = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokenSymbols[i];
        }
        return result;
    }

    function getContractsLength() public pure returns (uint256) {
        return uint256(type(Contract).max) + 1;
    }

    constructor() {
        thisBlockchain = determineBlockchain();

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );
            if (
                otherBlockchain.blockchainId != thisBlockchain.blockchainId &&
                !otherBlockchain.skip
            ) {
                BlockchainId blockchainId = BlockchainId(i);
                _otherChaincontractInfo[blockchainId][
                    Contract.HUB_PROXY
                ] = _getHubProxyContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.HUB_INIT
                ] = _getHubInitContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.DIAMOND_CUT_FACET
                ] = _getDiamondCutFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.DIAMOND_LOUPE_FACET
                ] = _getDiamondLoupeFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.REGISTRY_FACET
                ] = _getRegistryFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.TRANSFER_FACET
                ] = _getTransferFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.FORWARDER
                ] = _getForwarderContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.ACCESS_CONTROLLER
                ] = _getAccessControllerContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.BEST
                ] = _getBestContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN
                ] = _getVsnContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_MIGRATOR
                ] = _getVsnMigratorContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_AVAX
                ] = _getVsnAVAXContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_BNB
                ] = _getVsnBNBContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_CELO
                ] = _getVsnCELOContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_CRO
                ] = _getVsnCROContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_ETH
                ] = _getVsnETHContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_S
                ] = _getVsnSContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.VSN_POL
                ] = _getVsnPOLContractInfo();
            }
        }
        _currentChainContractInfo[
            Contract.HUB_PROXY
        ] = CurrentChainContractInfo(_getHubProxyContractInfo(), address(0));
        _currentChainContractInfo[
            Contract.HUB_INIT
        ] = CurrentChainContractInfo(_getHubInitContractInfo(), address(0));
        _currentChainContractInfo[
            Contract.DIAMOND_CUT_FACET
        ] = CurrentChainContractInfo(
            _getDiamondCutFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.DIAMOND_LOUPE_FACET
        ] = CurrentChainContractInfo(
            _getDiamondLoupeFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.REGISTRY_FACET
        ] = CurrentChainContractInfo(
            _getRegistryFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.TRANSFER_FACET
        ] = CurrentChainContractInfo(
            _getTransferFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.FORWARDER
        ] = CurrentChainContractInfo(_getForwarderContractInfo(), address(0));
        _currentChainContractInfo[
            Contract.ACCESS_CONTROLLER
        ] = CurrentChainContractInfo(
            _getAccessControllerContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.BEST] = CurrentChainContractInfo(
            _getBestContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.VSN] = CurrentChainContractInfo(
            _getVsnContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.VSN_MIGRATOR
        ] = CurrentChainContractInfo(
            _getVsnMigratorContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.VSN_AVAX
        ] = CurrentChainContractInfo(_getVsnAVAXContractInfo(), address(0));
        _currentChainContractInfo[Contract.VSN_BNB] = CurrentChainContractInfo(
            _getVsnBNBContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.VSN_CELO
        ] = CurrentChainContractInfo(_getVsnCELOContractInfo(), address(0));
        _currentChainContractInfo[Contract.VSN_CRO] = CurrentChainContractInfo(
            _getVsnCROContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.VSN_ETH] = CurrentChainContractInfo(
            _getVsnETHContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.VSN_S] = CurrentChainContractInfo(
            _getVsnSContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.VSN_POL] = CurrentChainContractInfo(
            _getVsnPOLContractInfo(),
            address(0)
        );
        for (uint256 i; i < getContractsLength(); i++) {
            _keysToContracts[
                _currentChainContractInfo[Contract(i)].contractInfo.key
            ] = Contract(i);
        }
    }

    function _getHubProxyContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory hubProxyContractInfo = ContractInfo(
            "hub_proxy",
            address(0),
            false
        );
        return hubProxyContractInfo;
    }

    function _getHubInitContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory hubInitContractInfo = ContractInfo(
            "hub_init",
            address(0),
            false
        );
        return hubInitContractInfo;
    }

    function _getDiamondCutFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory diamondCutFacetContractInfo = ContractInfo(
            "diamond_cut_facet",
            address(0),
            false
        );
        return diamondCutFacetContractInfo;
    }

    function _getDiamondLoupeFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory diamondLoupeFacetContractInfo = ContractInfo(
            "diamond_loupe_facet",
            address(0),
            false
        );
        return diamondLoupeFacetContractInfo;
    }

    function _getRegistryFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory registryFacetContractInfo = ContractInfo(
            "registry_facet",
            address(0),
            false
        );
        return registryFacetContractInfo;
    }

    function _getTransferFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory transferFacetContractInfo = ContractInfo(
            "transfer_facet",
            address(0),
            false
        );
        return transferFacetContractInfo;
    }

    function _getForwarderContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory forwarderContractInfo = ContractInfo(
            "forwarder",
            address(0),
            false
        );
        return forwarderContractInfo;
    }

    function _getAccessControllerContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory accessControllerContractInfo = ContractInfo(
            "access_controller",
            address(0),
            false
        );
        return accessControllerContractInfo;
    }

    function _getBestContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory bestContractInfo = ContractInfo(
            "best",
            address(0),
            true
        );
        return bestContractInfo;
    }

    function _getVsnContractInfo() private pure returns (ContractInfo memory) {
        ContractInfo memory vsnContractInfo = ContractInfo(
            "vsn",
            address(0),
            true
        );
        return vsnContractInfo;
    }

    function _getVsnMigratorContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnMigratorContractInfo = ContractInfo(
            "vsn_migrator",
            address(0),
            false
        );
        return vsnMigratorContractInfo;
    }

    function _getVsnAVAXContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnAVAXContractInfo = ContractInfo(
            "vsnAVAX",
            address(0),
            true
        );
        return vsnAVAXContractInfo;
    }

    function _getVsnBNBContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnBNBContractInfo = ContractInfo(
            "vsnBNB",
            address(0),
            true
        );
        return vsnBNBContractInfo;
    }

    function _getVsnCELOContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnCELOContractInfo = ContractInfo(
            "vsnCELO",
            address(0),
            true
        );
        return vsnCELOContractInfo;
    }

    function _getVsnCROContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnCROContractInfo = ContractInfo(
            "vsnCRO",
            address(0),
            true
        );
        return vsnCROContractInfo;
    }

    function _getVsnETHContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnETHContractInfo = ContractInfo(
            "vsnETH",
            address(0),
            true
        );
        return vsnETHContractInfo;
    }

    function _getVsnSContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnSContractInfo = ContractInfo(
            "vsnS",
            address(0),
            true
        );
        return vsnSContractInfo;
    }

    function _getVsnPOLContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory vsnPOLContractInfo = ContractInfo(
            "vsnPOL",
            address(0),
            true
        );
        return vsnPOLContractInfo;
    }
}
