pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./EIP712Base.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ERC20Interface {
  function transferFrom(address from, address to, uint tokens) external returns (bool success);
}

contract Subscriptions is Ownable, EIP712Base{
  using Address for address;

  struct Tier {
    bool valid;
    bytes32 tierId;
    address creator;
    uint256 price;
    uint256 motoCommission;
  }

  struct Subscription{
    Tier tier;
    uint256 expirationDate;
  }

  //keccak(creator, price);
  mapping(bytes32 => Tier) private _subscriptionDefintions;
  //keccak(creator,subscriber)
  mapping(bytes32 => Subscription) private _subscriptions;

  uint256 private _commission = 2;//in percent
  ERC20Interface immutable _acceptedToken;
  constructor(address acceptedToken_){
    require(acceptedToken_.isContract(), "not valid Token");
    _initializeEIP712("MotoSubscriptions","1");
    _acceptedToken = ERC20Interface(acceptedToken_);
  }

  function createTier(uint256 price) public returns (bytes32){
    require(price > 0,"price too low");
    uint256 motoFee = _calculateFee(price);
    bytes32 tierId = keccak256(abi.encodePacked(_msgSender(),price));
    _subscriptionDefintions[tierId] = Tier(true, tierId, _msgSender(),price+motoFee, _commission);
    return tierId;
  }

  function cancelTier(bytes32 subDefId) external{
    Tier storage subDef = _subscriptionDefintions[subDefId];
    require(_msgSender() == subDef.creator);
    _subscriptionDefintions[subDefId].valid = false;
  }
  function subscribe(bytes32 subDefinitionId, uint256 amount) public{
    Tier storage subDef = _subscriptionDefintions[subDefinitionId];
    require(subDef.creator != address(0));
    require(amount >= subDef.price);
    uint256 den = (100 + subDef.motoCommission)/100;
    uint256 creatorAmount = amount / den;
    uint256 motoAmount = amount - creatorAmount;
    uint256 monthsBought = creatorAmount/subDef.price;
    uint256 addedTime = block.timestamp + monthsBought * 30 days ;
    bytes32 subscriptionId = keccak256(abi.encodePacked(subDef.creator,_msgSender()));
    Subscription memory subscription = getSubscription(subscriptionId);
    if(subscription.expirationDate > block.timestamp){
      subscription.expirationDate = subscription.expirationDate + addedTime;
    }
    else{
      _subscriptions[subscriptionId] = Subscription(subDef, block.timestamp + addedTime);

    }
    _acceptedToken.transferFrom(_msgSender(),subDef.creator,creatorAmount);
    _acceptedToken.transferFrom(_msgSender(),owner(), motoAmount);
  } 

  function getSubscription(bytes32 subscriptionId) public view returns (Subscription memory){
    return _subscriptions[subscriptionId];
  }

  function _calculateFee(uint256 amount) private view returns (uint256){
    return (amount * _commission) / 100;
  }

  function changeCommission(uint256 amount) external {
    require(amount <= 5, "fee must be less than 5 percent");
    _commission = amount;
  }
}