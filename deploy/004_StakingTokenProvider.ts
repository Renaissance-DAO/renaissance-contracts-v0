import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {testnets} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;

  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await hre.getChainId();

  const signer = await ethers.getSigner(deployer);

  let { WETH, UNISWAP_V2_FACTORY } = await getNamedAccounts();
  if (testnets.includes(chainId)) {
    const mockWETH = await get('WETH');
    WETH = mockWETH.address;
  }

  // deploy implementation contract
  const stakingTokenProviderImpl = await deploy('StakingTokenProvider', {
    from: deployer,
    log: true,
  });

  // deploy proxy contract
  const deployerInfo = await get('Deployer')
  const deployerContract = new ethers.Contract(
    deployerInfo.address,
    deployerInfo.abi,
    signer
  );
  await deployerContract.deployStakingTokenProvider(
    stakingTokenProviderImpl.address,
    UNISWAP_V2_FACTORY,
    WETH,
    "x"
  );
};
func.tags = ['main', 'local', 'seed'];
export default func;