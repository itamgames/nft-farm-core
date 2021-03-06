// SPDX-License-Identifier: MIT
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
    // tokenId => lock
    mapping(uint256 => bool) public locks;
    mapping(bytes32 => bool) public usedHash;

    // minter => auth
    mapping(address => bool) public minters;

    // tokenId => uri path
    mapping(uint256 => string) public tokenURIPaths;
    
    event Lock(address indexed _to, uint256 indexed _tokenId);
    event Unlock(address indexed _to, uint256 indexed _tokenId);
    event UseNFT(address indexed _to, uint256 indexed _tokenId);
    event EmergencyBurn(address indexed _owner, uint256 indexed _tokenId);

    modifier onlyMinter {
        require(minters[msg.sender], 'ERC721SelfMintable: no authorized');
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _baseURI, address _exchange) public ERC721(_name, _symbol) {
        _setBaseURI(_baseURI);
        exchange = _exchange;
        mintCount = 0;
        minters[msg.sender] = true;
    }

    function mintTo(address _to, uint256 _tokenId, string memory _path) public onlyMinter {
        mintCount++;
        tokenURIPaths[_tokenId] = _path;
        _mint(_to, _tokenId);
    }

    function mintToSelf(uint256 _tokenId, string memory _path, bytes calldata _signature) public {
        bytes32 message = keccak256(abi.encodePacked(address(this), msg.sender, _tokenId, _path));
        bytes32 signature = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', message));
        require(ECDSA.recover(signature, _signature) == owner(), 'ERC721SelfMintable: invalid signature');
        mintCount++;
        tokenURIPaths[_tokenId] = _path;

        _mint(msg.sender, _tokenId);
    }

    function changeBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    function changeExchange(address _exchange) public onlyOwner {
        exchange = _exchange;
    }

    function lock(uint256 _tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721SelfMintable: transfer caller is not owner nor approved");
        require(locks[_tokenId] == false, 'ERC721SelfMintable: already lock token');
        locks[_tokenId] = true;
        emit Lock(msg.sender, _tokenId);
    }

    function unlock(uint256 _tokenId, uint256 _nonce, bytes calldata _signature) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721SelfMintable: transfer caller is not owner nor approved");
        require(locks[_tokenId], 'ERC721SelfMintable: already unlock token');

        bytes32 message = keccak256(abi.encodePacked(address(this), msg.sender, _tokenId, _nonce, 'unlock'));
        require(usedHash[message] == false, 'ERC721SelfMintable: already used hash');

        bytes32 signature = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', message));
        require(ECDSA.recover(signature, _signature) == owner(), 'ERC721SelfMintable: invalid signature');

        locks[_tokenId] = false;
        usedHash[message] = true;
        emit Unlock(msg.sender, _tokenId);
    }

    function use(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == _msgSender(), "ERC721SelfMintable: transfer caller is not owner nor approved");
        _burn(_tokenId);
        emit UseNFT(_msgSender(), _tokenId);

    }

    function emergencyBurn(uint256 _tokenId) public onlyOwner {
        _burn(_tokenId);
    }

    function setMinter(address _minter, bool _auth) public onlyOwner {
        minters[_minter] = _auth;
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(locks[tokenId] == false, 'ERC721SelfMintable: lock token');
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(locks[tokenId] == false, 'ERC721SelfMintable: lock token');
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(locks[tokenId] == false, 'ERC721SelfMintable: lock token');
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), 'ERC721: invalid token id');
        return string(abi.encodePacked(baseURI(), tokenURIPaths[_tokenId]));
    }

    function isApprovedForAll(address owner, address operator) public view override returns(bool) {
        return address(INFTFarmExchange(exchange).proxies(owner)) == operator || super.isApprovedForAll(owner, operator);
    }
}