# multi-party-lottery

## announce struct,mapping and variables

```solidity
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
```

- player เก็บข้อมูลของผู้เล่น
- playerIndex เก็บ index ของผู้เล่น โดยใช้ address เป็น key
- numPlayer เก็บจำนวนผู้เล่น
- maxPlayer เก็บจำนวนผู้เล่นที่สูงสุด
- reward เก็บเงินรางวัล
- startTime เก็บเวลาเริ่มต้นของการเล่น
- owner เก็บ address ของเจ้าของ contract
- T1, T2, T3 เก็บเวลาของแต่ละสถานะ

## constructor

```solidity
constructor(uint _T1, uint _T2, uint _T3, uint _max_player) {
    T1 = _T1;
    T2 = _T2;
    T3 = _T3;
    maxPlayer = _max_player;
    owner = msg.sender;
}
```
ให้ผู้สร้าง contract กำหนดเวลาของแต่ละสถานะและจำนวนผู้เล่นที่สูงสุด

## modifier

```solidity
modifier onlyOwner() {
    require(msg.sender == owner);
    _;
}
```

ให้เฉพาะเจ้าของ contract ที่สามารถเรียกใช้ function ได้

# function

## เช็ค state ของ contract

```solidity
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
```

return 0: ready to commit state, 1: commit state, 2: reveal state, 3: find winner state, 4: refund state

## Reset contract

```solidity
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
```

ใช้เมื่อแจกเงินให้กันผู้ชนะแล้ว หรือเมื่อทุกคนขอเงินคืน เพื่อให้ reuse contract ได้

## Hash

```solidity
function numberHash(uint lotteryNum,uint password) public view returns(bytes32){
    return getSaltedHash(bytes32(lotteryNum),bytes32(password));
}
```

hash ตัวเลข lotteryNum กับ password ของผู้เล่น

## Add player[state 0/1]

```solidity
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
```

เพิ่มผู้เล่น โดยต้องเป็นstate 0 หรือ 1 และจ่ายค่าธรรมเนียม 0.001 ether ต่อคน และจะเก็บ hash ของตัวเลขที่เลือกไว้ก่อน

## Player reveal[state 2]

```solidity
function playerReveal(uint lotteryNum, uint password) public {
    require(checkCurrentState()==2,"not reveal state");
    revealAnswer(bytes32(lotteryNum),bytes32(password));
    player[playerIndex[msg.sender]].choice = lotteryNum;
}
```

เปิดเผยตัวเลขที่เลือก โดยต้องเป็นstate 2

## Find winner[state 3]

```solidity
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
```

หาผู้ชนะ โดยต้องเป็นstate 3 และจะแจกเงินให้กับผู้ชนะ 98% และเจ้าของ contract 2% และ reset contract

## Refund[state 4]

```solidity
function refund() public payable {
    require(checkCurrentState()==4,"this round is not expire");
    require(msg.sender == player[playerIndex[msg.sender]].addr);
    address payable playerAddress = payable(msg.sender);
    reward -= 0.001 ether;
    playerAddress.transfer(0.001 ether);
    if(numPlayer==0)
        resetGame();
}
```

หากไม่มีผู้เล่นเลยและเจ้าของ contract ไม่หุบเงินให้ผู้เล่นสามารถขอเงินคืนได้ และ ถ้าขอครบทุกคนให้ reset contract

