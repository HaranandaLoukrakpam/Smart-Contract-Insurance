
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SmartContractInsurance
 * @dev Insurance contract for protecting against smart contract failures
 */
contract SmartContractInsurance {
    address public owner;
    uint256 public totalPoolBalance;
    uint256 public constant PREMIUM_RATE = 5; // 5% of insured amount
    uint256 public constant CLAIM_TIMEOUT = 30 days;
    
    struct InsurancePolicy {
        address policyholder;
        address insuredContract;
        uint256 insuredAmount;
        uint256 premiumPaid;
        uint256 policyStart;
        uint256 policyEnd;
        bool isActive;
    }
    
    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimedAmount;
        string failureDescription;
        uint256 claimTime;
        bool isProcessed;
        bool isApproved;
    }
    
    mapping(uint256 => InsurancePolicy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    
    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;
    
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, address indexed insuredContract, uint256 insuredAmount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 claimedAmount);
    event ClaimProcessed(uint256 indexed claimId, bool approved, uint256 payoutAmount);
    event PremiumPaid(uint256 indexed policyId, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyActivePolicyHolder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");
        require(policies[_policyId].isActive, "Policy is not active");
        require(block.timestamp <= policies[_policyId].policyEnd, "Policy has expired");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Create a new insurance policy for a smart contract
     * @param _insuredContract Address of the contract to be insured
     * @param _insuredAmount Amount to be covered by insurance
     * @param _policyDuration Duration of the policy in days
     */
    function createPolicy(
        address _insuredContract,
        uint256 _insuredAmount,
        uint256 _policyDuration
    ) external payable {
        require(_insuredContract != address(0), "Invalid contract address");
        require(_insuredAmount > 0, "Insured amount must be greater than 0");
        require(_policyDuration >= 30, "Minimum policy duration is 30 days");
        
        uint256 premiumAmount = (_insuredAmount * PREMIUM_RATE) / 100;
        require(msg.value >= premiumAmount, "Insufficient premium payment");
        
        uint256 policyId = nextPolicyId++;
        
        policies[policyId] = InsurancePolicy({
            policyholder: msg.sender,
            insuredContract: _insuredContract,
            insuredAmount: _insuredAmount,
            premiumPaid: premiumAmount,
            policyStart: block.timestamp,
            policyEnd: block.timestamp + (_policyDuration * 1 days),
            isActive: true
        });
        
        userPolicies[msg.sender].push(policyId);
        totalPoolBalance += premiumAmount;
        
        // Refund excess payment
        if (msg.value > premiumAmount) {
            payable(msg.sender).transfer(msg.value - premiumAmount);
        }
        
        emit PolicyCreated(policyId, msg.sender, _insuredContract, _insuredAmount);
        emit PremiumPaid(policyId, premiumAmount);
    }
    
    /**
     * @dev Submit a claim for contract failure
     * @param _policyId ID of the policy to claim against
     * @param _claimedAmount Amount being claimed
     * @param _failureDescription Description of the contract failure
     */
    function submitClaim(
        uint256 _policyId,
        uint256 _claimedAmount,
        string memory _failureDescription
    ) external onlyActivePolicyHolder(_policyId) {
        require(_claimedAmount > 0, "Claimed amount must be greater than 0");
        require(_claimedAmount <= policies[_policyId].insuredAmount, "Claimed amount exceeds insured amount");
        require(bytes(_failureDescription).length > 0, "Failure description required");
        
        uint256 claimId = nextClaimId++;
        
        claims[claimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimedAmount: _claimedAmount,
            failureDescription: _failureDescription,
            claimTime: block.timestamp,
            isProcessed: false,
            isApproved: false
        });
        
        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimedAmount);
    }
    
    /**
     * @dev Process a submitted claim (owner only)
     * @param _claimId ID of the claim to process
     * @param _approved Whether the claim is approved or rejected
     */
    function processClaim(uint256 _claimId, bool _approved) external onlyOwner {
        Claim storage claim = claims[_claimId];
        require(!claim.isProcessed, "Claim already processed");
        require(block.timestamp <= claim.claimTime + CLAIM_TIMEOUT, "Claim processing timeout");
        
        claim.isProcessed = true;
        claim.isApproved = _approved;
        
        uint256 payoutAmount = 0;
        
        if (_approved) {
            payoutAmount = claim.claimedAmount;
            require(totalPoolBalance >= payoutAmount, "Insufficient pool balance");
            
            totalPoolBalance -= payoutAmount;
            payable(claim.claimant).transfer(payoutAmount);
            
            // Deactivate the policy after successful claim
            policies[claim.policyId].isActive = false;
        }
        
        emit ClaimProcessed(_claimId, _approved, payoutAmount);
    }
    
    /**
     * @dev Get user's active policies
     * @param _user Address of the user
     * @return Array of policy IDs owned by the user
     */
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    /**
     * @dev Get contract balance and pool information
     * @return contractBalance Current contract balance
     * @return poolBalance Total insurance pool balance
     */
    function getContractInfo() external view returns (uint256 contractBalance, uint256 poolBalance) {
        return (address(this).balance, totalPoolBalance);
    }
    
    // Allow contract to receive Ether
    receive() external payable {
        totalPoolBalance += msg.value;
    }
}
