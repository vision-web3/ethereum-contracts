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
 * @title UpdateUnbondingPeriod
 *
 * @notice Update the unbonding period of the service node deposit
 * at the Vision Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/UpdateUnbondingPeriod.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(uint256)" <newUnbondingPeriod>
 */
contract UpdateUnbondingPeriod is
    VisionBaseAddresses,
    SafeAddresses,
    UpdateBase
{
    function roleActions(uint256 newUnbondingPeriod) public {
        readContractAddresses(determineBlockchain());
        IVisionHub visionHubProxy = IVisionHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        AccessController accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        vm.startBroadcast(accessController.mediumCriticalOps());

        VisionTypes.UpdatableUint256
            memory onChainUnbondingPeriod = visionHubProxy
                .getUnbondingPeriodServiceNodeDeposit();
        UpdateBase.UpdateState updateState = isInitiateOrExecute(
            onChainUnbondingPeriod,
            newUnbondingPeriod
        );
        if (updateState == UpdateBase.UpdateState.INITIATE) {
            visionHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
                newUnbondingPeriod
            );
            console.log(
                "Update of the unbonding period of service node "
                "deposit initiated %s",
                newUnbondingPeriod
            );
        } else if (updateState == UpdateBase.UpdateState.EXECUTE) {
            visionHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
            console.log(
                "Update of the unbonding period of service node "
                "deposit executed %s",
                onChainUnbondingPeriod.pendingValue
            );
        } else {
            revert("UpdateUnbondingPeriod: Invalid update state");
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
