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
    address owner;
    uint256 price;
    uint256 motoCommission;
  }

  struct Subscription{
    Tier tier;
    uint256 expirationDate;
  }

  //keccak(owner, price);
  mapping(bytes32 => Tier) private _tiers;
  //keccak(subscriber,tierID)
  mapping(bytes32 => Subscription) private _subscriptions;

  uint256 private _commission = 2;//in percent
  ERC20Interface immutable _acceptedToken;
  constructor(address acceptedToken_){
    require(acceptedToken_.isContract(), "not valid Token");
    _initializeEIP712("MotoSubscriptions","1");
    _acceptedToken = ERC20Interface(acceptedToken_);
  }

  function createTier(uint256 price) public returns (bytes32){
    return _updateTier(price);
  }

  function changePrice(bytes32 tierId, uint256 price) public returns (bytes32){
    Tier storage tier = _tiers[tierId];
    require(_msgSender() == tier.owner);
    delete(_tiers[tierId]);
    return _updateTier(price);
  }

  function _updateTier(uint256 price) private returns (bytes32){
    require(price > 0,"price too low");
    uint256 motoFee = _calculateFee(price);
    bytes32 tierId = keccak256(abi.encodePacked(_msgSender(),price));
    _tiers[tierId] = Tier(true, tierId, _msgSender(),price+motoFee, _commission);
    return tierId;
  }

  function cancelTier(bytes32 tierId) external{
    Tier storage tier = _tiers[tierId];
    require(_msgSender() == tier.owner);
    _tiers[tierId].valid = false;
  }
  function subscribe(bytes32 tierId, uint256 amount) public{
    Tier storage tier = _tiers[tierId];
    require(tier.owner != address(0));
    require(amount >= tier.price);
    uint256 denom = (100 + tier.motoCommission);
    uint256 intermediaryValue = amount / denom;
    uint256 creatorAmount = intermediaryValue * 100;
    uint256 motoAmount = amount - creatorAmount;
    uint256 monthsBought = (creatorAmount*100)/tier.price;
    uint256 bigTime = monthsBought * 30 * 1 days;
    uint256 smallTime = bigTime/100;
    bytes32 subscriptionId = keccak256(abi.encodePacked(_msgSender(),tier.tierId));
    Subscription memory subscription = getSubscription(subscriptionId);
    if(subscription.expirationDate > block.timestamp){
      subscription.expirationDate = subscription.expirationDate + smallTime;
    }
    else{
      _subscriptions[subscriptionId] = Subscription(tier, block.timestamp + smallTime);

    }
    _acceptedToken.transferFrom(_msgSender(),tier.owner,creatorAmount);
    _acceptedToken.transferFrom(_msgSender(),owner(), motoAmount);
  } 

  function getSubscription(bytes32 subscriptionId) public view returns (Subscription memory){
    return _subscriptions[subscriptionId];
  }

  function getTier(bytes32 tierId) public view returns (Tier memory){
    return _tiers[tierId];
  }

  function _calculateFee(uint256 amount) private view returns (uint256){
    return (amount * _commission) / 100;
  }

  function changeCommission(uint256 amount) external onlyOwner{
    require(amount <= 5, "fee must be less than 5 percent");
    _commission = amount;
  }
}