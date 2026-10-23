// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 amountRaised;
        bool claimed;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    bool private locked;
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );
    event Funded(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    event FundsClaimed(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    function createCampaign(
        string calldata _title,
        string calldata _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0, "Duration must be at least 1 day");

        campaignCount++;
        uint256 campaignId = campaignCount;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            deadline: deadline,
            amountRaised: 0,
            claimed: false
        });

        emit CampaignCreated(campaignId, msg.sender, _title, _goal, deadline);
        return campaignId;
    }

    function contribute(uint256 _campaignId) external payable nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be > 0");

        campaign.amountRaised += msg.value;
        contributions[_campaignId][msg.sender] += msg.value;

        emit Funded(_campaignId, msg.sender, msg.value);
    }

    function claimFunds(uint256 _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];

        require(msg.sender == campaign.creator, "Only creator can claim");
        require(
            block.timestamp >= campaign.deadline,
            "Campaign is still active"
        );
        require(campaign.amountRaised >= campaign.goal, "Goal was not reached");
        require(!campaign.claimed, "Funds already claimed");

        campaign.claimed = true;
        uint256 amount = campaign.amountRaised;

        (bool success, ) = campaign.creator.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsClaimed(_campaignId, campaign.creator, amount);
    }

    function claimRefund(uint256 _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];

        require(
            block.timestamp >= campaign.deadline,
            "Campaign is still active"
        );
        require(
            campaign.amountRaised < campaign.goal,
            "Goal was reached; no refunds"
        );

        uint256 pledged = contributions[_campaignId][msg.sender];
        require(pledged > 0, "No funds to refund");

        contributions[_campaignId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: pledged}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, msg.sender, pledged);
    }

    function getCampaign(
        uint256 _campaignId
    )
        external
        view
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 deadline,
            uint256 amountRaised,
            bool claimed
        )
    {
        Campaign storage c = campaigns[_campaignId];
        return (
            c.creator,
            c.title,
            c.description,
            c.goal,
            c.deadline,
            c.amountRaised,
            c.claimed
        );
    }
}
