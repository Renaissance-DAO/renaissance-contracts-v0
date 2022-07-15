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
