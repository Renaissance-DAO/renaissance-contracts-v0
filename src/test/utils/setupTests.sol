// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../../../lib/ds-test/src/test.sol";
import {Deployer} from "../../contracts/proxy/Deployer.sol";
import {MultiProxyController} from "../../contracts/proxy/MultiProxyController.sol";
import {CheatCodes} from "./cheatcodes.sol";
import {console} from "./console.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {PriceOracle} from "../../contracts/PriceOracle.sol";
import {IFOFactory} from "../../contracts/IFOFactory.sol";
import {StakingTokenProvider} from "../../contracts/StakingTokenProvider.sol";
import {FNFTCollectionFactory} from "../../contracts/FNFTCollectionFactory.sol";
import {FNFTCollection} from "../../contracts/FNFTCollection.sol";
import {LPStaking} from "../../contracts/LPStaking.sol";
import {InventoryStaking} from "../../contracts/InventoryStaking.sol";
import {FeeDistributor} from "../../contracts/FeeDistributor.sol";
import {IUniswapV2Factory} from "../../contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "../../contracts/interfaces/IUniswapV2Router.sol";
import {IFNFT} from "../../contracts/interfaces/IFNFT.sol";
import {FNFTFactory} from "../../contracts/FNFTFactory.sol";
import {VaultManager} from "../../contracts/VaultManager.sol";
import {FNFT} from "../../contracts/FNFT.sol";
import {MockNFT} from "../../contracts/mocks/NFT.sol";

contract SetupEnvironment {
    Deployer public deployer;
    CheatCodes public vm;
    MultiProxyController public proxyController;
    WETH public weth;
    address constant internal UNISWAP_V2_FACTORY_ADDRESS = 0xc66F594268041dB60507F00703b152492fb176E7;
    address constant internal UNISWAP_V2_ROUTER_ADDRESS = 0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B;
    address constant internal TREASURY_ADDRESS = 0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b;
    address constant internal WETH_ADDRESS = 0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB;

    function setupDeployerAndProxyController() public {
        deployer = new Deployer();
        bytes32[] memory keys;
        address[] memory proxies;
        proxyController = new MultiProxyController(keys, proxies, address(deployer));
        deployer.setProxyController(address(proxyController));
    }

    function setupWETH(uint256 _amountToMint) public {
        weth = new WETH(_amountToMint);
    }

    function setupPairFactory() public pure returns (IUniswapV2Factory v2Factory) {
        v2Factory = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS);
    }

    function setupRouter() public pure returns (IUniswapV2Router router) {
        router = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
    }

    function setupPriceOracle(address v2Factory) public returns (PriceOracle priceOracle) {
        priceOracle = PriceOracle(
            deployer.deployPriceOracle(address(new PriceOracle(v2Factory, address(weth))))
        );
    }

    function setupIFOFactory() public returns (IFOFactory ifoFactory) {
        ifoFactory = IFOFactory(
            deployer.deployIFOFactory(address(new IFOFactory()))
        );
    }

    function setupVaultManager(        
        address _ifoFactory,
        address _priceOracle
    ) public returns (VaultManager vaultManager) {
        vaultManager = VaultManager(
            deployer.deployVaultManager(
                address(new VaultManager()), address(weth), _ifoFactory, _priceOracle
            )
        );
    }

    function setupFNFTFactory(address _vaultManager) public returns (FNFTFactory fnftFactory) {
        fnftFactory = FNFTFactory(
            deployer.deployFNFTFactory(address(new FNFTFactory()), _vaultManager)
        );
    }

    function setupFNFT(address _fnftFactory, uint256 _amountToMint) public returns (FNFT fnft) {
        FNFTFactory factory = FNFTFactory(_fnftFactory);

        MockNFT token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(_fnftFactory, true);

        // FNFT minted on this test contract address.
        fnft = FNFT(factory.mint("testName", "TEST", address(token), 1, _amountToMint, 1 ether, 50));
    }

    function setupFNFTCollectionFactory(address vaultManager) public returns (FNFTCollectionFactory fnftCollectionFactory) {
        fnftCollectionFactory = FNFTCollectionFactory(
            deployer.deployFNFTCollectionFactory(
                address(new FNFTCollectionFactory()),
                vaultManager
            )
        );
    }

    function setupStakingTokenProvider() public returns (StakingTokenProvider stakingTokenProvider) {
        stakingTokenProvider = StakingTokenProvider(
            deployer.deployStakingTokenProvider(
                address(new StakingTokenProvider()),
                UNISWAP_V2_FACTORY_ADDRESS,
                WETH_ADDRESS,
                string("x")
            )
        );
    }

    function setupLPStaking(address vaultManager, address stakingTokenProvider) public returns (LPStaking lpStaking) {
        lpStaking = LPStaking(
            deployer.deployLPStaking(
                address(new LPStaking()),
                vaultManager,
                stakingTokenProvider
            )
        );
    }

    function setupFeeDistributor(address vaultManager, address lpStaking) public returns (FeeDistributor feeDistributor) {
        feeDistributor = FeeDistributor(
            deployer.deployFeeDistributor(
                address(new FeeDistributor()),
                vaultManager,
                lpStaking,
                TREASURY_ADDRESS
            )
        );
    }


    function setupEnvironment(uint256 _wethAmount) public {
        vm = CheatCodes(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        setupDeployerAndProxyController();
        setupWETH(_wethAmount);
    }

    function setupContracts() 
        public
        returns (
            StakingTokenProvider stakingTokenProvider,
            LPStaking lpStaking,
            IFOFactory ifoFactory,        
            IUniswapV2Factory pairFactory,            
            PriceOracle priceOracle,
            FeeDistributor feeDistributor,
            VaultManager vaultManager,            
            FNFTFactory fnftFactory,
            FNFTCollectionFactory fnftCollectionFactory
        )
    {        
        ifoFactory = setupIFOFactory();
        pairFactory = setupPairFactory();   
        priceOracle = setupPriceOracle(address(pairFactory));
        vaultManager = setupVaultManager(address(ifoFactory), address(priceOracle));
        stakingTokenProvider = setupStakingTokenProvider();
        
        lpStaking = setupLPStaking(address(vaultManager), address(stakingTokenProvider));
        feeDistributor = setupFeeDistributor(address(vaultManager), address(lpStaking));
        fnftFactory = setupFNFTFactory(address(vaultManager));
        fnftCollectionFactory = setupFNFTCollectionFactory(address(vaultManager));        

        vaultManager.setFNFTCollectionFactory(address(fnftCollectionFactory));
        vaultManager.setFNFTSingleFactory(address(fnftFactory));
        vaultManager.setFeeDistributor(address(feeDistributor));
    }

    function setupFNFTSingle(address fnftFactory, uint _fnftAmount) public returns (FNFT fnft) {
        fnft = setupFNFT(fnftFactory, _fnftAmount);
    }
}
