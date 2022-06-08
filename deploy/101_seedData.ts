import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {BigNumber, parseFixed} from '@ethersproject/bignumber';
import {ethers} from 'hardhat';

/**
 *
 * SCENARIOS
 * 1.  NFT1 => FNFT1 that is just created
 * 2.  NFT2 => FNFT2 that is undergoing IFO but not started
 * 3.  NFT3 => FNFT3 that is undergoing IFO and has started with a few sales here and there
 * 4.  NFT4 => FNFT4 that is undergoing IFO and is paused with a few sales here and there
 * 5.  NFT5 => FNFT5 that has finished IFO with a few sales here and there
 * 6.  NFT6 => FNFT6 that has averageReserve voted that doesn’t meet quorum
 * 7.  NFT7 => FNFT7 that has averageReserve that meets quorum
 * 8.  NFT8 => FNFT9 that has completed an auction w/ a few bids
 * 9.  NFT9 => FNFT9 that has a triggered start bid
 * 10. NFT10 => FNFT10 that is undergoing a bid war
 * 11. NFT11 => FNFT11 that is redeemed
 * 12: NFT12 => FNFT13 that is cashed out by a few people
 * 13. NFT13 => FNFT14 that has a liquidity pool above threshold
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
  const FNFTFactory = await getContract(hre, "FNFTFactory");

  // approve factory
  await nft1Collection.approve(FNFTFactory.address, 1);
  await nft2Collection.approve(FNFTFactory.address, 2);
  await nft3Collection.approve(FNFTFactory.address, 3);
  await nft4Collection.approve(FNFTFactory.address, 4);
  await nft5Collection.approve(FNFTFactory.address, 5);
  await nft6Collection.approve(FNFTFactory.address, 6);
  await nft7Collection.approve(FNFTFactory.address, 7);
  await nft8Collection.approve(FNFTFactory.address, 8);
  await nft9Collection.approve(FNFTFactory.address, 9);
  await nft10Collection.approve(FNFTFactory.address, 10);
  await nft11Collection.approve(FNFTFactory.address, 11);
  await nft12Collection.approve(FNFTFactory.address, 12);
  await nft13Collection.approve(FNFTFactory.address, 13);


  // NFT1 - scenario is done here
  await FNFTFactory.mint(
    "fNFT1", // name
    "fNFT1",  // symbol
    nft1CollectionInfo.address, // collection address
    1, // tokenId
    parseFixed('10000', 18), // supply
    parseFixed('100', 18), // initialPrice === 1e18
    .01 * PERCENTAGE_SCALE, // fee (1%)
  );

  // NFT2
  await FNFTFactory.mint(
    "fNFT2", // name
    "fNFT2",  // symbol
    nft2CollectionInfo.address, // collection address
    2, // tokenId
    parseFixed('1000', 18), // supply
    parseFixed('10000', 18), // initialPrice === 2e18
    .1 * PERCENTAGE_SCALE, // fee (10%)
  );
  const fNFT2Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft2CollectionInfo.address, 2));

  // NFT3
  await FNFTFactory.mint(
    "fNFT3", // name
    "fNFT3",  // symbol
    nft3CollectionInfo.address, // collection address
    3, // tokenId
    parseFixed('100', 18), // supply
    parseFixed('1000', 18), // initialPrice == 2e18
    .03 * PERCENTAGE_SCALE, // fee (3%)
  );
  const fNFT3Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft3CollectionInfo.address, 3));

  // NFT4
  await FNFTFactory.mint(
    "fNFT4", // name
    "fNFT4",  // symbol
    nft4CollectionInfo.address, // collection address
    4, // tokenId
    parseFixed('100000', 18), // supply
    parseFixed('1000000', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT4Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft4CollectionInfo.address, 4));

  // NFT5
  await FNFTFactory.mint(
    "fNFT5", // name
    "fNFT5",  // symbol
    nft5CollectionInfo.address, // collection address
    5, // tokenId
    parseFixed('100', 18), // supply
    parseFixed('100', 18), // initialPrice
    .01 * PERCENTAGE_SCALE, // fee (1%)
  );
  const fNFT5Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft5CollectionInfo.address, 5));

  // NFT6
  await FNFTFactory.mint(
    "fNFT6", // name
    "fNFT6",  // symbol
    nft6CollectionInfo.address, // collection address
    6, // tokenId
    parseFixed('10', 18), // supply // low supply to make quorum easy
    parseFixed('10', 18),
    .1 * PERCENTAGE_SCALE, // fee (10%)
  );
  const fNFT6Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft6CollectionInfo.address, 6));

  // NFT7
  await FNFTFactory.mint(
    "fNFT7", // name
    "fNFT7",  // symbol
    nft7CollectionInfo.address, // collection address
    7, // tokenId
    parseFixed('10', 18), // supply  // low supply to make quorum easy
    parseFixed('10', 18), // initialPrice == 1e18
    .03 * PERCENTAGE_SCALE, // fee (3%)
  );
  const fNFT7Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft7CollectionInfo.address, 7));

  // NFT8
  await FNFTFactory.mint(
    "fNFT8", // name
    "fNFT8",  // symbol
    nft8CollectionInfo.address, // collection address
    8, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT8Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft8CollectionInfo.address, 8));

  // NFT9
  await FNFTFactory.mint(
    "fNFT9", // name
    "fNFT9",  // symbol
    nft9CollectionInfo.address, // collection address
    9, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT9Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft9CollectionInfo.address, 9));

  // NFT10
  await FNFTFactory.mint(
    "fNFT10", // name
    "fNFT10",  // symbol
    nft10CollectionInfo.address, // collection address
    10, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT10Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft10CollectionInfo.address, 10));

  // NFT11
  await FNFTFactory.mint(
    "fNFT11", // name
    "fNFT11",  // symbol
    nft11CollectionInfo.address, // collection address
    11, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT11Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft11CollectionInfo.address, 11));

  // NFT12
  await FNFTFactory.mint(
    "fNFT12", // name
    "fNFT12",  // symbol
    nft12CollectionInfo.address, // collection address
    12, // tokenId
    parseFixed('10', 18), // supply
    parseFixed('10', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT12Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft12CollectionInfo.address, 12));

  // NFT13
  await FNFTFactory.mint(
    "fNFT13", // name
    "fNFT13",  // symbol
    nft13CollectionInfo.address, // collection address
    13, // tokenId
    parseFixed('100', 18), // supply
    parseFixed('100000', 18), // initialPrice
    .005 * PERCENTAGE_SCALE, // fee (.5%)
  );
  const fNFT13Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft13CollectionInfo.address, 13));

  // IFOFactory
  const IFOFactory = await getContract(hre, 'IFOFactory');

  const fNft2 = await ethers.getContractAt('FNFT', fNFT2Address);
  const fNft3 = await ethers.getContractAt('FNFT', fNFT3Address);
  const fNft4 = await ethers.getContractAt('FNFT', fNFT4Address);
  const fNft5 = await ethers.getContractAt('FNFT', fNFT5Address);
  const fNft6 = await ethers.getContractAt('FNFT', fNFT6Address);
  const fNft7 = await ethers.getContractAt('FNFT', fNFT7Address);
  const fNft8 = await ethers.getContractAt('FNFT', fNFT8Address);
  const fNft9 = await ethers.getContractAt('FNFT', fNFT9Address);
  const fNft10 = await ethers.getContractAt('FNFT', fNFT10Address);
  const fNft11 = await ethers.getContractAt('FNFT', fNFT11Address);
  const fNft12 = await ethers.getContractAt('FNFT', fNFT12Address);
  const fNft13 = await ethers.getContractAt('FNFT', fNFT13Address);


  await fNft2.approve(IFOFactory.address, await fNft2.balanceOf(deployer));
  await fNft3.approve(IFOFactory.address, await fNft3.balanceOf(deployer));
  await fNft4.approve(IFOFactory.address, await fNft4.balanceOf(deployer));
  await fNft5.approve(IFOFactory.address, await fNft5.balanceOf(deployer));
  await fNft6.approve(IFOFactory.address, await fNft6.balanceOf(deployer));
  await fNft7.approve(IFOFactory.address, await fNft7.balanceOf(deployer));
  await fNft8.approve(IFOFactory.address, await fNft8.balanceOf(deployer));
  await fNft9.approve(IFOFactory.address, await fNft9.balanceOf(deployer));
  await fNft10.approve(IFOFactory.address, await fNft10.balanceOf(deployer));
  await fNft11.approve(IFOFactory.address, await fNft11.balanceOf(deployer));
  await fNft12.approve(IFOFactory.address, await fNft12.balanceOf(deployer));
  await fNft13.approve(IFOFactory.address, await fNft13.balanceOf(deployer));



  // NFT2 IFO - NFT2 scenario is done here.
  await IFOFactory.create(
    fNFT2Address, // fNft
    await fNft2.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft2.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT3 IFO
  await IFOFactory.create(
    fNFT3Address, // fNft
    await fNft3.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft3.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO3Address = await IFOFactory.getIFO(fNFT3Address)

  // NFT4 IFO
  await IFOFactory.create(
    fNFT4Address, // fNft
    await fNft4.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft4.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO4Address = await IFOFactory.getIFO(fNFT4Address);

  // NFT5 IFO
  await IFOFactory.create(
    fNFT5Address, // fNft
    await fNft5.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft5.totalSupply(), // cap
    86400, // short duration for purposes of testing
    false // allow whitelisting
  );
  const IFO5Address = await IFOFactory.getIFO(fNFT5Address);

  // NFT6 IFO
  await IFOFactory.create(
    fNFT6Address, // fNft
    await fNft6.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft6.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO6Address = await IFOFactory.getIFO(fNFT6Address)

  // NFT7 IFO
  await IFOFactory.create(
    fNFT7Address, // fNft
    await fNft7.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft7.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO7Address = await IFOFactory.getIFO(fNFT7Address)

  // NFT8 IFO
  await IFOFactory.create(
    fNFT8Address, // fNft
    await fNft8.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft8.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO8Address = await IFOFactory.getIFO(fNFT8Address);

  // NFT9 IFO
  await IFOFactory.create(
    fNFT9Address, // fNft
    await fNft9.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft9.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );
  const IFO9Address = await IFOFactory.getIFO(fNFT9Address);

  // NFT10 IFO
  await IFOFactory.create(
    fNFT10Address, // fNft
    await fNft10.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft10.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO10Address = await IFOFactory.getIFO(fNFT10Address);

  // NFT11 No IFO

  // NFT12 IFO
  await IFOFactory.create(
    fNFT12Address, // fNft
    await fNft12.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft12.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );
  const IFO12Address = await IFOFactory.getIFO(fNFT12Address);

  // NFT13 IFO
  await IFOFactory.create(
    fNFT13Address, // fNft
    await fNft13.totalSupply(), // amount for sale
    parseFixed('1', 18), // price
    await fNft13.totalSupply(), // cap
    1_000_000, // short duration for purposes of testing
    false // allow whitelisting
  );
  const IFO13Address = await IFOFactory.getIFO(fNFT13Address);


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
  const fNft6Price: BigNumber = await fNft6.callStatic.getAuctionPrice();

  // cast one vote. wont reach quorum.
  await fNft6.connect(signers[0]).updateUserPrice(fNft6Price.add(parseFixed('1', 18)));


  // Scenario 7 ends here. fNft has votes and reaches quorum.
  const fNft7Price: BigNumber = await fNft7.callStatic.getAuctionPrice();
  signers.slice(9, 19).forEach(async (signer) => {
    await fNft7.connect(signer).updateUserPrice(fNft7Price.add(parseFixed('1', 18)));
  }); // all holders vote in favor of new price. vote reaches quorum.

  // get global min percentage increase for auction bids
  const fnftFactory = await getContract(hre, 'FNFTFactory');
  const minIncrease = await fnftFactory.minBidIncrease()
  const minPercentIncrease = (minIncrease / PERCENTAGE_SCALE) + 1
  console.log(`minPercentIncrease === ${minPercentIncrease}`)


  // SCENARIO 8
  // start auction on NFT8. deployer will win.
  let auctionPrice8 = await fNft8.getAuctionPrice();
  await fNft8.start({value: auctionPrice8});

  // signer 1 bids
  let livePrice = await fNft8.livePrice();
  auctionPrice8 = livePrice * minPercentIncrease;
  await fNft8.connect(signers[1]).bid({value: BigNumber.from(auctionPrice8.toString())})

  // deployer out bids signer 1
  livePrice = await fNft8.livePrice();
  auctionPrice8 = livePrice * minPercentIncrease;
  await fNft8.bid({value: BigNumber.from(auctionPrice8.toString())})

  // move time forward so we can end the auction
  const auctionLength = (await fNft8.auctionLength()).toNumber();
  await increaseBlockTimestamp(auctionLength);

  // SCENARIO 8 FINISHED
  await fNft8.end();


  // SCENARIO 9 FINISHED, auction that has started
  let auctionPrice9 = await fNft9.getAuctionPrice();
  await fNft9.start({value: auctionPrice9});


  // SCENARIO 10 FINISHED, ongoing bid war
  let auctionPrice10 = await fNft10.getAuctionPrice();
  await fNft10.start({value: auctionPrice10});
  signers.slice(9,14).forEach(async (signer) => {
    auctionPrice10 *= minPercentIncrease;
    await fNft10.connect(signer).bid({value: BigNumber.from(auctionPrice10.toString())})
  });


  // SCENARIO 11, curator redeems
  console.log(`fnft11.totalSupply() === ${await fNft11.totalSupply()}`)
  console.log(`fnft11.balanceOf(deployer) === ${await fNft11.balanceOf(deployer)}`)
  await fNft11.redeem()


  // SCENARIO 12, half of the buyers cashout
  let auctionPrice12 = await fNft12.getAuctionPrice();
  await fNft12.start({value: auctionPrice12});
  signers.slice(0,3).forEach(async (signer) => {
    auctionPrice12 *= minPercentIncrease;
    await fNft12.connect(signer).bid({value: BigNumber.from(auctionPrice12.toString())});
  });
  // deployer out bids and wins nft
  livePrice = await fNft12.livePrice();
  auctionPrice12 *= minPercentIncrease;
  await fNft12.bid({value: BigNumber.from(auctionPrice12.toString())});

  // move time forward so we can end the auction
  const auctionLength12 = (await fNft12.auctionLength()).toNumber();
  await increaseBlockTimestamp(auctionLength12);
  await fNft12.end();

  // SCENARIO 12 ends here, everyone cashes out
  signers.slice(0,9).forEach(async (signer) => {
    await fNft12.connect(signer).cash();
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
