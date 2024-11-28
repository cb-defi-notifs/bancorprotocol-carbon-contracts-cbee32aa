// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Upgradeable } from "./Upgradeable.sol";

import { ICarbonController } from "../carbon/interfaces/ICarbonController.sol";
import { IVoucher } from "../voucher/interfaces/IVoucher.sol";

import { Order } from "../carbon/Strategies.sol";

import { Utils } from "../utility/Utils.sol";

import { Token, NATIVE_TOKEN } from "../token/Token.sol";

struct StrategyData {
    Token[2] tokens;
    Order[2] orders;
}

/**
 * @dev Contract to batch create carbon controller strategies
 */
contract CarbonBatcher is Upgradeable, Utils, ReentrancyGuardUpgradeable, IERC721Receiver {
    error InsufficientNativeTokenSent();

    ICarbonController private immutable carbonController;
    IVoucher private immutable voucher;

    /**
     * @dev triggered when tokens have been withdrawn from the carbon batcher
     */
    event FundsWithdrawn(Token indexed token, address indexed caller, address indexed target, uint256 amount);

    constructor(
        ICarbonController _carbonController,
        IVoucher _voucher
    ) validAddress(address(_carbonController)) validAddress(address(_voucher)) {
        carbonController = _carbonController;
        voucher = _voucher;
    }

    /**
     * @dev fully initializes the contract and its parents
     */
    function initialize() public initializer {
        __CarbonBatcher_init();
    }

    // solhint-disable func-name-mixedcase

    /**
     * @dev initializes the contract and its parents
     */
    function __CarbonBatcher_init() internal onlyInitializing {
        __Upgradeable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @inheritdoc Upgradeable
     */
    function version() public pure virtual override(Upgradeable) returns (uint16) {
        return 1;
    }

    /**
     * @dev creates several new strategies, returns the strategies id's
     *
     * requirements:
     *
     * - the caller must have approved the tokens with assigned liquidity in the orders
     */
    function batchCreate(StrategyData[] calldata strategies) external payable nonReentrant returns (uint256[] memory) {
        uint256[] memory strategyIds = new uint256[](strategies.length);
        uint256 txValueLeft = msg.value;

        // main loop - transfer funds from user for strategies,
        // create strategies and transfer nfts to user
        for (uint256 i = 0; i < strategies.length; i++) {
            // get tokens for this strategy
            Token[2] memory tokens = strategies[i].tokens;
            // if any of the tokens is native, send this value with the create strategy tx
            uint256 valueToSend = 0;

            // transfer tokens and approve to carbon controller
            for (uint256 j = 0; j < 2; j++) {
                Token token = strategies[i].tokens[j];
                uint256 amount = strategies[i].orders[j].y;
                if (amount == 0) {
                    continue;
                }
                if (token.isNative()) {
                    if (txValueLeft < amount) {
                        revert InsufficientNativeTokenSent();
                    }
                    valueToSend = amount;
                    // subtract the native token left sent with the tx
                    txValueLeft -= amount;
                }

                token.safeTransferFrom(msg.sender, address(this), amount);
                _setCarbonAllowance(token, amount);
            }

            // create strategy on carbon
            strategyIds[i] = carbonController.createStrategy{ value: valueToSend }(
                tokens[0],
                tokens[1],
                strategies[i].orders
            );
            // transfer nft to user
            voucher.safeTransferFrom(address(this), msg.sender, strategyIds[i], "");
        }
        // refund user any remaining native token
        if (txValueLeft > 0) {
            // safe due to nonReentrant modifier (forwards all available gas)
            NATIVE_TOKEN.unsafeTransfer(msg.sender, txValueLeft);
        }

        return strategyIds;
    }

    /**
     * @dev withdraws funds held by the contract and sends them to an account
     *
     * requirements:
     *
     * - the caller be admin of the contract
     */
    function withdrawFunds(
        Token token,
        address payable target,
        uint256 amount
    ) external validAddress(target) nonReentrant onlyAdmin {
        if (amount == 0) {
            return;
        }

        // safe due to nonReentrant modifier (forwards all available gas in case of ETH)
        token.unsafeTransfer(target, amount);

        emit FundsWithdrawn({ token: token, caller: msg.sender, target: target, amount: amount });
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev set carbon controller allowance to 2 ** 256 - 1 if it's less than the input amount
     */
    function _setCarbonAllowance(Token token, uint256 inputAmount) private {
        if (token.isNative()) {
            return;
        }
        uint256 allowance = token.toIERC20().allowance(address(this), address(carbonController));
        if (allowance < inputAmount) {
            // increase allowance to the max amount if allowance < inputAmount
            token.forceApprove(address(carbonController), type(uint256).max);
        }
    }
}
