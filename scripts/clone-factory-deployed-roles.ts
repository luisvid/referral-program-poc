// **** This a example test code, not a test itself and not suitable for production **** 
// 
// Interacting with cone factory deployed contracts - Roles version
// 
// $ npx hardhat run --network ropsten scripts/script-name.ts

import { ethers } from 'hardhat';
import { increaseTimeStampDays, toWei } from '../test/utils/index';

async function main(): Promise<void> {

  // Retrieve accounts from the local node
  // this can be set from count propertie of accounts in networks config (hardhat.config.ts)
  const users = await ethers.provider.listAccounts();

  const owner = '0xB5664e6278009bE57131a466750370898E1F72f7'
  const publisherAddres = '0x9A30EC0b6412649802542a881B71865197cc132D';

  const TokenAAddress = '0xca448F81735f173987a66f7E0EaF14520c239354';
  const NFTAddress = '0x0Ae103C113BDA82935f795ad88fF5b9e938B58bF';

  const factoryAddres = '0x887639A54f485a8E119285Fc4d4923961934c0d4';
  
  const ReferralFactoryClone = await ethers.getContractFactory('ReferralFactoryClone');
  const factoryClone = await ReferralFactoryClone.attach(factoryAddres);


  // create a referral clone and initialize it
  const gameId = 1;
  const programEndTime = increaseTimeStampDays(20);
  const maxRewardAmount = toWei(100);
  const minClaimAmount = toWei(30);
  const refereeRewardERC20 = toWei(2);
  const refereeRewardERC721 = 0;

  // from Owner account
  let tx = await factoryClone.connect(await ethers.getSigner(owner))
    .createReferral(
      publisherAddres, gameId, TokenAAddress, NFTAddress,
      programEndTime, maxRewardAmount, minClaimAmount,
      refereeRewardERC20, refereeRewardERC721
    );

  // wait for the transaction to be mined
  await tx.wait();

  // get the address of the clone deployed in te previus step
  let cloneAddress = await factoryClone.getNewReferralClone();

  // attach address to a contract instance
  const ReferralMaster = await ethers.getContractFactory('ReferralMaster');
  const externalReferral = ReferralMaster.attach(cloneAddress);


  // creates the rewards tiers, this functions is onlyPublisher
  const referralsUpTo = [10, 20, 0];
  const rewardAmountERC20 = [toWei(10), toWei(15), toWei(20)];
  const rewardAmountERC721 = [0, 1, 1];
  const rewardERC721Step = [0, 3, 5];

  tx = await externalReferral.connect(await ethers.getSigner(publisherAddres))
    .updateRewardsTiers(referralsUpTo, rewardAmountERC20,
      rewardAmountERC721, rewardERC721Step);

  await tx.wait();

  console.log("Rewards tiers length: ", await externalReferral.tiersInfoCount());

  // ...

  // set rewards tokens ERC20 and ERC721

  // claim rewards including NFT

  // update the max rewards functions is onlyPublisher
  tx = await externalReferral.connect(await ethers.getSigner(publisherAddres)).updateMaxReward(toWei(500));

  await tx.wait();

  console.log("MaxRewardAmount: ", await externalReferral.maxRewardAmount());


}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });