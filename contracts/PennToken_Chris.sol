pragma solidity >=0.4.21 <0.6.0;

import "./IERC20.sol";
import "./SafeMath.sol";

contract PennToken is IERC20 {
  using SafeMath for uint256;

  enum eventState {CREATED, SIGNIN, CLOSED, REWARDED}
  enum rewardState {REDEEM, CLOSED}

  mapping (uint => mapping (address => bool)) attendance;
  mapping (uint => Event) events;
  mapping (uint => Reward) rewards;
  mapping (address => bool) owners;
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;

  uint256 private _totalSupply;

  uint numRewards = 0;

  struct Event {
    uint EventID;
    eventState state;
    string description;
    uint rewardAmount;
    uint maxAttendees;
    address[] presentMembers;
  }

  struct Reward {
      uint RewardID;
      rewardState state;
      string description;
      uint price;
      uint numClaimed;
      uint maxClaimable;
  }

  event EventCreated (uint indexed EventID, string description);
  event EventOpen (uint indexed EventID, string description);
  event EventClosed (uint indexed EventID, string description);
  event TokensMinted (uint indexed EventID, uint amount, address receiver, string description);
  event RewardCreated (uint indexed RewardID, uint price, string description);
  event RewardRedeemable (uint indexed RewardID, uint price, string description);
  event RewardClosed (uint indexed RewardID, uint price, string description);
  event RewardClaimed (uint indexed RewardID, uint price, string description, address indexed claimer);
  event AttendeeSignedIn (uint indexed EventID, address indexed attendee, string description);

  modifier onlyOwners (address sender) {
      require(owners[sender], "not owner");
      _;
  }

  constructor () public {
      owners[msg.sender] = true;
  }

  function signIn(uint EventID) public {
    require(attendance[EventID][msg.sender] == false, "already signed in");
    require(events[EventID].state == eventState.SIGNIN, "not sign in period");
    attendance[EventID][msg.sender] = true;
    events[EventID].presentMembers.push(msg.sender);
    emit AttendeeSignedIn(EventID, msg.sender, events[EventID].description);
  }

  function createNewEvent (string memory _description, uint _rewardAmount, uint _maxAttendees, uint _EventID) public onlyOwners(msg.sender) {
      address[] memory _presentMembers;
      events[_EventID] = Event ({
          EventID: _EventID,
          state: eventState.CREATED,
          description: _description,
          rewardAmount: _rewardAmount,
          maxAttendees: _maxAttendees,
          presentMembers: _presentMembers
      });
      emit EventCreated(_EventID, _description);
  }

  function openEvent (uint EventID) onlyOwners (msg.sender) public {
      events[EventID].state = eventState.SIGNIN;
      emit EventOpen (EventID, events[EventID].description);
  }

  function closeEvent (uint EventID) onlyOwners (msg.sender) public {
      events[EventID].state = eventState.CLOSED;
      emit EventClosed (EventID, events[EventID].description);
  }

  function mintTokensForAttendees (uint EventID) onlyOwners (msg.sender) public {
      events[EventID].state = eventState.REWARDED;
      uint attendanceReward = events[EventID].rewardAmount;
      address[] storage attendees = events[EventID].presentMembers;
      uint size = attendees.length;
      string memory description = events[EventID].description;
      uint i = 0;
      for (i; i < size; i++) {
          address attendee = attendees[i];
          _balances[attendee] = _balances[attendee] += attendanceReward;
          emit TokensMinted (EventID, attendanceReward, attendee, description);
      }
      _totalSupply += (size * attendanceReward);

  }

  function createReward (string memory _description, uint _price, uint _maxClaimable) onlyOwners(msg.sender) public {
      numRewards ++;
      rewards[numRewards] = Reward({
          RewardID: numRewards,
          state: rewardState.REDEEM,
          description: _description,
          price: _price,
          numClaimed: 0,
          maxClaimable: _maxClaimable
      });
      emit RewardCreated(numRewards, _price, _description);
  }
  
  function closeRedemption (uint RewardID) onlyOwners(msg.sender) public {
      rewards[RewardID].state = rewardState.CLOSED;
      emit RewardClosed(rewards[RewardID].RewardID, rewards[RewardID].price, rewards[RewardID].description);
  }

  function claimReward (uint RewardID) public {
      require(rewards[RewardID].state == rewardState.REDEEM, "unable to redeem now");
      require(balanceOf(msg.sender) >= rewards[RewardID].price, "not enough Penn Tokens");
      require(rewards[RewardID].numClaimed < rewards[RewardID].maxClaimable, "this reward has been claimed too many times");
      _balances[msg.sender] -= (rewards[RewardID].price);
      _totalSupply -= (rewards[RewardID].price);
      rewards[RewardID].numClaimed += 1;
      emit RewardClaimed(rewards[RewardID].RewardID, rewards[RewardID].price, rewards[RewardID].description, msg.sender);
  }

  function addOwner (address newOwner) onlyOwners(msg.sender) public {
      owners[newOwner] = true;
  }

  function removeOwner (address owner) onlyOwners(msg.sender) public {
      owners[owner] = false;
  }

  function manualReward (address receiver, uint amount) onlyOwners(msg.sender) public {
      _balances[receiver] += amount;
      _totalSupply += amount;
  }
  
  function claimReward2 (uint RewardID) public {
      require(rewards[RewardID].state == rewardState.REDEEM, "unable to redeem now");
      require(balanceOf(msg.sender) >= rewards[RewardID].price, "not enough Penn Tokens");
      require(rewards[RewardID].numClaimed < rewards[RewardID].maxClaimable, "this reward has been claimed too many times");
      _balances[msg.sender] -= (rewards[RewardID].price);
      _totalSupply -= (rewards[RewardID].price);
      rewards[RewardID].numClaimed += 1;
      emit RewardClaimed(rewards[RewardID].RewardID, rewards[RewardID].price, rewards[RewardID].description, msg.sender);
  }
  
  function transfer(address to, uint256 value) public returns(bool){
    address from = msg.sender;
    require(to != address(0), "ERC20: transfer to the zero address");
    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
    return true;
  }
  
  function approve(address spender, uint256 value) public returns(bool) {
    require(spender != address(0), "ERC20: transfer to the zero address");
    address owner = msg.sender;
    emit Approval(owner, spender, value);
    return true;
  }
  
  function transferFrom(address from, address to, uint256 value) public returns(bool) {}

  function totalSupply () public view returns (uint256){
    return _totalSupply;
  }

  function balanceOf(address who) public view returns (uint256){
    return _balances[who];
  }

  function allowance(address owner, address spender) public view returns (uint256){
    // need to work this out
    return _allowed[owner][spender];
  }

}
