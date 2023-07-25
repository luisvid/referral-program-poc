// **** This a example test code, not a test itself and not suitable for production **** 
// 
// Interacting with cone factory deployed contracts - Roles version
// In a way similar to how it would be from node.js
// 
// $ npx hardhat run --network ropsten scripts/script-name.ts


import { ethers, providers } from 'ethers';
import { increaseTimeStampDays, toWei, fromWei } from '../test/utils/index';

// get the abis for the contracts to work with
import abi_ReferralFactory from  '../abi/contracts/ReferralFactoryClone.sol/ReferralFactoryClone.json';
import abi_Referral from '../abi/contracts/ReferralMaster.sol/ReferralMaster.json';

// addresses and PKs of the involved accounts
const publisherAddres = '0x9A30EC0b6412649802542a881B71865197cc132D';
const referralUser = '0x723a19676EF0f25989C4cD96E049013B400894d6';
const refereeUser = '0xc2A50A453031eece2bA552388930B9edAaE6F465';
const owner_pk = 'xxx';
const publisher_pk = 'xxx';

// addresses of deployed contracts on ropsten
const tokenAAddress = '0xca448F81735f173987a66f7E0EaF14520c239354';
const NFTAddress = '0x0Ae103C113BDA82935f795ad88fF5b9e938B58bF';
const factoryAddres = '0x887639A54f485a8E119285Fc4d4923961934c0d4';

// alchemy uri
const ETH_NODE_URI_ROPSTEN = 'https://eth-ropsten.alchemyapi.io/v2/xxx';
const provider = new ethers.providers.JsonRpcProvider(ETH_NODE_URI_ROPSTEN, 'ropsten');

// get the publisher and owner signer object so we can send transactions 
// on their behalf in functions marked as onlyPublisher or onlyOwner
const ownerSigner = new ethers.Wallet(owner_pk, provider);
const publisherSigner = new ethers.Wallet(publisher_pk, provider);

// get an instance of the deployed factory contract
const referralFactory = new ethers.Contract(factoryAddres, abi_ReferralFactory, ownerSigner);

// set the option object to set a higher gas value to speed up the transaction 
// (ropsten network is highly congested)
// e.g. options = { gasPrice: 1000000000, gasLimit: 85000, nonce: 45, value: 0 };
const options = { gasPrice: ethers.utils.parseUnits('100', 'gwei'), gasLimit: 1000000 };


const transaction = async () => {

    // *** create a new referral clone and initialize it
    console.log('*** create a new referral clone and initialize it');

    const gameId = 1;
    const programEndTime = increaseTimeStampDays(20);
    const maxRewardAmount = toWei(100);
    const minClaimAmount = toWei(30);
    const refereeRewardERC20 = toWei(2);
    const refereeRewardERC721 = 0;

    // this transaction is sent in behalf of the owner
    let tx = await referralFactory.createReferral(
        publisherAddres, gameId, tokenAAddress, NFTAddress,
        programEndTime, maxRewardAmount, minClaimAmount,
        refereeRewardERC20, refereeRewardERC721, options
    );

    // wait for the transaction to be mined
    await tx.wait();

    // get the address of the new referral clone deployed in te previus step
    const cloneAddress = await referralFactory.getNewReferralClone();
    console.log('New referral clone address: ', cloneAddress);

    // now we work with the recently deployed referrals clone
    // create instances of the contract cloned with the owner and the publihser
    // as the signers, since some methods are called on their behalf
    const referralClone_pub = new ethers.Contract(cloneAddress, abi_Referral, publisherSigner);
    const referralClone_own = new ethers.Contract(cloneAddress, abi_Referral, ownerSigner);

    // *** set the rewards tiers
    console.log('*** set the rewards tiers');

    const referralsUpTo = [10, 20, 0];
    const rewardAmountERC20 = [toWei(10), toWei(15), toWei(20)];
    const rewardAmountERC721 = [0, 1, 1];
    const rewardERC721Step = [0, 3, 5];

    tx = await referralClone_pub.updateRewardsTiers(referralsUpTo, rewardAmountERC20,
        rewardAmountERC721, rewardERC721Step, options);

    // wait for the transaction to be mined
    await tx.wait();

    // If all went well, the reward array should have 3 items
    console.log("Rewards tiers length: ", await referralClone_pub.tiersInfoCount());

    // *** increase the maximum amount of reward, this functions is onlyPublisher    
    console.log('*** increase the maximum amount of reward');
    tx = await referralClone_pub.updateMaxRewardAmount(toWei(500), options);
    await tx.wait();
    console.log("MaxRewardAmount: ", await referralClone_pub.maxRewardAmount());

    // *** add referral (only owner)
    console.log('*** add referral');
    tx = await referralClone_own.addReferral(referralUser, refereeUser, options);
    await tx.wait();

    // show pending rewards (any user)
    let [pendingERC20, pendingNFT] = await referralClone_own.getPendingRewards(referralUser);
    console.log('Pending rewards for user referral: ', fromWei(pendingERC20));

    [pendingERC20, pendingNFT] = await referralClone_own.getPendingRewards(refereeUser);
    console.log('Pending rewards for user referee: ', fromWei(pendingERC20));

    // *** claim rewards
    // this is done by the end users

}

transaction()