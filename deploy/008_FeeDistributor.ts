import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {testnets} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;

  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  let { TREASURY } = await getNamedAccounts();

  const proxyControllerInfo = await get('MultiProxyController');
  const proxyController = new ethers.Contract(
    proxyControllerInfo.address,
    proxyControllerInfo.abi,
    signer
  );
  const vaultManagerAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("VaultManager")
  ))[1];

  const lpStakingAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("LPStaking")
  ))[1];

  // deploy implementation contract
  const feeDistributorImpl = await deploy('FeeDistributor', {
    from: deployer,
    log: true,
  });

  // deploy proxy contract
  const deployerInfo = await get('Deployer');
  const deployerContract = new ethers.Contract(
    deployerInfo.address,
    deployerInfo.abi,
    signer
  );
  await deployerContract.deployFeeDistributor(
    feeDistributorImpl.address,
    vaultManagerAddress,
    lpStakingAddress,
    TREASURY
  );
};

func.tags = ['main', 'local', 'seed'];
export default func;