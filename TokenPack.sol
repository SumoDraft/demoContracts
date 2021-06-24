//SPDX-License-Identifier: Unlicense

/*
1) Deploy TokenPack initialized with USDC address
2) Deploy PlayerTokens initialized with TokenPack address
3) Call setPlayerTokens on TokenPack conteract
*/

//Just need to ensure price is set so that by the time the initial token packs are sold, 
//there is enough extraUSDC for a full league minting


pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "oldZep/token/ERC20/IERC20.sol";
import "oldZep/access/Ownable.sol";

interface IPlayerToken{
    function mint(uint256 _amount) external;
} 

contract TokenPack is Ownable, VRFConsumerBase  {

    //mock_randomness to be replaced by VFR response
    uint256 mock_randomness = 52250567107703374146753479728662485838927187998528117750795613956853263270299;

    address[] public playerTokens;

    mapping(address => bool) public playersWhitelist;   //Verified player tokens


    uint256 public pricePerPack; 
    uint256 public tokensPerPack;
    uint256 public usdcBackingTokens;
    
    uint256 public numberOfPlayers;

    IERC20 public USDC;



    bytes32 internal keyHash;
    uint256 internal fee;

    uint256 public randomResult;
    



    constructor(address _USDC, uint256 _pricePerPack, uint256 _tokensPerPack) 
        VRFConsumerBase( 
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
        ) public
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
        USDC = IERC20(_USDC);
        pricePerPack = _pricePerPack;
        tokensPerPack = _tokensPerPack;
    }



    //------------------------- Get Pack functions ---------------------------------//

    function get_n_packs(uint256 _n, uint256 _userProvidedSeed) public {

        //1) User underwrites payouts by buying tokens
        USDC.transferFrom(msg.sender, address(this), _n * pricePerPack * (10 ** 6) );
        usdcBackingTokens += _n * pricePerPack * (10 ** 6); 
    
        //2)  Get _n * tokensPerPack  random numbers 
        uint256[] memory randomNumbers = expand( mock_randomness , tokensPerPack * _n );
        randomNumbers[0] = randomNumbers[0].mod(playerTokens.length);


        // Transform each random number to another between 0 and playerTokens.length - 1
        for(uint i = 0; i < randomNumbers.length; i++){
            randomNumbers[i] = randomNumbers[i].mod(playerTokens.length);
        }
        
        //Change source of randomness after
        mock_randomness++;

        //5) Transfer tokens to owner
        //Should revert if not enough tokens for chosen player
        //This is not a problem in practice if the number of player tokens the TokenPack contract has is absolutely huge
        for(uint i = 0; i < randomNumbers.length; i++){
            IERC20(playerTokens[randomNumbers[i]]).transfer(msg.sender, 1 * 10 ** 18);
        }
        
        
    }


    //-----------------------------Admin Functions ---------------------------------------//

    function setPlayerTokens(address[] memory _playerTokens) onlyOwner public  {
        playerTokens = _playerTokens;
        for(uint i =0; i< playerTokens.length; i++){
            playersWhitelist[playerTokens[i]] = true;
        }
        numberOfPlayers = playerTokens.length;
        

    }


    //----------------------------Player Token Functions------------------------------------//

    function playerTokenPayout(uint256 _amount, address _playerTokenHolder) public {

        require(playersWhitelist[msg.sender], "token not whitelisted"); // Check that this is a verified PlayerToken

        USDC.transfer(_playerTokenHolder, _amount.div(10**18)); 
    }


    //-----------------------------Helper Funcions----------------------------------------------------//
    function expand(uint256 randomValue, uint256 n) public pure returns (uint256[] memory expandedValues) {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
            //how make sure these vals are between 0 and numberOfPlayers - 1 ?
        }
        return expandedValues;
    }

    //necessary for chainlink interface
    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }


    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }


}

