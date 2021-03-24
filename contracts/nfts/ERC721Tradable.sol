pragma solidity 0.7.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '../DelegateProxy.sol';

contract INFTFarmExchange {
    mapping(address => DelegateProxy) public proxies;
}

contract ERC721Tradable is ERC721, Ownable {
    address public exchange;
    uint256 public mintCount;
    string public baseTokenURI;

    constructor(string memory _name, string memory _symbol, string memory _baseTokenURI, address _exchange) public ERC721(_name, _symbol) {
        baseTokenURI = _baseTokenURI;
        exchange = _exchange;
        mintCount = 0;
    }

    function mintTo(address _to) public onlyOwner {
        mintCount++;
        _mint(_to, mintCount);
    }

    function changeBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, _tokenId));
    }

    function isApprovedForAll(address owner, address operator) public view override returns(bool) {
        return address(INFTFarmExchange(exchange).proxies(owner)) == operator || super.isApprovedForAll(owner, operator);
    }
}