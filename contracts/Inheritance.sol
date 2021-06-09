pragma solidity ^0.5.17;

import "./AddrArrayLib.sol";

contract Inheritance {
	using AddrArrayLib for AddrArrayLib.Addresses;

	address public owner;
	
	struct Will {
		address donator;
		address[] heirs; 
		uint[] proportions; 
		uint capital; 
		uint executionTime;
	}
	
	//mapping from address to the will of this address
	mapping(address => Will) public wills;
	
	//@DEV
	// may be used track which address have issued a will
	//address[] private donators;
	AddrArrayLib.Addresses donators;

	//holding track of the executed wills
	AddrArrayLib.Addresses executedWills;
	
	//@DEV
	//So far no use for the owner in this contract..
	constructor() {
		owner == msg.sender;
	}
	
	// create a will
	function lastWill
	(
		address[] memory heirs, 
		uint[] memory proportions, // in percent of the total capital to be inheritet 
									// 1 = 1%
								   // 100 = 100%
		uint timeTillExecution // in years 
	)
		public payable
	{
		require
		(
				!donators.exists(msg.sender), 
				"The address you are calling from has already set up its will."
		);
		require
		(
				heirs.length == proportions.length, 
				"Number of heirs must equal the given number of proportions"
		); 	
		uint sentEther = msg.value;
		uint creationTime = block.timestamp;
		uint inYears = (timeTillExecution * 365 days); 
		uint executionTime = creationTime + inYears;
		Will memory will; 
		will.donator = msg.sender;
		will.heirs = heirs;
		will.proportions = proportions;
		will.capital = sentEther;
		will.executionTime = executionTime;
		wills[msg.sender] = will;
		bool isNewDonor = donators.pushAddress(msg.sender);
		require(isNewDonor, "This contract accepts only one will per address!"); // redundant check..
	}
	
	// revoke the will
	function killTheWill(address donator) public payable{
		require(msg.sender == wills[donator].donator, "You have no right to execute this function!");
		require(!executedWills.exists(donator), "Will was already executed. You should reset in peace.");
		uint capital = wills[donator].capital;
		Will memory will;
		wills[donator] = will;
		address payable account = payable(msg.sender);
		account.transfer(capital);
		donators.removeAddress(msg.sender);
	}	
	
	// the creator of a will may update the execution time of his will
	function sendHeartbeat(uint timeExtension) public returns (uint){
		require(msg.sender == wills[msg.sender].donator, "Its not your will!");
		uint currentTime = block.timestamp;
		uint newExecutionTime = currentTime + (timeExtension * 1 days);
	   	wills[msg.sender].executionTime = newExecutionTime;
		return newExecutionTime;	
	}
	
	//call this function the execute the will of the address "donator"	
	function inherit(address donator) public payable{
		require(wills[donator].executionTime <= block.timestamp, "Its too early...");
		require(!executedWills.exists(donator), "This will was already executed");
		uint capital = wills[donator].capital;
		address[] memory sender = wills[donator].heirs;
		uint[] memory shares = calculateShares(wills[donator].proportions, capital); 
		for(uint i = 0; i < sender.length; i++){
			address payable account = payable(sender[i]);
			account.transfer(shares[i]);
		}
		executedWills.pushAddress(donator);
		
	}
	
	// auxiliary function to compute the shares each heir is getting form the total amount 
	// to be inherited (capital)
	function calculateShares
	(	
	 	uint[] memory proportions,
		uint capital
	) 	public 
		pure
		returns(uint[] memory)
	{
		uint[] memory shares = new uint[](proportions.length);
		for(uint i = 0; i < proportions.length; i++){
			shares[i] = (capital * proportions[i]) / 100;
		}
		return shares;
	}
}
