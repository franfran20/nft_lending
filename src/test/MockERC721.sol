// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 public tokenCounter;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function mintToken(address user) public {
        tokenCounter++;
        _mint(user, tokenCounter);
    }
}
