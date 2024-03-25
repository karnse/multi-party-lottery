# multi-party-lottery

### announce struct,mapping and variables

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


### 