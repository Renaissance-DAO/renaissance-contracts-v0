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
  const txSetBaseURI1 = await nft1.setBaseURI("ipfs://QmVTuf8VqSjJ6ma6ykTJiuVtvAY9CHJiJnXsgSMf5rBRtZ/");
  await txSetBaseURI1.wait();

  // NFT2
  const nft2Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT2 Name", "NFT2"],
    log: true,
    autoMine: true,
  });
  const nft2 = await ethers.getContractAt(nft2Info.abi, nft2Info.address);
  const txSetBaseURI2 = await nft2.setBaseURI("https://www.timelinetransit.xyz/metadata/");
  await txSetBaseURI2.wait();

  // NFT3
  const nft3Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT3 Name", "NFT3"],
    log: true,
    autoMine: true,
  });
  const nft3 = await ethers.getContractAt(nft3Info.abi, nft3Info.address);
  const txSetBaseURI3 = await nft3.setBaseURI("ipfs://bafybeie7oivvuqcmhjzvxbiezyz7sr4fxkcrutewmaoathfsvcwksqiyuy/");
  await txSetBaseURI3.wait();

  for (let i = 1; i <= 5; i++) {
    // approve factory
    const txMint1 = await nft1.mint(deployer, i);
    await txMint1.wait();
    const txMint2 = await nft2.mint(deployer, i);
    await txMint2.wait();
    const txMint3 = await nft3.mint(deployer, i);
    await txMint3.wait();
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
  await fnftCollection1Receipt.wait();

  // NFT2
  const fnftCollection2Receipt = await FNFTCollectionFactory.createVault(
    nft2Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 2", // name
    "FNFTC2" // symbol
  );
  await fnftCollection2Receipt.wait();

  // NFT3
  const fnftCollection3Receipt = await FNFTCollectionFactory.createVault(
    nft3Info.address, // collection address
    false, // is1155
    true, // allowAllItems
    "FNFT Collection 3", // name
    "FNFTC3" // symbol
  );
  await fnftCollection3Receipt.wait();

  const fnftCollection1Address = await getFNFTCollectionAddress(fnftCollection1Receipt);
  console.log("Collection1Address: ", fnftCollection1Address);
  const fnftCollection2Address = await getFNFTCollectionAddress(fnftCollection2Receipt);
  console.log("Collection2Address: ", fnftCollection2Address);
  const fnftCollection3Address = await getFNFTCollectionAddress(fnftCollection3Receipt);
  console.log("Collection3Address: ", fnftCollection3Address);

  const fnftCollection1 = await ethers.getContractAt("FNFTCollection", fnftCollection1Address);
  const fnftCollection2 = await ethers.getContractAt("FNFTCollection", fnftCollection2Address);
  const fnftCollection3 = await ethers.getContractAt("FNFTCollection", fnftCollection3Address);

  const txSetApprovalForAll1 = await nft1.setApprovalForAll(fnftCollection1.address, true);
  await txSetApprovalForAll1.wait();
  const txSetApprovalForAll2 = await nft2.setApprovalForAll(fnftCollection2.address, true);
  await txSetApprovalForAll2.wait();
  const txSetApprovalForAll3 = await nft3.setApprovalForAll(fnftCollection3.address, true);
  await txSetApprovalForAll3.wait();

  const txMintTo1 = await fnftCollection1.mintTo([1, 2, 3, 4, 5], [], deployer);
  await txMintTo1.wait();
  const txMintTo2 = await fnftCollection2.mintTo([1], [], deployer);
  await txMintTo2.wait();
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
