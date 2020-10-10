/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {IDODO} from "../intf/IDODO.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";
import {DODOMath} from "../lib/DODOMath.sol";


contract DODOSellHelper {
    using SafeMath for uint256;

    enum RStatus {ONE, ABOVE_ONE, BELOW_ONE}

    uint256 constant ONE = 10**18;

    struct DODOState {
        uint256 oraclePrice;
        uint256 K;
        uint256 B;
        uint256 Q;
        uint256 baseTarget;
        uint256 quoteTarget;
        RStatus rStatus;
    }

    function querySellBaseToken(address dodo, uint256 amount) public view returns (uint256) {
        return IDODO(dodo).querySellBaseToken(amount);
    }

    function querySellQuoteToken(address dodo, uint256 amount) public view returns (uint256) {
        DODOState memory state;
        (state.baseTarget, state.quoteTarget) = IDODO(dodo).getExpectedTarget();
        state.rStatus = RStatus(IDODO(dodo)._R_STATUS_());
        state.oraclePrice = IDODO(dodo).getOraclePrice();
        state.Q = IDODO(dodo)._QUOTE_BALANCE_();
        state.B = IDODO(dodo)._BASE_BALANCE_();
        state.K = IDODO(dodo)._K_();

        uint256 boughtAmount;
        // Determine the status (RStatus) and calculate the amount
        // based on the state
        if (state.rStatus == RStatus.ONE) {
            boughtAmount = _ROneSellQuoteToken(amount, state);
        } else if (state.rStatus == RStatus.ABOVE_ONE) {
            boughtAmount = _RAboveSellQuoteToken(amount, state);
        } else {
            uint256 backOneBase = state.B.sub(state.baseTarget);
            uint256 backOneQuote = state.quoteTarget.sub(state.Q);
            if (amount <= backOneQuote) {
                boughtAmount = _RBelowSellQuoteToken(amount, state);
            } else {
                boughtAmount = backOneBase.add(
                    _ROneSellQuoteToken(amount.sub(backOneQuote), state)
                );
            }
        }
        // Calculate fees
        return
            DecimalMath.divFloor(
                boughtAmount,
                DecimalMath.ONE.add(IDODO(dodo)._MT_FEE_RATE_()).add(IDODO(dodo)._LP_FEE_RATE_())
            );
    }

    function _ROneSellQuoteToken(uint256 amount, DODOState memory state)
        internal
        pure
        returns (uint256 receiveBaseToken)
    {
        uint256 i = DecimalMath.divFloor(ONE, state.oraclePrice);
        uint256 B2 = DODOMath._SolveQuadraticFunctionForTrade(
            state.baseTarget,
            state.baseTarget,
            DecimalMath.mul(i, amount),
            false,
            state.K
        );
        return state.baseTarget.sub(B2);
    }

    function _RAboveSellQuoteToken(uint256 amount, DODOState memory state)
        internal
        pure
        returns (uint256 receieBaseToken)
    {
        uint256 i = DecimalMath.divFloor(ONE, state.oraclePrice);
        uint256 B2 = DODOMath._SolveQuadraticFunctionForTrade(
            state.baseTarget,
            state.B,
            DecimalMath.mul(i, amount),
            false,
            state.K
        );
        return state.B.sub(B2);
    }

    function _RBelowSellQuoteToken(uint256 amount, DODOState memory state)
        internal
        pure
        returns (uint256 receiveBaseToken)
    {
        uint256 Q1 = state.Q.add(amount);
        uint256 i = DecimalMath.divFloor(ONE, state.oraclePrice);
        return DODOMath._GeneralIntegrate(state.quoteTarget, Q1, state.Q, i, state.K);
    }
}
