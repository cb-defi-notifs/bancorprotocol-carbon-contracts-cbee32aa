// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { TestFixture } from "./TestFixture.t.sol";

import { AccessDenied, InvalidAddress, InvalidIndices } from "../../contracts/utility/Utils.sol";

import { IVoucher } from "../../contracts/voucher/interfaces/IVoucher.sol";

contract VoucherTest is TestFixture {
    using Address for address payable;

    string private constant VOUCHER_SYMBOL = "CARBON-STRAT";
    string private constant VOUCHER_NAME = "Carbon Automated Trading Strategy";

    uint256 private constant FETCH_AMOUNT = 5;

    // Events
    /**
     @dev triggered when updating useGlobalURI
     */
    event UseGlobalURIUpdated(bool newUseGlobalURI);

    /**
     * @dev triggered when updating the baseURI
     */
    event BaseURIUpdated(string newBaseURI);

    /**
     * @dev triggered when updating the baseExtension
     */
    event BaseExtensionUpdated(string newBaseExtension);

    /// @dev function to set up state before tests
    function setUp() public virtual {
        // Set up tokens and users
        systemFixture();
        // Deploy Carbon Controller
        setupCarbonController();
    }

    /**
     * @dev construction tests
     */

    /// @dev test should be initialized properly
    function testShouldBeInitializedProperly() public {
        uint256 version = voucher.version();
        assertEq(version, 2);

        bytes32 adminRole = keccak256("ROLE_ADMIN");
        assertEq(adminRole, voucher.roleAdmin());

        assertEq(admin, voucher.getRoleMember(adminRole, 0));

        assertEq(1, voucher.getRoleMemberCount(adminRole));

        assertEq(VOUCHER_SYMBOL, voucher.symbol());
        assertEq(VOUCHER_NAME, voucher.name());
    }

    /// @dev test should return the controller address
    function testShouldReturnControllerAddress() public {
        assertEq(address(carbonController), voucher.controller());
    }

    /// @dev test should revert when attempting to reinitialize
    function testShouldRevertWhenAttemptingToReinitialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        voucher.initialize(true, "ipfs://xxx", "");
    }

    /// @dev test should revert when attempting to mint from address other than the controller
    function testShouldRevertWhenAttemptingToMintFromAddressOtherThanTheController() public {
        vm.prank(user1);
        vm.expectRevert(IVoucher.OnlyController.selector);
        voucher.mint(user1, 1);
    }

    /// @dev test should revert when attempting to burn from address other than the controller
    function testShouldRevertWhenAttemptingToBurnFromAddressOtherThanTheController() public {
        vm.prank(user1);
        vm.expectRevert(IVoucher.OnlyController.selector);
        voucher.burn(1);
    }

    /// @dev test should revert when a non admin attempts to set the base URI
    function testShouldRevertWhenANonAdminAttemptsToSetTheBaseURI() public {
        vm.prank(user1);
        vm.expectRevert(AccessDenied.selector);
        voucher.setBaseURI("123");
    }

    /// @dev test should revert when a non admin tries to update the extension URI
    function testShouldRevertWhenANonAdminTriesToUpdateTheExtensionURI() public {
        vm.prank(user1);
        vm.expectRevert(AccessDenied.selector);
        voucher.setBaseExtension("123");
    }

    /// @dev test should revert when a non admin tries to call use global URI
    function testShouldRevertWhenANonAdminTriesToCallUseGlobalURI() public {
        vm.prank(user1);
        vm.expectRevert(AccessDenied.selector);
        voucher.useGlobalURI(false);
    }

    /// @dev test should emit BaseURIUpdated event
    function testEmitsBaseURIUpdatedEvent() public {
        vm.prank(admin);
        vm.expectEmit();
        emit BaseURIUpdated("123");
        voucher.setBaseURI("123");
    }

    /// @dev test should emit BaseExtensionUpdated event
    function testEmitsBaseExtensionUpdatedEvent() public {
        vm.prank(admin);
        vm.expectEmit();
        emit BaseExtensionUpdated("123");
        voucher.setBaseExtension("123");
    }

    /// @dev test should emit UseGlobalURIUpdated event
    function testEmitsUseGlobalURIUpdatedEvent() public {
        vm.prank(admin);
        vm.expectEmit();
        emit UseGlobalURIUpdated(false);
        voucher.useGlobalURI(false);
    }

    /// @dev test shouldn't emit UseGlobalURIUpdated if updated with the same value
    function testFailDoesntEmitUseGlobalURIUpdatedIfAnUpdateWasAttemptedWithSameValue() public {
        vm.startPrank(admin);
        voucher.useGlobalURI(true);
        vm.expectEmit();
        emit UseGlobalURIUpdated(true);
        voucher.useGlobalURI(true);
        vm.stopPrank();
    }

    /// @dev test should support erc721 interface
    function testShouldSupportERC721Interface() public {
        bytes4 erc721InterfaceId = 0x80ac58cd;
        assertTrue(voucher.supportsInterface(erc721InterfaceId));
    }

    /// @dev test should be able to transfer voucher token
    function testShouldBeAbleToTransferVoucherToken() public {
        vm.startPrank(user1);
        voucher.safeMintTest(user1, 0);
        assertEq(voucher.balanceOf(user1), 1);

        voucher.safeTransferFrom(user1, user2, 0);

        assertEq(voucher.balanceOf(user1), 0);
        assertEq(voucher.balanceOf(user2), 1);
    }

    /// @dev test transferring voucher token to same address shouldn't change balance
    function testTransferringVoucherTokenToSameAddressShouldntChangeBalance() public {
        vm.startPrank(user1);
        voucher.safeMintTest(user1, 0);
        assertEq(voucher.balanceOf(user1), 1);

        voucher.safeTransferFrom(user1, user1, 0);

        assertEq(voucher.balanceOf(user1), 1);
        assertEq(voucher.balanceOf(user2), 0);
    }

    /**
     * @dev tokens by owner function
     */

    /// @dev test should revert calling tokensByOwner for non valid owner address
    function testRevertsForNonValidOwnerAddress() public {
        vm.expectRevert(InvalidAddress.selector);
        voucher.tokensByOwner(address(0), 0, 100);
    }

    /// @dev test should fetch the correct token ids when calling tokensByOwner
    function testFetchesTheCorrectTokenIds() public {
        voucher.safeMintTest(user1, 1);
        voucher.safeMintTest(user1, 2);
        voucher.safeMintTest(user2, 3);

        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, 100);
        assertEq(tokenIds.length, 2);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
    }

    /// @dev test tokensByOwner should set end index to max possible if set to 0
    function testSetsEndIndexToTheMaxPossibleIfProvidedWithZero() public {
        for (uint256 i = 1; i < FETCH_AMOUNT + 1; ++i) {
            voucher.safeMintTest(user1, i);
        }
        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, 0);
        assertEq(tokenIds.length, FETCH_AMOUNT);
    }

    /// @dev test tokensByOwner should set end index to max possible if provided with an out of bounds value
    function testSetsEndIndexToTheMaxPossibleIfProvidedWithAnOutOfBoundValue() public {
        for (uint256 i = 1; i < FETCH_AMOUNT + 1; ++i) {
            voucher.safeMintTest(user1, i);
        }
        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, FETCH_AMOUNT + 100);
        assertEq(tokenIds.length, FETCH_AMOUNT);
    }

    /// @dev test tokensByOwner should revert if start index is greater than end index
    function testRevertsIfStartIndexIsGreaterThanEndIndex() public {
        for (uint256 i = 1; i < FETCH_AMOUNT + 1; ++i) {
            voucher.safeMintTest(user1, i);
        }
        vm.expectRevert(InvalidIndices.selector);
        voucher.tokensByOwner(user1, 6, 5);
    }

    /// @dev test reverts on attempt to set controller by user other than admin
    function testRevertsOnAttemptToSetControllerByUser() public {
        vm.prank(user1);
        vm.expectRevert(AccessDenied.selector);
        voucher.setController(user1);
    }

    /// @dev test attempt to set the controller address by admin should revert after the address has been set
    function testRevertsOnAttemptToChangeControllerByAdmin() public {
        vm.prank(admin);
        vm.expectRevert(IVoucher.ControllerAlreadySet.selector);
        voucher.setController(user1);
    }

    /// @dev test tokensByOwner should map owner when minting
    function testMapsOwnerWhenMinting() public {
        voucher.safeMintTest(user1, 1);
        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, 100);
        assertEq(tokenIds[0], 1);
    }

    /// @dev test tokensByOwner should clear owner mapping when burning
    function testClearsOwnerMappingWhenBurning() public {
        voucher.safeMintTest(user1, 1);
        voucher.burnTest(1);
        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, 100);
        assertEq(tokenIds.length, 0);
    }
}
