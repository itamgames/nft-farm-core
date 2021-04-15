pragma solidity 0.7.3;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '../DelegateProxy.sol';

contract INFTFarmExchange {
    mapping(address => DelegateProxy) public proxies;
}

contract ERC1155SelfMintable is ERC1155, Ownable {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    address public exchange;
    string public baseURI;
    mapping(uint256 => uint256) supply;
    mapping(bytes => bool) minted;

    // token owner => (token id => lock amount)
    mapping(address => mapping(uint256 => uint256)) public locks;

    event Lock(address _to, uint256 id, uint256 lockAmount, uint256 totalLockAmount);
    event Unlock(address _to, uint256 id, uint256 unlockAmount, uint256 totalUnlockAmount);

    constructor(string memory _name, string memory _symbol, string memory _baseURI, address _exchange) public ERC1155(_baseURI) {
        name = _name;
        symbol = _symbol;
        exchange = _exchange;
        baseURI = _baseURI;
    }

    function isApprovedForAll(address owner, address operator) public view override returns(bool) {
        return address(INFTFarmExchange(exchange).proxies(owner)) == operator || super.isApprovedForAll(owner, operator);
    }

    function changeBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        supply[id] = supply[id].add(amount);
        _mint(account, id, amount, data);
    }

    function mintToSelf(uint256 id, uint256 amount, bytes memory data, uint256 nonce, bytes calldata _signature) public {
        require(minted[_signature] == false, 'ERC1155SelfMintable: already mint signature');
        bytes32 message = keccak256(abi.encodePacked(address(this), msg.sender, id, amount, data, nonce));
        bytes32 signature = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', message));
        require(ECDSA.recover(signature, _signature) == owner(), 'ERC1155SelfMintable: invalid signature');
        supply[id] = supply[id].add(amount);
        _mint(msg.sender, id, amount, data);
        minted[_signature] = true;
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        for (uint i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            supply[id] = supply[id].add(amounts[i]);
        }

        _mintBatch(to, ids, amounts, data);
    }

    function mintBatchToSelf(uint256[] memory ids, uint256[] memory amounts, bytes memory data, bytes calldata _signature) public {
        bytes32 message = keccak256(abi.encodePacked(address(this), msg.sender, ids, amounts, data));
        bytes32 signature = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', message));
        require(ECDSA.recover(signature, _signature) == owner(), 'ERC1155SelfMintable: invalid signature');

        for (uint i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            supply[id] = supply[id].add(amounts[i]);
        }

        _mintBatch(msg.sender, ids, amounts, data);
    }

    function lock(uint256 id, uint256 amount) public {
        require(amount > 0, 'ERC1155SelfMintable: amount have to greater than 0');
        uint256 balanceAmount = balanceOf(msg.sender, id);
        uint256 lockAmount = locks[msg.sender][id];
        require(balanceAmount.sub(lockAmount) >= amount, 'ERC1155SelfMintable: overbalance lock amount');
        uint256 totalLockAmount = lockAmount.add(amount);
        locks[msg.sender][id] = totalLockAmount;
        Lock(msg.sender, id, amount, totalLockAmount);
    }

    function unlock(uint256 id, uint256 amount) public {
        require(amount > 0, 'ERC1155SelfMintable: amount have to greater than 0');
        uint256 lockAmount = locks[msg.sender][id];
        uint256 totalUnlockAmount = lockAmount.sub(amount);
        require(totalUnlockAmount >= 0, 'ERC1155SelfMintable: overbalance unlock amount');
        locks[msg.sender][id] = totalUnlockAmount;
        Unlock(msg.sender, id, amount, totalUnlockAmount);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual override {
        require(locks[msg.sender][id] >= amount, 'ERC1155SelfMintable: lock token');
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
        for (uint i = 0; i < ids.length; i++) {
            require(locks[msg.sender][ids[i]] >= amounts[i], 'ERC1155SelfMintable: lock token');
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function uri(uint256 _id) external view virtual override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(_id)));
    }

    function tokenSupply(uint256 _id) public view returns (uint256) {
        return supply[_id];
    }
}