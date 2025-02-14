// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IVisionHub} from "../../../src/interfaces/IVisionHub.sol";
import {VisionTypes} from "../../../src/interfaces/VisionTypes.sol";
import {AccessController} from "../../../src/access/AccessController.sol";

import {VisionBaseAddresses} from "./../../helpers/VisionBaseAddresses.s.sol";
import {SafeAddresses} from "../../helpers/SafeAddresses.s.sol";
import {UpdateBase} from "./UpdateBase.s.sol";

/**
 * @title UpdateFeeFactors
 *
 * @notice Update the fee factors at the Vision Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/UpdateFeeFactors.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions()"
 */
contract UpdateFeeFactors is VisionBaseAddresses, SafeAddresses, UpdateBase {
    function roleActions() public {
        readContractAddresses(determineBlockchain());
        IVisionHub visionHubProxy = IVisionHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        AccessController accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        vm.startBroadcast(accessController.mediumCriticalOps());

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                uint256 blockchainId = uint256(blockchain.blockchainId);
                VisionTypes.UpdatableUint256
                    memory onChainFeeFactor = visionHubProxy
                        .getValidatorFeeFactor(blockchainId);
                UpdateBase.UpdateState updateState = isInitiateOrExecute(
                    onChainFeeFactor,
                    blockchain.feeFactor
                );
                if (updateState == UpdateBase.UpdateState.INITIATE) {
                    visionHubProxy.initiateValidatorFeeFactorUpdate(
                        blockchainId,
                        blockchain.feeFactor
                    );
                    console.log(
                        "Update of fee factor for blockchain %s initiated %s",
                        blockchain.name,
                        blockchain.feeFactor
                    );
                } else if (updateState == UpdateBase.UpdateState.EXECUTE) {
                    visionHubProxy.executeValidatorFeeFactorUpdate(
                        blockchainId
                    );
                    console.log(
                        "Update of fee factor for blockchain %s executed %s",
                        blockchain.name,
                        onChainFeeFactor.pendingValue
                    );
                } else {
                    revert("UpdateFeeFactors: Invalid update state");
                }
            }
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
