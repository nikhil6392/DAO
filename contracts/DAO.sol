// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DAO is ReentrancyGuard,AccessControl{
    bytes32 private immutable CONTRIBUTOR_ROLE=keccak256("CONTRIBUTOR");
    bytes32 private immutable STAKEHOLDER_ROLE=keccak256("STAKEHOLDER");

    uint256 immutable MIN_STAKEHOLDER_CONTRIBUTION=1 ether;
    uint32 immutable MIN_VOTE_DURATION=3 minutes;

    uint32  totalProposals;
    uint256 public daoBalance;

    mapping(uint256 => Proposals) private raisedProposals;
    mapping(address => uint256[]) private stakeHolderVotes;
    mapping(uint256 => Voted[]) private votedOn;
    mapping(address => uint256) private contributors;
    mapping(address => uint256) private stakeHolders;

    struct Proposals{
        uint256 id;
        uint256 amount;
        uint256 duration;
        uint256 upvotes;
        uint256 downVotes;
        string title;
        string description;
        bool passed;
        bool paid; 
        address payable beneficiary;
        address proposer;
        address executor;
    }

    struct Voted{
        address voter;
        uint256 timestamp;
        bool chosen;
    }

    event Action(
        address indexed initiator,
        bytes32 role,
        string message,
        address indexed beneficiary,
        uint256 amount
    );

    //we are giving this modifier for stakeholder 
    modifier stakeholderOnly(string memory message){
        require(hasRole(STAKEHOLDER_ROLE,msg.sender),message);
        _;
    }

    modifier contributorOnly(string memory message){
        require(hasRole(CONTRIBUTOR_ROLE,msg.sender),message);
        _;
    }

    function createProposal(
        string memory title,
        string memory description,
        address beneficiary,
        uint amount
    ) external stakeholderOnly("proposal creation allowed for the stake holders only"){
       
        uint32 proposalId=totalProposals++;

        //We have created an instace of Proposals struct
        Proposals storage proposal=raisedProposals[proposalId];
        proposal.id=proposalId;
        proposal.proposer=payable(msg.sender);
        proposal.title=title;
        proposal.description=description;
        proposal.amount=amount;
        proposal.duration=block.timestamp + MIN_VOTE_DURATION;
        
        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL RAISED",
            beneficiary,
            amount
        );
    }

    function handleVotiong(Proposals storage proposal) private{
        if(
            proposal.passed||
            proposal.duration<=block.timestamp
        ){
            proposal.passed=true;
            revert("proposal duration expired");
        }

        uint256[] memory tempVotes=stakeHolderVotes[msg.sender];
        for(uint256 votes=0;votes<tempVotes.length;votes++){
            if(proposal.id==tempVotes[votes]){
                revert("Double Voting is not allowed");
            }
        }
    }

    function Vote(uint256 proposalId,bool chosen) external stakeholderOnly("Unauthorized Access") returns(Voted memory){
        Proposals storage proposal=raisedProposals[proposalId];
        handleVotiong(proposal);

        if(chosen) proposal.upvotes++;
        else proposal.downVotes++;

        stakeHolderVotes[msg.sender].push(proposal.id);

        votedOn[proposal.id].push(
            Voted(
                msg.sender,
                block.timestamp,
                chosen
            )
        );

        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL VOTE",
            proposal.beneficiary,
            proposal.amount
        );

        return Voted(
            msg.sender,
            block.timestamp,
            chosen
        );
    }

    function payTo(
        address to,
        uint256 amount
    ) internal returns(bool) {
        (bool success,)=payable(to).call{value:amount}("");
        require(success,"Payment Failed,Something went wrong");
        return true;
    }

    function payBeneficiary(uint proposalId) public stakeholderOnly("Unauthorized ,Stakeholder only")  nonReentrant() returns(uint256) {
        Proposals storage proposal = raisedProposals[proposalId];
        require(daoBalance>=proposal.amount,"Insufficient Funds");

        if(proposal.paid) revert("Payment has already happened");
        if(proposal.upvotes<=proposal.downVotes){
            revert("Insufficient Votes");
        }

        proposal.paid=true;
        proposal.executor=msg.sender;
        daoBalance-=proposal.amount;

        //We have this function here because we have just changed the state after state change we can run the function for prevention of reentrancy attack

        payTo(proposal.beneficiary,proposal.amount);
        
        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PAYMENT TRANSFERRED",
            proposal.beneficiary,
            proposal.amount
        );
        return daoBalance;
    }

    function contribute() public payable{
        require(msg.value>0,"Contribution should be more than 0");
        if(!hasRole(STAKEHOLDER_ROLE,msg.sender)){
            uint256 totalContribution=contributors[msg.sender]+msg.value;

            if(totalContribution>=MIN_STAKEHOLDER_CONTRIBUTION){
                stakeHolders[msg.sender]=totalContribution;
                _grantRole(STAKEHOLDER_ROLE,msg.sender);
            }
            contributors[msg.sender]+=msg.value;
            _grantRole(CONTRIBUTOR_ROLE, msg.sender);
        }
        else{
            contributors[msg.sender]+=msg.value;
            stakeHolders[msg.sender]+=msg.value;
        }

        daoBalance+=msg.value;

        emit Action(
            msg.sender,
            CONTRIBUTOR_ROLE,
            "CONTRIBUTION RECEVIED",
            address(this),
            msg.value
        );
  }

  function getProposals() external view returns(Proposals[] memory props){
    props =new Proposals[](totalProposals);
    for(uint256 i=0;i<totalProposals;i++){
        props[i]=raisedProposals[i];

    }
  }

  function getProposal(uint256 proposalId) public view returns(Proposals memory){
    return  raisedProposals[proposalId];
  } 

  function getVoteOf(uint256 proposalId) public view returns(Voted[] memory){
    return votedOn[proposalId];
  }

//retrieve the vote provided by stakeHolder
  function getStakeHolderVotes() external view stakeholderOnly("Unauthorized,Not a Stake Holder") returns(uint256[] memory){
    return stakeHolderVotes[msg.sender];
  }

  function getStakeHolderBalance()
    external
    view
    stakeholderOnly("Unauthorized,Not a Stake Holder")
    returns(uint256){
        return stakeHolders[msg.sender];
  }

 
}