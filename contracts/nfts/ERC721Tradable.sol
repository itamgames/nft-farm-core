pragma solidity 0.7.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '../DelegateProxy.sol';

contract INFTFarmExchange {
    mapping(address => DelegateProxy) public proxies;
}

contract ERC721Tradable is ERC721, Ownable {
    address public exchange;
    uint256 public mintCount;

    constructor(string memory _name, string memory _symbol, string memory _baseURI, address _exchange) public ERC721(_name, _symbol) {
        _setBaseURI(_baseURI);
        exchange = _exchange;
        mintCount = 0;
    }

    function mintTo(address _to) public onlyOwner {
        mintCount++;
        _mint(_to, mintCount);
    }

    function changeBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    function changeExchange(address _exchange) public onlyOwner {
        exchange = _exchange;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), 'invalid token id');
        return string(abi.encodePacked(baseURI(), Strings.toString(_tokenId)));
    }

    function isApprovedForAll(address owner, address operator) public view override returns(bool) {
        return address(INFTFarmExchange(exchange).proxies(owner)) == operator || super.isApprovedForAll(owner, operator);
    }
}