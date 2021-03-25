pragma solidity 0.7.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '../DelegateProxy.sol';

contract INFTFarmExchange {
    mapping(address => DelegateProxy) public proxies;
}

contract ERC721SelfMintable is ERC721, Ownable {
    address public exchange;
    uint256 public mintCount;

    constructor(string memory _name, string memory _symbol, string memory _baseURI, address _exchange) public ERC721(_name, _symbol) {
        _setBaseURI(_baseURI);
        exchange = _exchange;
        mintCount = 0;
    }

    function mintTo(address _to, uint256 _tokenId) public onlyOwner {
        mintCount++;
        _mint(_to, _tokenId);
    }

    function mintToSelf(uint256 _tokenId, bytes calldata _signature) public {
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _tokenId));
        bytes32 signature = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', message));
        require(ECDSA.recover(signature, _signature) == owner(), 'invalid signature');
        mintCount++;
        _mint(msg.sender, _tokenId);
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