// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title MockERC721
/// @author Egbolcuhe Francis
/// @notice A mock NFT contract for local testing
contract MockERC721 is ERC721 {
    uint256 public tokenCounter;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    /// @notice mints a token to an address
    /// @param user the address the token is minted to
    function mintToken(address user) public {
        tokenCounter++;
        _mint(user, tokenCounter);
    }
}
