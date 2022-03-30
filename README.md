## Ideas:
## fNFT Utility
1. Trading an fNFT allows you to gain exposure to the upside of blue-chip NFTs
2. Holding an fNFT or fNFT-ETH LP entitles you to an ART APY boost (discuss mechanism)
3. (OPTION): inter-token mechanics
    1. Holding an fNFT or the fNFT-ETH LP token allows you to vote on fNFT liquidation bids
    2. Holding a certain % of an fNFT will allow you to withdraw the NFT and payout the remaining holders.
## fNFT Lifecycle
### Birth of an fNFT
1. DAO buys NFT on mainnet
2. DAO bridges NFT to Aurora
3. DAO uses the NFT as the underlying asset and creates a new fNFT contract for that token with a fixed amount of fractions (e.g. 1000).
4. (OPTION): Create an LP - [(dev note) uniRouter.addLiquidity](https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L61) - for the fNFT ERC20s at a _slight_ discount, (e.g. if the DAO bought the nft for 1000ETH and made 1000 fractions, the LP would be created with 950ETH and 1000 fractions, so the initial price of an fNFT would be .95ETH)
    1. DAO creates a new liquidity pool with ETH using 100% of the fNFT supply - i.e: the DAO moves all the fractions into the market for trading (net result: more swapping fees for the treasury)
    2. DAO holds 50% of the fNFTs and creates an LP with the other 50% (net result: more governance over the fNFT lifecycle? - (plus other benefits?))
    - NOTE: 10*3 of both the initial tokens are frozen forever when the pool is created
- NOTE: In terms of the protocol, the process would be the exact same for any NFT holder, this would _not_ be a permissioned smart contract and anyone could create an fNFT token from their own NFT.


### Death of an fNFT (liquidation)
1. (OPTION) Have a redemption mechanism - redeemer owns greater than a certain % of the totalSupply *OR* an `accept bid -> sell -> payout holders` process -- *OR* both?
    1. REDEMPTION: if you own more than a certain defined percent of the fNFT totalsupply (e.g. 95%), then you have the right to withdraw/liquidate the NFT from the fNFT token?
        - Steps
            1. The buyer pays out the remaining 5% holders as (LP_LAST_TRADED_PRICE * (TOTAL_SUPPLY * .05)) in ETH to the fNFT smart contract.
            2. Remaining holders or liquidity providers then can remove their liquidity from the pool and receive their payout on the fNFT contract.
    2. BID: You could escrow a bid for the underlying NFT at the fNFT contract with an expiry date. 
        - As a fNFT holder, you get voting rights to vote in favor of the sale *or* ignore the bid.
        - If the bid expires, the bidder can withdraw their escrow.
        - If a bid is accepted by a THRESHOLD amount of votes, the escrow stays in the fNFT contract. The contract goes into a multi-day cooldown to allow for the market (liquidity pools) to settle.
        - fNFT holders can then withdraw their payout with the payout ratio being: `userBalance / totalSupply`
2. Buyer - or redeemer - can withdraw the underlying NFT from the fNFT ERC20 contract.
3. We of course keep the contract open and usable, even though it's intrinsic value will be theoretically 0
- (IDEA): we could change the fNFT name to `🔒fNFT` or `🔥fNFT` upon liquidation to indicate there is no underlying asset

---
### Compile
npx hardhat compile

### Start a local node
npx hardhat node

### Deploy to a local node
npx hardhat run --network localhost dev-scripts/deploy.js

### Deploy to Aurora Testnet
npx hardhat run --network aurora_testnet dev-scripts/deploy.js

### Deploy to Aurora
npx hardhat run --network aurora scripts/deploy.js

## setup forge test
install usbmodule
`git submodule add URL`
install submodules
`git submodule update --init`
install cargo
`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs/ | sh`