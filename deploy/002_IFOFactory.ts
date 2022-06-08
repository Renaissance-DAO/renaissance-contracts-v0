import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;
  
  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();
  
  const signer = await ethers.getSigner(deployer);  

  // deploy implementation contract
  const ifoFactoryImpl = await deploy('IFOFactory', {
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
  await deployerContract.deployIFOFactory(ifoFactoryImpl.address);

};
func.tags = ['main', 'local', 'seed'];
export default func;