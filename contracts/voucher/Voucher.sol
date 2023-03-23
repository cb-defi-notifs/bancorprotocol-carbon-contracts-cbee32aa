// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Utils, InvalidIndices } from "../utility/Utils.sol";
import { IVoucher } from "./interfaces/IVoucher.sol";
import { CarbonController } from "../carbon/CarbonController.sol";

contract Voucher is IVoucher, ERC721, Utils, Ownable {
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    error CarbonControllerNotSet();
    error BatchNotSupported();

    // the carbon controller contract
    CarbonController private _carbonController;

    // a flag used to toggle between a unique URI per token / one global URI for all tokens
    bool private _useGlobalURI;

    // the prefix of a dynamic URI representing a single token
    string private __baseURI;

    // the suffix of a dynamic URI for e.g. `.json`
    string private _baseExtension;

    // a mapping between an owner to its tokenIds
    mapping(address => EnumerableSet.UintSet) internal _owned;

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

    /**
     * @dev triggered when updating the address of the carbonController contract
     */
    event CarbonControllerUpdated(CarbonController carbonController);

    constructor(
        bool newUseGlobalURI,
        string memory newBaseURI,
        string memory newBaseExtension
    ) ERC721("Carbon Automated Trading Strategy", "CARBON-STRAT") {
        useGlobalURI(newUseGlobalURI);
        setBaseURI(newBaseURI);
        setBaseExtension(newBaseExtension);
    }

    /**
     * @inheritdoc IVoucher
     */
    function mint(address owner, uint256 tokenId) external only(address(_carbonController)) {
        _safeMint(owner, tokenId);
    }

    /**
     * @inheritdoc IVoucher
     */
    function burn(uint256 tokenId) external only(address(_carbonController)) {
        _burn(tokenId);
    }

    /**
     * @inheritdoc IVoucher
     */
    function tokensByOwner(
        address owner,
        uint256 startIndex,
        uint256 endIndex
    ) external view validAddress(owner) returns (uint256[] memory) {
        EnumerableSet.UintSet storage tokenIds = _owned[owner];
        uint256 allLength = tokenIds.length();

        // when the endIndex is 0 or out of bound, set the endIndex to the last value possible
        if (endIndex == 0 || endIndex > allLength) {
            endIndex = allLength;
        }

        // revert when startIndex is out of bound
        if (startIndex > endIndex) {
            revert InvalidIndices();
        }

        // populate the result
        uint256 resultLength = endIndex - startIndex;
        uint256[] memory result = new uint256[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            uint256 tokenId = tokenIds.at(startIndex + i);
            result[i] = tokenId;
        }

        return result;
    }

    /**
     * @dev stores the carbonController address
     *
     * requirements:
     *
     * - the caller must be the owner of this contract
     */
    function setCarbonController(
        CarbonController carbonController
    ) external onlyOwner validAddress(address(carbonController)) {
        if (_carbonController == carbonController) {
            return;
        }

        _carbonController = carbonController;
        emit CarbonControllerUpdated(carbonController);
    }

    /**
     * @dev depending on the useGlobalURI flag, returns a unique URI point to a json representing the voucher,
     * or a URI of a global json used for all tokens
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        string memory baseURI = _baseURI();
        if (_useGlobalURI) {
            return baseURI;
        }

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), _baseExtension)) : "";
    }

    /**
     * @dev sets the base URI
     *
     * requirements:
     *
     * - the caller must be the owner of this contract
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        __baseURI = newBaseURI;

        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev sets the base extension
     *
     * requirements:
     *
     * - the caller must be the owner of this contract
     */
    function setBaseExtension(string memory newBaseExtension) public onlyOwner {
        _baseExtension = newBaseExtension;

        emit BaseExtensionUpdated(newBaseExtension);
    }

    /**
     * @dev sets the useGlobalURI flag
     *
     * requirements:
     *
     * - the caller must be the owner of this contract
     */
    function useGlobalURI(bool newUseGlobalURI) public onlyOwner {
        if (_useGlobalURI == newUseGlobalURI) {
            return;
        }

        _useGlobalURI = newUseGlobalURI;
        emit UseGlobalURIUpdated(newUseGlobalURI);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI`, `tokenId`
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return __baseURI;
    }

    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        if (batchSize > 1) {
            revert BatchNotSupported();
        }

        if (from == address(0)) {
            _owned[to].add(firstTokenId);
        } else if (from != to) {
            _owned[from].remove(firstTokenId);
        }
        if (to == address(0)) {
            _owned[from].remove(firstTokenId);
        } else if (to != from) {
            _owned[to].add(firstTokenId);
        }
    }
}
