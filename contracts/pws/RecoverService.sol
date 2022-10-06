//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract RecoverService {
    event SubmitRecover(address indexed owner, uint indexed txIndex, bytes data);
    event ConfirmRecover(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteRecover(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    struct Recover {
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Recover[] public recovers;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < recovers.length, "rc does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!recovers[_txIndex].executed, "rc already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "rc already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {}

    fallback() external payable {}

    function submitRecover(
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = recovers.length;

        recovers.push(
            Recover({
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitRecover(msg.sender, txIndex, _data);
    }

    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Recover storage recover = recovers[_txIndex];
        recover.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmRecover(msg.sender, _txIndex);
    }

    function executeRecover(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Recover storage recover = recovers[_txIndex];

        require(
            recover.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        recover.executed = true;

        emit ExecuteRecover(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Recover storage recover = recovers[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        recover.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getRecoverCount() public view returns (uint) {
        return recovers.length;
    }

    function getRecover(uint _txIndex)
        public
        view
        returns (
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Recover storage recover = recovers[_txIndex];
        return (
            recover.data,
            recover.executed,
            recover.numConfirmations
        );
    }
}
