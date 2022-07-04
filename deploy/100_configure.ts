import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { Bytes } from 'ethers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;
  const {get} = deployments;

  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  // 1. get proxy controller
  const proxyControllerInfo = await get('MultiProxyController');
  const proxyController = new ethers.Contract(
    proxyControllerInfo.address,
    proxyControllerInfo.abi,
    signer
  );

  // 2. get necessary contract addresses from controller
  const fnftSingleFactoryAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("FNFTSingleFactory")
  ))[1];

  const fnftCollectionFactoryAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("FNFTCollectionFactory")
  ))[1];

  const feeDistributorAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("FeeDistributor")
  ))[1];

  // 2. get vaultManager from controller
  const vaultManagerAbi = (await get('VaultManager')).abi; // get abi of impl contract
  const vaultManagerAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("VaultManager")
  ))[1];
  const vaultManager = new ethers.Contract(
    vaultManagerAddress,
    vaultManagerAbi,
    signer
  );

  // 3. setup variables in vaultManager
  await vaultManager.setFNFTSingleFactory(fnftSingleFactoryAddress);
  await vaultManager.setFNFTCollectionFactory(fnftCollectionFactoryAddress);
  await vaultManager.setFeeDistributor(feeDistributorAddress);

  // finally, print all proxy addresses
  console.log("Proxy contracts:");
  const keys = await proxyController.getAllProxiesInfo();
  await Promise.all(keys.map(async (key: Bytes) => {
    const address = await proxyController.proxyMap(key);
    console.log(`${ethers.utils.parseBytes32String(key)} : ${address[1]}`);
  }));
};

func.tags = ['main', 'local', 'seed'];
export default func;