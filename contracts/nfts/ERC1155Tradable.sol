pragma solidity 0.7.3;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '../DelegateProxy.sol';

contract INFTFarmExchange {
    mapping(address => DelegateProxy) public proxies;
}

contract ERC1155Tradable is ERC1155, Ownable {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    address public exchange;
    string public baseURI;
    mapping(uint256 => uint256) supply;

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

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        for (uint i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            supply[id] = supply[id].add(amounts[i]);
        }

        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 _id) external view virtual override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(_id)));
    }

    function tokenSupply(uint256 _id) public view returns (uint256) {
        return supply[_id];
    }
}