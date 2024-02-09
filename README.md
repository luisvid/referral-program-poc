# Referral program POC


## Referral Campaigns Managed by Smart Contracts Utilizing ERC-1167: Minimal Proxy Contracts

&nbsp;

# Referrals program Use case

> **Use case of creation and configuration of a new referral program
> Registration of new referrals.
> Claiming rewards by users**

###  Prerequisites:
- ReferralFactoryClone contract deployed

### Roles

**Owner**:

- Owner of the Clone Factory contract
- Owner / Deployer of the Referral Clone contract

**Publisher**:

- Media publisher, creates and administrates a Referral program
- Owner of the rewards tokens (ERC20 and ERC721)

**End users:**

- Referral user: the one who refers a friend to buy a game/media
- Referee user: is the one who is referred by a friend and actually buys the game/media

### Functions allowed by Role

**Only Owner functions**

- Deployment of the new referral program (Referral contract clone)
    - `ReferralFactoryClone.createReferral ()`
- Inform/adds referrals
    - `addReferral()`
    - `addReferralBulk()`

**Only Publisher functions**

- Parameterization
    - `updateRewardsTiers()`
    - `setNFTRewards()`
    - `updateRewardTokenERC20()`
    - `updateProgramEndTime()`
    - `updateMxRewardAmount()`
    - `updateMinClaimAmount()`
    - `updateRewardTokenERC721()`
    - `setNFTRewards()`

**Open to End users**

- `getPendingRewards()`
- `claimRewards()`

**Only Owner or Publisher**

- `pause()`
- `unpause()`

### Use case detail

1. The publisher decides to create a referral program from the platform
2. The publisher enters the necessary data to generate the referral program
3. The backend carries out the deployment of the new clone of the Referral Contract
4. The publisher finishes configuring the program, adding the reward tiers and the tokens with which the rewards will be paid.
5. The backend informs the contract of the referrals that are happening on the platform
6. Users referral and referee request the transfer of their pending rewards

&nbsp;

## information needed to be entered by the publisher to initialize the program

&nbsp;

| Name | Type | Description |
|---|---|---|
| _gameId | uint256 | media identification
| _publisherAddress | address | Publisher address (reward token owner)
| _programEndTime | uint256 | Program end date
| _maxRewardAmount | uint256 | Maximum amount of reward that the program will deliver
| _minClaimAmount | uint256 | Minimum amount for the user to claim rewards
| _refereeRewAmountERC20 | uint256 | ERC20 reward amount for the referee user
| _refereeRewAmountERC721 | uint256 | ERC721 reward amount for the referee user
| _rewardTokenERC20 | address | ERC20 reward token address
| _rewardTokenERC721 | address | ERC721 reward token address


The backend executes the `createReferral()` function passing the specified parameters to implement a new clone of the reference contract.

```
ReferralFactoryClone.createReferral();
```

Then the backend executes the `getNewReferralClone()` function without parameters, which returns the address of the new cloned contract.

```
const newReferralProgram = getNewReferralClone();
```

## Parameterization of Rewards Tiers

The next step to finish initializing the smart contract of the referral program is to execute the `updateRewardsTiers()` function, passing arrays with the data of the tiers as parameters.

Example of reward tiers

| Init | UpTo | rewardERC20 | rewardERC721 | rewardERC721Step |
|---|---|---|---|---|
|  1 | 10 | 10 | 0 | 0 |
| 11 | 20 | 15 | 1 | 3 |
| 21 |  0 | 20 | 1 | 5 |

sample code to create or update the rewards tier scheme

```
const referralsUpTo = [10, 20, 0];
const rewardAmountERC20 = [toWei(10), toWei(15), toWei(20)];
const rewardAmountERC721 = [0, 1, 1];
const rewardERC721Step = [0, 3, 5];

await externalReferral.updateRewardsTiers(referralsUpTo, rewardAmountERC20, rewardAmountERC721, rewardERC721Step);
```

### Parameters

| Name | Type | Description |
|---|---|---|
| _referralsUpTo | uint256[] | Tiers max value
| _rewardAmountERC20 | uint256[] | ERC20 reward amount by tier
| _rewardAmountERC721 | uint256[] | ERC721 reward amount by tier
| _rewardERC721Step | uint256[] | ERC721 reward step


## Parameterization of Rewards Tokens

Prerequisites:
- The publisher has minted and approved, via `approve()` or `increaseAllowance()`, to the program contract address, enough ERC20 tokens to pay the rewards.
- The publisher has minted and approved `approve()`, to the program contract address, enough ERC721 tokens to pay the rewards and reports the IDs of those NFTs to the platform

The function to call to store in the smart contract of the referral program the IDs of the NFTs generated as rewards is `setNFTRewards()`

```
externalReferral.setNFTRewards(_nftRewards);
```

Sets the ERC721 tokens IDs asigned for reward

#### Parameters

| Name | Type | Description |
|---|---|---|
| _nftRewards | uint256[] | ERC721 tokens IDs array to be added as rewards

&nbsp;

## Inform/adds referrals

The backend receives the information of a purchase by referral, after the validations and blocking time, it informs the smart contract of the referral so that it can be paid.

### Individual add of referrals

The backend calls the `addReferral()` function which assigns the rewards to both users for the reported referral

```
addReferral(address _referral, address _referee) 
```

#### Parameters

| Name | Type | Description |
|---|---|---|
| _referral | address | user referral address
| _referee | address | user referee address


### bulk reported referral

The backend calls the `addReferralBulk()` function which assigns the rewards to both list of users for the reported referrals

```
addReferralBulk(address[] _referral, address[] _referee)
```

#### Parameters

| Name | Type | Description |
|---|---|---|
| _referral | address[] | adress array of referral users
| _referee | address[] | adress array of referee users

&nbsp;

## Claim Rewards

User referral o referee call the function `claimRewards()` to get the pendig rewards, in both ERC20 and ERC721 tokens
The transfer is only made if:
- The end date of the program has not been reached
- The user achieved the minimum rewards to claim
- There is enough amount of tokens to transfer
- Tokens are approved by the publisher to be transferred

```
function claimRewards() returns (bool)
```
Transfer the pending rewards to the user claiming

#### Returns

| Name | Type | Description |
|---|---|---|
|   | bool | True if the claim completes without errors

&nbsp;

### Aditional Info

### About the cost of gas for both options: `AddReferral()` vs `AddReferralBulk()`

This is how the gas report looks like after calling the function 40 times vs. pass an array of 40 items as a parameter

![image](https://user-images.githubusercontent.com/330947/159276801-b5b92b93-9063-4bf1-a3ce-d6f67af95475.png)

Summary of gas cost tests calling addReferral function n times vs. calling addReferralBulk and passing it an array of n addresses.

![image](https://user-images.githubusercontent.com/330947/159275484-01222f83-3e3f-44b5-bf8e-52cb04a83202.png)

>**Calling the function in batch is more cost efficient**

&nbsp;

### Referral contract deployment architecture

Clone Factory or Minimal Proxy Contract  [EIP 1167](https://eips.ethereum.org/EIPS/eip-1167)

The Clone Factory or Minimal Proxy contract is a design pattern and technique used in Ethereum smart contracts to create gas-efficient and scalable contracts. It involves creating a minimal proxy contract that acts as a proxy for multiple instances of another contract, known as the implementation contract.

Here's a high-level explanation of how it works:

1. Implementation Contract: This is the main contract that defines the logic and functionality. It contains the actual code and state variables.
2. Minimal Proxy Contract: This is a lightweight contract that acts as a proxy for the implementation contract. It doesn't contain any logic or state variables of its own.
3. Proxy Deployment: When deploying a new instance of the implementation contract, instead of deploying a full copy of the contract, a minimal proxy contract is deployed. The minimal proxy contract points to the implementation contract.
4. Delegate Calls: When a function is called on the minimal proxy contract, it forwards the call to the implementation contract using a delegate call. The implementation contract executes the function and returns the result to the minimal proxy contract, which then returns it to the caller.

By using the Clone Factory or Minimal Proxy contract pattern, multiple instances of the implementation contract can be created with minimal deployment costs. This is because the minimal proxy contract is lightweight and doesn't require deploying the entire implementation contract code for each instance.

The pattern is commonly used in scenarios where multiple instances of a contract are needed, such as creating unique tokens, managing user accounts, or creating decentralized applications (dApps) with shared logic.

It's worth noting that the implementation contract and minimal proxy contract need to be carefully designed and audited to ensure the security and integrity of the system.


#### Main modifications from the original contract version
- Change all imports contracts to upgradable versions (install @openzeppelin/contracts-upgradeable)
- Only deploy Factory contract!, then it takes care of instantiating the master contract and creating the clones
- An ownable contract is not a cloneable contract, remove all onlyOwner.
- To use the clone it is necessary to configure an ethers contract for the deployed clone instance
- Unfortunately, it's not possible to get the return value of a state-changing function outside the off-chain. It's only possible to get it on-chain, in other contracts which call your contract. What is usually done is that you emit events with the required data, and listen to those events. Or then you save the required data in the contract and have another view function 

### **Regarding gas consumption**

The deployment of each contract individually costs:

![image](https://user-images.githubusercontent.com/330947/160045639-2f8581e8-fb12-44f8-9061-939e0bfa3f3a.png)

in the case of the Clone Factory, the initial deployment of the Factory, which internally does the one-time deployment of the implementation, costs little more than the original:
But then the cost of deploying each clone costs about 14 times less than the deploy of the full contract!

![Screen Shot 2022-03-25 at 00 00 11](https://user-images.githubusercontent.com/330947/160046381-a121a8dd-cbd1-4243-b51e-e395461326d6.png)

&nbsp;
