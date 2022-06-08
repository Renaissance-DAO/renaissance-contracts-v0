import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {testnets} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;
  
  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await hre.getChainId();

  const signer = await ethers.getSigner(deployer);

  // get WETH address
  let { WETH } = await getNamedAccounts();
  if (testnets.includes(chainId)) {
    const mockWETH = await get('WETH');
    WETH = mockWETH.address;
  }

  // get ifo factory proxy address
  const proxyControllerInfo = await get('MultiProxyController');
  const proxyController = new ethers.Contract(
    proxyControllerInfo.address,
    proxyControllerInfo.abi,
    signer
  );
  const ifoFactoryAddress = (await proxyController.proxyMap(
    ethers.utils.formatBytes32String("IFOFactory")
  ))[1];

  // deploy implementation contract
  const fnftFactoryImpl = await deploy('FNFTFactory', {
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
  await deployerContract.deployFNFTFactory(
    fnftFactoryImpl.address, 
    WETH,
    ifoFactoryAddress
  );

};

func.tags = ['main', 'local', 'seed'];
export default func;