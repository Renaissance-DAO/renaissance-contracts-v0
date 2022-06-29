## Ideas:
## FNFT Utility
1. Trading an FNFT allows you to gain exposure to the upside of blue-chip NFTs
2. Holding an FNFT or FNFT-ETH LP entitles you to an ART APY boost (discuss mechanism)
3. (OPTION): inter-token mechanics
    1. Holding an FNFT or the FNFT-ETH LP token allows you to vote on FNFT liquidation bids
    2. Holding a certain % of an FNFT will allow you to withdraw the NFT and payout the remaining holders.
## FNFT Lifecycle
### Birth of an FNFT
1. DAO buys NFT on mainnet
2. DAO bridges NFT to Aurora
3. DAO uses the NFT as the underlying asset and creates a new FNFT contract for that token with a fixed amount of fractions (e.g. 1000).
4. (OPTION): Create an LP - [(dev note) uniRouter.addLiquidity](https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L61) - for the FNFT ERC20s at a _slight_ discount, (e.g. if the DAO bought the nft for 1000ETH and made 1000 fractions, the LP would be created with 950ETH and 1000 fractions, so the initial price of an FNFT would be .95ETH)
    1. DAO creates a new liquidity pool with ETH using 100% of the FNFT supply - i.e: the DAO moves all the fractions into the market for trading (net result: more swapping fees for the treasury)
    2. DAO holds 50% of the FNFTs and creates an LP with the other 50% (net result: more governance over the FNFT lifecycle? - (plus other benefits?))
    - NOTE: 10*3 of both the initial tokens are frozen forever when the pool is created
- NOTE: In terms of the protocol, the process would be the exact same for any NFT holder, this would _not_ be a permissioned smart contract and anyone could create an FNFT token from their own NFT.


### Death of an FNFT (liquidation)
1. (OPTION) Have a redemption mechanism - redeemer owns greater than a certain % of the totalSupply *OR* an `accept bid -> sell -> payout holders` process -- *OR* both?
    1. REDEMPTION: if you own more than a certain defined percent of the FNFT totalsupply (e.g. 95%), then you have the right to withdraw/liquidate the NFT from the FNFT token?
        - Steps
            1. The buyer pays out the remaining 5% holders as (LP_LAST_TRADED_PRICE * (TOTAL_SUPPLY * .05)) in ETH to the FNFT smart contract.
            2. Remaining holders or liquidity providers then can remove their liquidity from the pool and receive their payout on the FNFT contract.
    2. BID: You could escrow a bid for the underlying NFT at the FNFT contract with an expiry date.
        - As a FNFT holder, you get voting rights to vote in favor of the sale *or* ignore the bid.
        - If the bid expires, the bidder can withdraw their escrow.
        - If a bid is accepted by a THRESHOLD amount of votes, the escrow stays in the FNFT contract. The contract goes into a multi-day cooldown to allow for the market (liquidity pools) to settle.
        - FNFT holders can then withdraw their payout with the payout ratio being: `userBalance / totalSupply`
2. Buyer - or redeemer - can withdraw the underlying NFT from the FNFT ERC20 contract.
3. We of course keep the contract open and usable, even though it's intrinsic value will be theoretically 0
- (IDEA): we could change the FNFT name to `🔒FNFT` or `🔥FNFT` upon liquidation to indicate there is no underlying asset

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
run test with specific network
`forge test -f https://rpc.api.moonbase.moonbeam.network -vvv --force`
run specific test
`forge test --match-contract IFOTest`
run gas costs
`forge test --gas-report`

## setup seed data / subgraph
-run yarn install and forge install and whatever else to setup project
-then run yarn dev:seed
--this will start a local hardhat node with seed data from the first 2 and a few other unfinished sceanrios (sceanrio 3 almost finished)

-after start local hardhat node with seed data the logs printed out will give you an rpc address to your hardhat rpc (should look like this: http://127.0.0.1:8545/

-go to subgraph directory and update the docker-compose.yml file "ethereum" environment variable to point to your local hardhat RPC. it should look like this: 'mainnet:http://host.docker.internal:8545'

-subgraph should be connected to local hardhat node and should start reading event data