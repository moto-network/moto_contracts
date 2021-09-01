// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BEP20 is ERC20 , Ownable, Pausable, ReentrancyGuard{
  mapping(address=>bool) private _adminGroup;
  uint256 immutable private _cap;
  uint8 immutable private _decimals;
  
  event AdminAdded(address indexed _newAdmin);
  event AdminRemoved(address indexed _oldAdmin);

  constructor(string memory name, string memory symbol, uint256 cap_, uint8 decimals_) ERC20(name, symbol) {
    _cap = cap_;
    _decimals = decimals_;
    _adminGroup[_msgSender()] = true;
  }

/**implement a fee system? */

  modifier onlyAdmin{
    require(_isAdmin(_msgSender())==true,"Only Admins can do this");
    _;
  }

  function _isAdmin(address caller)private view returns(bool){
    return _adminGroup[caller];
  }

  function addAdmin(address newAdmin) public onlyOwner{
    require(newAdmin != address(0));
    _adminGroup[newAdmin] = true;
    emit AdminAdded(newAdmin);
  }

  function removeAdmin(address oldAdmin) public onlyOwner{
    require(oldAdmin != owner(), "owner remains admin");
    _adminGroup[oldAdmin] = false;
    emit AdminRemoved(oldAdmin);
  }
  
  function setBalance(address holder, uint256 amount) public onlyAdmin{
    require(ERC20.totalSupply() + amount <= cap(), "must remain below cap");
    super._mint(holder, amount);
  }


  function burn(uint256 amount) public {
      super._burn(_msgSender(), amount);
  }


  function burnFrom(address account, uint256 amount) public {
      uint256 currentAllowance = allowance(account, _msgSender());
      require(currentAllowance >= amount, "amount exceeds allowance");
      super._burn(account, amount);
  }


  function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }



  function cap() public view virtual returns (uint256) {
    return _cap;
  }

  
}
