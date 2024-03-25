// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.2 < 0.9.0;

import "CommitReveal.sol";

contract Lottery is CommitReveal{
    struct Player {
        uint choice;
        address addr;
    }
    mapping (uint => Player) public player;
    mapping (address => uint) public playerIndex;

    uint public numPlayer = 0;
    uint public maxPlayer;
    
    uint public reward = 0;
    uint public startTime = 0;
    
    address owner;
    uint public T1;
    uint public T2;
    uint public T3;

    constructor(uint _T1, uint _T2, uint _T3, uint _max_player) {
        T1 = _T1;
        T2 = _T2;
        T3 = _T3;
        maxPlayer = _max_player;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function checkCurrentState() public view returns(uint8){
        if(startTime == 0||block.timestamp < startTime)  return 0;
        if(block.timestamp < startTime + T1)
            return 1;
        if(block.timestamp < startTime + T1 + T2)
            return 2;
        if(block.timestamp < startTime + T1 + T2 + T3)
            return 3;
        else
            return 4;
    }

    function resetGame() internal {
        for(uint i = 0; i < numPlayer; i++)
        {
            if(commits[player[i].addr].commit!=0){
                delete commits[player[i].addr];
                delete player[i];
            }
        }
        reward=0;
        startTime=0;
        numPlayer=0;
    }

    function numberHash(uint lotteryNum,uint password) public view returns(bytes32){
        return getSaltedHash(bytes32(lotteryNum),bytes32(password));
    }

    function addPlayer(bytes32 hashedChoice) public payable {
        require(checkCurrentState() == 0 || checkCurrentState() == 1,"not addplayer stage");
        require(msg.value == 0.001 ether,"0.001 ether per lottery");
        require(numPlayer<maxPlayer,"full player");
        reward += msg.value;
        if(startTime == 0) {
            startTime = block.timestamp;
        }
        commit(hashedChoice);
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 1000;
        playerIndex[msg.sender] = numPlayer;
        numPlayer++;
    }

    function playerReveal(uint lotteryNum, uint password) public {
        require(checkCurrentState()==2,"not reveal state");
        revealAnswer(bytes32(lotteryNum),bytes32(password));
        player[playerIndex[msg.sender]].choice = lotteryNum;
    }

    function checkWinner() public payable onlyOwner{
        require(checkCurrentState()==3,"not check winner stage");
        uint numValidPlayer = 0;
        uint choiceXOR = 0;
        for(uint i = 0; i < numPlayer; i++){
            if(player[i].choice >= 0 && player[i].choice < 1000){
                numValidPlayer++;
                choiceXOR ^= player[i].choice;
            }
        }
        address winnerAddress = owner;
        uint winnerIndex;
        uint validIndex;
        if(numValidPlayer != 0){
            winnerIndex = uint(keccak256(abi.encodePacked(choiceXOR))) % numValidPlayer;
            validIndex = 0;
            for(uint i = 0; i < numPlayer; i++) {
                if(player[i].choice >= 0 && player[i].choice < 1000) {
                    if(validIndex == winnerIndex)
                        winnerAddress = player[i].addr;
                    else
                        validIndex ++;
                }
            }
        }
        address payable ownerPayable = payable(owner);
        address payable winnerPayable = payable(winnerAddress);
        ownerPayable.transfer(reward*2/100);
        winnerPayable.transfer(reward*98/100);
        resetGame();
    }

    function refund() public payable {
        require(checkCurrentState()==4,"this round is not expire");
        require(msg.sender == player[playerIndex[msg.sender]].addr);
        address payable playerAddress = payable(msg.sender);
        reward -= 0.001 ether;
        playerAddress.transfer(0.001 ether);
        if(numPlayer==0)
            resetGame();
    }
}