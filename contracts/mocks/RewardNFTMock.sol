// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RewardNFTMock is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint256 public currentTokenID;

    constructor() ERC721("Reward NFT", "RWNFT") {}

    function safeMint(address to) public onlyOwner {
        uint256 newItemId = _tokenIdCounter.current();
        _safeMint(to, newItemId);
        _tokenIdCounter.increment();
        currentTokenID = newItemId;
    }
}
