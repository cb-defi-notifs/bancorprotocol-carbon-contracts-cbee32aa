// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @dev this contract abstracts the block timestamp in order to allow for more flexible control in tests
 */
abstract contract Time {
    /**
     * @dev returns the current time
     */
    function _time() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
    }
}
