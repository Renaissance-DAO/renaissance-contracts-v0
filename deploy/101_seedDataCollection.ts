import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {BigNumber, parseFixed} from '@ethersproject/bignumber';
import {ethers} from 'hardhat';

/**
 *
 * SCENARIOS
 * 1.  NFT1 => FNFTCollection with 5 items
 * 2.  NFT2 => FNFTCollection with 1 item
 * 3.  NFT3 => FNFTCollection without an item
 * 4.  NFT4 => FNFTCollection with 5 items that has 3 items in bid
 * 5.  NFT5 => FNFTCollection with 5 items that has 2 items in bid and 2 items redeemed
 * 6.  NFT6 => FNFTCollection with 5 items that have no tokenURI
 * 7.  NFT7 => FNFTCollection with 50 items
 * 8.  NFT8 => FNFTCollection with 5 items, where 2 have been deposited by a chosen (user) address
 * 9.  NFT9 => FNFTCollection that is undergoing IFO but not started
 * 10.  NFT10 => FNFTCollection that is undergoing IFO and has started with a few sales here and there
 * 11.  NFT11 => FNFTCollection that is undergoing IFO and is paused with a few sales here and there
 * 12.  NFT12 => FNFTCollection that has finished IFO with a few sales here and there
 */

 const PERCENTAGE_SCALE = 10000; // for converting percentages to fixed point

 const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
   const {getNamedAccounts, ethers} = hre;
   const {deploy} = hre.deployments;
   const {deployer} = await getNamedAccounts();

   // NFT1
   const nft1CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT1 Name", "NFT1"],
     log: true,
     autoMine: true
   });
   const nft1Collection = await ethers.getContractAt(
     nft1CollectionInfo.abi,
     nft1CollectionInfo.address
   );
   await nft1Collection.setBaseURI("ipfs://QmVTuf8VqSjJ6ma6ykTJiuVtvAY9CHJiJnXsgSMf5rBRtZ/");

   // NFT2
   const nft2CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT2 Name", "NFT2"],
     log: true,
     autoMine: true
   });
   const nft2Collection = await ethers.getContractAt(
     nft2CollectionInfo.abi,
     nft2CollectionInfo.address
   );
   await nft2Collection.setBaseURI("https://www.timelinetransit.xyz/metadata/");

   // NFT3
   const nft3CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT3 Name", "NFT3"],
     log: true,
     autoMine: true
   });
   const nft3Collection = await ethers.getContractAt(
     nft3CollectionInfo.abi,
     nft3CollectionInfo.address
   );
   await nft3Collection.setBaseURI("ipfs://bafybeie7oivvuqcmhjzvxbiezyz7sr4fxkcrutewmaoathfsvcwksqiyuy/");

   // NFT4
   const nft4CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT4 Name", "NFT4"],
     log: true,
     autoMine: true
   });
   const nft4Collection = await ethers.getContractAt(
     nft4CollectionInfo.abi,
     nft4CollectionInfo.address
   );
   await nft4Collection.setBaseURI("https://cdn.childrenofukiyo.com/metadata/");

   // NFT5
   const nft5CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT5 Name", "NFT5"],
     log: true,
     autoMine: true
   });
   const nft5Collection = await ethers.getContractAt(
     nft5CollectionInfo.abi,
     nft5CollectionInfo.address
   );
   await nft5Collection.setBaseURI("https://chainbase-api.matrixlabs.org/metadata/api/v1/apps/ethereum:mainnet:bKPQsA_Ohnj1Ug0MvX39i/contracts/0x249aeAa7fA06a63Ea5389b72217476db881294df_ethereum/metadata/tokens/");

   // NFT6
   const nft6CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT6 Name", "NFT6"],
     log: true,
     autoMine: true
   });
   const nft6Collection = await ethers.getContractAt(
     nft6CollectionInfo.abi,
     nft6CollectionInfo.address
   );
   await nft6Collection.setBaseURI("https://us-central1-catblox-1f4e5.cloudfunctions.net/api/tbt-prereveal/1");

   // NFT7
   const nft7CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT7 Name", "NFT7"],
     log: true,
     autoMine: true
   });
   const nft7Collection = await ethers.getContractAt(
     nft7CollectionInfo.abi,
     nft7CollectionInfo.address
   );
   await nft7Collection.setBaseURI("https://loremnft.com/nft/token/");

   // NFT8
   const nft8CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT8 Name", "NFT8"],
     log: true,
     autoMine: true
   });
   const nft8Collection = await ethers.getContractAt(
     nft8CollectionInfo.abi,
     nft8CollectionInfo.address
   );
   await nft8Collection.setBaseURI("ipfs://QmQNdnPx1K6a8jd5XJEJvGorx73U9pmpqU2YAhEfQZDwcw/");

   // NFT9
   const nft9CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT9 Name", "NFT9"],
     log: true,
     autoMine: true
   });
   const nft9Collection = await ethers.getContractAt(
     nft9CollectionInfo.abi,
     nft9CollectionInfo.address
   );
   await nft9Collection.setBaseURI("ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/");

   // NFT10
   const nft10CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT10 Name", "NFT10"],
     log: true,
     autoMine: true
   });
   const nft10Collection = await ethers.getContractAt(
     nft10CollectionInfo.abi,
     nft10CollectionInfo.address
   );
   await nft10Collection.setBaseURI("https://metadata.buildship.xyz/api/dummy-metadata-for/bafybeifuibkffbtlu4ttpb6c3tiyhezxoarxop5nuhr3ht3mdb7puumr2q/");

   // NFT11
   const nft11CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT11 Name", "NFT11"],
     log: true,
     autoMine: true
   });
   const nft11Collection = await ethers.getContractAt(
     nft11CollectionInfo.abi,
     nft11CollectionInfo.address
   );
   await nft11Collection.setBaseURI("http://api.cyberfist.xyz/badges/metadata/");

   // NFT12
   const nft12CollectionInfo = await deploy('StandardMockNFT', {
     from: deployer,
     args: ["NFT12 Name", "NFT12"],
     log: true,
     autoMine: true
   });
   const nft12Collection = await ethers.getContractAt(
     nft12CollectionInfo.abi,
     nft12CollectionInfo.address
   );
   await nft12Collection.setBaseURI("https://gateway.pinata.cloud/ipfs/Qmdp8uFBrWq3CJmNHviq4QLZzbw5BchA7Xi99xTxuxoQjY/");

   // mint
   for (let i = 0; i < 5; i++) {
    await nft1Collection.mint(deployer, i);
    await nft2Collection.mint(deployer, i);
    await nft3Collection.mint(deployer, i);
    await nft4Collection.mint(deployer, i);
    await nft5Collection.mint(deployer, i);
    await nft6Collection.mint(deployer, i);
    await nft7Collection.mint(deployer, i);
    await nft8Collection.mint(deployer, i);
    await nft9Collection.mint(deployer, i);
    await nft10Collection.mint(deployer, i);
    await nft11Collection.mint(deployer, i);
    await nft12Collection.mint(deployer, i);
   }

   //mint 50 for 7
   for (let i = 5; i < 50; i++) {
    await nft7Collection.mint(deployer, i);
   }

   // fractionalize nfts
   const FNFTCollectionFactory = await getContract(hre, "FNFTCollectionFactory");

   // approve factory
   await nft1Collection.approve(FNFTCollectionFactory.address, 1);
   await nft2Collection.approve(FNFTCollectionFactory.address, 2);
   await nft3Collection.approve(FNFTCollectionFactory.address, 3);
   await nft4Collection.approve(FNFTCollectionFactory.address, 4);
   await nft5Collection.approve(FNFTCollectionFactory.address, 5);
   await nft6Collection.approve(FNFTCollectionFactory.address, 6);
   await nft7Collection.approve(FNFTCollectionFactory.address, 7);
   await nft8Collection.approve(FNFTCollectionFactory.address, 8);
   await nft9Collection.approve(FNFTCollectionFactory.address, 9);
   await nft10Collection.approve(FNFTCollectionFactory.address, 10);
   await nft11Collection.approve(FNFTCollectionFactory.address, 11);
   await nft12Collection.approve(FNFTCollectionFactory.address, 12);

   // NFT1
   const fnftCollection1Receipt = await FNFTCollectionFactory.createVault(
    nft1CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 1", // name
    "FNFTC1" // symbol
   );

   // NFT1
   const fnftCollection2Receipt = await FNFTCollectionFactory.createVault(
    nft2CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 2", // name
    "FNFTC2" // symbol
   );

   // NFT1
   const fnftCollection3Receipt = await FNFTCollectionFactory.createVault(
    nft3CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 3", // name
    "FNFTC3" // symbol
   );

   // NFT1
   const fnftCollection4Receipt = await FNFTCollectionFactory.createVault(
    nft4CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 4", // name
    "FNFTC4" // symbol
   );

   // NFT1
   const fnftCollection5Receipt = await FNFTCollectionFactory.createVault(
    nft5CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 5", // name
    "FNFTC5" // symbol
   );

   // NFT1
   const fnftCollection6Receipt = await FNFTCollectionFactory.createVault(
    nft6CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 6", // name
    "FNFTC6" // symbol
   );

   // NFT1
   const fnftCollection7Receipt = await FNFTCollectionFactory.createVault(
    nft7CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 7", // name
    "FNFTC7" // symbol
   );

   // NFT1
   const fnftCollection8Receipt = await FNFTCollectionFactory.createVault(
    nft8CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 8", // name
    "FNFTC8" // symbol
   );

   // NFT1
   const fnftCollection9Receipt = await FNFTCollectionFactory.createVault(
    nft9CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 9", // name
    "FNFTC9" // symbol
   );

   // NFT1
   const fnftCollection10Receipt = await FNFTCollectionFactory.createVault(
    nft10CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 10", // name
    "FNFTC10" // symbol
   );

   // NFT1
   const fnftCollection11Receipt = await FNFTCollectionFactory.createVault(
    nft11CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 11", // name
    "FNFTC11" // symbol
   );

   // NFT1
   const fnftCollection12Receipt = await FNFTCollectionFactory.createVault(
    nft12CollectionInfo.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 12", // name
    "FNFTC12" // symbol
   );




   // IFOFactory
   const IFOFactory = await getContract(hre, 'IFOFactory');

   const fnftCollection2Address = await getFNFTCollectionAddress(fnftCollection2Receipt);
   const fnftCollection3Address = await getFNFTCollectionAddress(fnftCollection3Receipt);
   const fnftCollection4Address = await getFNFTCollectionAddress(fnftCollection4Receipt);
   const fnftCollection5Address = await getFNFTCollectionAddress(fnftCollection5Receipt);
   const fnftCollection6Address = await getFNFTCollectionAddress(fnftCollection6Receipt);
   const fnftCollection7Address = await getFNFTCollectionAddress(fnftCollection7Receipt);
   const fnftCollection8Address = await getFNFTCollectionAddress(fnftCollection8Receipt);
   const fnftCollection9Address = await getFNFTCollectionAddress(fnftCollection9Receipt);
   const fnftCollection10Address = await getFNFTCollectionAddress(fnftCollection10Receipt);
   const fnftCollection11Address = await getFNFTCollectionAddress(fnftCollection11Receipt);
   const fnftCollection12Address = await getFNFTCollectionAddress(fnftCollection12Receipt);

   const fnftCollection2 = await ethers.getContractAt('FNFTCollection', fnftCollection2Address);
   const fnftCollection3 = await ethers.getContractAt('FNFTCollection', fnftCollection3Address);
   const fnftCollection4 = await ethers.getContractAt('FNFTCollection', fnftCollection4Address);
   const fnftCollection5 = await ethers.getContractAt('FNFTCollection', fnftCollection5Address);
   const fnftCollection6 = await ethers.getContractAt('FNFTCollection', fnftCollection6Address);
   const fnftCollection7 = await ethers.getContractAt('FNFTCollection', fnftCollection7Address);
   const fnftCollection8 = await ethers.getContractAt('FNFTCollection', fnftCollection8Address);
   const fnftCollection9 = await ethers.getContractAt('FNFTCollection', fnftCollection9Address);
   const fnftCollection10 = await ethers.getContractAt('FNFTCollection', fnftCollection10Address);
   const fnftCollection11 = await ethers.getContractAt('FNFTCollection', fnftCollection11Address);
   const fnftCollection12 = await ethers.getContractAt('FNFTCollection', fnftCollection12Address);

   await fnftCollection2.approve(IFOFactory.address, await fnftCollection2.balanceOf(deployer));
   await fnftCollection3.approve(IFOFactory.address, await fnftCollection3.balanceOf(deployer));
   await fnftCollection4.approve(IFOFactory.address, await fnftCollection4.balanceOf(deployer));
   await fnftCollection5.approve(IFOFactory.address, await fnftCollection5.balanceOf(deployer));
   await fnftCollection6.approve(IFOFactory.address, await fnftCollection6.balanceOf(deployer));
   await fnftCollection7.approve(IFOFactory.address, await fnftCollection7.balanceOf(deployer));
   await fnftCollection8.approve(IFOFactory.address, await fnftCollection8.balanceOf(deployer));
   await fnftCollection9.approve(IFOFactory.address, await fnftCollection9.balanceOf(deployer));
   await fnftCollection10.approve(IFOFactory.address, await fnftCollection10.balanceOf(deployer));
   await fnftCollection11.approve(IFOFactory.address, await fnftCollection11.balanceOf(deployer));
   await fnftCollection12.approve(IFOFactory.address, await fnftCollection12.balanceOf(deployer));
 };

 async function getFNFTCollectionAddress(transactionReceipt: any) {

 }

 async function getIFOAddress(transactionReceipt: any) {
   const abi = ["event IFOCreated(address indexed ifo, address indexed fnft, uint256 amountForSale, uint256 price, uint256 cap, uint256 duration, bool allowWhitelisting);"];
   const _interface = new ethers.utils.Interface(abi);
   const topic = "0x1bb72b46985d7a3abad1d345d856e8576c1d4842b34a5373f3533a4c72970352";
   const receipt = await transactionReceipt.wait();
   const event = receipt.logs.find((log: any) => log.topics[0] === topic);
   return _interface.parseLog(event).args[0];
 }

 async function mineNBlocks(n:number) {
   for (let index = 0; index < n; index++) {
     await ethers.provider.send('evm_mine', []);
   }
 }

 async function increaseBlockTimestamp(seconds:number) {
   await ethers.provider.send("evm_increaseTime", [seconds]);
   await ethers.provider.send("evm_mine", []);
 }

 async function getContract(hre:HardhatRuntimeEnvironment, key:string) {
   const {deployments, getNamedAccounts} = hre;
   const {get} = deployments;
   const {deployer} = await getNamedAccounts();
   const signer = await ethers.getSigner(deployer);

   const proxyControllerInfo = await get('MultiProxyController');
   const proxyController = new ethers.Contract(
     proxyControllerInfo.address,
     proxyControllerInfo.abi,
     signer
   );
   const abi = (await get(key)).abi; // get abi of impl contract
   const address = (await proxyController.proxyMap(
     ethers.utils.formatBytes32String(key)
   ))[1];
   return new ethers.Contract(address, abi, signer);
 }

 func.tags = ['seed'];
 export default func;
