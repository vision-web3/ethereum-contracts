// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {VisionTypes} from "./interfaces/VisionTypes.sol";

/**
 * @notice Vision Hub storage state variables.
 * Used as App Storage struct for Vision Hub Diamond Proxy implementation.
 */
struct VisionHubStorage {
    uint64 initialized;
    bool paused;
    address visionForwarder;
    address visionToken;
    address primaryValidatorNodeAddress;
    uint256 numberBlockchains;
    uint256 numberActiveBlockchains;
    uint256 currentBlockchainId;
    mapping(uint256 => VisionTypes.BlockchainRecord) blockchainRecords;
    VisionTypes.UpdatableUint256 minimumServiceNodeDeposit;
    address[] tokens;
    mapping(address => uint256) tokenIndices;
    mapping(address => VisionTypes.TokenRecord) tokenRecords;
    // Token address => blockchain ID => external token record
    mapping(address => mapping(uint256 => VisionTypes.ExternalTokenRecord)) externalTokenRecords;
    address[] serviceNodes;
    mapping(address => uint256) serviceNodeIndices;
    mapping(address => VisionTypes.ServiceNodeRecord) serviceNodeRecords;
    uint256 nextTransferId;
    // Source blockchain ID => source transfer ID => already used?
    mapping(uint256 => mapping(uint256 => bool)) usedSourceTransferIds;
    mapping(uint256 => VisionTypes.UpdatableUint256) validatorFeeFactors;
    VisionTypes.UpdatableUint256 parameterUpdateDelay;
    VisionTypes.UpdatableUint256 unbondingPeriodServiceNodeDeposit;
    mapping(bytes32 => bool) isServiceNodeUrlUsed;
    bytes32 protocolVersion;
    mapping(address => VisionTypes.Commitment) commitments;
    uint256 commitmentWaitPeriod;
}
