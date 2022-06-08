import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'ethers';
import { testnets } from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers, getChainId} = hre;
  const {Contract, getSigner} = ethers;

  const {deploy, get} = deployments;
  const chainId = await getChainId();
  let { WETH, deployer, TREASURY, UNISWAP_V2_FACTORY } = await getNamedAccounts();
  if (testnets.includes(chainId)) {
    const mockWETH = await get('WETH');
    WETH = mockWETH.address;
  }

  const signer = await getSigner(deployer);

  // deploy implementation contract
  const vaultImpl = await deploy('FNFTCollection', {
    from: deployer,
    log: true,
  });

  const lpStakingImpl = await deploy('LPStaking', {
    from: deployer,
    log: true,
  });

  const feeDistributorImpl = await deploy('FeeDistributor', {
    from: deployer,
    log: true,
  });

  const factoryImpl = await deploy('FNFTCollectionFactory', {
    from: deployer,
    log: true,
  });

  const stakingTokenProviderImpl = await deploy('StakingTokenProvider', {
    from: deployer,
    log: true,
  });

  // deploy proxy contract
  const deployerInfo = await get('Deployer')
  const deployerContract = new Contract(
    deployerInfo.address,
    deployerInfo.abi,
    signer
  );

  const stakingTokenProviderTx = await deployerContract.deployStakingTokenProvider(
    stakingTokenProviderImpl.address,
    UNISWAP_V2_FACTORY,
    WETH,
    "x" // default prefix
  );
  const stakingTokenProviderReceipt = await stakingTokenProviderTx.wait();
  let event = stakingTokenProviderReceipt.events.find((event: ethers.Event) => event.event === "ProxyDeployed");
  const [,stakingTokenProviderAddress,] = event.args;

  const lpStakingTx = await deployerContract.deployLPStaking(
    lpStakingImpl.address,
    stakingTokenProviderAddress
  );
  const lpStakingReceipt = await lpStakingTx.wait();
  event = lpStakingReceipt.events.find((event: ethers.Event) => event.event === "ProxyDeployed");
  const [,lpStakingAddress,] = event.args;

  const feeDistributorTx = await deployerContract.deployFeeDistributor(
    feeDistributorImpl.address,
    lpStakingAddress,
    TREASURY
  );
  const feeDistributorReceipt = await feeDistributorTx.wait();
  event = feeDistributorReceipt.events.find((event: ethers.Event) => event.event === "ProxyDeployed");
  const [,feeDistributorAddress,] = event.args;

  await deployerContract.deployFNFTCollectionFactory(
    factoryImpl.address,
    vaultImpl.address,
    feeDistributorAddress
  );

  const feeDistributorInfo = await get('FeeDistributor');
  const feeDistributorContract = new Contract(
    feeDistributorAddress,
    feeDistributorInfo.abi,
    signer
  );
  await feeDistributorContract.setFNFTCollectionFactory(factoryImpl.address);

  const lpStakingInfo = await get('LPStaking');
  const lpStakingContract = new Contract(
    lpStakingAddress,
    lpStakingInfo.abi,
    signer
  );
  await lpStakingContract.setFNFTCollectionFactory(factoryImpl.address);
};

func.tags = ['main', 'local', 'seed'];
export default func;