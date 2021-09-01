// SPDX-License-Identifier: MIT
pragma solidity^0.8.0;
import "./Ownable.sol";

contract Adminable is Ownable{
  event MinterAdded(address indexed newMinter);
  event MinterRemoved(address indexed oldMinter);
  event AdminAdded(address indexed newAdmin);
  event AdminRemoved(address indexed oldAdmin);
  event NewFeeSet(string feeName, uint256 indexed feeAmount,address adjuster);


   modifier onlyMinters{
    require(minters[_msgSender()]==true,"can not mint because not approved minter");
    _;
  }

  modifier onlyAdmins{
    require(admins[_msgSender()]==true,"not admin");
    _;
  }

  mapping(address => bool) private admins;
  mapping(address => bool) private minters;
/**
    Administrative Functions
   */
  
  function addMinter(address newMinter) public onlyOwner{
    require(newMinter != address(0), "address(0) no");
    minters[newMinter] = true;
    emit MinterAdded(newMinter);
  }


  function removeMinter(address oldMinter) public onlyOwner{
    require(oldMinter!=owner(), "owner stays");
    minters[oldMinter] = false;
    emit MinterRemoved(oldMinter);
  }


  function addAdmin(address newAdmin) public onlyOwner{
    require(newAdmin!=address(0),"address(0) no");
    admins[newAdmin] = true;
    emit AdminAdded(newAdmin);
  }


  function removeAdmin(address oldAdmin) public onlyOwner{
    require(oldAdmin!=owner(),"owner stays");
    admins[oldAdmin] = false;
    emit AdminRemoved(oldAdmin);
  }

}
