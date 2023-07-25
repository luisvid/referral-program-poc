import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, network } from 'hardhat';


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer, publisher } = await getNamedAccounts();

  await deploy('ReferralFactoryClone', {
    from: deployer,
    log: true,
  });

};
export default func;
func.tags = ['Factory'];
func.dependencies = ['Mocks']; // this ensure the Mocks script is executed first
