import { TestERC20Burnable } from '../../typechain-types';
import { TradeActionStruct } from '../../typechain-types/contracts/carbon/CarbonController';
import { TestTradeActions } from '../utility/testDataFactory';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import Decimal from 'decimal.js';
import { BigNumber, BigNumberish, ContractReceipt } from 'ethers';

export const generateStrategyId = (pairId: number, strategyIndex: number) =>
    BigNumber.from(pairId).shl(128).or(strategyIndex);

export type TradeTestReturnValues = {
    tradingFeeAmount: BigNumber;
    gasUsed: BigNumber;
    receipt: ContractReceipt;
    value: BigNumber;
};

export type TradeParams = {
    tradeActions: TestTradeActions[];
    sourceSymbol: string;
    targetSymbol: string;
    sourceAmount: BigNumberish;
    targetAmount: BigNumberish;
    byTargetAmount: boolean;
    sendWithExcessNativeTokenValue?: boolean;
    constraint?: BigNumberish;
};

export type SimpleTradeParams = {
    sourceToken: string;
    targetToken: string;
    byTargetAmount: boolean;
    sourceAmount: BigNumberish;
    tradeActions?: TradeActionStruct[];
    deadlineDelta?: number;
    txValue?: BigNumberish;
    constraint?: BigNumberish;
};

export interface TestOrder {
    y: BigNumber;
    z: BigNumber;
    A: BigNumber;
    B: BigNumber;
}

export interface CreateStrategyParams {
    owner?: SignerWithAddress;
    token0?: TestERC20Burnable;
    token1?: TestERC20Burnable;
    token0Amount?: number;
    token1Amount?: number;
    skipFunding?: boolean;
    order?: TestOrder;
    secondOrder?: TestOrder;
    sendWithExcessNativeTokenValue?: boolean;
}

export interface UpdateStrategyParams {
    strategyId?: number;
    owner?: SignerWithAddress;
    token0?: TestERC20Burnable;
    token1?: TestERC20Burnable;
    order0Delta?: number;
    order1Delta?: number;
    skipFunding?: boolean;
    sendWithExcessNativeTokenValue?: boolean;
}

export const mulDivF = (x: BigNumberish, y: BigNumberish, z: BigNumberish) => BigNumber.from(x).mul(y).div(z);
export const mulDivC = (x: BigNumberish, y: BigNumberish, z: BigNumberish) =>
    BigNumber.from(x).mul(y).add(z).sub(1).div(z);
export const toFixed = (x: Decimal) => new Decimal(x.toFixed(12)).toFixed();

export const setConstraint = (
    constraint: BigNumberish | undefined,
    byTargetAmount: boolean,
    expectedResultAmount: BigNumberish
): BigNumberish => {
    if (!constraint && constraint !== 0) {
        return byTargetAmount ? expectedResultAmount : 1;
    }
    return constraint;
};

/**
 * generates a test order
 */
export const generateTestOrder = (): TestOrder => {
    return {
        y: BigNumber.from(800000),
        z: BigNumber.from(8000000),
        A: BigNumber.from(736899889),
        B: BigNumber.from(12148001999)
    };
};
