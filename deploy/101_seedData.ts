import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {BigNumber, parseFixed} from '@ethersproject/bignumber';
import {ethers} from 'hardhat';

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
 * 8.  NFT8 => FNFTSingle9 that has completed an auction w/ a few bids
 * 9.  NFT9 => FNFTSingle9 that has a triggered start bid
 * 10. NFT10 => FNFTSingle10 that is undergoing a bid war
 * 11. NFT11 => FNFTSingle11 that is redeemed
 * 12: NFT12 => FNFTSingle13 that is cashed out by a few people
 * 13. NFT13 => FNFTSingle14 that has a liquidity pool above threshold
 */

const PERCENTAGE_SCALE = 10000; // for converting percentages to fixed point

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {getNamedAccounts, ethers} = hre;
  const {deploy} = hre.deployments;
  const {deployer} = await getNamedAccounts();

  // NFT1
  const nft1CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT1", "NFT1"],
    log: true,
    autoMine: true
  });
  const nft1Collection = await ethers.getContractAt(
    nft1CollectionInfo.abi,
    nft1CollectionInfo.address
  );

  // NFT2
  const nft2CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT2", "NFT2"],
    log: true,
    autoMine: true
  });
  const nft2Collection = await ethers.getContractAt(
    nft2CollectionInfo.abi,
    nft2CollectionInfo.address
  );

  // NFT3
  const nft3CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT3", "NFT3"],
    log: true,
    autoMine: true
  });
  const nft3Collection = await ethers.getContractAt(
    nft3CollectionInfo.abi,
    nft3CollectionInfo.address
  );

  // NFT4
  const nft4CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT4", "NFT4"],
    log: true,
    autoMine: true
  });
  const nft4Collection = await ethers.getContractAt(
    nft4CollectionInfo.abi,
    nft4CollectionInfo.address
  );

  // NFT5
  const nft5CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT5", "NFT5"],
    log: true,
    autoMine: true
  });
  const nft5Collection = await ethers.getContractAt(
    nft5CollectionInfo.abi,
    nft5CollectionInfo.address
  );

  // NFT6
  const nft6CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT6", "NFT6"],
    log: true,
    autoMine: true
  });
  const nft6Collection = await ethers.getContractAt(
    nft6CollectionInfo.abi,
    nft6CollectionInfo.address
  );

  // NFT7
  const nft7CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT7", "NFT7"],
    log: true,
    autoMine: true
  });
  const nft7Collection = await ethers.getContractAt(
    nft7CollectionInfo.abi,
    nft7CollectionInfo.address
  );

  // NFT8
  const nft8CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT8", "NFT8"],
    log: true,
    autoMine: true
  });
  const nft8Collection = await ethers.getContractAt(
    nft8CollectionInfo.abi,
    nft8CollectionInfo.address
  );

  // NFT9
  const nft9CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT9", "NFT9"],
    log: true,
    autoMine: true
  });
  const nft9Collection = await ethers.getContractAt(
    nft9CollectionInfo.abi,
    nft9CollectionInfo.address
  );

  // NFT10
  const nft10CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT10", "NFT10"],
    log: true,
    autoMine: true
  });
  const nft10Collection = await ethers.getContractAt(
    nft10CollectionInfo.abi,
    nft10CollectionInfo.address
  );

  // NFT11
  const nft11CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT11", "NFT11"],
    log: true,
    autoMine: true
  });
  const nft11Collection = await ethers.getContractAt(
    nft11CollectionInfo.abi,
    nft11CollectionInfo.address
  );

  // NFT12
  const nft12CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT12", "NFT12"],
    log: true,
    autoMine: true
  });
  const nft12Collection = await ethers.getContractAt(
    nft12CollectionInfo.abi,
    nft12CollectionInfo.address
  );

  // NFT13
  const nft13CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT13", "NFT13"],
    log: true,
    autoMine: true
  });
  const nft13Collection = await ethers.getContractAt(
    nft13CollectionInfo.abi,
    nft13CollectionInfo.address
  );

  // mint
  await nft1Collection.mint(deployer, 1);
  await nft2Collection.mint(deployer, 2);
  await nft3Collection.mint(deployer, 3);
  await nft4Collection.mint(deployer, 4);
  await nft5Collection.mint(deployer, 5);
  await nft6Collection.mint(deployer, 6);
  await nft7Collection.mint(deployer, 7);
  await nft8Collection.mint(deployer, 8);
  await nft9Collection.mint(deployer, 9);
  await nft10Collection.mint(deployer, 10);
  await nft11Collection.mint(deployer, 11);
  await nft12Collection.mint(deployer, 12);
  await nft13Collection.mint(deployer, 13);

  // fractionalize nfts
  const FNFTSingleFactory = await getContract(hre, "FNFTSingleFactory");

  // approve factory
  await nft1Collection.approve(FNFTSingleFactory.address, 1);
  await nft2Collection.approve(FNFTSingleFactory.address, 2);
  await nft3Collection.approve(FNFTSingleFactory.address, 3);
  await nft4Collection.approve(FNFTSingleFactory.address, 4);
  await nft5Collection.approve(FNFTSingleFactory.address, 5);
  await nft6Collection.approve(FNFTSingleFactory.address, 6);
  await nft7Collection.approve(FNFTSingleFactory.address, 7);
  await nft8Collection.approve(FNFTSingleFactory.address, 8);
  await nft9Collection.approve(FNFTSingleFactory.address, 9);
  await nft10Collection.approve(FNFTSingleFactory.address, 10);
  await nft11Collection.approve(FNFTSingleFactory.address, 11);
  await nft12Collection.approve(FNFTSingleFactory.address, 12);
  await nft13Collection.approve(FNFTSingleFactory.address, 13);


  // NFT1 - scenario is done here
  await FNFTSingleFactory.createVault(
    "FNFTSingle1", // name
    "FNFTSingle1",  // symbol
    nft1CollectionInfo.address, // collection address
    1, // tokenId
    parseFixed('10000', 18), // supply
    parseFixed('100', 18), // initialPrice === 1e18
    .01 * PERCENTAGE_SCALE, // fee (1%)
  );

  // NFT2
  const fnftSingle2Address = await FNFTSingleFactory.createVault(
    "FNFTSingle2", // name
    "FNFTSingle2",  // symbol
    nft2CollectionInfo.address, // collection address
    2, // tokenId
    parseFixed('1000', 18), // supply
    parseFixed('10000', 18), // initialPrice === 2e18
    .1 * PERCENTAGE_SCALE, // fee (10%)
  );

  // NFT3
  const fnftSingle3Address = await FNFTSingleFactory.createVault(
    "FNFTSingle3", // name
    "FNFTSingle3",  // symbol
    nft3CollectionInfo.address, // collection address
    3, // tokenId
    parseFixed('100', 18), // supply
    parseFixed('1000', 18), // initialPrice == 2e18
    .03 * PERCENTAGE_SCALE, // fee (3%)
  );

  // NFT4
  const fnftSingle4Address = await FNFTSingleFactory.createVault(
    "FNFTSingle4", // name
    "FNFTSingle4",  // symbol
    nft4CollectionInfo.address, // collection address
    4, // tokenId
    parseFixed('100000', 18), // supply
    parseFixed('1000000', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // NFT5
  const fnftSingle5Address = await FNFTSingleFactory.createVault(
    "FNFTSingle5", // name
    "FNFTSingle5",  // symbol
    nft5CollectionInfo.address, // collection address
    5, // tokenId
    parseFixed('100', 18), // supply
    parseFixed('100', 18), // initialPrice
    .01 * PERCENTAGE_SCALE, // fee (1%)
  );

  // NFT6
  const fnftSingle6Address = await FNFTSingleFactory.createVault(
    "FNFTSingle6", // name
    "FNFTSingle6",  // symbol
    nft6CollectionInfo.address, // collection address
    6, // tokenId
    parseFixed('10', 18), // supply // low supply to make quorum easy
    parseFixed('10', 18),
    .1 * PERCENTAGE_SCALE, // fee (10%)
  );

  // NFT7
  const fnftSingle7Address = await FNFTSingleFactory.createVault(
    "FNFTSingle7", // name
    "FNFTSingle7",  // symbol
    nft7CollectionInfo.address, // collection address
    7, // tokenId
    parseFixed('10', 18), // supply  // low supply to make quorum easy
    parseFixed('10', 18), // initialPrice == 1e18
    .03 * PERCENTAGE_SCALE, // fee (3%)
  );

  // NFT8
  const fnftSingle8Address = await FNFTSingleFactory.createVault(
    "FNFTSingle8", // name
    "FNFTSingle8",  // symbol
    nft8CollectionInfo.address, // collection address
    8, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // NFT9
  const fnftSingle9Address = await FNFTSingleFactory.createVault(
    "FNFTSingle9", // name
    "FNFTSingle9",  // symbol
    nft9CollectionInfo.address, // collection address
    9, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // NFT10
  const fnftSingle10Address = await FNFTSingleFactory.createVault(
    "FNFTSingle10", // name
    "FNFTSingle10",  // symbol
    nft10CollectionInfo.address, // collection address
    10, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // NFT11
  const fnftSingle11Address = await FNFTSingleFactory.createVault(
    "FNFTSingle11", // name
    "FNFTSingle11",  // symbol
    nft11CollectionInfo.address, // collection address
    11, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // NFT12
  const fnftSingle12Address = await FNFTSingleFactory.createVault(
    "FNFTSingle12", // name
    "FNFTSingle12",  // symbol
    nft12CollectionInfo.address, // collection address
    12, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // NFT13
  const fnftSingle13Address = await FNFTSingleFactory.createVault(
    "FNFTSingle13", // name
    "FNFTSingle13",  // symbol
    nft13CollectionInfo.address, // collection address
    13, // tokenId
    parseFixed('100', 18), // supply
    parseFixed('100000', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );

  // IFOFactory
  const IFOFactory = await getContract(hre, 'IFOFactory');

  const fnftSingle2 = await ethers.getContractAt('FNFTSingle', fnftSingle2Address);
  const fnftSingle3 = await ethers.getContractAt('FNFTSingle', fnftSingle3Address);
  const fnftSingle4 = await ethers.getContractAt('FNFTSingle', fnftSingle4Address);
  const fnftSingle5 = await ethers.getContractAt('FNFTSingle', fnftSingle5Address);
  const fnftSingle6 = await ethers.getContractAt('FNFTSingle', fnftSingle6Address);
  const fnftSingle7 = await ethers.getContractAt('FNFTSingle', fnftSingle7Address);
  const fnftSingle8 = await ethers.getContractAt('FNFTSingle', fnftSingle8Address);
  const fnftSingle9 = await ethers.getContractAt('FNFTSingle', fnftSingle9Address);
  const fnftSingle10 = await ethers.getContractAt('FNFTSingle', fnftSingle10Address);
  const fnftSingle11 = await ethers.getContractAt('FNFTSingle', fnftSingle11Address);
  const fnftSingle12 = await ethers.getContractAt('FNFTSingle', fnftSingle12Address);
  const fnftSingle13 = await ethers.getContractAt('FNFTSingle', fnftSingle13Address);


  await fnftSingle2.approve(IFOFactory.address, await fnftSingle2.balanceOf(deployer));
  await fnftSingle3.approve(IFOFactory.address, await fnftSingle3.balanceOf(deployer));
  await fnftSingle4.approve(IFOFactory.address, await fnftSingle4.balanceOf(deployer));
  await fnftSingle5.approve(IFOFactory.address, await fnftSingle5.balanceOf(deployer));
  await fnftSingle6.approve(IFOFactory.address, await fnftSingle6.balanceOf(deployer));
  await fnftSingle7.approve(IFOFactory.address, await fnftSingle7.balanceOf(deployer));
  await fnftSingle8.approve(IFOFactory.address, await fnftSingle8.balanceOf(deployer));
  await fnftSingle9.approve(IFOFactory.address, await fnftSingle9.balanceOf(deployer));
  await fnftSingle10.approve(IFOFactory.address, await fnftSingle10.balanceOf(deployer));
  await fnftSingle11.approve(IFOFactory.address, await fnftSingle11.balanceOf(deployer));
  await fnftSingle12.approve(IFOFactory.address, await fnftSingle12.balanceOf(deployer));
  await fnftSingle13.approve(IFOFactory.address, await fnftSingle13.balanceOf(deployer));



  // NFT2 IFO - NFT2 scenario is done here.
  await IFOFactory.create(
    fnftSingle2Address, // fNft
    await fnftSingle2.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle2.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT3 IFO
  const IFO3Address = await IFOFactory.create(
    fnftSingle3Address, // fNft
    await fnftSingle3.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle3.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT4 IFO
  const IFO4Address = await IFOFactory.create(
    fnftSingle4Address, // fNft
    await fnftSingle4.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle4.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT5 IFO
  const IFO5Address = await IFOFactory.create(
    fnftSingle5Address, // fNft
    await fnftSingle5.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle5.totalSupply(), // cap
    86400, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT6 IFO
  const IFO6Address = await IFOFactory.create(
    fnftSingle6Address, // fNft
    await fnftSingle6.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle6.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT7 IFO
  const IFO7Address = await IFOFactory.create(
    fnftSingle7Address, // fNft
    await fnftSingle7.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle7.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT8 IFO
  const IFO8Address = await IFOFactory.create(
    fnftSingle8Address, // fNft
    await fnftSingle8.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle8.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT9 IFO
  const IFO9Address = await IFOFactory.create(
    fnftSingle9Address, // fNft
    await fnftSingle9.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle9.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT10 IFO
  const IFO10Address = await IFOFactory.create(
    fnftSingle10Address, // fNft
    await fnftSingle10.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle10.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT11 No IFO

  // NFT12 IFO
  const IFO12Address = await IFOFactory.create(
    fnftSingle12Address, // fNft
    await fnftSingle12.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle12.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );

  // NFT13 IFO
  const IFO13Address = await IFOFactory.create(
    fnftSingle13Address, // fNft
    await fnftSingle13.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fnftSingle13.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );


  // start IFOs
  const IFO3 = await ethers.getContractAt('IFO', IFO3Address);
  const IFO4 = await ethers.getContractAt('IFO', IFO4Address);
  const IFO5 = await ethers.getContractAt('IFO', IFO5Address);
  const IFO6 = await ethers.getContractAt('IFO', IFO6Address);
  const IFO7 = await ethers.getContractAt('IFO', IFO7Address);
  const IFO8 = await ethers.getContractAt('IFO', IFO8Address);
  const IFO9 = await ethers.getContractAt('IFO', IFO9Address);
  const IFO10 = await ethers.getContractAt('IFO', IFO10Address);
  // NFT11 no IFO
  const IFO12 = await ethers.getContractAt('IFO', IFO12Address);
  const IFO13 = await ethers.getContractAt('IFO', IFO13Address);


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
  signers.forEach(async signer => { // 20 addresses
    await IFO3.connect(signer).deposit({value: ifo3Price});
  });

  // NFT4
  const ifo4Price = await IFO4.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO4.connect(signer).deposit({value: ifo4Price});
  });

  // NFT5
  const ifo5Price = await IFO5.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO5.connect(signer).deposit({value: ifo5Price});
  });

  // NFT6
  const ifo6Price = await IFO6.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO6.connect(signer).deposit({value: ifo6Price});
  });

  // NFT7
  const ifo7Price = await IFO7.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO7.connect(signer).deposit({value: ifo7Price});
  });

  // NFT8
  const ifo8Price = await IFO8.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO8.connect(signer).deposit({value: ifo8Price});
  });

  // NFT9
  const ifo9Price = await IFO9.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO9.connect(signer).deposit({value: ifo9Price});
  });

  // NFT10
  const ifo10Price = await IFO10.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO10.connect(signer).deposit({value: ifo10Price});
  });

  // NFT11 => no IFO

  // NFT12
  const ifo12Price = await IFO12.price();
  signers.slice(0, 9).forEach(async (signer) => {
    await IFO12.connect(signer).deposit({value: ifo12Price});
  });

  // NFT13
  const ifo13Price = await IFO13.price();
  signers.slice(9, 19).forEach(async (signer) => {
    await IFO13.connect(signer).deposit({value: ifo13Price});
  });

  // mine here to allow sales time to finish and also to allow IFO5 duration to complete
  console.log('starting to mine... (this takes a few minutes)');
  await mineNBlocks(86400); // this takes a few min unfortunately
  console.log('completed mining');

  // Pause IFO, NFT4 sceanrio ends here
  await IFO4.togglePause();


  // END IFO, NFT5 sceanrio ends here
  await IFO5.end();


  // Scenario 6 ends here. fNft has votes but no quorum
  // callStatic is ok because cause this is basically a view w/o TWAP
  const fNft6Price: BigNumber = await fnftSingle6.callStatic.getAuctionPrice();

  // cast one vote. wont reach quorum.
  await fnftSingle6.connect(signers[0]).updateUserPrice(fNft6Price.add(parseFixed('1', 18)));


  // Scenario 7 ends here. fNft has votes and reaches quorum.
  const fNft7Price: BigNumber = await fnftSingle7.callStatic.getAuctionPrice();
  signers.slice(9, 19).forEach(async (signer) => {
    await fnftSingle7.connect(signer).updateUserPrice(fNft7Price.add(parseFixed('1', 18)));
  }); // all holders vote in favor of new price. vote reaches quorum.

  // get global min percentage increase for auction bids
  const fnftSingleFactory = await getContract(hre, 'FNFTSingleFactory');
  const minIncrease = await fnftSingleFactory.minBidIncrease()
  const minPercentIncrease = (minIncrease / PERCENTAGE_SCALE) + 1
  console.log(`minPercentIncrease === ${minPercentIncrease}`)


  // SCENARIO 8
  // start auction on NFT8. deployer will win.
  let auctionPrice8 = await fnftSingle8.getAuctionPrice();
  await fnftSingle8.start({value: auctionPrice8});

  // signer 1 bids
  let livePrice = await fnftSingle8.livePrice();
  auctionPrice8 = livePrice * minPercentIncrease;
  await fnftSingle8.connect(signers[1]).bid({value: BigNumber.from(auctionPrice8.toString())})

  // deployer out bids signer 1
  livePrice = await fnftSingle8.livePrice();
  auctionPrice8 = livePrice * minPercentIncrease;
  await fnftSingle8.bid({value: BigNumber.from(auctionPrice8.toString())})

  // move time forward so we can end the auction
  const auctionLength = (await fnftSingle8.auctionLength()).toNumber();
  await increaseBlockTimestamp(auctionLength);

  // SCENARIO 8 FINISHED
  await fnftSingle8.end();


  // SCENARIO 9 FINISHED, auction that has started
  let auctionPrice9 = await fnftSingle9.getAuctionPrice();
  await fnftSingle9.start({value: auctionPrice9});


  // SCENARIO 10 FINISHED, ongoing bid war
  let auctionPrice10 = await fnftSingle10.getAuctionPrice();
  await fnftSingle10.start({value: auctionPrice10});
  signers.slice(9,14).forEach(async (signer) => {
    auctionPrice10 *= minPercentIncrease;
    await fnftSingle10.connect(signer).bid({value: BigNumber.from(auctionPrice10.toString())})
  });


  // SCENARIO 11, curator redeems
  console.log(`fnft11.totalSupply() === ${await fnftSingle11.totalSupply()}`)
  console.log(`fnft11.balanceOf(deployer) === ${await fnftSingle11.balanceOf(deployer)}`)
  await fnftSingle11.redeem()


  // SCENARIO 12, half of the buyers cashout
  let auctionPrice12 = await fnftSingle12.getAuctionPrice();
  await fnftSingle12.start({value: auctionPrice12});
  signers.slice(0,3).forEach(async (signer) => {
    auctionPrice12 *= minPercentIncrease;
    await fnftSingle12.connect(signer).bid({value: BigNumber.from(auctionPrice12.toString())});
  });
  // deployer out bids and wins nft
  livePrice = await fnftSingle12.livePrice();
  auctionPrice12 *= minPercentIncrease;
  await fnftSingle12.bid({value: BigNumber.from(auctionPrice12.toString())});

  // move time forward so we can end the auction
  const auctionLength12 = (await fnftSingle12.auctionLength()).toNumber();
  await increaseBlockTimestamp(auctionLength12);
  await fnftSingle12.end();

  // SCENARIO 12 ends here, everyone cashes out
  signers.slice(0,9).forEach(async (signer) => {
    await fnftSingle12.connect(signer).cash();
  });

  //TODO scenario 13 not done yet.
};

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
