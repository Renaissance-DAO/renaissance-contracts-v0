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
  await nft1.setBaseURI("ipfs://QmVTuf8VqSjJ6ma6ykTJiuVtvAY9CHJiJnXsgSMf5rBRtZ/");

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
  await nft2.setBaseURI("https://www.timelinetransit.xyz/metadata/");

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
  await nft3.setBaseURI(
    "ipfs://bafybeie7oivvuqcmhjzvxbiezyz7sr4fxkcrutewmaoathfsvcwksqiyuy/"
  );

  // NFT4
  const nft4Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT4 Name", "NFT4"],
    log: true,
    autoMine: true,
  });
  const nft4 = await ethers.getContractAt(
    nft4Info.abi,
    nft4Info.address
  );
  await nft4.setBaseURI("https://cdn.childrenofukiyo.com/metadata/");

  // NFT5
  const nft5Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT5 Name", "NFT5"],
    log: true,
    autoMine: true,
  });
  const nft5 = await ethers.getContractAt(
    nft5Info.abi,
    nft5Info.address
  );
  await nft5.setBaseURI(
    "https://chainbase-api.matrixlabs.org/metadata/api/v1/apps/ethereum:mainnet:bKPQsA_Ohnj1Ug0MvX39i/contracts/0x249aeAa7fA06a63Ea5389b72217476db881294df_ethereum/metadata/tokens/"
  );

  // NFT6
  const nft6Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT6 Name", "NFT6"],
    log: true,
    autoMine: true,
  });
  const nft6 = await ethers.getContractAt(
    nft6Info.abi,
    nft6Info.address
  );
  await nft6.setBaseURI(
    "https://us-central1-catblox-1f4e5.cloudfunctions.net/api/tbt-prereveal/1"
  );

  // NFT7
  const nft7Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT7 Name", "NFT7"],
    log: true,
    autoMine: true,
  });
  const nft7 = await ethers.getContractAt(
    nft7Info.abi,
    nft7Info.address
  );
  await nft7.setBaseURI("https://loremnft.com/nft/token/");

  // NFT8
  const nft8Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT8 Name", "NFT8"],
    log: true,
    autoMine: true,
  });
  const nft8 = await ethers.getContractAt(
    nft8Info.abi,
    nft8Info.address
  );
  await nft8.setBaseURI("ipfs://QmQNdnPx1K6a8jd5XJEJvGorx73U9pmpqU2YAhEfQZDwcw/");

  // NFT9
  const nft9Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT9 Name", "NFT9"],
    log: true,
    autoMine: true,
  });
  const nft9 = await ethers.getContractAt(
    nft9Info.abi,
    nft9Info.address
  );
  await nft9.setBaseURI("ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/");

  // NFT10
  const nft10Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT10 Name", "NFT10"],
    log: true,
    autoMine: true,
  });
  const nft10 = await ethers.getContractAt(
    nft10Info.abi,
    nft10Info.address
  );
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
  const nft11 = await ethers.getContractAt(
    nft11Info.abi,
    nft11Info.address
  );
  await nft11.setBaseURI("http://api.cyberfist.xyz/badges/metadata/");

  // NFT12
  const nft12Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT12 Name", "NFT12"],
    log: true,
    autoMine: true,
  });
  const nft12 = await ethers.getContractAt(
    nft12Info.abi,
    nft12Info.address
  );
  await nft12.setBaseURI(
    "https://gateway.pinata.cloud/ipfs/Qmdp8uFBrWq3CJmNHviq4QLZzbw5BchA7Xi99xTxuxoQjY/"
  );

  // NFT13
  const nft13Info = await deploy("StandardMockNFT", {
    from: deployer,
    args: ["NFT13 Name", "NFT13"],
    log: true,
    autoMine: true,
  });
  const nft13 = await ethers.getContractAt(
    nft13Info.abi,
    nft13Info.address
  );
  await nft13.setBaseURI("https://static-resource.dirtyflies.xyz/metadata/");

  // NFT14
  const nft14Info = await deploy("NoURIMockNFT", {
    from: deployer,
    args: ["NFT14 Name", "NFT14"],
    log: true,
    autoMine: true,
  });
  const nft14 = await ethers.getContractAt(
    nft14Info.abi,
    nft14Info.address
  );

  // mint
  await nft1.mint(deployer, 1);
  await nft2.mint(deployer, 2);
  await nft3.mint(deployer, 3);
  await nft4.mint(deployer, 4);
  await nft5.mint(deployer, 5);
  await nft6.mint(deployer, 6);
  await nft7.mint(deployer, 7);
  await nft8.mint(deployer, 8);
  await nft9.mint(deployer, 9);
  await nft10.mint(deployer, 10);
  await nft11.mint(deployer, 11);
  await nft12.mint(deployer, 12);
  await nft13.mint(deployer, 13);
  await nft14.mint(deployer, 14);

  // fractionalize nfts
  const FNFTSingleFactory = await getContract(hre, "FNFTSingleFactory");

  // approve factory
  await nft1.approve(FNFTSingleFactory.address, 1);
  await nft2.approve(FNFTSingleFactory.address, 2);
  await nft3.approve(FNFTSingleFactory.address, 3);
  await nft4.approve(FNFTSingleFactory.address, 4);
  await nft5.approve(FNFTSingleFactory.address, 5);
  await nft6.approve(FNFTSingleFactory.address, 6);
  await nft7.approve(FNFTSingleFactory.address, 7);
  await nft8.approve(FNFTSingleFactory.address, 8);
  await nft9.approve(FNFTSingleFactory.address, 9);
  await nft10.approve(FNFTSingleFactory.address, 10);
  await nft11.approve(FNFTSingleFactory.address, 11);
  await nft12.approve(FNFTSingleFactory.address, 12);
  await nft13.approve(FNFTSingleFactory.address, 13);
  await nft14.approve(FNFTSingleFactory.address, 14);

  // NFT1 - scenario is done here
  await FNFTSingleFactory.createVault(
    nft1Info.address, // collection address
    1, // tokenId
    parseFixed("10000", 18), // supply
    parseFixed("100", 18), // initialPrice === 1e18
    0.01 * PERCENTAGE_SCALE, // fee (1%)
    "FNFT Single 1", // name
    "FNFTSingle1" // symbol
  );

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

  // NFT4
  const fnftSingle4Receipt = await FNFTSingleFactory.createVault(
    nft4Info.address, // collection address
    4, // tokenId
    parseFixed("100000", 18), // supply
    parseFixed("1000000", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 4", // name
    "FNFTSingle4" // symbol
  );

  // NFT5
  const fnftSingle5Receipt = await FNFTSingleFactory.createVault(
    nft5Info.address, // collection address
    5, // tokenId
    parseFixed("100", 18), // supply
    parseFixed("100", 18), // initialPrice
    0.01 * PERCENTAGE_SCALE, // fee (1%)
    "FNFT Single 5", // name
    "FNFTSingle5" // symbol
  );

  // NFT6
  const fnftSingle6Receipt = await FNFTSingleFactory.createVault(
    nft6Info.address, // collection address
    6, // tokenId
    parseFixed("10", 18), // supply // low supply to make quorum easy
    parseFixed("10", 18),
    0.1 * PERCENTAGE_SCALE, // fee (10%)
    "FNFT Single 6", // name
    "FNFTSingle6" // symbol
  );

  // NFT7
  const fnftSingle7Receipt = await FNFTSingleFactory.createVault(
    nft7Info.address, // collection address
    7, // tokenId
    parseFixed("10", 18), // supply  // low supply to make quorum easy
    parseFixed("10", 18), // initialPrice == 1e18
    0.03 * PERCENTAGE_SCALE, // fee (3%)
    "FNFT Single 7", // name
    "FNFTSingle7" // symbol
  );

  // NFT8
  const fnftSingle8Receipt = await FNFTSingleFactory.createVault(
    nft8Info.address, // collection address
    8, // tokenId
    parseFixed("10", 18), // supply
    parseFixed("10", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 8", // name
    "FNFTSingle8" // symbol
  );

  // NFT9
  const fnftSingle9Receipt = await FNFTSingleFactory.createVault(
    nft9Info.address, // collection address
    9, // tokenId
    parseFixed("10", 18), // supply
    parseFixed("10", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 9", // name
    "FNFTSingle9" // symbol
  );

  // NFT10
  const fnftSingle10Receipt = await FNFTSingleFactory.createVault(
    nft10Info.address, // collection address
    10, // tokenId
    parseFixed("10", 18), // supply
    parseFixed("10", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 10", // name
    "FNFTSingle10" // symbol
  );

  // NFT11
  const fnftSingle11Receipt = await FNFTSingleFactory.createVault(
    nft11Info.address, // collection address
    11, // tokenId
    parseFixed("10", 18), // supply
    parseFixed("10", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 11", // name
    "FNFTSingle11" // symbol
  );

  // NFT12
  const fnftSingle12Receipt = await FNFTSingleFactory.createVault(
    nft12Info.address, // collection address
    12, // tokenId
    parseFixed("10", 18), // supply
    parseFixed("10", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 12", // name
    "FNFTSingle12" // symbol
  );

  // NFT13
  const fnftSingle13Receipt = await FNFTSingleFactory.createVault(
    nft13Info.address, // collection address
    13, // tokenId
    parseFixed("100", 18), // supply
    parseFixed("100000", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 13", // name
    "FNFTSingle13" // symbol
  );

  // NFT14
  const fnftSingle14Receipt = await FNFTSingleFactory.createVault(
    nft14Info.address, // collection address
    14, // tokenId
    parseFixed("100", 18), // supply
    parseFixed("100000", 18), // initialPrice
    0.005 * PERCENTAGE_SCALE, // fee (.5%)
    "FNFT Single 14", // name
    "FNFTSingle14" // symbol
  );

  // IFOFactory
  const ifoFactory = await getContract(hre, "IFOFactory");

  const fnftSingle2Address = await getFNFTSingleAddress(fnftSingle2Receipt);
  const fnftSingle3Address = await getFNFTSingleAddress(fnftSingle3Receipt);
  const fnftSingle4Address = await getFNFTSingleAddress(fnftSingle4Receipt);
  const fnftSingle5Address = await getFNFTSingleAddress(fnftSingle5Receipt);
  const fnftSingle6Address = await getFNFTSingleAddress(fnftSingle6Receipt);
  const fnftSingle7Address = await getFNFTSingleAddress(fnftSingle7Receipt);
  const fnftSingle8Address = await getFNFTSingleAddress(fnftSingle8Receipt);
  const fnftSingle9Address = await getFNFTSingleAddress(fnftSingle9Receipt);
  const fnftSingle10Address = await getFNFTSingleAddress(fnftSingle10Receipt);
  const fnftSingle11Address = await getFNFTSingleAddress(fnftSingle11Receipt);
  const fnftSingle12Address = await getFNFTSingleAddress(fnftSingle12Receipt);
  const fnftSingle13Address = await getFNFTSingleAddress(fnftSingle13Receipt);
  const fnftSingle14Address = await getFNFTSingleAddress(fnftSingle14Receipt);

  const fnftSingle2 = await ethers.getContractAt("FNFTSingle", fnftSingle2Address);
  const fnftSingle3 = await ethers.getContractAt("FNFTSingle", fnftSingle3Address);
  const fnftSingle4 = await ethers.getContractAt("FNFTSingle", fnftSingle4Address);
  const fnftSingle5 = await ethers.getContractAt("FNFTSingle", fnftSingle5Address);
  const fnftSingle6 = await ethers.getContractAt("FNFTSingle", fnftSingle6Address);
  const fnftSingle7 = await ethers.getContractAt("FNFTSingle", fnftSingle7Address);
  const fnftSingle8 = await ethers.getContractAt("FNFTSingle", fnftSingle8Address);
  const fnftSingle9 = await ethers.getContractAt("FNFTSingle", fnftSingle9Address);
  const fnftSingle10 = await ethers.getContractAt("FNFTSingle", fnftSingle10Address);
  const fnftSingle11 = await ethers.getContractAt("FNFTSingle", fnftSingle11Address);
  const fnftSingle12 = await ethers.getContractAt("FNFTSingle", fnftSingle12Address);
  const fnftSingle13 = await ethers.getContractAt("FNFTSingle", fnftSingle13Address);
  const fnftSingle14 = await ethers.getContractAt("FNFTSingle", fnftSingle14Address);

  await fnftSingle2.approve(ifoFactory.address, await fnftSingle2.balanceOf(deployer));
  await fnftSingle3.approve(ifoFactory.address, await fnftSingle3.balanceOf(deployer));
  await fnftSingle4.approve(ifoFactory.address, await fnftSingle4.balanceOf(deployer));
  await fnftSingle5.approve(ifoFactory.address, await fnftSingle5.balanceOf(deployer));
  await fnftSingle6.approve(ifoFactory.address, await fnftSingle6.balanceOf(deployer));
  await fnftSingle7.approve(ifoFactory.address, await fnftSingle7.balanceOf(deployer));
  await fnftSingle8.approve(ifoFactory.address, await fnftSingle8.balanceOf(deployer));
  await fnftSingle9.approve(ifoFactory.address, await fnftSingle9.balanceOf(deployer));
  await fnftSingle10.approve(ifoFactory.address, await fnftSingle10.balanceOf(deployer));
  await fnftSingle11.approve(ifoFactory.address, await fnftSingle11.balanceOf(deployer));
  await fnftSingle12.approve(ifoFactory.address, await fnftSingle12.balanceOf(deployer));
  await fnftSingle13.approve(ifoFactory.address, await fnftSingle13.balanceOf(deployer));
  await fnftSingle14.approve(ifoFactory.address, await fnftSingle14.balanceOf(deployer));

  // NFT2 IFO - NFT2 scenario is done here.
  await ifoFactory.create(
    fnftSingle2Address, // fNft
    await fnftSingle2.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle2.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT3 IFO
  const IFO3Receipt = await ifoFactory.create(
    fnftSingle3Address, // fNft
    await fnftSingle3.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle3.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT4 IFO
  const IFO4Receipt = await ifoFactory.create(
    fnftSingle4Address, // fNft
    await fnftSingle4.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle4.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT5 IFO
  const IFO5Receipt = await ifoFactory.create(
    fnftSingle5Address, // fNft
    await fnftSingle5.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle5.totalSupply(), // cap
    86400, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT6 IFO
  const IFO6Receipt = await ifoFactory.create(
    fnftSingle6Address, // fNft
    await fnftSingle6.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle6.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT7 IFO
  const IFO7Receipt = await ifoFactory.create(
    fnftSingle7Address, // fNft
    await fnftSingle7.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle7.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT8 IFO
  const IFO8Receipt = await ifoFactory.create(
    fnftSingle8Address, // fNft
    await fnftSingle8.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle8.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT9 IFO
  const IFO9Receipt = await ifoFactory.create(
    fnftSingle9Address, // fNft
    await fnftSingle9.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle9.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT10 IFO
  const IFO10Receipt = await ifoFactory.create(
    fnftSingle10Address, // fNft
    await fnftSingle10.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle10.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT11 No IFO

  // NFT12 IFO
  const IFO12Receipt = await ifoFactory.create(
    fnftSingle12Address, // fNft
    await fnftSingle12.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle12.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT13 IFO
  const IFO13Receipt = await ifoFactory.create(
    fnftSingle13Address, // fNft
    await fnftSingle13.totalSupply(), // amount for sale
    parseFixed("1", 18), // price
    await fnftSingle13.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );

  const IFO3Address = await getIFOAddress(IFO3Receipt);
  const IFO4Address = await getIFOAddress(IFO4Receipt);
  const IFO5Address = await getIFOAddress(IFO5Receipt);
  const IFO6Address = await getIFOAddress(IFO6Receipt);
  const IFO7Address = await getIFOAddress(IFO7Receipt);
  const IFO8Address = await getIFOAddress(IFO8Receipt);
  const IFO9Address = await getIFOAddress(IFO9Receipt);
  const IFO10Address = await getIFOAddress(IFO10Receipt);
  const IFO12Address = await getIFOAddress(IFO12Receipt);
  const IFO13Address = await getIFOAddress(IFO13Receipt);

  // start IFOs
  const IFO3 = await ethers.getContractAt("IFO", IFO3Address);
  const IFO4 = await ethers.getContractAt("IFO", IFO4Address);
  const IFO5 = await ethers.getContractAt("IFO", IFO5Address);
  const IFO6 = await ethers.getContractAt("IFO", IFO6Address);
  const IFO7 = await ethers.getContractAt("IFO", IFO7Address);
  const IFO8 = await ethers.getContractAt("IFO", IFO8Address);
  const IFO9 = await ethers.getContractAt("IFO", IFO9Address);
  const IFO10 = await ethers.getContractAt("IFO", IFO10Address);
  // NFT11 no IFO
  const IFO12 = await ethers.getContractAt("IFO", IFO12Address);
  const IFO13 = await ethers.getContractAt("IFO", IFO13Address);

  await IFO3.start();
  await IFO4.start();
  await IFO5.start();
  await IFO6.start();
  await IFO7.start();
  await IFO8.start();
  await IFO9.start();
  await IFO10.start();
  // NFNT11 no IFO
  await IFO12.start();
  await IFO13.start();

  const signers = await ethers.getSigners();

  // SIMULATE RANDOM IFO SALE

  // NFT3 scenario is done after this loop.
  const ifo3Price = await IFO3.price();
  signers.forEach(async (signer) => {
    // 20 addresses
    await IFO3.connect(signer).deposit({ value: ifo3Price });
  });

  // NFT4
  const ifo4Price = await IFO4.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO4.connect(signer).deposit({ value: ifo4Price });
  });

  // NFT5
  const ifo5Price = await IFO5.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO5.connect(signer).deposit({ value: ifo5Price });
  });

  // NFT6
  const ifo6Price = await IFO6.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO6.connect(signer).deposit({ value: ifo6Price });
  });

  // NFT7
  const ifo7Price = await IFO7.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO7.connect(signer).deposit({ value: ifo7Price });
  });

  // NFT8
  const ifo8Price = await IFO8.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO8.connect(signer).deposit({ value: ifo8Price });
  });

  // NFT9
  const ifo9Price = await IFO9.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO9.connect(signer).deposit({ value: ifo9Price });
  });

  // NFT10
  const ifo10Price = await IFO10.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO10.connect(signer).deposit({ value: ifo10Price });
  });

  // NFT11 => no IFO

  // NFT12
  const ifo12Price = await IFO12.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO12.connect(signer).deposit({ value: ifo12Price });
  });

  // NFT13
  const ifo13Price = await IFO13.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO13.connect(signer).deposit({ value: ifo13Price });
  });

  // mine here to allow sales time to finish and also to allow IFO5 duration to complete
  console.log("starting to mine... (this takes a few minutes)");
  await mineNBlocks(86400); // this takes a few min unfortunately
  console.log("completed mining");

  // Pause IFO, NFT4 sceanrio ends here
  await IFO4.togglePause();

  // END IFO, NFT5 sceanrio ends here
  await IFO5.end();

  // Scenario 6 ends here. fNft has votes but no quorum
  // callStatic is ok because cause this is basically a view w/o TWAP
  const fNft6Price: BigNumber = await fnftSingle6.callStatic.getAuctionPrice();

  // cast one vote. wont reach quorum.
  await fnftSingle6.connect(signers[0]).updateUserPrice(fNft6Price.add(parseFixed("1", 18)));

  // Scenario 7 ends here. fNft has votes and reaches quorum.
  const fNft7Price: BigNumber = await fnftSingle7.callStatic.getAuctionPrice();
  signers.slice(9, 19).forEach(async (signer) => {
    await fnftSingle7.connect(signer).updateUserPrice(fNft7Price.add(parseFixed("1", 18)));
  }); // all holders vote in favor of new price. vote reaches quorum.

  // get global min percentage increase for auction bids
  const fnftSingleFactory = await getContract(hre, "FNFTSingleFactory");
  const minIncrease = await fnftSingleFactory.minBidIncrease();
  const minPercentIncrease = minIncrease / PERCENTAGE_SCALE + 1;
  console.log(`minPercentIncrease === ${minPercentIncrease}`);

  // SCENARIO 8
  // start auction on NFT8. deployer will win.
  let auctionPrice8 = await fnftSingle8.getAuctionPrice();
  await fnftSingle8.start({ value: auctionPrice8 });

  // signer 1 bids
  let livePrice = await fnftSingle8.livePrice();
  auctionPrice8 = livePrice * minPercentIncrease;
  await fnftSingle8.connect(signers[1]).bid({ value: BigNumber.from(auctionPrice8.toString()) });

  // deployer out bids signer 1
  livePrice = await fnftSingle8.livePrice();
  auctionPrice8 = livePrice * minPercentIncrease;
  await fnftSingle8.bid({ value: BigNumber.from(auctionPrice8.toString()) });

  // move time forward so we can end the auction
  const auctionLength = (await fnftSingle8.auctionLength()).toNumber();
  await increaseBlockTimestamp(auctionLength);

  // SCENARIO 8 FINISHED
  await fnftSingle8.end();

  // SCENARIO 9 FINISHED, auction that has started
  let auctionPrice9 = await fnftSingle9.getAuctionPrice();
  await fnftSingle9.start({ value: auctionPrice9 });

  // SCENARIO 10 FINISHED, ongoing bid war
  let auctionPrice10 = await fnftSingle10.getAuctionPrice();
  await fnftSingle10.start({ value: auctionPrice10 });
  signers.slice(9, 14).forEach(async (signer) => {
    auctionPrice10 *= minPercentIncrease;
    await fnftSingle10.connect(signer).bid({ value: BigNumber.from(auctionPrice10.toString()) });
  });

  // SCENARIO 11, curator redeems
  console.log(`fnft11.totalSupply() === ${await fnftSingle11.totalSupply()}`);
  console.log(`fnft11.balanceOf(deployer) === ${await fnftSingle11.balanceOf(deployer)}`);
  await fnftSingle11.redeem();

  // SCENARIO 12, half of the buyers cashout
  let auctionPrice12 = await fnftSingle12.getAuctionPrice();
  await fnftSingle12.start({ value: auctionPrice12 });
  signers.slice(0, 3).forEach(async (signer) => {
    auctionPrice12 *= minPercentIncrease;
    await fnftSingle12.connect(signer).bid({ value: BigNumber.from(auctionPrice12.toString()) });
  });
  // deployer out bids and wins nft
  livePrice = await fnftSingle12.livePrice();
  auctionPrice12 *= minPercentIncrease;
  await fnftSingle12.bid({ value: BigNumber.from(auctionPrice12.toString()) });

  // move time forward so we can end the auction
  const auctionLength12 = (await fnftSingle12.auctionLength()).toNumber();
  await increaseBlockTimestamp(auctionLength12);
  await fnftSingle12.end();

  // SCENARIO 12 ends here, everyone cashes out
  signers.slice(0, 9).forEach(async (signer) => {
    await fnftSingle12.connect(signer).cash();
  });

  //TODO scenario 13 not done yet.
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

async function mineNBlocks(n: number) {
  for (let index = 0; index < n; index++) {
    await ethers.provider.send("evm_mine", []);
  }
}

async function increaseBlockTimestamp(seconds: number) {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
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
