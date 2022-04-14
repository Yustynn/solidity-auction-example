// Basic lottery contract.

// From https://github.com/PatrickAlphaC/smartcontract-lottery/blob/main/contracts/Lottery.sol
// Accessed 2022-04-13

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol"; // for ETH-USD pricefeed
import "@openzeppelin/contracts/access/Ownable.sol"; // for the "owner" property
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol"; // For RNG. VRF: verifiable random function

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players; // array of players (wallet ids)
    address payable public recentWinner; // most recent winner (wallet id)
    uint256 public randomness; // random number
    uint256 public usdEntryFee; // entry fee in USD
    AggregatorV3Interface internal ethUsdPriceFeed; // ETH Price Feed 
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    } // lottery state space
    LOTTERY_STATE public lottery_state; // current state
    uint256 public fee; // fee
    bytes32 public keyhash; // key hash
    event RequestedRandomness(bytes32 requestId); // event definition for requesting randomness

    // 0
    // 1
    // 2

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        // record initialized instance properties
        // whoever calls it gets set as owner (part of Ownable)

        usdEntryFee = 50 * (10**18); // store the USD entry fee * 10^18
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress); // set up the ETH price feed
        lottery_state = LOTTERY_STATE.CLOSED; // initialize lottery state to CLOSED;
        fee = _fee; // set fee
        keyhash = _keyhash; // set keyhash
    }

    function enter() public payable {
        // add message sender to players

        // $50 minimum
        require(lottery_state == LOTTERY_STATE.OPEN); // ensure lottery state is OPEN. Else, terminate.
        require(msg.value >= getEntranceFee(), "Not enough ETH!"); // ensure payment of sufficient ETH to meet entrance fee. Else, terminate with message "Not enough ETH".
        players.push(msg.sender); // add message
    }

    function getEntranceFee() public view returns (uint256) {
        // return entrance fee in ETH (i think)
        // anyone can call

        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData(); // fetch ETH price
        uint256 adjustedPrice = uint256(price) * 10**10; // 18 decimals // adjust ETH price to match the adjusted USD entry fee stored price
        // $50, $2,000 / ETH
        // 50/2,000
        // 50 * 100000 / 2000
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice; // determine cost to enter in ETH
        return costToEnter; // return cost to enter
    }

    function startLottery() public onlyOwner {
        // start the lottery, unless it's closed
        // only owner can call

        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        ); // ensure lottery state is CLOSED. Else, terminate with message "Can't start a new lottery yet!"
        lottery_state = LOTTERY_STATE.OPEN; // set lottery state to OPEN
    }

    function endLottery() public onlyOwner {
        // end lottery and trigger transfer
        // only owner can call

        // uint256(
        //     keccack256(
        //         abi.encodePacked(
        //             nonce, // nonce is preditable (aka, transaction number)
        //             msg.sender, // msg.sender is predictable
        //             block.difficulty, // can actually be manipulated by the miners!
        //             block.timestamp // timestamp is predictable
        //         )
        //     )
        // ) % players.length;
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER; // set lottery state to CALCULATING_WINNER
        bytes32 requestId = requestRandomness(keyhash, fee); // create randomness requestId
        emit RequestedRandomness(requestId); // make randomness request
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        // choose and pay winner, close auction
        // callback for RequestedRandomness event. Part of VRFConsumerBase.
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        ); // ensure lottery is meant to be calculating the winner. Else, terminate with message "You aren't there yet!"
        require(_randomness > 0, "random-not-found"); // ensure at least 1 random number. Else, terminate with message "random-not-found".
        uint256 indexOfWinner = _randomness % players.length; // compute the index of the winner by modulus-ing the relatively large random number on the relatively small number of players
        recentWinner = players[indexOfWinner]; // retrieve the winner
        recentWinner.transfer(address(this).balance); // transfer the winner the winnings
        // Reset
        players = new address payable[](0); // clear all players
        lottery_state = LOTTERY_STATE.CLOSED; // end the lottery
        randomness = _randomness; // set new randomness
    }
}