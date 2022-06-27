import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { Bytes } from 'ethers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;
  const {get} = deployments;

  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  /** SET PRICE ORACLE IN FNFTSingleFactory */

  // 1. get proxy controller
  const proxyControllerInfo = await get('MultiProxyController');
  const proxyController = new ethers.Contract(
    proxyControllerInfo.address,
    proxyControllerInfo.abi,
    signer
  );

  // 1. get price oracle proxy address from controller
  const priceOracleAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("PriceOracle")
  ))[1];


  // 2. get fnftSingleFactory proxy address from controller
  const fnftSingleFactoryAbi = (await get('FNFTSingleFactory')).abi; // get abi of impl contract
  const fnftSingleFactoryAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("FNFTSingleFactory")
  ))[1];
  const fnftSingleFactory = new ethers.Contract(
    fnftSingleFactoryAddress,
    fnftSingleFactoryAbi,
    signer
  );

  // 3. set price oracle address in FNFTSingleFactory
  await fnftSingleFactory.setPriceOracle(priceOracleAddress);



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