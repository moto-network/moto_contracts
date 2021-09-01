// SPDX-License-Identifier: MIT
pragma solidity^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./EIP712Base.sol";
import "./Adminable.sol";

contract testnft is Ownable,EIP712Base, ERC721URIStorage, Adminable{

  constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
    _initializeEIP712('Moto Network NFT', '1');
    addMinter(owner());
    addAdmin(owner());
  }


  event NFTMinted(address indexed owner, uint256 indexed tokenID);
  event NFTBurned(address indexed burner, uint256 indexed tokenID);


  struct NFT{
    string name;
    uint256 chainId;
    address beneficiary;
    bytes32 contentHash;
    uint256 tokenId;
  }
  bytes32 constant NFT_TYPEHASH = keccak256("NFT(string name,uint256 chainId,address beneficiary,bytes32 contentHash,uint256 tokenId)");

  
  mapping(uint256 => NFT) private NFTmetaData;
  mapping(bytes32 => bool) private existingHash;
  mapping(uint256 => string) private idToHandle;
  mapping(string => uint256) private handleToId;

  //fees
  uint256 private _creationFee;
  uint256 private _nameFee;
  uint256 private _handleFee;
  string private _payFee = "pay fee";

  //User Functions 

  function userMint(string calldata name, uint256 chainId, address beneficiary, 
  bytes32 contentHash, uint256 tokenId, bytes32 r, bytes32 s, uint8 v) 
  payable public returns(bytes32[3] memory){
    require(msg.value >= _creationFee, _payFee);
    return _executeMint(name, chainId, beneficiary, contentHash, tokenId, r, s, v);

  }


  function userMintWithHandle(string calldata name, uint256 chainId, address beneficiary, 
  bytes32 contentHash, uint256 tokenId, string calldata handle, bytes32 r, bytes32 s, uint8 v) 
  payable public{
    require(msg.value >= (_creationFee+_handleFee),_payFee);
    _executeMint(name, chainId, beneficiary, contentHash, tokenId, r, s, v);
    _changeHandle(tokenId, handle);

  }


  function _executeMint(string calldata name, uint256 chainId, address beneficiary, 
  bytes32 contentHash, uint256 tokenId, bytes32 r, bytes32 s, uint8 v) private returns ( bytes32[3] memory ){
    NFT memory nft = NFT(name,chainId, beneficiary, contentHash, tokenId);
    
    return verifySignature(nft, r, s, v);
  }


  function _createNFT(NFT memory nft) private {
    verifyUnique(nft);
    super._mint(nft.beneficiary, nft.tokenId);
    NFTmetaData[nft.tokenId] = nft;
    existingHash[nft.contentHash] = true;
    emit NFTMinted(nft.beneficiary, nft.tokenId);
  }


  function verifyUnique(NFT memory nft)internal view {
    require(existingHash[nft.contentHash]==false,"file has nft");
    require(_exists(nft.tokenId)==false,"nft exists");
  }


  function existsAsNFT(bytes32 hash) public view returns(bool){
    return existingHash[hash];
  }


  function burn(uint256 _tokenId) public {
    require(ownerOf(_tokenId)==_msgSender(),"only owner");
    super._burn(_tokenId);
    NFT storage nft = NFTmetaData[_tokenId];
    existingHash[nft.contentHash]=false;
    delete NFTmetaData[_tokenId];
    emit NFTBurned(_msgSender(),_tokenId);
  }



  function nftFromTokenId(uint256 tokenID) public view returns(NFT memory){
    return NFTmetaData[tokenID];
  }


  function nftFromHandle(string calldata handle) public view returns (NFT memory){
    require(handleToId[handle]!=0, "no handle");
    uint256 tokenId = handleToId[handle];
    return NFTmetaData[tokenId];
  }


  function changeName(uint256 tokenId,string calldata newName) public payable{
    require(msg.value >=_nameFee);
    require(ownerOf(tokenId)==_msgSender());
    NFT storage nft = NFTmetaData[tokenId];
    nft.name = newName;
  }


  function changeHandle(uint256 tokenId, string calldata handle) public payable{
    require(msg.value>=_handleFee, _payFee);
    _changeHandle(tokenId, handle);
  }


  function _changeHandle(uint256 tokenId, string calldata handle) private{
    require(_exists(tokenId)==false,"no token");
    require(ownerOf(tokenId)==_msgSender());
    require(bytes(handle).length>0,"value empty");
    require(handleToId[handle]==0,"handle taken");
    handleToId[handle] = tokenId;
    idToHandle[tokenId] = handle;
  }


  function getHandle(uint256 tokenId) public view returns(string memory) {
    require(bytes(idToHandle[tokenId]).length!=0,"no handle");
    return idToHandle[tokenId];
  }


  function getCreationFee() public view returns(uint256){
    return _creationFee;
  }


  function getNameFee() public view returns(uint256){
    return _nameFee;
  }


  function  getHandleFee() public view returns(uint256){
    return _handleFee;
  } 

//Admin Functions

  function adminMint(string calldata name, uint256 chainId, address beneficiary, 
  bytes32 contentHash, uint256 tokenId) public onlyMinters{
    NFT memory nft = NFT(name,chainId, beneficiary, contentHash, tokenId);
    _createNFT(nft);
  }


  function setTokenURI(uint256 _tokenId, string calldata _uri) public onlyAdmins{
    super._setTokenURI(_tokenId, _uri);
  }


  function setCreationFee(uint256 fee_) public onlyAdmins{
    _creationFee = fee_;
    emit NewFeeSet("CreationFee",fee_,_msgSender());
  }


  function setNameFee(uint256 fee_) public onlyAdmins{
    _nameFee = fee_;
    emit NewFeeSet("NameFee",fee_,_msgSender());
  }


  function setHandleFee(uint256 fee_) public onlyAdmins{
    _handleFee = fee_;
    emit NewFeeSet("HandleFee",fee_,_msgSender());
  }


  function withdraw(uint256 amount) external onlyOwner{
    address payable payee = payable(owner());
    payee.transfer(amount);
  }
  
  //Base Functions

  function hashVerfiedNFT(NFT memory nft) private pure returns(bytes32){
    return keccak256(abi.encodePacked(
      NFT_TYPEHASH,
      keccak256(bytes(nft.name)),
      nft.chainId,
      nft.beneficiary,
      nft.contentHash,
      nft.tokenId
    ));
  }

  
  function verifySignature(NFT memory nft, bytes32 r,bytes32 s,uint8 v)
  private view returns(bytes32[3] memory){
    bytes32 digest = keccak256(abi.encodePacked(
      "\x19\x01",
      DOMAIN_SEPERATOR,
      hashVerfiedNFT(nft)
    ));
    bytes32 domainTypedHash = keccak256(
      
            "EIP712Domain(string name,string version,address verifyingContract,uint256 chainID)"
        );
    return [domainTypedHash, DOMAIN_SEPERATOR,hashVerfiedNFT(nft)];
    //return ecrecover(digest,v,r,s) == _msgSender();
  }



  

  


}
