// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract VotingProtocol {
    error VotingProtocol__AddressZeroNotAllowed();
    error VotingProtocol__PleaseProvideProposalString();
    error VotingProtocol__PleaseProvideMoreVoters();
    error VotingProtocol__ThisVotingIdDoesnotExists();
    error VotingProtocol__CannotAddVotersAfterVotingHasStarted();
    error VotingProtocol__CannotAuthorizeVotersAfterVotingHasStarted();
    error VotingProtocol__OnlyOwnerCanStartOrStopVoting();
    error VotingProtocol__VotingHasAlreadyBeenStarted();    
    error VotingProtocol__VotingHasAlreadyBeenEnded();
    error VotingProtocol__VotingHasNotBeenStartedYet();
    error VotingProtocol__YouAreNotAuthorizedToCastVote();
    error VotingProtocol__YouHaveAlradyCastedYourVote();
    error VotingProtocol__OnlyOwnerCanAuthorizeVoters();
    error VotingProtocol__NoVotersHaveBeenAddedYet();
    error VotingProtocol__DurationTimeTooLess();
    error VotingProtocol__DeadlineHasBeenAreadyPassed();
    error VotingProtocol__VoteCannotBeCastedAfterTheDeadLine();

    event VotingProtocol__ThisVoterHasNotBeenAddedSoItCannotBeAdded(uint256 id, address voterAddress);
    event VotingProtocol__AddressAlreadyAddedToThisProposal(uint256 id, address voterAddress);
    event VotingProtocol__VotingHasBeenStarted(uint256 id);
    event VotingProtocol__AllVoterHaveBeenAuthorized(uint256 id);
    event VotingProtocol__ZeroAddressVoterNotAllowed(uint256 id);

    struct Voters {
        bool exists;
        bool isAuthorized;
        bool voted;
        Vote voteChoice;
    }

    struct Vote {
        bool choice;
    }

    struct VotingState {
        bool votingStarted;
        bool votingEnded;
    }

    struct Proposals {
        address[] voterArray;
        mapping(address => Voters) allVoters;
        string proposalRequestMessage;
        address requester; // who created the proposal
        VotingState state;
        uint256 totalVotersAdded;
        uint256 totalVotersAuthorized;
        uint256 totalVotersVoted;
        uint256 deadline;
    }
    uint256 votingId = 0;
    mapping(uint256 => Proposals) private idToProposals;

    function requestProposal(string memory proposal) public returns (bool) {
        require(msg.sender != address(0), VotingProtocol__AddressZeroNotAllowed());
        require(bytes(proposal).length > 0, VotingProtocol__PleaseProvideProposalString());
        Proposals storage P = idToProposals[votingId];
        P.requester = msg.sender;
        P.proposalRequestMessage = proposal;
        votingId++;
        return true;
    }

    function addVotersToMyProposal(uint256 id, address[] memory voters) external returns (bool) {
        require(voters.length > 0, VotingProtocol__PleaseProvideMoreVoters());
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        Proposals storage P = idToProposals[id];
        require(msg.sender == P.requester, VotingProtocol__OnlyOwnerCanAuthorizeVoters());

        require(
            P.state.votingStarted == false && P.state.votingEnded == false,
            VotingProtocol__CannotAddVotersAfterVotingHasStarted()
        );
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == address(0)) {
                emit VotingProtocol__ZeroAddressVoterNotAllowed(id);
                continue;
            }
            bool isPresent = P.allVoters[voters[i]].exists;
            if (isPresent) {
                emit VotingProtocol__AddressAlreadyAddedToThisProposal(id, voters[i]);
                continue;
            } else {
                P.voterArray.push(voters[i]);
                P.allVoters[voters[i]] =
                    Voters({exists: true, isAuthorized: false, voted: false, voteChoice: Vote({choice: false})});
                P.totalVotersAdded++;
            }
        }
        return true;
    }

    function authorizeVotersForMyProposal(uint256 id, address[] memory voters) external returns (bool) {
        require(voters.length > 0, VotingProtocol__PleaseProvideMoreVoters());
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        Proposals storage P = idToProposals[id];
        require(msg.sender == P.requester, VotingProtocol__OnlyOwnerCanAuthorizeVoters());
        require(
            P.state.votingStarted == false && P.state.votingEnded == false,
            VotingProtocol__CannotAuthorizeVotersAfterVotingHasStarted()
        );

        for (uint256 i = 0; i < voters.length; i++) {
            bool isPresent = P.allVoters[voters[i]].exists;
            if (!isPresent) {
                emit VotingProtocol__ThisVoterHasNotBeenAddedSoItCannotBeAdded(id, voters[i]);
            } else {
                P.allVoters[voters[i]].isAuthorized = true;
                P.totalVotersAuthorized++;
            }
        }
        return true;
    }

    function startVotingForMyProposal(uint256 id, uint256 durationInHours) external returns (bool) {
        require(durationInHours > 0, VotingProtocol__DurationTimeTooLess());

        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        Proposals storage P = idToProposals[id];

        require(msg.sender == P.requester, VotingProtocol__OnlyOwnerCanStartOrStopVoting());
        require(P.state.votingStarted == false, VotingProtocol__VotingHasAlreadyBeenStarted());
        require(P.state.votingEnded == false, VotingProtocol__VotingHasAlreadyBeenEnded());
        P.deadline = block.timestamp + durationInHours * 1 hours;

        P.state.votingStarted = true;

        emit VotingProtocol__VotingHasBeenStarted(id);
        return true;
    }

    function endVotingForMyProposal(uint256 id) external returns (bool) {
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        Proposals storage P = idToProposals[id];

        require(msg.sender == P.requester, VotingProtocol__OnlyOwnerCanStartOrStopVoting());
        require(P.state.votingStarted == true, VotingProtocol__VotingHasNotBeenStartedYet());
        require(P.state.votingEnded == false, VotingProtocol__VotingHasAlreadyBeenEnded());

        P.state.votingEnded = true;
        return true;
    }

    function castVote(uint256 id, bool choice) external returns (bool) {
        Proposals storage P = idToProposals[id];
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        require(P.state.votingEnded == false, VotingProtocol__VotingHasAlreadyBeenEnded());
        require(P.state.votingStarted == true, VotingProtocol__VotingHasNotBeenStartedYet());
        require(P.allVoters[msg.sender].voted == false, VotingProtocol__YouHaveAlradyCastedYourVote());
        require(P.deadline > block.timestamp, VotingProtocol__VoteCannotBeCastedAfterTheDeadLine());

        require(P.allVoters[msg.sender].isAuthorized == true, VotingProtocol__YouAreNotAuthorizedToCastVote());
        P.allVoters[msg.sender].voted = true;
        P.allVoters[msg.sender].voteChoice.choice = choice;
        P.totalVotersVoted++;
        return true;
    }

    function authorizeAllVoters(uint256 id) public returns (bool) {
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        Proposals storage P = idToProposals[id];

        require(msg.sender == P.requester, VotingProtocol__OnlyOwnerCanAuthorizeVoters());
        require(
            P.state.votingStarted == false && P.state.votingEnded == false,
            VotingProtocol__CannotAuthorizeVotersAfterVotingHasStarted()
        );
        uint256 numberOfVoters = P.voterArray.length;
        require(numberOfVoters > 0, VotingProtocol__NoVotersHaveBeenAddedYet());
        for (uint256 i = 0; i < numberOfVoters; i++) {
            if (P.allVoters[P.voterArray[i]].exists) {
                P.allVoters[P.voterArray[i]].isAuthorized = true;
            }
        }
        emit VotingProtocol__AllVoterHaveBeenAuthorized(id);
        return true;
    }

    function getTotalVotersAdded(uint256 id) public view returns (uint256) {
        Proposals storage P = idToProposals[id];
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        return P.totalVotersAdded;
    }

    function getTotalVotersAuthorised(uint256 id) public view returns (uint256) {
        Proposals storage P = idToProposals[id];
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        return P.totalVotersAuthorized;
    }

    function getTotalVotersWhoVoted(uint256 id) public view returns (uint256) {
        Proposals storage P = idToProposals[id];
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        return P.totalVotersVoted;
    }

    function getResultForTheVoting(uint256 id) public view returns (uint256, uint256, uint256) {
        require(id <= votingId, VotingProtocol__ThisVotingIdDoesnotExists());
        Proposals storage P = idToProposals[id];
        require(P.state.votingStarted == true, VotingProtocol__VotingHasNotBeenStartedYet());
        if (P.state.votingStarted && P.deadline <= block.timestamp) {
            P.state.votingEnded;
        }

        uint256 totalVoters = P.voterArray.length;
        uint256 votersAgreeing;
        uint256 votersDisagreeing;
        for (uint256 i = 0; i < totalVoters; i++) {
            if (P.allVoters[P.voterArray[i]].voted) {
                if (P.allVoters[P.voterArray[i]].voteChoice.choice) {
                    votersAgreeing++;
                } else {
                    votersDisagreeing++;
                }
            }
        }
        return (votersAgreeing, votersDisagreeing, totalVoters);
    }
}
