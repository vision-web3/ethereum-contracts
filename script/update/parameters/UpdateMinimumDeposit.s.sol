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
 * @title UpdateMinimumDeposit
 *
 * @notice Update the minimum deposit of the service node at the Vision Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/UpdateMinimumDeposit.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(uint256)" <newMinimumDeposit>
 */
contract UpdateMinimumDeposit is
    VisionBaseAddresses,
    SafeAddresses,
    UpdateBase
{
    function roleActions(uint256 newMinimumDeposit) public {
        readContractAddresses(determineBlockchain());
        IVisionHub visionHubProxy = IVisionHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        AccessController accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        vm.startBroadcast(accessController.mediumCriticalOps());
        VisionTypes.UpdatableUint256
            memory onchainMinimumDeposit = visionHubProxy
                .getMinimumServiceNodeDeposit();
        UpdateBase.UpdateState updateState = isInitiateOrExecute(
            onchainMinimumDeposit,
            newMinimumDeposit
        );
        if (updateState == UpdateBase.UpdateState.INITIATE) {
            visionHubProxy.initiateMinimumServiceNodeDepositUpdate(
                newMinimumDeposit
            );
            console.log(
                "Update of minimum service node deposit initiated %s",
                newMinimumDeposit
            );
        } else if (updateState == UpdateBase.UpdateState.EXECUTE) {
            visionHubProxy.executeMinimumServiceNodeDepositUpdate();
            console.log(
                "Update of minimum service node deposit executed %s",
                onchainMinimumDeposit.pendingValue
            );
        } else {
            revert("UpdateMinimumDeposit: Invalid update state");
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
