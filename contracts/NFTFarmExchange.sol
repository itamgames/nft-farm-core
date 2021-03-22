pragma solidity 0.7.3;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/cryptography/ECDSA.sol';
import './DelegateProxy.sol';

struct Order {
    address user;
    address target;
    bytes targetCalldata;
    address paymentToken;
    uint256 paymentAmount;
    uint256 feePercent;
    uint256 expirationBlock;
    uint256 nonce;
}

contract NFTFarmExchange is Ownable {
    using SafeMath for uint256;

    // Address of team
    address public team;

    // minimum exchange fee
    uint256 public minimumFeePercent;

    // cancel or ordered hashs
    mapping(bytes32 => bool) public closedOrders;

    // proxy for send nft
    mapping(address => DelegateProxy) public proxies;

    event Exchange(address nft, address seller, address buyer, address paymentToken, uint256 paymentAmount);
    event CancelOrder();

    constructor(address _team, uint256 _minimumFeePercent) {
        team = _team;
        minimumFeePercent = _minimumFeePercent;
    }

    function exchange(
        address _target,
        bytes calldata _targetCalldata,
        address _paymentToken,
        uint256 _paymentAmount,
        uint256 _feePercent,
        address _seller,
        address _buyer,
        uint256[2] calldata _expirationBlocks,
        uint256[2] calldata _nonces,
        bytes[2] calldata _signatures
    ) public {
        // prevent stack limit error
        _exchangeTargetForToken(
            Order(_seller, _target, _targetCalldata, _paymentToken, _paymentAmount, _feePercent, _expirationBlocks[0], _nonces[0]),
            _signatures[0],
            Order(_buyer, _target, _targetCalldata, _paymentToken, _paymentAmount, _feePercent, _expirationBlocks[1], _nonces[1]),
            _signatures[1]
        );
    }

    function _exchangeTargetForToken(Order memory _sellOrder, bytes memory _sellerSignature, Order memory _buyOrder, bytes memory _buyerSignature) internal {
        bytes32 sellHash = keccak256(abi.encodePacked(_sellOrder.target, _sellOrder.targetCalldata, _sellOrder.paymentToken, _sellOrder.paymentAmount, _sellOrder.feePercent, _sellOrder.expirationBlock, _sellOrder.nonce));
        require(_validHash(_sellOrder.user, sellHash, _sellerSignature), 'invalid seller signature');
        require(closedOrders[sellHash] == false, 'closed seller order');
        require(_sellOrder.expirationBlock == 0 || _sellOrder.expirationBlock < block.timestamp, 'expired seller order');

        bytes32 buyHash = keccak256(abi.encodePacked(_buyOrder.target, _buyOrder.targetCalldata, _buyOrder.paymentToken, _buyOrder.paymentAmount, _buyOrder.feePercent, _buyOrder.expirationBlock, _buyOrder.nonce));
        require(_validHash(_buyOrder.user, buyHash, _buyerSignature), 'invalid buyer signature');
        require(closedOrders[buyHash] == false, 'closed buyer order');
        require(_buyOrder.expirationBlock == 0 || _buyOrder.expirationBlock < block.timestamp, 'expired buyer order');

        require(_sellOrder.user != _buyOrder.user, 'cannot match myself');
        require(_matchOrder(_sellOrder, _buyOrder), 'not matched order');

        require(_buyOrder.feePercent >= minimumFeePercent, 'fee percent too low');
        uint256 paymentAmount = _buyOrder.paymentAmount;
        uint256 feeAmount = paymentAmount.div(100).mul(_buyOrder.feePercent);

        DelegateProxy buyerProxy = proxies[_buyOrder.user];
        require(buyerProxy.proxyTransferFrom(_buyOrder.paymentToken, _buyOrder.user, _sellOrder.user, paymentAmount.sub(feeAmount)), 'failed to send payment amount');
        if (feeAmount > 0) {
            require(buyerProxy.proxyTransferFrom(_buyOrder.paymentToken, _buyOrder.user, team, paymentAmount.sub(feeAmount)), 'failed to send fee');
        }

        DelegateProxy sellerProxy = proxies[_sellOrder.user];
        require(sellerProxy.proxyCall(_sellOrder.target, _sellOrder.targetCalldata), 'failed to send target');

        closedOrders[sellHash] = true;
        closedOrders[buyHash] = true;
    }

    function _validHash(address _signer, bytes32 _message, bytes memory _signature) internal pure returns(bool) {
        bytes32 signature = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', _message));
        return ECDSA.recover(signature, _signature) == _signer;
    }

    function _matchOrder(Order memory orderA, Order memory orderB) internal pure returns(bool) {
        return orderA.target == orderB.target &&
               _equalBytes(orderA.targetCalldata, orderB.targetCalldata) &&
               orderA.paymentToken == orderB.paymentToken &&
               orderA.paymentAmount == orderB.paymentAmount &&
               orderA.feePercent == orderB.feePercent;
    }

    function _equalBytes(bytes memory a, bytes memory b) internal pure returns(bool equal) {
        if (a.length != b.length) {
            return false;
        }

        uint addr;
        uint addr2;
        uint len = a.length;
        assembly {
            addr := add(a, /*BYTES_HEADER_SIZE*/32)
            addr2 := add(b, /*BYTES_HEADER_SIZE*/32)
            equal := eq(keccak256(addr, len), keccak256(addr2, len))
        }
    }

    function createProxy() public {
        require(proxies[msg.sender].user() == address(0), 'already created proxy');
        DelegateProxy proxy = new DelegateProxy(msg.sender);
        proxies[msg.sender] = proxy;
    }

    function changeTeam(address _team) public onlyOwner {
        team = _team;
    }

    function changeMinimumFeePercent(uint8 _minimumFeePercent) public onlyOwner {
        require(_minimumFeePercent <= 100, 'invalid percent');
        minimumFeePercent = _minimumFeePercent;
    }
}