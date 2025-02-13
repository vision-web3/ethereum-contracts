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
 * @title UpdateParameterUpdateDelay
 *
 * @notice Update the parameter update delay at the Vision Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/UpdateParameterUpdateDelay.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(uint256)" <newParameterUpdateDelay>
 */
contract UpdateParameterUpdateDelay is
    VisionBaseAddresses,
    SafeAddresses,
    UpdateBase
{
    function roleActions(uint256 newParameterUpdateDelay) public {
        readContractAddresses(determineBlockchain());
        IVisionHub visionHubProxy = IVisionHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        AccessController accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        vm.startBroadcast(accessController.mediumCriticalOps());

        VisionTypes.UpdatableUint256
            memory onChainParameterUpdateDelay = visionHubProxy
                .getParameterUpdateDelay();
        UpdateBase.UpdateState updateState = isInitiateOrExecute(
            onChainParameterUpdateDelay,
            newParameterUpdateDelay
        );
        if (updateState == UpdateBase.UpdateState.INITIATE) {
            visionHubProxy.initiateParameterUpdateDelayUpdate(
                newParameterUpdateDelay
            );
            console.log(
                "Update of parameter update delay initiated %s",
                newParameterUpdateDelay
            );
        } else if (updateState == UpdateBase.UpdateState.EXECUTE) {
            visionHubProxy.executeParameterUpdateDelayUpdate();
            console.log(
                "Update of parameter update delay executed %s",
                onChainParameterUpdateDelay.pendingValue
            );
        } else {
            revert("UpdateParameterUpdateDelay: Invalid update state");
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
