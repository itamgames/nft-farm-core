pragma solidity 0.7.3;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract DelegateProxy {
    address public user;
    mapping(address => bool) public approves;

    constructor(address _user) {
        user = _user;
        approves[_user] = true;
        approves[msg.sender] = true;
    }

    modifier onlyApprover {
        require(approves[msg.sender], 'DelegateProxy: unauthorized');
        _;
    }

    function setApprove(address _approver, bool _approve) onlyApprover public {
        approves[_approver] = _approve;
    }

    function proxyCall(address _target, bytes calldata _calldata) onlyApprover public returns(bool) {
        (bool result, ) = _target.call(_calldata);
        return result;
    }

    function proxyTransferFrom(address _target, address _from, address _to, uint256 _value) onlyApprover public returns(bool) {
        return IERC20(_target).transferFrom(_from, _to, _value);
    }
}