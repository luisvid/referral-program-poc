///SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/**
 * @title Referral programa
 * @author Luis Videla
 * @notice this contract manages the referral program
 */
contract ReferralMaster is
    Initializable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// Publisher address (reward token owner)
    address public publisher;
    address public owner;

    /// game identification
    uint256 public gameId;

    // Reward tokens
    /// ERC20 reward token address
    address public rewardTokenERC20;    
    /// ERC721 reward token address
    address public rewardTokenERC721;   

    // Limits
    /// date until which the program will be active
    uint48 public programEndTime;       
    /// amount of rewards delivered so far
    uint256 public totalRewardAmount;   
    /// maximum amount of reward that the program will deliver
    uint256 public maxRewardAmount;     
    /// Minimum amount for the user to claim rewards.
    uint256 public minClaimAmount;      

    /// Rewards Tiers
    struct TiersInfo {
        uint32 referralsUpTo;
        uint32 rewardAmountERC721;
        uint32 rewardERC721Step;
        uint256 rewardAmountERC20;
    }

    /// Tiers array
    TiersInfo[] public tiersInfo;

    /// Rewards NFTs
    struct RewardNFT {
        uint256 TokenId;
        bool delivered;
    }

    /// Rewards NFTs array
    RewardNFT[] public rewardsNFTs;

    /// Referral Reward info
    struct RewardInfo {
        uint32 referralsTotal;
        uint16 rewardAmountTotalERC721;
        uint256 rewardAmountTotalERC20;
        uint48 lastClaimTime;
    }

    // Referee reward info
    /// ERC721 reward amount for the referee user
    uint16 public refereeRewAmountERC721;   
    /// ERC20 reward amount for the referee user
    uint256 public refereeRewAmountERC20;   

    /// Maps users Referee or Referral, (both get payed), to RewardInfo struct
    mapping(address => RewardInfo) public userRewards;

    // EVENTS
    event tierSchemeUpdated(uint _tiersLength);
    event nftRewardIdsUpdated (uint _idsLength);
    event referralAdded(address _referral, address _referee);
    event rewardsClaimed(address _user);
    event programEndTimeUpdated (uint _newEndTime);
    event minClaimAmountUpdated (uint _newMinClaim);

    // MODIFIERS
    // check that the caller is the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    // check that the caller is the publiser
    modifier onlyPublisher() {
        require(msg.sender == publisher, "Not publisher");
        _;
    }
    // check that the caller is the owner or publiser
    modifier onlyAdmins() {
        require(msg.sender == publisher || msg.sender == owner, "Not an admin");
        _;
    }
     /**
     * @notice Clone initializer function
     * @param _owner Publisher address (reward token owner)
     * @param _publisher Publisher address (reward token owner)
     * @param _gameId game identification
     * @param _rewardTokenERC20 ERC20 reward token address
     * @param _rewardTokenERC721 ERC721 reward token address
     * @param _programEndTime Date until which the program will be active
     * @param _maxRewardAmount Maximum amount of reward that the program will deliver
     * @param _minClaimAmount Minimum amount for the user to claim rewards
     * @param _refereeRewAmountERC20 ERC20 reward amount for the referee user
     * @param _refereeRewAmountERC721 ERC721 reward amount for the referee user
     */
    function initialize(
        address _owner,
        address _publisher,
        uint256 _gameId,
        address _rewardTokenERC20,
        address _rewardTokenERC721,
        uint256 _programEndTime,
        uint256 _maxRewardAmount,
        uint256 _minClaimAmount,
        uint256 _refereeRewAmountERC20,
        uint256 _refereeRewAmountERC721
    ) public initializer {
        require(_owner != address(0), "Zero address");
        owner = _owner;
        require(_publisher != address(0), "Zero address");
        publisher = _publisher;
        gameId = _gameId;
        // keep tokens as address and cast to interfaces when trasferring e.g.
        // IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        // addresses check
        require(_rewardTokenERC20 != address(0), "Zero token address");
        require(_rewardTokenERC721 != address(0), "Zero token address");
        rewardTokenERC20 = _rewardTokenERC20;
        rewardTokenERC721 = _rewardTokenERC721;

        // limits
        require(uint48(_programEndTime) > block.timestamp, "Program end must be in future");
        programEndTime = uint48(_programEndTime);
        maxRewardAmount = _maxRewardAmount;
        minClaimAmount = _minClaimAmount;

        // referee rewards
        refereeRewAmountERC20 = _refereeRewAmountERC20;
        refereeRewAmountERC721 = uint16(_refereeRewAmountERC721);
    }

    // *** Administrative Actions ***

   /**
     * @notice Creates or updates the rewards tier scheme
     * @param _referralsUpTo Tiers max value
     * @param _rewardAmountERC20 ERC20 reward amount by tier
     * @param _rewardAmountERC721 ERC721 reward amount by tier
     * @param _rewardERC721Step ERC721 reward step
     */
    function updateRewardsTiers(
        uint256[] calldata _referralsUpTo,
        uint256[] calldata _rewardAmountERC20,
        uint256[] calldata _rewardAmountERC721,
        uint256[] calldata _rewardERC721Step
    ) onlyPublisher external {
        require(
            _referralsUpTo.length == _rewardAmountERC20.length &&
                _rewardAmountERC20.length == _rewardAmountERC721.length &&
                _rewardAmountERC721.length == _rewardERC721Step.length,
            "Referral: invalid tier data"
        );
        // reset tiers ans recreate
        delete tiersInfo;
        for (uint8 i = 0; i < _referralsUpTo.length; i++) {
            tiersInfo.push(
                TiersInfo({
                    // if UpTo equals 0, then save the max uint32 number
                    referralsUpTo: (
                        (_referralsUpTo[i] == 0)
                        ? 2**32 - 1
                        : uint32(_referralsUpTo[i])
                    ),
                    rewardAmountERC721: uint32(_rewardAmountERC721[i]),
                    rewardERC721Step: uint32(_rewardERC721Step[i]),
                    rewardAmountERC20: _rewardAmountERC20[i]
                })
            );
        }
        emit tierSchemeUpdated(tiersInfo.length);
    }
    
    /**
     * @notice Reward Tiers array length
     * @return Reward Tiers array length
     */
    function tiersInfoCount() external view returns (uint256) {
        return tiersInfo.length;
    }

    /**
     * @notice Updates the ERC20 reward token
     * @param _newRewardToken new reward token address
     */
    function updateRewardTokenERC20(address _newRewardToken)
        onlyPublisher external
    {
        require(_newRewardToken != address(0), "Zero token address");
        rewardTokenERC20 = _newRewardToken;
    }

    /**
     * @notice Updates the date until which the program will be active
     * @param _newEndTime the new end date
     */
    function updateProgramEndTime(uint256 _newEndTime) onlyPublisher external  {
        require(_newEndTime > block.timestamp, "Program end must be in future");
        programEndTime = uint48(_newEndTime);
        emit programEndTimeUpdated(_newEndTime);
    }

    /**
     * @notice Updates max amount of reward that the program will deliver
     * @param _newMaxReward the new max reward amount
     */
    function updateMaxRewardAmount(uint256 _newMaxReward) onlyPublisher external  {
        maxRewardAmount = _newMaxReward;
    }

    /**
     * @notice Updates the minimum amount for the user to claim rewards.
     * @param _newMinClaim the new min reward amount to claim
     */
    function updateMinClaimAmount(uint256 _newMinClaim) onlyPublisher external  {
        minClaimAmount = _newMinClaim;
        emit minClaimAmountUpdated(_newMinClaim);
    }

    // *** NFTs rewards functions ***

    /**
     * @notice Updates the ERC721 reward token
     * @param _newRewardToken new reward token address
     */
    function updateRewardTokenERC721(address _newRewardToken)
       onlyPublisher external
    {
        require(_newRewardToken != address(0), "Zero token address");
        rewardTokenERC721 = _newRewardToken;
    }

    /**
     * @notice Sets the ERC721 tokens IDs asigned for reward
     * @param _nftRewards ERC721 tokens IDs array to be added as rewards
     */
    function setNFTRewards(uint256[] memory _nftRewards) onlyPublisher public  {
        for (uint i = 0; i < _nftRewards.length; i++) {
            rewardsNFTs.push(
                RewardNFT({TokenId: _nftRewards[i], delivered: false})
            );
        }
        emit nftRewardIdsUpdated(_nftRewards.length);
    }

    /**
     * @notice Return the index of the first available reward NFT, if any
     * @return tuple with a bool value indicating if there is an available
     * tokens and the corresponding id
     */
    function getNextRewardNFTIndex() private view returns (bool, uint) {
        for (uint i = 0; i < rewardsNFTs.length; i++) {
            if (rewardsNFTs[i].delivered == false) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /**
     * @notice Return amount of reward NFTs
     * @return rewards NFTs array length
     */
    function getNFTRewardsCount() external view returns (uint256) {
        return rewardsNFTs.length;
    }

    // *** Rewards functions ***

    /**
     * @notice Returns de pending rewards for the specified user
     * @param _user user address
     * @return tuple with the ERC20 and ERC721 pending amunts
     */
    function getPendingRewards(address _user)
        external
        view
        returns (uint256, uint256)
    {
        return (
            userRewards[_user].rewardAmountTotalERC20,
            userRewards[_user].rewardAmountTotalERC721
        );
    }

    /**
     * @notice Assign the rewards to both users for the informed referral
     * @param _referral user referral address
     * @param _referee user referee address
     */
    function addReferral(address _referral, address _referee)
        onlyOwner public returns (bool)
    {
        require(
            _referral != address(0) && _referee != address(0),
            "addReferral: invalid user address"
        );
        require(
            _referral != publisher && _referee != publisher,
            "addReferral: The publisher cannot assign rewards to itself"
        );
        require(
            _referral != msg.sender && _referee != msg.sender,
            "addReferral: The platform cannot assign rewards to itself"
        );
        require(
            tiersInfo.length > 0,
            "addReferral: reward tier scheme has not been configured "
        );

        // check tier and updates rewards mapping
        uint256 totalRefs = userRewards[_referral].referralsTotal + 1;
        uint256 rewardERC20 = 0;
        uint256 rewardERC721 = 0;
        uint256 tierInit = 1;
        for (uint i = 0; i < tiersInfo.length; i++) {
            if (totalRefs <= tiersInfo[i].referralsUpTo) {
                rewardERC20 = tiersInfo[i].rewardAmountERC20;
                // check if there are some nfts rewards
                if (tiersInfo[i].rewardAmountERC721 > 0) {
                    // check if there are steps on the nfts rewards
                    if (tiersInfo[i].rewardERC721Step > 0) {
                        rewardERC721 = (totalRefs - tierInit) %
                            tiersInfo[i].rewardERC721Step ==
                            0
                            ? rewardERC721 = tiersInfo[i].rewardAmountERC721
                            : rewardERC721 = 0;
                    } else {
                        rewardERC721 = tiersInfo[i].rewardAmountERC721;
                    }
                }
                break;
            }
            tierInit = tiersInfo[i].referralsUpTo + 1;
        }
        // update the total reward assigned and validate that it is not greater
        // than the maximum  reward assigned to the campaign
        uint256 totalRewardAssigned = totalRewardAmount +
            rewardERC20 +
            refereeRewAmountERC20;
        require(
            totalRewardAssigned <= maxRewardAmount,
            "addReferral: The maximum number of rewards to assign has been reached"
        );
        totalRewardAmount = totalRewardAssigned;
        // update the user referral rewards
        userRewards[_referral].referralsTotal += 1;
        userRewards[_referral].rewardAmountTotalERC721 += uint16(rewardERC721);
        userRewards[_referral].rewardAmountTotalERC20 += rewardERC20;
        // update the user referee rewards
        userRewards[_referee].rewardAmountTotalERC721 += refereeRewAmountERC721;
        userRewards[_referee].rewardAmountTotalERC20 += refereeRewAmountERC20;
        // uncomment to document reward progression
        // console.log("referralsTotal: %s - rewardERC721: %s - rewardERC20: %s",
        //     userRewards[_referral].referralsTotal, rewardERC721, rewardERC20 );

        emit referralAdded(_referral, _referee);
        return true;
    }

    /**
     * @notice Assign the rewards to both users for the informed batch of referrals
     * @param _referral adress array of referral users
     * @param _referee adress array of referee users
     */
    function addReferralBulk(
        address[] calldata _referral,
        address[] calldata _referee
    ) external  onlyOwner {
        require(
            _referral.length == _referee.length,
            "addReferralBulk: Array length mismatch"
        );
        for (uint256 i = 0; i < _referral.length; i++) {
            addReferral(_referral[i], _referee[i]);
        }
    }

    /**
     * @notice Transfer the pending rewards to the user claiming
     * @return True if the claim completes without errors
     */
    function claimRewards() external nonReentrant whenNotPaused returns (bool) {
        require(
            programEndTime > block.timestamp,
            "Claim: referral program has ended"
        );
        uint256 rewardAmount = userRewards[msg.sender].rewardAmountTotalERC20;
        require(
            rewardAmount >= minClaimAmount,
            "Claim: minimum claim amount not reached"
        );
        // Allowance validation
        uint256 ourAllowance = IERC20Upgradeable(rewardTokenERC20).allowance(
            publisher,
            address(this)
        );
        require(rewardAmount <= ourAllowance, "Claim: Allowance is too low");
        // transfer tokens from publisher to user
        userRewards[msg.sender].rewardAmountTotalERC20 = 0;
        IERC20Upgradeable(rewardTokenERC20).transferFrom(
            publisher,
            msg.sender,
            rewardAmount
        );
        // NFT validation and transfer from publisher to user
        uint256 rewardAmountNft = userRewards[msg.sender]
            .rewardAmountTotalERC721;
        for (uint i = 0; i < rewardAmountNft; i++) {
            (bool exist, uint index) = getNextRewardNFTIndex();
            require(exist, "Claim: Not enough ERC721 tokens for reward");
            address operator = ERC721Upgradeable(rewardTokenERC721).getApproved(
                rewardsNFTs[index].TokenId
            );
            require(
                operator == address(this),
                "Claim: token ERC721 not approved to trasfer"
            );
            rewardsNFTs[index].delivered = true;
            ERC721Upgradeable(rewardTokenERC721).safeTransferFrom(
                publisher,
                msg.sender,
                rewardsNFTs[index].TokenId
            );
        }

        emit rewardsClaimed(msg.sender);
        return true;
    }
    /**
     * @dev Triggers stopped state.
     * Requirements:
     * - The contract must not be paused.
     */
    function pause() external onlyAdmins  {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     * Requirements:
     * - The contract must be paused.
     */
    function unpause() external onlyAdmins {
        _unpause();
    }

}
