//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.0;

import "oldZep/token/ERC20/ERC20.sol"; 
import "oldZep/token/ERC20/IERC20.sol";
import "oldZep/token/ERC20/ERC20Burnable.sol";
import "oldZep/access/Ownable.sol";

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

interface ITokenPack {
    function playerTokenPayout(uint256 _amount, address _playerTokenHolder) external;
}


contract PlayerToken is  ERC20, ChainlinkClient, Ownable {
  
    string public apiEndpoint;  // ex. "https://us-central1-sumodraft-22fc7.cloudfunctions.net/app/players/19801"
    address public tokenPackAddress;
    uint256 public endTime;  
    uint256 public finalTokenPrice;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    /**
     * Network: Kovan
     * Chainlink - 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
     * Chainlink - 29fa9aa13bf1468788b7cc4a500a45b8
     * Fee: 0.1 LINK
     */

    constructor(string memory _apiEndpoint, address _tokenPackAddress, uint256 _endTime) ERC20("PLT", "PLT") public {
        
        apiEndpoint =  _apiEndpoint;
        tokenPackAddress =  _tokenPackAddress;
        endTime = _endTime;
        finalTokenPrice = 0;
        
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        
        // Mint 1 billion player tokens to TokenPacks contract
        // This is admitttedly a large number but unbacked tokens dont circulate
        _mint(tokenPackAddress, 1 * 10 ** 27);  
    }
    
    

    function requestPlayerData() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get",  apiEndpoint);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _val) public recordChainlinkFulfillment(_requestId)
    {
        finalTokenPrice = _val;
    }
    
    
    function payout() public {

        //require(block.timestamp > endTime, "Season has not ended"); <--- Bring back after test
        require(finalTokenPrice != 0, "Either Chainlink has not been called or player has 0 fantasy points"); 

        //burn player tokens 
        uint numberOfTokens = balanceOf(msg.sender); 
        _burn(msg.sender, numberOfTokens);

        //request payout from TokenPack
        uint usdcPayout =  numberOfTokens * finalTokenPrice ; 
        ITokenPack(tokenPackAddress).playerTokenPayout(usdcPayout, msg.sender);
        
    }
    
    function withdrawLink() public onlyOwner{
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
}

