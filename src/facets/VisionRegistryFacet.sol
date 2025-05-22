// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {VisionRoles} from "../access/VisionRoles.sol";
import {VisionTypes} from "../interfaces/VisionTypes.sol";
import {IVisionForwarder} from "../interfaces/IVisionForwarder.sol";
import {IVisionToken} from "../interfaces/IVisionToken.sol";
import {IVisionRegistry} from "../interfaces/IVisionRegistry.sol";

import {VisionBaseFacet} from "./VisionBaseFacet.sol";

/**
 * @title Vision Registry facet
 *
 * @notice See {IVisionRegistry}.
 */
contract VisionRegistryFacet is IVisionRegistry, VisionBaseFacet {
    /**
     * @dev See {IVisionRegistry-commitHash}.
     */
    function commitHash(bytes32 hash) external override whenNotPaused {
        s.commitments[msg.sender].hash = hash;
        s.commitments[msg.sender].blockNumber = block.number;
        emit HashCommited(msg.sender, hash);
    }

    /**
     * @dev See {IVisionRegistry-setCommitmentWaitPeriod}.
     */
    function setCommitmentWaitPeriod(
        uint256 commitmentWaitPeriod
    )
        external
        override
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        s.commitmentWaitPeriod = commitmentWaitPeriod;
        emit CommitmentWaitPeriodUpdated(commitmentWaitPeriod);
    }

    /**
     * @dev See {IVisionRegistry-getCommitmentWaitPeriod}.
     */
    function getCommitmentWaitPeriod()
        external
        view
        override
        returns (uint256)
    {
        return s.commitmentWaitPeriod;
    }

    /**
     * @dev See {IVisionRegistry-pause}.
     */
    function pause()
        external
        override
        whenNotPaused
        onlyRole(VisionRoles.PAUSER_ROLE)
    {
        s.paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev See {IVisionRegistry-unpause}.
     */
    // slither-disable-next-line timestamp
    function unpause()
        external
        override
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        require(
            s.visionForwarder != address(0),
            "VisionHub: VisionForwarder has not been set"
        );
        require(
            s.visionToken != address(0),
            "VisionHub: VisionToken has not been set"
        );
        require(
            s.primaryValidatorNodeAddress != address(0),
            "VisionHub: primary validator node has not been set"
        );
        require(
            s.commitmentWaitPeriod != 0,
            "VisionHub: commitment wait period has not been set"
        );
        s.paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @dev See {IVisionRegistry-setVisionForwarder}.
     */
    // slither-disable-next-line timestamp
    function setVisionForwarder(
        address visionForwarder
    )
        external
        override
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        require(
            visionForwarder != address(0),
            "VisionHub: VisionForwarder must not be the zero account"
        );
        s.visionForwarder = visionForwarder;
        emit VisionForwarderSet(visionForwarder);
    }

    /**
     * @dev See {IVisionRegistry-setVisionToken}.
     */
    // slither-disable-next-line timestamp
    function setVisionToken(
        address visionToken
    )
        external
        override
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        require(
            visionToken != address(0),
            "VisionHub: VisionToken must not be the zero account"
        );
        require(
            s.visionToken == address(0),
            "VisionHub: VisionToken already set"
        );
        s.visionToken = visionToken;
        emit VisionTokenSet(visionToken);
        registerToken(visionToken);
    }

    /**
     * @dev See {IVisionRegistry-setPrimaryValidatorNode}.
     */
    function setPrimaryValidatorNode(
        address primaryValidatorNodeAddress
    )
        external
        override
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        require(
            primaryValidatorNodeAddress != address(0),
            "VisionHub: primary validator node address must not be zero"
        );
        s.primaryValidatorNodeAddress = primaryValidatorNodeAddress;
        emit PrimaryValidatorNodeUpdated(primaryValidatorNodeAddress);
    }

    /**
     * @dev See {IVisionRegistry-setProtocolVersion}.
     */
    function setProtocolVersion(
        bytes32 protocolVersion
    )
        external
        override
        whenPaused
        onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE)
    {
        require(
            protocolVersion != bytes32(0),
            "VisionHub: protocol version must not be zero"
        );
        s.protocolVersion = protocolVersion;
        emit ProtocolVersionUpdated(protocolVersion);
    }

    /**
     * @dev See {IVisionRegistry-registerBlockchain}.
     */
    function registerBlockchain(
        uint256 blockchainId,
        string calldata name,
        uint256 validatorFeeFactor
    ) external override onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE) {
        require(
            bytes(name).length > 0,
            "VisionHub: blockchain name must not be empty"
        );
        VisionTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            !blockchainRecord.active,
            "VisionHub: blockchain already registered"
        );
        blockchainRecord.active = true;
        blockchainRecord.name = name;
        _initializeUpdatableUint256(
            s.validatorFeeFactors[blockchainId],
            validatorFeeFactor
        );
        if (blockchainId >= s.numberBlockchains)
            s.numberBlockchains = blockchainId + 1;
        s.numberActiveBlockchains++;
        emit BlockchainRegistered(blockchainId, validatorFeeFactor);
    }

    /**
     * @dev See {IVisionRegistry-unregisterBlockchain}.
     */
    // slither-disable-next-line timestamp
    function unregisterBlockchain(
        uint256 blockchainId
    ) external override onlyRole(VisionRoles.SUPER_CRITICAL_OPS_ROLE) {
        // Validate the input parameter
        require(
            blockchainId != s.currentBlockchainId,
            "VisionHub: blockchain ID must not be the current blockchain ID"
        );
        // Validate the stored blockchain data
        VisionTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "VisionHub: blockchain must be active"
        );
        assert(blockchainId < s.numberBlockchains);
        // Update the blockchain record
        blockchainRecord.active = false;
        // s.numberBlockchains is not updated since also a once registered but
        // now inactive blockchain counts (it keeps its blockchainId in case it
        // is registered again)
        assert(s.numberActiveBlockchains > 0);
        s.numberActiveBlockchains--;
        emit BlockchainUnregistered(blockchainId);
    }

    /**
     * @dev See {IVisionRegistry-updateBlockchainName}.
     */
    // slither-disable-next-line timestamp
    function updateBlockchainName(
        uint256 blockchainId,
        string calldata name
    )
        external
        override
        whenPaused
        onlyRole(VisionRoles.MEDIUM_CRITICAL_OPS_ROLE)
    {
        // Validate the input parameters
        require(
            bytes(name).length > 0,
            "VisionHub: blockchain name must not be empty"
        );
        // Validate the stored blockchain data
        VisionTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "VisionHub: blockchain must be active"
        );
        assert(blockchainId < s.numberBlockchains);
        // Update the blockchain record
        blockchainRecord.name = name;
        emit BlockchainNameUpdated(blockchainId);
    }

    /**
     * @dev See {IVisionRegistry-initiateValidatorFeeFactorUpdate}.
     */
    // slither-disable-next-line timestamp
    function initiateValidatorFeeFactorUpdate(
        uint256 blockchainId,
        uint256 newValidatorFeeFactor
    ) external override onlyRole(VisionRoles.MEDIUM_CRITICAL_OPS_ROLE) {
        require(
            newValidatorFeeFactor >= 1,
            "VisionHub: new validator fee factor must be >= 1"
        );
        require(
            s.blockchainRecords[blockchainId].active,
            "VisionHub: blockchain must be active"
        );
        VisionTypes.UpdatableUint256 storage validatorFeeFactor = s
            .validatorFeeFactors[blockchainId];
        _initiateUpdatableUint256Update(
            validatorFeeFactor,
            newValidatorFeeFactor
        );
        emit ValidatorFeeFactorUpdateInitiated(
            blockchainId,
            newValidatorFeeFactor,
            validatorFeeFactor.updateTime
        );
    }

    /**
     * @dev See {IVisionRegistry-executeValidatorFeeFactorUpdate}.
     */
    // slither-disable-next-line timestamp
    function executeValidatorFeeFactorUpdate(
        uint256 blockchainId
    ) external override {
        require(
            s.blockchainRecords[blockchainId].active,
            "VisionHub: blockchain must be active"
        );
        VisionTypes.UpdatableUint256 storage validatorFeeFactor = s
            .validatorFeeFactors[blockchainId];
        _executeUpdatableUint256Update(validatorFeeFactor);
        emit ValidatorFeeFactorUpdateExecuted(
            blockchainId,
            validatorFeeFactor.currentValue
        );
    }

    /**
     * @dev See
     * {IVisionRegistry-initiateUnbondingPeriodServiceNodeDepositUpdate}.
     */
    function initiateUnbondingPeriodServiceNodeDepositUpdate(
        uint256 newUnbondingPeriodServiceNodeDeposit
    ) external override onlyRole(VisionRoles.MEDIUM_CRITICAL_OPS_ROLE) {
        _initiateUpdatableUint256Update(
            s.unbondingPeriodServiceNodeDeposit,
            newUnbondingPeriodServiceNodeDeposit
        );
        emit UnbondingPeriodServiceNodeDepositUpdateInitiated(
            newUnbondingPeriodServiceNodeDeposit,
            s.unbondingPeriodServiceNodeDeposit.updateTime
        );
    }

    /**
     * @dev See
     * {IVisionRegistry-executeUnbondingPeriodServiceNodeDepositUpdate}.
     */
    function executeUnbondingPeriodServiceNodeDepositUpdate()
        external
        override
    {
        _executeUpdatableUint256Update(s.unbondingPeriodServiceNodeDeposit);
        emit UnbondingPeriodServiceNodeDepositUpdateExecuted(
            s.unbondingPeriodServiceNodeDeposit.currentValue
        );
    }

    /**
     * @dev See {IVisionRegistry-initiateMinimumServiceNodeDepositUpdate}.
     */
    function initiateMinimumServiceNodeDepositUpdate(
        uint256 newMinimumServiceNodeDeposit
    ) external override onlyRole(VisionRoles.MEDIUM_CRITICAL_OPS_ROLE) {
        _initiateUpdatableUint256Update(
            s.minimumServiceNodeDeposit,
            newMinimumServiceNodeDeposit
        );
        emit MinimumServiceNodeDepositUpdateInitiated(
            newMinimumServiceNodeDeposit,
            s.minimumServiceNodeDeposit.updateTime
        );
    }

    /**
     * @dev See {IVisionRegistry-executeMinimumServiceNodeDepositUpdate}.
     */
    function executeMinimumServiceNodeDepositUpdate() external override {
        _executeUpdatableUint256Update(s.minimumServiceNodeDeposit);
        emit MinimumServiceNodeDepositUpdateExecuted(
            s.minimumServiceNodeDeposit.currentValue
        );
    }

    /**
     * @dev See {IVisionRegistry-initiateParameterUpdateDelayUpdate}.
     */
    function initiateParameterUpdateDelayUpdate(
        uint256 newParameterUpdateDelay
    ) external override onlyRole(VisionRoles.MEDIUM_CRITICAL_OPS_ROLE) {
        _initiateUpdatableUint256Update(
            s.parameterUpdateDelay,
            newParameterUpdateDelay
        );
        emit ParameterUpdateDelayUpdateInitiated(
            newParameterUpdateDelay,
            s.parameterUpdateDelay.updateTime
        );
    }

    /**
     * @dev See {IVisionRegistry-executeParameterUpdateDelayUpdate}.
     */
    function executeParameterUpdateDelayUpdate() external override {
        _executeUpdatableUint256Update(s.parameterUpdateDelay);
        emit ParameterUpdateDelayUpdateExecuted(
            s.parameterUpdateDelay.currentValue
        );
    }

    /**
     * @dev See {IVisionRegistry-registerToken}.
     */
    // slither-disable-next-line timestamp
    function registerToken(
        address token
    ) public override superCriticalOpsOrNotPaused {
        // Validate the input parameters
        require(
            token != address(0),
            "VisionHub: token must not be the zero account"
        );
        // Only the token owner is allowed to register the token
        require(
            IVisionToken(token).getOwner() == msg.sender,
            "VisionHub: caller is not the token owner"
        );
        require(
            IVisionToken(token).getVisionForwarder() == s.visionForwarder,
            "VisionHub: VisionForwarder must match"
        );
        // Validate the stored token data
        VisionTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(!tokenRecord.active, "VisionHub: token must not be active");
        // Store the token record
        tokenRecord.active = true;
        s.tokenIndices[token] = s.tokens.length;
        s.tokens.push(token);
        emit TokenRegistered(token);
    }

    /**
     * @dev See {IVisionRegistry-unregisterToken}.
     */
    // slither-disable-next-line timestamp
    function unregisterToken(
        address token
    ) public override superCriticalOpsOrNotPaused {
        // Validate the stored token data
        VisionTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "VisionHub: token must be active");
        require(
            IVisionToken(token).getOwner() == msg.sender,
            "VisionHub: caller is not the token owner"
        );
        // Update the token record
        tokenRecord.active = false;
        // Inactivate the associated external tokens
        mapping(uint256 => VisionTypes.ExternalTokenRecord)
            storage externalTokenRecords = s.externalTokenRecords[token];
        for (uint256 i = 0; i < s.numberBlockchains; i++) {
            if (i != s.currentBlockchainId) {
                VisionTypes.ExternalTokenRecord
                    storage externalTokenRecord = externalTokenRecords[i];
                if (externalTokenRecord.active) {
                    externalTokenRecord.active = false;
                    emit ExternalTokenUnregistered(
                        token,
                        externalTokenRecord.externalToken,
                        i
                    );
                }
            }
        }
        // Remove the token address
        uint256 tokenIndex = s.tokenIndices[token];
        uint256 maxTokenIndex = s.tokens.length - 1;
        assert(tokenIndex <= maxTokenIndex);
        assert(s.tokens[tokenIndex] == token);
        if (tokenIndex != maxTokenIndex) {
            // Replace the removed token with the last token
            address otherTokenAddress = s.tokens[maxTokenIndex];
            s.tokenIndices[otherTokenAddress] = tokenIndex;
            s.tokens[tokenIndex] = otherTokenAddress;
        }
        s.tokens.pop();
        emit TokenUnregistered(token);
    }

    /**
     * @dev See {IVisionRegistry-registerExternalToken}.
     */
    // slither-disable-next-line timestamp
    function registerExternalToken(
        address token,
        uint256 blockchainId,
        string calldata externalToken
    ) external override superCriticalOpsOrNotPaused {
        // Validate the input parameters
        require(
            blockchainId != s.currentBlockchainId,
            "VisionHub: blockchain must not be the current blockchain"
        );
        require(
            s.blockchainRecords[blockchainId].active,
            "VisionHub: blockchain of external token must be active"
        );
        require(
            bytes(externalToken).length == 42 &&
                bytes(externalToken)[0] == bytes1("0") &&
                (bytes(externalToken)[1] == bytes1("x") ||
                    bytes(externalToken)[1] == bytes1("X")),
            "VisionHub: external token address must not be empty or more than 22 bytes with leading 0x"
        );
        // Validate the stored token data
        VisionTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "VisionHub: token must be active");
        require(
            IVisionToken(token).getOwner() == msg.sender,
            "VisionHub: caller is not the token owner"
        );
        // Validate the stored external token data
        VisionTypes.ExternalTokenRecord storage externalTokenRecord = s
            .externalTokenRecords[token][blockchainId];
        require(
            !externalTokenRecord.active,
            "VisionHub: external token must not be active"
        );
        // Store the external token record
        externalTokenRecord.active = true;
        externalTokenRecord.externalToken = externalToken;
        emit ExternalTokenRegistered(token, externalToken, blockchainId);
    }

    /**
     * @dev See {IVisionRegistry-unregisterExternalToken}.
     */
    function unregisterExternalToken(
        address token,
        uint256 blockchainId
    ) external override superCriticalOpsOrNotPaused {
        // Validate the stored token data
        VisionTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "VisionHub: token must be active");
        require(
            IVisionToken(token).getOwner() == msg.sender,
            "VisionHub: caller is not the token owner"
        );
        // Validate the stored external token data
        VisionTypes.ExternalTokenRecord storage externalTokenRecord = s
            .externalTokenRecords[token][blockchainId];
        require(
            externalTokenRecord.active,
            "VisionHub: external token must be active"
        );
        // Update the external token record
        externalTokenRecord.active = false;
        emit ExternalTokenUnregistered(
            token,
            externalTokenRecord.externalToken,
            blockchainId
        );
    }

    /**
     * @dev See {IVisionRegistry-registerServiceNode}.
     */
    // slither-disable-next-line timestamp
    function registerServiceNode(
        address serviceNodeAddress,
        string calldata url,
        uint256 deposit,
        address withdrawalAddress
    ) external override whenNotPaused {
        // Validate the input parameters
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == withdrawalAddress,
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );
        _verifyCommitment(
            abi.encodePacked(
                serviceNodeAddress,
                withdrawalAddress,
                url,
                msg.sender
            )
        );

        require(
            bytes(url).length > 0,
            "VisionHub: service node URL must not be empty"
        );
        bytes32 urlHash = keccak256(bytes(url));
        require(
            !s.isServiceNodeUrlUsed[urlHash],
            "VisionHub: service node URL must be unique"
        );
        require(
            deposit >= s.minimumServiceNodeDeposit.currentValue,
            "VisionHub: deposit must be >= minimum service node deposit"
        );
        // Validate the stored service node data
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            !serviceNodeRecord.active,
            "VisionHub: service node already registered"
        );
        require(
            serviceNodeRecord.withdrawalTime == 0,
            "VisionHub: service node must withdraw its deposit or cancel "
            "the unregistration"
        );
        assert(serviceNodeRecord.deposit == 0);
        // Store the service node record
        serviceNodeRecord.active = true;
        serviceNodeRecord.url = url;
        serviceNodeRecord.deposit = deposit;
        serviceNodeRecord.withdrawalAddress = withdrawalAddress;
        s.serviceNodeIndices[serviceNodeAddress] = s.serviceNodes.length;
        s.serviceNodes.push(serviceNodeAddress);
        s.isServiceNodeUrlUsed[urlHash] = true;
        emit ServiceNodeRegistered(serviceNodeAddress, url, deposit);
        // Transfer the service node deposit to this contract
        require(
            IVisionToken(s.visionToken).transferFrom(
                msg.sender,
                address(this),
                deposit
            ),
            "VisionHub: transfer of service node deposit failed"
        );
    }

    /**
     * @dev See {IVisionRegistry-unregisterServiceNode}.
     */
    // slither-disable-next-line timestamp
    function unregisterServiceNode(
        address serviceNodeAddress
    ) external override whenNotPaused {
        // Validate the stored service node data
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );
        require(
            serviceNodeRecord.active,
            "VisionHub: service node must be active"
        );

        // Update the service node record
        serviceNodeRecord.active = false;
        serviceNodeRecord.withdrawalTime =
            block.timestamp +
            s.unbondingPeriodServiceNodeDeposit.currentValue;
        // Remove the service node address
        uint256 serviceNodeIndex = s.serviceNodeIndices[serviceNodeAddress];
        uint256 maxServiceNodeIndex = s.serviceNodes.length - 1;
        assert(serviceNodeIndex <= maxServiceNodeIndex);
        assert(s.serviceNodes[serviceNodeIndex] == serviceNodeAddress);
        if (serviceNodeIndex != maxServiceNodeIndex) {
            // Replace the removed service node with the last service node
            address otherServiceNodeAddress = s.serviceNodes[
                maxServiceNodeIndex
            ];
            s.serviceNodeIndices[otherServiceNodeAddress] = serviceNodeIndex;
            s.serviceNodes[serviceNodeIndex] = otherServiceNodeAddress;
        }
        s.serviceNodes.pop();
        emit ServiceNodeUnregistered(
            serviceNodeAddress,
            serviceNodeRecord.url
        );
    }

    /**
     * @dev See {IVisionRegistry-withdrawServiceNodeDeposit}.
     */
    function withdrawServiceNodeDeposit(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            serviceNodeRecord.withdrawalTime != 0,
            "VisionHub: service node has no deposit to withdraw"
        );
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );
        // slither-disable-next-line timestamp
        require(
            block.timestamp >= serviceNodeRecord.withdrawalTime,
            "VisionHub: the unbonding period has not elapsed"
        );
        uint256 deposit = serviceNodeRecord.deposit;
        // Update the service node record
        serviceNodeRecord.withdrawalTime = 0;
        serviceNodeRecord.deposit = 0;
        s.isServiceNodeUrlUsed[
            keccak256(bytes(serviceNodeRecord.url))
        ] = false;
        delete serviceNodeRecord.url;
        // Refund the service node deposit
        if (deposit > 0) {
            require(
                IVisionToken(s.visionToken).transfer(
                    serviceNodeRecord.withdrawalAddress,
                    deposit
                ),
                "VisionHub: refund of service node deposit failed"
            );
        }
    }

    /**
     * @dev See {IVisionRegistry-cancelServiceNodeUnregistration}.
     */
    function cancelServiceNodeUnregistration(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            serviceNodeRecord.withdrawalTime != 0,
            "VisionHub: service node is not in the unbonding period"
        );
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );
        serviceNodeRecord.active = true;
        serviceNodeRecord.withdrawalTime = 0;
        s.serviceNodeIndices[serviceNodeAddress] = s.serviceNodes.length;
        s.serviceNodes.push(serviceNodeAddress);
        emit ServiceNodeRegistered(
            serviceNodeAddress,
            serviceNodeRecord.url,
            serviceNodeRecord.deposit
        );
    }

    /**
     * @dev See {IVisionRegistry-increaseServiceNodeDeposit}.
     */
    // slither-disable-next-line timestamp
    function increaseServiceNodeDeposit(
        address serviceNodeAddress,
        uint256 deposit
    ) external override {
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );
        require(
            serviceNodeRecord.active,
            "VisionHub: service node must be active"
        );
        require(
            deposit > 0,
            "VisionHub: additional deposit must be greater than 0"
        );
        uint256 newServiceNodeDeposit = serviceNodeRecord.deposit + deposit;
        require(
            newServiceNodeDeposit >= s.minimumServiceNodeDeposit.currentValue,
            "VisionHub: new deposit must be at least the minimum "
            "service node deposit"
        );
        serviceNodeRecord.deposit = newServiceNodeDeposit;
        require(
            IVisionToken(s.visionToken).transferFrom(
                msg.sender,
                address(this),
                deposit
            ),
            "VisionHub: transfer of service node deposit failed"
        );
    }

    /**
     * @dev See {IVisionRegistry-decreaseServiceNodeDeposit}.
     */
    // slither-disable-next-line timestamp
    function decreaseServiceNodeDeposit(
        address serviceNodeAddress,
        uint256 deposit
    ) external override {
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "VisionHub: caller is not the service node or the "
            "withdrawal address"
        );
        require(
            serviceNodeRecord.active,
            "VisionHub: service node must be active"
        );
        require(
            deposit > 0,
            "VisionHub: reduced deposit must be greater than 0"
        );
        uint256 newServiceNodeDeposit = serviceNodeRecord.deposit - deposit;
        require(
            newServiceNodeDeposit >= s.minimumServiceNodeDeposit.currentValue,
            "VisionHub: new deposit must be at least the minimum "
            "service node deposit"
        );
        serviceNodeRecord.deposit = newServiceNodeDeposit;
        require(
            IVisionToken(s.visionToken).transfer(
                serviceNodeRecord.withdrawalAddress,
                deposit
            ),
            "VisionHub: refund of service node deposit failed"
        );
    }

    /**
     * @dev See {IVisionRegistry-updateServiceNodeUrl}.
     */
    function updateServiceNodeUrl(
        string calldata url
    ) external override whenNotPaused {
        // Validate the input parameter
        require(
            bytes(url).length > 0,
            "VisionHub: service node URL must not be empty"
        );

        bytes32 urlHash = keccak256(bytes(url));
        // slither-disable-next-line timestamp
        require(
            !s.isServiceNodeUrlUsed[urlHash],
            "VisionHub: service node URL must be unique"
        );
        // Validate the stored service node data
        VisionTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[msg.sender];
        require(
            serviceNodeRecord.active,
            "VisionHub: service node must be active"
        );

        _verifyCommitment(abi.encodePacked(url, msg.sender));

        s.isServiceNodeUrlUsed[
            keccak256(bytes(serviceNodeRecord.url))
        ] = false;
        s.isServiceNodeUrlUsed[urlHash] = true;
        // Update the stored service node URL
        serviceNodeRecord.url = url;
        emit ServiceNodeUrlUpdated(msg.sender, url);
    }

    /**
     * @dev See {IVisionRegistry-getVisionForwarder}.
     */
    function getVisionForwarder() public view override returns (address) {
        return s.visionForwarder;
    }

    /**
     * @dev See {IVisionRegistry-getVisionToken}.
     */
    function getVisionToken() public view override returns (address) {
        return s.visionToken;
    }

    /**
     * @dev See {IVisionRegistry-getPrimaryValidatorNode}.
     */
    function getPrimaryValidatorNode() public view override returns (address) {
        return s.primaryValidatorNodeAddress;
    }

    /**
     * @dev See {IVisionRegistry-getProtocolVersion}.
     */
    function getProtocolVersion() public view override returns (bytes32) {
        return s.protocolVersion;
    }

    /**
     * @dev See {IVisionRegistry-getNumberBlockchains}.
     */
    function getNumberBlockchains() public view override returns (uint256) {
        return s.numberBlockchains;
    }

    /**
     * @dev See {IVisionRegistry-getNumberActiveBlockchains}.
     */
    function getNumberActiveBlockchains()
        public
        view
        override
        returns (uint256)
    {
        return s.numberActiveBlockchains;
    }

    /**
     * @dev See {IVisionRegistry-getCurrentBlockchainId}.
     */
    function getCurrentBlockchainId() public view override returns (uint256) {
        return s.currentBlockchainId;
    }

    /**
     * @dev See {IVisionRegistry-getBlockchainRecord}.
     */
    function getBlockchainRecord(
        uint256 blockchainId
    ) public view override returns (VisionTypes.BlockchainRecord memory) {
        return s.blockchainRecords[blockchainId];
    }

    /**
     * @dev See {IVisionRegistry-getCurrentMinimumServiceNodeDeposit}.
     */
    function getCurrentMinimumServiceNodeDeposit()
        public
        view
        override
        returns (uint256)
    {
        return s.minimumServiceNodeDeposit.currentValue;
    }

    /**
     * @dev See {IVisionRegistry-getMinimumServiceNodeDeposit}.
     */
    function getMinimumServiceNodeDeposit()
        public
        view
        override
        returns (VisionTypes.UpdatableUint256 memory)
    {
        return s.minimumServiceNodeDeposit;
    }

    /**
     * @dev See {IVisionRegistry-getCurrentUnbondingPeriodServiceNodeDeposit}.
     */
    function getCurrentUnbondingPeriodServiceNodeDeposit()
        public
        view
        override
        returns (uint256)
    {
        return s.unbondingPeriodServiceNodeDeposit.currentValue;
    }

    /**
     * @dev See {IVisionRegistry-getUnbondingPeriodServiceNodeDeposit}.
     */
    function getUnbondingPeriodServiceNodeDeposit()
        public
        view
        override
        returns (VisionTypes.UpdatableUint256 memory)
    {
        return s.unbondingPeriodServiceNodeDeposit;
    }

    /**
     * @dev See {IVisionRegistry-getTokens}.
     */
    function getTokens() public view override returns (address[] memory) {
        return s.tokens;
    }

    /**
     * @dev See {IVisionRegistry-getTokenRecord}.
     */
    function getTokenRecord(
        address token
    ) public view override returns (VisionTypes.TokenRecord memory) {
        return s.tokenRecords[token];
    }

    /**
     * @dev See {IVisionRegistry-getExternalTokenRecord}.
     */
    function getExternalTokenRecord(
        address token,
        uint256 blockchainId
    ) public view override returns (VisionTypes.ExternalTokenRecord memory) {
        return s.externalTokenRecords[token][blockchainId];
    }

    /**
     * @dev See {IVisionRegistry-getServiceNodes}.
     */
    function getServiceNodes()
        public
        view
        override
        returns (address[] memory)
    {
        return s.serviceNodes;
    }

    /**
     * @dev See {IVisionRegistry-getServiceNodeRecord}.
     */
    function getServiceNodeRecord(
        address serviceNode
    ) public view override returns (VisionTypes.ServiceNodeRecord memory) {
        return s.serviceNodeRecords[serviceNode];
    }

    /**
     * @dev See {IVisionRegistry-getCurrentValidatorFeeFactor}.
     */
    function getCurrentValidatorFeeFactor(
        uint256 blockchainId
    ) public view override returns (uint256) {
        return s.validatorFeeFactors[blockchainId].currentValue;
    }

    /**
     * @dev See {IVisionRegistry-getValidatorFeeFactor}.
     */
    function getValidatorFeeFactor(
        uint256 blockchainId
    ) public view override returns (VisionTypes.UpdatableUint256 memory) {
        return s.validatorFeeFactors[blockchainId];
    }

    /**
     * @dev See {IVisionRegistry-getCurrentParameterUpdateDelay}.
     */
    function getCurrentParameterUpdateDelay()
        public
        view
        override
        returns (uint256)
    {
        return s.parameterUpdateDelay.currentValue;
    }

    /**
     * @dev See {IVisionRegistry-getParameterUpdateDelay}.
     */
    function getParameterUpdateDelay()
        public
        view
        override
        returns (VisionTypes.UpdatableUint256 memory)
    {
        return s.parameterUpdateDelay;
    }

    /**
     * @dev See {IVisionRegistry-isServiceNodeInTheUnbondingPeriod}.
     */
    function isServiceNodeInTheUnbondingPeriod(
        address serviceNodeAddress
    ) external view override returns (bool) {
        VisionTypes.ServiceNodeRecord memory serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        // slither-disable-next-line timestamp
        return serviceNodeRecord.withdrawalTime != 0;
    }

    /**
     * @dev See {IVisionRegistry-isValidValidatorNodeNonce}.
     */
    function isValidValidatorNodeNonce(
        uint256 nonce
    ) external view override returns (bool) {
        return
            IVisionForwarder(s.visionForwarder).isValidValidatorNodeNonce(
                nonce
            );
    }

    /**
     * @dev See {IVisionRegistry-paused}.
     */
    function paused() external view returns (bool) {
        return s.paused;
    }

    function _verifyCommitment(bytes memory data) private {
        require(
            s.commitments[msg.sender].hash != bytes32(0),
            "VisionHub: "
            "service node must have made a commitment"
        );
        bytes32 computedHash = keccak256(abi.encodePacked(data));
        require(
            s.commitments[msg.sender].hash == computedHash,
            "VisionHub: Commitment does not match"
        );
        require(
            s.commitments[msg.sender].blockNumber + s.commitmentWaitPeriod <=
                block.number,
            "VisionHub: Commitment period has not elapsed"
        );
        delete s.commitments[msg.sender];
    }

    function _initializeUpdatableUint256(
        VisionTypes.UpdatableUint256 storage updatableUint256,
        uint256 currentValue
    ) private {
        updatableUint256.currentValue = currentValue;
        updatableUint256.pendingValue = 0;
        updatableUint256.updateTime = 0;
    }

    function _initiateUpdatableUint256Update(
        VisionTypes.UpdatableUint256 storage updatableUint256,
        uint256 newValue
    ) private {
        updatableUint256.pendingValue = newValue;
        // slither-disable-next-line timestamp
        updatableUint256.updateTime =
            block.timestamp +
            s.parameterUpdateDelay.currentValue;
    }

    function _executeUpdatableUint256Update(
        VisionTypes.UpdatableUint256 storage updatableUint256
    ) private {
        require(
            updatableUint256.updateTime > 0 &&
                updatableUint256.pendingValue != updatableUint256.currentValue,
            "VisionHub: no pending update"
        );
        // slither-disable-next-line timestamp
        require(
            block.timestamp >= updatableUint256.updateTime,
            "VisionHub: update time not reached"
        );
        updatableUint256.currentValue = updatableUint256.pendingValue;
    }
}
