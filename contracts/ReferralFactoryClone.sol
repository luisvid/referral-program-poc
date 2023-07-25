//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReferralMaster.sol";

// only for tests
import "hardhat/console.sol";

contract ReferralFactoryClone is Ownable {
    /// referral implementation contract
    address immutable referralImplementation;

    /// Address of the last clone created so that it
    // can be returned offchain through a view function
    address private newReferralClone;

    /// event new referral program created
    event NewReferralProgram(address indexed contractAddress);

    using Clones for address;

    /**
     * @notice Constructor
     * Only factory is deployed and it create an instance of de referral
     * implementation contract
     */
    constructor() {
        referralImplementation = address(new ReferralMaster());
    }

    /**
     * @notice Creates and initialize a new referral program contract clone
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
    function createReferral(
        address _publisher,
        uint256 _gameId,
        address _rewardTokenERC20,
        address _rewardTokenERC721,
        uint256 _programEndTime,
        uint256 _maxRewardAmount,
        uint256 _minClaimAmount,
        uint256 _refereeRewAmountERC20,
        uint256 _refereeRewAmountERC721
    ) external onlyOwner {
        address clone = Clones.clone(referralImplementation);
        newReferralClone = clone;
        ReferralMaster(clone).initialize(
            owner(),
            _publisher,
            _gameId,
            _rewardTokenERC20,
            _rewardTokenERC721,
            _programEndTime,
            _maxRewardAmount,
            _minClaimAmount,
            _refereeRewAmountERC20,
            _refereeRewAmountERC721
        );

        emit NewReferralProgram(clone);
    }

    /**
     * @notice Address of the last clone created so that it
     * can be returned offchain through a view function
     * @dev Unfortunately, it's not possible to get the return value of a
     * state-changing function outside the off-chain. It's only possible to
     * get it on-chain, in other contracts which call your contract.
     * What is usually done is that you emit events with the required data,
     * and listen to those events. Or then you save the required data in the
     * contract and have another view function
     */
    function getNewReferralClone() external view returns (address) {
        return newReferralClone;
    }
}
