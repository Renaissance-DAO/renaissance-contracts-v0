import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumber, parseFixed } from "@ethersproject/bignumber";
import { ethers } from "hardhat";

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
 * 8.  NFT8 => FNFTCollection with 5 items, where 2 have been minted to a chosen (user) address
 * 9.  NFT9 => FNFTCollection that is undergoing IFO but not started
 * 10.  NFT10 => FNFTCollection that is undergoing IFO and has started with a few sales here and there
 * 11.  NFT11 => FNFTCollection that is undergoing IFO and is paused with a few sales here and there
 * 12.  NFT12 => FNFTCollection that has finished IFO with a few sales here and there
 */

const PERCENTAGE_SCALE = 10000; // for converting percentages to fixed point

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, ethers } = hre;
  const { deploy } = hre.deployments;
  const { deployer } = await getNamedAccounts();

  // NFT1
  const nft1Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT1 Name", "NFT1"],
    log: true,
    autoMine: true,
  });
  const nft1 = await ethers.getContractAt(nft1Info.abi, nft1Info.address);
  await nft1.setBaseURI("ipfs://QmVTuf8VqSjJ6ma6ykTJiuVtvAY9CHJiJnXsgSMf5rBRtZ/");

  // NFT2
  const nft2Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT2 Name", "NFT2"],
    log: true,
    autoMine: true,
  });
  const nft2 = await ethers.getContractAt(nft2Info.abi, nft2Info.address);
  await nft2.setBaseURI("https://www.timelinetransit.xyz/metadata/");

  // NFT3
  const nft3Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT3 Name", "NFT3"],
    log: true,
    autoMine: true,
  });
  const nft3 = await ethers.getContractAt(nft3Info.abi, nft3Info.address);
  await nft3.setBaseURI("ipfs://bafybeie7oivvuqcmhjzvxbiezyz7sr4fxkcrutewmaoathfsvcwksqiyuy/");

  // NFT4
  const nft4Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT4 Name", "NFT4"],
    log: true,
    autoMine: true,
  });
  const nft4 = await ethers.getContractAt(nft4Info.abi, nft4Info.address);
  await nft4.setBaseURI("https://cdn.childrenofukiyo.com/metadata/");

  // NFT5
  const nft5Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT5 Name", "NFT5"],
    log: true,
    autoMine: true,
  });
  const nft5 = await ethers.getContractAt(nft5Info.abi, nft5Info.address);
  await nft5.setBaseURI(
    "https://chainbase-api.matrixlabs.org/metadata/api/v1/apps/ethereum:mainnet:bKPQsA_Ohnj1Ug0MvX39i/contracts/0x249aeAa7fA06a63Ea5389b72217476db881294df_ethereum/metadata/tokens/"
  );

  // NFT6 (No TokenURI)
  const nft6Info = await deploy("NoURIMockNFT", {
    from: deployer,
    args: ["NFT6 Name", "NFT6"],
    log: true,
    autoMine: true,
  });
  const nft6 = await ethers.getContractAt(nft6Info.abi, nft6Info.address);

  // NFT7
  const nft7Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT7 Name", "NFT7"],
    log: true,
    autoMine: true,
  });
  const nft7 = await ethers.getContractAt(nft7Info.abi, nft7Info.address);
  await nft7.setBaseURI("https://loremnft.com/nft/token/");

  // NFT8
  const nft8Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT8 Name", "NFT8"],
    log: true,
    autoMine: true,
  });
  const nft8 = await ethers.getContractAt(nft8Info.abi, nft8Info.address);
  await nft8.setBaseURI("ipfs://QmQNdnPx1K6a8jd5XJEJvGorx73U9pmpqU2YAhEfQZDwcw/");

  // NFT9
  const nft9Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT9 Name", "NFT9"],
    log: true,
    autoMine: true,
  });
  const nft9 = await ethers.getContractAt(nft9Info.abi, nft9Info.address);
  await nft9.setBaseURI("ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/");

  // NFT10
  const nft10Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT10 Name", "NFT10"],
    log: true,
    autoMine: true,
  });
  const nft10 = await ethers.getContractAt(nft10Info.abi, nft10Info.address);
  await nft10.setBaseURI(
    "https://metadata.buildship.xyz/api/dummy-metadata-for/bafybeifuibkffbtlu4ttpb6c3tiyhezxoarxop5nuhr3ht3mdb7puumr2q/"
  );

  // NFT11
  const nft11Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT11 Name", "NFT11"],
    log: true,
    autoMine: true,
  });
  const nft11 = await ethers.getContractAt(nft11Info.abi, nft11Info.address);
  await nft11.setBaseURI("http://api.cyberfist.xyz/badges/metadata/");

  // NFT12
  const nft12Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT12 Name", "NFT12"],
    log: true,
    autoMine: true,
  });
  const nft12 = await ethers.getContractAt(nft12Info.abi, nft12Info.address);
  await nft12.setBaseURI(
    "https://gateway.pinata.cloud/ipfs/Qmdp8uFBrWq3CJmNHviq4QLZzbw5BchA7Xi99xTxuxoQjY/"
  );

  for (let i = 1; i <= 5; i++) {
    // approve factory
    await nft1.mint(deployer, i);
    await nft2.mint(deployer, i);
    await nft3.mint(deployer, i);
    await nft4.mint(deployer, i);
    await nft5.mint(deployer, i);
    await nft6.mint(deployer, i);
    await nft7.mint(deployer, i);
    await nft8.mint(deployer, i);
    await nft9.mint(deployer, i);
    await nft10.mint(deployer, i);
    await nft11.mint(deployer, i);
    await nft12.mint(deployer, i);
  }

  for (let i = 6; i <= 50; i++) {
    await nft7.mint(deployer, i);
  }

  // fractionalize nfts
  const FNFTCollectionFactory = await getContract(hre, "FNFTCollectionFactory");

  // NFT1
  const fnftCollection1Receipt = await FNFTCollectionFactory.createVault(
    nft1Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 1", // name
    "FNFTC1" // symbol
  );

  // NFT2
  const fnftCollection2Receipt = await FNFTCollectionFactory.createVault(
    nft2Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 2", // name
    "FNFTC2" // symbol
  );

  // NFT3
  const fnftCollection3Receipt = await FNFTCollectionFactory.createVault(
    nft3Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 3", // name
    "FNFTC3" // symbol
  );

  // NFT4
  const fnftCollection4Receipt = await FNFTCollectionFactory.createVault(
    nft4Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 4", // name
    "FNFTC4" // symbol
  );

  // NFT5
  const fnftCollection5Receipt = await FNFTCollectionFactory.createVault(
    nft5Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 5", // name
    "FNFTC5" // symbol
  );

  // NFT6
  const fnftCollection6Receipt = await FNFTCollectionFactory.createVault(
    nft6Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 6", // name
    "FNFTC6" // symbol
  );

  // NFT7
  const fnftCollection7Receipt = await FNFTCollectionFactory.createVault(
    nft7Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 7", // name
    "FNFTC7" // symbol
  );

  // NFT8
  const fnftCollection8Receipt = await FNFTCollectionFactory.createVault(
    nft8Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 8", // name
    "FNFTC8" // symbol
  );

  // NFT9
  const fnftCollection9Receipt = await FNFTCollectionFactory.createVault(
    nft9Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 9", // name
    "FNFTC9" // symbol
  );

  // NFT10
  const fnftCollection10Receipt = await FNFTCollectionFactory.createVault(
    nft10Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 10", // name
    "FNFTC10" // symbol
  );

  // NFT11
  const fnftCollection11Receipt = await FNFTCollectionFactory.createVault(
    nft11Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 11", // name
    "FNFTC11" // symbol
  );

  // NFT12
  const fnftCollection12Receipt = await FNFTCollectionFactory.createVault(
    nft12Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 12", // name
    "FNFTC12" // symbol
  );

  const fnftCollection1Address = await getFNFTCollectionAddress(fnftCollection1Receipt);
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

  const fnftCollection1 = await ethers.getContractAt("FNFTCollection", fnftCollection1Address);
  const fnftCollection2 = await ethers.getContractAt("FNFTCollection", fnftCollection2Address);
  const fnftCollection3 = await ethers.getContractAt("FNFTCollection", fnftCollection3Address);
  const fnftCollection4 = await ethers.getContractAt("FNFTCollection", fnftCollection4Address);
  const fnftCollection5 = await ethers.getContractAt("FNFTCollection", fnftCollection5Address);
  const fnftCollection6 = await ethers.getContractAt("FNFTCollection", fnftCollection6Address);
  const fnftCollection7 = await ethers.getContractAt("FNFTCollection", fnftCollection7Address);
  const fnftCollection8 = await ethers.getContractAt("FNFTCollection", fnftCollection8Address);
  const fnftCollection9 = await ethers.getContractAt("FNFTCollection", fnftCollection9Address);
  const fnftCollection10 = await ethers.getContractAt("FNFTCollection", fnftCollection10Address);
  const fnftCollection11 = await ethers.getContractAt("FNFTCollection", fnftCollection11Address);
  const fnftCollection12 = await ethers.getContractAt("FNFTCollection", fnftCollection12Address);

  await nft1.setApprovalForAll(fnftCollection1.address, true);
  await nft2.setApprovalForAll(fnftCollection2.address, true);
  await nft3.setApprovalForAll(fnftCollection3.address, true);
  await nft4.setApprovalForAll(fnftCollection4.address, true);
  await nft5.setApprovalForAll(fnftCollection5.address, true);
  await nft6.setApprovalForAll(fnftCollection6.address, true);
  await nft7.setApprovalForAll(fnftCollection7.address, true);
  await nft8.setApprovalForAll(fnftCollection8.address, true);
  await nft9.setApprovalForAll(fnftCollection9.address, true);
  await nft10.setApprovalForAll(fnftCollection10.address, true);
  await nft11.setApprovalForAll(fnftCollection11.address, true);
  await nft12.setApprovalForAll(fnftCollection12.address, true);

  await fnftCollection1.mintTo([1, 2, 3, 4, 5], [], deployer);
  await fnftCollection2.mintTo([1], [], deployer);
  //skip fnft 3 mint
  await fnftCollection4.mintTo([1, 2, 3, 4, 5], [], deployer); // bid 3
  await fnftCollection5.mintTo([1, 2, 3, 4, 5], [], deployer); // bid 2 and redeem 2
  await fnftCollection6.mintTo([1, 2, 3, 4, 5], [], deployer); // no tokenURI
  await fnftCollection7.mintTo(
    Array.from({ length: 50 }, (_, i) => i + 1),
    [],
    deployer
  ); // mint 50
  await fnftCollection8.mintTo([1, 2, 3], [], deployer); // 3 mint to deployer
  await fnftCollection8.mintTo([4, 5], [], deployer); // 2 mint to chosen (change address)
  await fnftCollection9.mintTo([1, 2, 3, 4, 5], [], deployer); // ifo not started
  await fnftCollection10.mintTo([1, 2, 3, 4, 5], [], deployer); // ifo ongoing
  await fnftCollection11.mintTo([1, 2, 3, 4, 5], [], deployer); // ifo paused
  await fnftCollection12.mintTo([1, 2, 3, 4, 5], [], deployer); // ifo finished

  // IFO

  // IFOFactory
  const ifoFactory = await getContract(hre, "IFOFactory");

  await fnftCollection9.approve(ifoFactory.address, await fnftCollection9.balanceOf(deployer));
  await fnftCollection10.approve(ifoFactory.address, await fnftCollection10.balanceOf(deployer));
  await fnftCollection11.approve(ifoFactory.address, await fnftCollection11.balanceOf(deployer));
  await fnftCollection12.approve(ifoFactory.address, await fnftCollection12.balanceOf(deployer));

  // NFT9 IFO
  await ifoFactory.create(
    fnftCollection9Address, // fNft
    await fnftCollection9.balanceOf(deployer), // amount for sale
    parseFixed("1", 18), // price
    await fnftCollection9.balanceOf(deployer), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT10 IFO
  const IFO10Receipt = await ifoFactory.create(
    fnftCollection10Address, // fNft
    await fnftCollection10.balanceOf(deployer), // amount for sale
    parseFixed("1", 18), // price
    await fnftCollection10.balanceOf(deployer), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT11 IFO
  const IFO11Receipt = await ifoFactory.create(
    fnftCollection11Address, // fNft
    await fnftCollection11.balanceOf(deployer), // amount for sale
    parseFixed("1", 18), // price
    await fnftCollection11.balanceOf(deployer), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT12 IFO
  const IFO12Receipt = await ifoFactory.create(
    fnftCollection12Address, // fNft
    await fnftCollection12.balanceOf(deployer), // amount for sale
    parseFixed("1", 18), // price
    await fnftCollection12.balanceOf(deployer), // cap
    86400, // short duration for purposes of testing
    false // allow whitelisting
  );

  const IFO10Address = await getIFOAddress(IFO10Receipt);
  const IFO11Address = await getIFOAddress(IFO11Receipt);
  const IFO12Address = await getIFOAddress(IFO12Receipt);

  // start IFOs
  const IFO10 = await ethers.getContractAt("IFO", IFO10Address);
  const IFO11 = await ethers.getContractAt("IFO", IFO11Address);
  const IFO12 = await ethers.getContractAt("IFO", IFO12Address);

  // IFO9 skipped
  await IFO10.start();
  await IFO11.start();
  await IFO12.start();

  const signers = await ethers.getSigners();

  // SIMULATE RANDOM IFO SALE

  // NFT10
  const ifo10Price = BigNumber.from(await IFO10.price()).div(10);
  await Promise.all(
    signers.map(async (signer) => {
      await IFO10.connect(signer).deposit({ value: ifo10Price });
    })
  );

  // NFT11
  const ifo11Price = BigNumber.from(await IFO11.price()).div(10);
  await Promise.all(
    signers.slice(9, 19).map(async (signer) => {
      // console.log("2: ", await signer.getBalance(), ifo11Price);
      await IFO11.connect(signer).deposit({ value: ifo11Price });
    })
  );

  // NFT12
  const ifo12Price = BigNumber.from(await IFO12.price()).div(10);
  await Promise.all(
    signers.slice(0, 9).map(async (signer) => {
      // console.log("3: ", await signer.getBalance(), ifo10Price);
      await IFO12.connect(signer).deposit({ value: ifo12Price });
    })
  );

  // mine here to allow sales time to finish and also to allow IFO5 duration to complete
  console.log("starting to mine... (this takes a few minutes)");
  await mineNBlocks(86400); // this takes a few min unfortunately
  console.log("completed mining");

  // Pause IFO, NFT11 sceanrio ends here
  await IFO11.togglePause();

  // END IFO, NFT12 sceanrio ends here
  await IFO12.end();
};

async function getFNFTCollectionAddress(transactionReceipt: any) {
  const abi = [
    "event VaultCreated(uint256 indexed vaultId, address curator, address vaultAddress, address assetAddress, string name, string symbol);",
  ];
  const _interface = new ethers.utils.Interface(abi);
  const topic = "0x7ba4daf113dab617fb46d5bf414c46f4e17aa717bce3c75bacbad12baef0233c";
  const receipt = await transactionReceipt.wait();
  const event = receipt.logs.find((log: any) => log.topics[0] === topic);
  return _interface.parseLog(event).args[2];
}

async function getIFOAddress(transactionReceipt: any) {
  const abi = [
    "event IFOCreated(address indexed ifo, address indexed fnft, uint256 amountForSale, uint256 price, uint256 cap, uint256 duration, bool allowWhitelisting);",
  ];
  const _interface = new ethers.utils.Interface(abi);
  const topic = "0x1bb72b46985d7a3abad1d345d856e8576c1d4842b34a5373f3533a4c72970352";
  const receipt = await transactionReceipt.wait();
  const event = receipt.logs.find((log: any) => log.topics[0] === topic);
  return _interface.parseLog(event).args[0];
}

async function mineNBlocks(n: number) {
  for (let index = 0; index < n; index++) {
    await ethers.provider.send("evm_mine", []);
  }
}

async function getContract(hre: HardhatRuntimeEnvironment, key: string) {
  const { deployments, getNamedAccounts } = hre;
  const { get } = deployments;
  const { deployer } = await getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const proxyControllerInfo = await get("MultiProxyController");
  const proxyController = new ethers.Contract(
    proxyControllerInfo.address,
    proxyControllerInfo.abi,
    signer
  );
  const abi = (await get(key)).abi; // get abi of impl contract
  const address = (await proxyController.proxyMap(ethers.utils.formatBytes32String(key)))[1];
  return new ethers.Contract(address, abi, signer);
}

func.tags = ["seed"];
export default func;
