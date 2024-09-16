// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { Token } from "../token/Token.sol";

contract TestTokenType {
    receive() external payable {}

    function isNative(Token token) external pure returns (bool) {
        return token.isNative();
    }

    function symbol(Token token) external view returns (string memory) {
        return token.symbol();
    }

    function decimals(Token token) external view returns (uint8) {
        return token.decimals();
    }

    function balanceOf(Token token, address account) external view returns (uint256) {
        return token.balanceOf(account);
    }

    function safeTransfer(Token token, address to, uint256 amount) external {
        token.safeTransfer(to, amount);
    }

    function safeTransferFrom(Token token, address from, address to, uint256 amount) external {
        token.safeTransferFrom(from, to, amount);
    }

    function safeApprove(Token token, address spender, uint256 amount) external {
        token.safeApprove(spender, amount);
    }

    function isEqual(Token token1, Token token2) external pure returns (bool) {
        return token1 == token2;
    }
}
