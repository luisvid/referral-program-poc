import { expect } from "./chai-setup";
import { ethers, deployments, getNamedAccounts, getUnnamedAccounts } from 'hardhat';
import { Contract } from "ethers";
import { fromWei, increaseTimeStampDays, toWei } from './utils';
import { text } from "stream/consumers";

describe('ExternalReferral', async () => {

    // namedAccounts: deployer, publisher, treasury
    let named: { [x: string]: string; nammedAcc?: any; };
    let users: any[];
    let factory: Contract;
    let rewardTokenA: Contract;
    let rewardNFT: Contract;
    let externalReferral: Contract;

    it('Successfully deploy factory', async () => {

        // deploy contracts
        await deployments.fixture(["Factory"]);

        // get accounts
        named = await getNamedAccounts();
        users = await getUnnamedAccounts();

        // get contracts
        factory = await ethers.getContract("ReferralFactoryClone");
        rewardTokenA = await ethers.getContract("RewardTokenAMock");
        rewardNFT = await ethers.getContract("RewardNFTMock");

        expect(factory).to.exist;
    })


    it('Successfully create N referral clones to check gas reporter', async () => {
        for (let i = 0; i < 10; i++) {
            const gameId = i;
            const programEndTime = increaseTimeStampDays(20 + i);
            const maxRewardAmount = toWei(100 + i);
            const minClaimAmount = toWei(30 + i);
            const refereeRewardERC20 = toWei(2);
            const refereeRewardERC721 = 0;

            let tx = await factory.createReferral(
                named.publisher, gameId, rewardTokenA.address, rewardNFT.address,
                programEndTime, maxRewardAmount, minClaimAmount,
                refereeRewardERC20, refereeRewardERC721
            );

            // Set up an ethers contract, for the deployed Referral clone instance
            let cloneAddress = await factory.getNewReferralClone();
            expect(cloneAddress).to.exist;
        }
    })

    it('Successfully create a referral clone and initialize it', async () => {

        const gameId = 1;
        const programEndTime = increaseTimeStampDays(20);
        const maxRewardAmount = toWei(100);
        const minClaimAmount = toWei(30);
        const refereeRewardERC20 = toWei(2);
        const refereeRewardERC721 = 0;

        let tx = await factory.createReferral(
            named.publisher, gameId, rewardTokenA.address, rewardNFT.address,
            programEndTime, maxRewardAmount, minClaimAmount,
            refereeRewardERC20, refereeRewardERC721
        );

        // Set up an ethers contract, for the deployed Referral clone instance
        let cloneAddress = await factory.getNewReferralClone();
        const ReferralMaster = await ethers.getContractFactory('ReferralMaster');
        externalReferral = await ReferralMaster.attach(cloneAddress);
        expect(externalReferral).to.exist;

        // roles - adress
        // console.table("ROLES");
        // console.table(named);
        // console.log("Factory address: ", factory.address)
        // console.log("Factory Owner: ", await factory.owner())
        // console.log("Clone address: ", externalReferral.address)
        // console.log("Clone Owner: ", await externalReferral.owner());
        // console.log("Clone Publisher: ", await externalReferral.publisher());
    })

    it('Successfully update rewards tiers', async () => {

        // create rewards tiers
        // init        UpTo 		rewardERC20     rewardERC721    rewardERC721Step
        //  1           10		        10              0               0
        //  11		    20 		        15	            1               3
        //  21         0(max)  	        20	            1               5

        const referralsUpTo = [10, 20, 0];
        const rewardAmountERC20 = [toWei(10), toWei(15), toWei(20)];
        const rewardAmountERC721 = [0, 1, 1];
        const rewardERC721Step = [0, 3, 5];

        await externalReferral.connect(await ethers.getSigner(named.publisher))
            .updateRewardsTiers(referralsUpTo, rewardAmountERC20,
                rewardAmountERC721, rewardERC721Step);
        expect(await externalReferral.tiersInfoCount()).equal(3);
    })

    it('Successfully set rewards tokens ERC20 and ERC721', async () => {
        // mint rewards ERC20, change ownership to publisher and 
        // increase allowance externalReferral contract

        await rewardTokenA.mint(named.publisher, toWei(500));
        await rewardTokenA.transferOwnership(named.publisher);
        await rewardTokenA.connect(await ethers.getSigner(named.publisher))
            .increaseAllowance(externalReferral.address, toWei(500));

        // transfer ownership, mint NFTs and approve them to externalReferral contract
        let newItemId;
        let arrayIds = [];
        await rewardNFT.transferOwnership(named.publisher);
        for (let i = 0; i < 5; i++) {
            await rewardNFT.connect(await ethers.getSigner(named.publisher))
                .safeMint(named.publisher);
            newItemId = await rewardNFT.currentTokenID();
            await rewardNFT.connect(await ethers.getSigner(named.publisher))
                .approve(externalReferral.address, newItemId);
            arrayIds.push(newItemId);
        }
        // update in referral contract the available NFTs for reward
        await externalReferral.connect(await ethers.getSigner(named.publisher))
            .setNFTRewards(arrayIds);
        expect((await externalReferral.getNFTRewardsCount()).toNumber()).equal(5);

    })

    it('Successfully claim rewards including NFTs', async () => {
        // increase the maximum amount of reward to be able to pay everyone
        await externalReferral.connect(await ethers.getSigner(named.publisher))
            .updateMaxRewardAmount(toWei(205));
        // add referrals: user[0] refers to 15 friends so he can reach the NFTs reward tier
        // expect 2 NFTs
        for (let i = 1; i < 16; i++) {
            await externalReferral.addReferral(users[0], users[i + 1]);
        }
        let [pendingERC20, pendingNFT] = await externalReferral.getPendingRewards(users[0]);
        expect(pendingNFT.toNumber()).equal(2);

        // claim rewards for user[0]
        await externalReferral.connect(await ethers.getSigner(users[0]))
            .claimRewards()
        console.log("User referral tokens balance : ", fromWei(await rewardTokenA.balanceOf(users[0])));
        console.log("User referral NFTs balance : ", (await rewardNFT.balanceOf(users[0])).toNumber());
        expect((await rewardNFT.balanceOf(users[0])).toNumber()).equal(2);
    })


})
