// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigTreasury {

    event TransactionProposed(uint256 indexed txId, address indexed proposer);
    event TransactionApproved(uint256 indexed txId, address indexed owner);
    event ApprovalRevoked(uint256 indexed txId, address indexed owner); // not required
    event TransactionExecuted(uint256 indexed txId);

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 newThreshold);

    error NotOwner();
    error TxDoesNotExist(uint256 txId);
    error TxAlreadyExecuted(uint256 txId);
    error AlreadyApproved(uint256 txId, address owner);
    error NotApproved(uint256 txId, address owner);
    error InsufficientApprovals(uint256 txId);
    error InvalidThreshold(uint256 threshold);
    error InvalidOwner(address owner);

    // owners list
    address[] private owners;
    mapping(address => bool) private _isOwner;

    // approvals required
    uint256 private threshold;

    // transaction structure
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
    }

    Transaction[] private _transactions;

    // txId => owner => approved
    mapping(uint256 => mapping(address => bool)) private _approved;

    modifier onlyOwner() {
        if (!_isOwner[msg.sender]) revert NotOwner();
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        // will figure this out later lol
           if (_owners.length == 0) revert InvalidThreshold(_threshold);
    if (_threshold == 0 || _threshold > _owners.length) revert InvalidThreshold(_threshold);

    for (uint256 i = 0; i < _owners.length; i++) {
        address owner = _owners[i];
        if (owner == address(0)) revert InvalidOwner(owner);
        if (_isOwner[owner]) revert InvalidOwner(owner); // duplicate

        _isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAdded(owner);
    }

    threshold = _threshold;
    emit ThresholdChanged(_threshold);
    }

    recieve() external payable {}

    fallback() external payable {}

    // propose a transaction
    function proposeTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (uint256 txId) {
        
        if (to == address(0)) revert InvalidOwner(to);

        _transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            approvalCount: 0
        }));

        txId = _transactions.length - 1;

        emit TransactionProposed(txId, msg.sender);

        // return txId;    

    }

    function approveTransaction(uint256 txId) external onlyOwner {
        if (txId >= _transactions.length) revert TxDoesNotExist(txId); 
        
        Transaction storage txn = _transactions[txId];

        if (txn.executed) revert TxAlreadyExecuted(txId); 

        if (_approved[txId][msg.sender]) revert AlreadyApproved(txId, msg.sender);

        _approved[txId][msg.sender] = true;
        txn.approvalCount += 1;

        emit TransactionApproved(txId, msg.sender);
    }

    function revokeApproval(uint256 txId) external onlyOwner {
         if (txId >= _transactions.length) revert TxDoesNotExist(txId);
        
        Transaction storage txn = _transactions[txId];

        if (txn.executed) revert TxAlreadyExecuted(txId); 

        if (!_approved[txId][msg.sender]) revert NotApproved(txId, msg.sender); 

        _approved[txId][msg.sender] = false;
        txn.approvalCount -= 1;

        emit ApprovalRevoked(txId, msg.sender);
    }

function executeTransaction(uint256 txId) external onlyOwner {
    if (txId >= _transactions.length) revert TxDoesNotExist(txId);

    Transaction storage txn = _transactions[txId];

    if (txn.executed) revert TxAlreadyExecuted(txId);

    if (txn.approvalCount < threshold) revert InsufficientApprovals(txId);

    txn.executed = true;

    (bool ok, bytes memory ret) = txn.to.call{value: txn.value}(txn.data);
    if (!ok) {
        // bubble revert data if present
        assembly {
            revert(add(ret, 0x20), mload(ret))
        }
    }

    emit TransactionExecuted(txId);
}



    function addOwner(address owner) external {
        if (msg.sender != address(this)) revert NotOwner();
        if (owner == address(0)) revert InvalidOwner(owner);
        if (_isOwner[owner]) revert InvalidOwner(owner);

        _isOwner[owner] = true;
        owners.push(owner);

        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) external {
        if (msg.sender != address(this)) revert NotOwner();

        if(!_isOwner[owner]) revert InvalidOwner(owner);

        if(owners.length - 1 < threshold) {
            revert InvalidThreshold(threshold);
        }

        _isOwner[owner] = false;

        uint256 len = owners.length;
        for (uint256 i = 0; i < len; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[len -1];
                owners.pop();
                break;
            }
        }

        emit OwnerRemoved(owner);
    }

    function changeThreshold(uint256 newThreshold) external {
        if (msg.sender != address(this)) revert NotOwner();

        if(_newThreshold == 0 || _newThreshold > owners.length) {
            revert InvalidThreshold(_newThreshold);
        }

        threshold = _newThreshold;

        emit ThresholdChanged(_newThreshold);
    }

    function isOwner(address account) external view returns (bool) {
        return _isOwner[account];
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 txId) external view returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 approvalCount
        )
    {
        Transaction storage txn = _transactions[txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.approvalCount);
    }
}
