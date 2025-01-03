// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ICarbonController } from "../carbon/interfaces/ICarbonController.sol";
import { IVoucher } from "../voucher/interfaces/IVoucher.sol";

import { Upgradeable } from "./Upgradeable.sol";
import { Order } from "../carbon/Strategies.sol";
import { Utils, InsufficientNativeTokenSent } from "../utility/Utils.sol";
import { Token } from "../token/Token.sol";

struct StrategyData {
    Token[2] tokens;
    Order[2] orders;
}

/**
 * @dev Contract to batch create carbon controller strategies
 */
contract CarbonBatcher is Upgradeable, Utils, ReentrancyGuard, IERC721Receiver {
    using Address for address payable;

    ICarbonController private immutable _carbonController;
    IVoucher private immutable _voucher;

    /**
     * @dev triggered when tokens have been withdrawn from the carbon batcher
     */
    event FundsWithdrawn(Token indexed token, address indexed caller, address indexed target, uint256 amount);

    constructor(
        ICarbonController carbonControllerInit,
        IVoucher voucherInit
    ) validAddress(address(carbonControllerInit)) validAddress(address(voucherInit)) {
        _carbonController = carbonControllerInit;
        _voucher = voucherInit;

        _disableInitializers();
    }

    /**
     * @dev fully initializes the contract and its parents
     */
    function initialize() external initializer {
        __CarbonBatcher_init();
    }

    // solhint-disable func-name-mixedcase

    /**
     * @dev initializes the contract and its parents
     */
    function __CarbonBatcher_init() internal onlyInitializing {
        __Upgradeable_init();
    }

    /**
     * @inheritdoc Upgradeable
     */
    function version() public pure virtual override(Upgradeable) returns (uint16) {
        return 1;
    }

    /**
     * @notice creates several new strategies, returns the strategies ids
     *
     * requirements:
     *
     * - the caller must have approved the tokens with assigned liquidity in the orders
     */
    function batchCreate(
        StrategyData[] calldata strategies
    ) external payable greaterThanZero(strategies.length) nonReentrant returns (uint256[] memory) {
        uint256[] memory strategyIds = new uint256[](strategies.length);
        uint256 txValueLeft = msg.value;

        // extract unique tokens and amounts
        (Token[] memory uniqueTokens, uint256[] memory amounts) = _extractUniqueTokensAndAmounts(strategies);
        // transfer funds from user for strategies
        for (uint256 i = 0; i < uniqueTokens.length; i = uncheckedInc(i)) {
            Token token = uniqueTokens[i];
            uint256 amount = amounts[i];
            if (token.isNative()) {
                if (txValueLeft < amount) {
                    revert InsufficientNativeTokenSent();
                }
                txValueLeft -= amount;
                continue;
            }
            token.safeTransferFrom(msg.sender, address(this), amount);
            _setCarbonAllowance(token, amount);
        }

        // create strategies and transfer nfts to user
        for (uint256 i = 0; i < strategies.length; i = uncheckedInc(i)) {
            // get tokens for this strategy
            Token[2] memory tokens = strategies[i].tokens;
            Order[2] memory orders = strategies[i].orders;
            // if any of the tokens is native, send this value with the create strategy tx
            uint256 valueToSend = 0;
            if (tokens[0].isNative()) {
                valueToSend = orders[0].y;
            } else if (tokens[1].isNative()) {
                valueToSend = orders[1].y;
            }

            // create strategy on carbon
            strategyIds[i] = _carbonController.createStrategy{ value: valueToSend }(tokens[0], tokens[1], orders);
            // transfer nft to user
            _voucher.safeTransferFrom(address(this), msg.sender, strategyIds[i], "");
        }
        // refund user any remaining native token
        if (txValueLeft > 0) {
            // forwards all available gas
            payable(msg.sender).sendValue(txValueLeft);
        }

        return strategyIds;
    }

    /**
     * @notice withdraws funds held by the contract and sends them to an account
     *
     * requirements:
     *
     * - the caller is admin of the contract
     */
    function withdrawFunds(
        Token token,
        address payable target,
        uint256 amount
    ) external validAddress(target) onlyAdmin nonReentrant {
        if (amount == 0) {
            return;
        }

        // forwards all available gas in case of ETH
        token.unsafeTransfer(target, amount);

        emit FundsWithdrawn({ token: token, caller: msg.sender, target: target, amount: amount });
    }

    /**
     * @inheritdoc IERC721Receiver
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev extracts unique tokens and amounts for each token from the strategy data
     */
    function _extractUniqueTokensAndAmounts(
        StrategyData[] calldata strategies
    ) private pure returns (Token[] memory uniqueTokens, uint256[] memory amounts) {
        // Maximum possible unique tokens
        Token[] memory tempUniqueTokens = new Token[](strategies.length * 2);
        uint256[] memory tempAmounts = new uint256[](strategies.length * 2);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < strategies.length; i = uncheckedInc(i)) {
            StrategyData calldata strategy = strategies[i];

            for (uint256 j = 0; j < 2; j = uncheckedInc(j)) {
                Token token = strategy.tokens[j];
                uint128 amount = strategy.orders[j].y;

                // Check if the token is already in the uniqueTokens array
                uint256 index = _findInArray(token, tempUniqueTokens, uniqueCount);
                if (index == type(uint256).max) {
                    // If not found, add to the array
                    tempUniqueTokens[uniqueCount] = token;
                    tempAmounts[uniqueCount] = amount;
                    uniqueCount++;
                } else {
                    // If found, aggregate the amount
                    tempAmounts[index] += amount;
                }
            }
        }

        // Resize the arrays to fit the unique count
        uniqueTokens = new Token[](uniqueCount);
        amounts = new uint256[](uniqueCount);

        for (uint256 i = 0; i < uniqueCount; i = uncheckedInc(i)) {
            uniqueTokens[i] = tempUniqueTokens[i];
            amounts[i] = tempAmounts[i];
        }

        return (uniqueTokens, amounts);
    }

    /**
     * @dev finds the first token in a token array if it exists and returns its index
     * @dev returns type(uint256).max if not found
     */
    function _findInArray(Token element, Token[] memory array, uint256 arrayLength) private pure returns (uint256) {
        for (uint256 i = 0; i < arrayLength; i = uncheckedInc(i)) {
            if (array[i] == element) {
                return i;
            }
        }
        return type(uint256).max; // Return max value if not found
    }

    /**
     * @dev set carbon controller allowance to 2 ** 256 - 1 if it's less than the input amount
     */
    function _setCarbonAllowance(Token token, uint256 inputAmount) private {
        if (token.isNative()) {
            return;
        }
        uint256 allowance = token.toIERC20().allowance(address(this), address(_carbonController));
        if (allowance < inputAmount) {
            // increase allowance to the max amount if allowance < inputAmount
            token.forceApprove(address(_carbonController), type(uint256).max);
        }
    }

    /**
     * @dev increments a uint256 value without reverting on overflow
     */
    function uncheckedInc(uint256 i) private pure returns (uint256 j) {
        unchecked {
            j = i + 1;
        }
    }
}
