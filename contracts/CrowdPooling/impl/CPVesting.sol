/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {SafeMath} from "../../lib/SafeMath.sol";
import {DecimalMath} from "../../lib/DecimalMath.sol";
import {Ownable} from "../../lib/Ownable.sol";
import {SafeERC20} from "../../lib/SafeERC20.sol";
import {IERC20} from "../../intf/IERC20.sol";
import {CPFunding} from "./CPFunding.sol";

/**
 * @title CPVesting
 * @author DODO Breeder
 *
 * @notice Lock Token and release it linearly
 */

contract CPVesting is CPFunding {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier afterSettlement() {
        require(_SETTLED_, "NOT_SETTLED");
        _;
    }

    // ============ Bidder Functions ============

    function bidderClaim() external afterSettlement {
        require(!_CLAIMED_[msg.sender], "ALREADY_CLAIMED");
        _CLAIMED_[msg.sender] = true;

        _transferBaseOut(msg.sender, _UNUSED_BASE_.mul(_SHARES_[msg.sender]).div(_TOTAL_SHARES_));
        _transferQuoteOut(msg.sender, _UNUSED_QUOTE_.mul(_SHARES_[msg.sender]).div(_TOTAL_SHARES_));
    }

    // ============ Owner Functions ============

    function claimLPToken() external onlyOwner afterSettlement {
        IERC20(_POOL_).safeTransfer(_OWNER_, getClaimableLPToken());
    }

    function getClaimableLPToken() public view afterSettlement returns (uint256) {
        uint256 remainingLPToken = DecimalMath.mulFloor(
            getRemainingLPRatio(block.timestamp),
            _TOTAL_LP_AMOUNT_
        );
        return IERC20(_POOL_).balanceOf(address(this)).sub(remainingLPToken);
    }

    function getRemainingLPRatio(uint256 timestamp) public view afterSettlement returns (uint256) {
        uint256 timePast = timestamp.sub(_SETTLED_TIME_);
        if (timePast < _VESTING_DURATION_) {
            uint256 remainingTime = _VESTING_DURATION_.sub(timePast);
            return DecimalMath.ONE.sub(_CLIFF_RATE_).mul(remainingTime).div(_VESTING_DURATION_);
        } else {
            return 0;
        }
    }
}