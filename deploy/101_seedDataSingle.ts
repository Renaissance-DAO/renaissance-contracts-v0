import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumber, parseFixed } from "@ethersproject/bignumber";
import { ethers } from "hardhat";

/**
 *
 * SCENARIOS
 * 1.  NFT1 => FNFTSingle1 that is just created
 * 2.  NFT2 => FNFTSingle2 that is undergoing IFO but not started
 * 3.  NFT3 => FNFTSingle3 that is undergoing IFO and has started with a few sales here and there
 * 4.  NFT4 => FNFTSingle4 that is undergoing IFO and is paused with a few sales here and there
 * 5.  NFT5 => FNFTSingle5 that has finished IFO with a few sales here and there
 * 6.  NFT6 => FNFTSingle6 that has averageReserve voted that doesn’t meet quorum
 * 7.  NFT7 => FNFTSingle7 that has averageReserve that meets quorum
 * 8.  NFT8 => FNFTSingle8 that has completed an auction w/ a few bids
 * 9.  NFT9 => FNFTSingle9 that has a triggered start bid
 * 10. NFT10 => FNFTSingle10 that is undergoing a bid war
 * 11. NFT11 => FNFTSingle11 that is redeemed
 * 12: NFT12 => FNFTSingle12 that is cashed out by a few people
 * 13. NFT13 => FNFTSingle13 that has a liquidity pool above threshold // TODO
 * 14. NFT14 => FNFTSingle14 that doesn't have tokenURI // TODO
 */

// Test images used
//  1
//  0x0453435725ccb8AaA1AB52474Dcb12aEf220679E
//  ipfs://QmVTuf8VqSjJ6ma6ykTJiuVtvAY9CHJiJnXsgSMf5rBRtZ/1

//  2
//  0xECCAE88FF31e9f823f25bEb404cbF2110e81F1FA
//  https://www.timelinetransit.xyz/metadata/1

//  3
//  0xdcAF23e44639dAF29f6532da213999D737F15aa4
//  ipfs://bafybeie7oivvuqcmhjzvxbiezyz7sr4fxkcrutewmaoathfsvcwksqiyuy/1

//  4
//  0x3b3C2daCfDD7b620C8916A5f7Aa6476bdFb1aa07
//  https://cdn.childrenofukiyo.com/metadata/1

//  5
//  0x249aeAa7fA06a63Ea5389b72217476db881294df
//  https://chainbase-api.matrixlabs.org/metadata/api/v1/apps/ethereum:mainnet:bKPQsA_Ohnj1Ug0MvX39i/contracts/0x249aeAa7fA06a63Ea5389b72217476db881294df_ethereum/metadata/tokens/1

//  6
//  0xEA2652EC4e36547d58dC4E58DaB00Acb11b351Ee
//  https://us-central1-catblox-1f4e5.cloudfunctions.net/api/tbt-prereveal/1

//  7
//  0x6E3B47A8697Bc62be030827f4927A50Eb3a93d2A
//  https://loremnft.com/nft/token/1

//  8
//  0x32dD588f23a95280134107A22C064cEA065327E9
//  ipfs://QmQNdnPx1K6a8jd5XJEJvGorx73U9pmpqU2YAhEfQZDwcw/1

//  9
//  0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D
//  ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/1

//  10
//  0xB6C035ebc715d2E14946B03D49709140b86f1A75
//  https://metadata.buildship.xyz/api/dummy-metadata-for/bafybeifuibkffbtlu4ttpb6c3tiyhezxoarxop5nuhr3ht3mdb7puumr2q/1

//  11
//  0x866ebb7d3Dc493ac0994719D4481341A3a678B0c
//  http://api.cyberfist.xyz/badges/metadata/1

//  12
//  0x9294b5Bce53C444eb78B7BD9532D809e9b9cD123
//  https://gateway.pinata.cloud/ipfs/Qmdp8uFBrWq3CJmNHviq4QLZzbw5BchA7Xi99xTxuxoQjY/1

//  13
//  0x9984bD85adFEF02Cea2C28819aF81A6D17a3Cb96
//  https://static-resource.dirtyflies.xyz/metadata/1

//  14
//  0x69BE8755FEd63C0A7BE139b96e929cF7Ff63897D
//  ipfs://QmRd7BKD3ubYEGck6UESEfL2PJkzLr2oZhGyAC2dz8e8FB/1

//  15
//  0x7401aaeF871046583Ef3C97FCaCD4749dEB88448
//  ipfs://QmV97nkwJuyv6axWRE54HWvWFYzq2XUaUa63RqM1mQpSTT/?2

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
  const nft1 = await ethers.getContractAt(
    nft1Info.abi,
    nft1Info.address
  );
  const txSetBaseURI1 = await nft1.setBaseURI("ipfs://QmVTuf8VqSjJ6ma6ykTJiuVtvAY9CHJiJnXsgSMf5rBRtZ/");
  await txSetBaseURI1.wait();

  // NFT2
  const nft2Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT2 Name", "NFT2"],
    log: true,
    autoMine: true,
  });
  const nft2 = await ethers.getContractAt(
    nft2Info.abi,
    nft2Info.address
  );
  const txSetBaseURI2 = await nft2.setBaseURI("https://www.timelinetransit.xyz/metadata/");
  await txSetBaseURI2.wait();

  // NFT3
  const nft3Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT3 Name", "NFT3"],
    log: true,
    autoMine: true,
  });
  const nft3 = await ethers.getContractAt(
    nft3Info.abi,
    nft3Info.address
  );
  const txSetBaseURI3 = await nft3.setBaseURI(
    "ipfs://bafybeie7oivvuqcmhjzvxbiezyz7sr4fxkcrutewmaoathfsvcwksqiyuy/"
  );
  await txSetBaseURI3.wait();

  // mint
  const txMint1 = await nft1.mint(deployer, 1);
  await txMint1.wait();
  const txMint2 = await nft2.mint(deployer, 2);
  await txMint2.wait();
  const txMint3 = await nft3.mint(deployer, 3);
  await txMint3.wait();

  // fractionalize nfts
  const FNFTSingleFactory = await getContract(hre, "FNFTSingleFactory");

  // approve factory
  const txApprove1 = await nft1.approve(FNFTSingleFactory.address, 1);
  await txApprove1.wait();
  const txApprove2 = await nft2.approve(FNFTSingleFactory.address, 2);
  await txApprove2.wait();
  const txApprove3 = await nft3.approve(FNFTSingleFactory.address, 3);
  await txApprove3.wait();

  // NFT1 - scenario is done here
  const fnftSingle1Receipt = await FNFTSingleFactory.createVault(
    nft1Info.address, // collection address
    1, // tokenId
    parseFixed("10000", 18), // supply
    parseFixed("100", 18), // initialPrice === 1e18
    0.01 * PERCENTAGE_SCALE, // fee (1%)
    "FNFT Single 1", // name
    "FNFTSingle1" // symbol
  );
  await fnftSingle1Receipt.wait();

  // NFT2
  const fnftSingle2Receipt = await FNFTSingleFactory.createVault(
    nft2Info.address, // collection address
    2, // tokenId
    parseFixed("1000", 18), // supply
    parseFixed("10000", 18), // initialPrice === 2e18
    0.1 * PERCENTAGE_SCALE, // fee (10%)
    "FNFT Single 2", // name
    "FNFTSingle2" // symbol
  );
  await fnftSingle2Receipt.wait();

  // NFT3
  const fnftSingle3Receipt = await FNFTSingleFactory.createVault(
    nft3Info.address, // collection address
    3, // tokenId
    parseFixed("100", 18), // supply
    parseFixed("1000", 18), // initialPrice == 2e18
    0.03 * PERCENTAGE_SCALE, // fee (3%)
    "FNFT Single 3", // name
    "FNFTSingle3" // symbol
  );
  await fnftSingle3Receipt.wait();

  const fnftSingle1Address = await getFNFTSingleAddress(fnftSingle1Receipt);
  console.log("Single1Address: ", fnftSingle1Address);
  const fnftSingle2Address = await getFNFTSingleAddress(fnftSingle2Receipt);
  console.log("Single2Address: ", fnftSingle2Address);
  const fnftSingle3Address = await getFNFTSingleAddress(fnftSingle3Receipt);
  console.log("Single3Address: ", fnftSingle3Address);

  const fnftSingle2 = await ethers.getContractAt("FNFTSingle", fnftSingle2Address);

  const signers = await ethers.getSigners();

  // SIMULATE RANDOM IFO SALE

  // Scenario 6 ends here. fNft has votes but no quorum
  // callStatic is ok because cause this is basically a view w/o TWAP
  const fNft2Price: BigNumber = await fnftSingle2.callStatic.getAuctionPrice();

  // cast one vote. wont reach quorum.
  await fnftSingle2.connect(signers[0]).updateUserPrice(fNft2Price.add(parseFixed("1", 18)));

};

async function getFNFTSingleAddress(transactionReceipt: any) {
  const abi = [
    "event VaultCreated(uint256 indexed vaultId, address curator, address vaultAddress, address assetAddress, uint256 tokenId, uint256 supply, uint256 listPrice, string name, string symbol);",
  ];
  const _interface = new ethers.utils.Interface(abi);
  const topic = "0x220044f302cf7fe455029c3b05386aa5d8020bdeb160379089b81b53ed95693d";
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
