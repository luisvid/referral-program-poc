import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer, publisher } = await getNamedAccounts();

  await deploy('RewardNFTMock', {
    from: deployer,
    log: true,
  });

  await deploy('RewardTokenAMock', {
    from: deployer,
    log: true,
  });

  await deploy('RewardTokenBMock', {
    from: deployer,
    log: true,
  });

};
export default func;
func.tags = ['Mocks'];