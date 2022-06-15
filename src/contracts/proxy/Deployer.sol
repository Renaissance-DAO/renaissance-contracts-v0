//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../FNFTFactory.sol";
import "../IFOFactory.sol";
import "../PriceOracle.sol";
import "../FNFTCollectionFactory.sol";
import "../FeeDistributor.sol";
import "../LPStaking.sol";
import "../StakingTokenProvider.sol";
import "./AdminUpgradeabilityProxy.sol";
import "./IMultiProxyController.sol";
import "../interfaces/IOwnable.sol";

contract Deployer is Ownable {
    event ProxyDeployed(
        bytes32 indexed _identifier,
        address _logic,
        address _creator
    );

    error NoController();

    IMultiProxyController public proxyController;

    bytes32 constant public FNFT_FACTORY = bytes32(0x464e4654466163746f7279000000000000000000000000000000000000000000);
    bytes32 constant public IFO_FACTORY = bytes32(0x49464f466163746f727900000000000000000000000000000000000000000000);
    bytes32 constant public PRICE_ORACLE = bytes32(0x50726963654f7261636c65000000000000000000000000000000000000000000);
    bytes32 constant public FNFT_COLLECTION_FACTORY = bytes32(0x464e4654436f6c6c656374696f6e466163746f72790000000000000000000000);
    bytes32 constant public FEE_DISTRIBUTOR = bytes32(0x4665654469737472696275746f72000000000000000000000000000000000000);
    bytes32 constant public LP_STAKING = bytes32(0x4c505374616b696e670000000000000000000000000000000000000000000000);
    bytes32 constant public STAKING_TOKEN_PROVIDER = bytes32(0x5374616b696e67546f6b656e50726f7669646572000000000000000000000000);

    // Gov

    function setProxyController(address _controller) external onlyOwner {
        proxyController = IMultiProxyController(_controller);
    }

    /// @notice the function to deploy FNFTFactory
    /// @param _logic the implementation
    /// @param _weth variable needed for FNFTFactory
    /// @param _ifoFactory variable needed for FNFTFactory
    function deployFNFTFactory(
        address _logic,
        address _weth,
        address _priceOracle,
        address _ifoFactory,
        address _feeDistributor
    ) external onlyOwner returns (address fnftFactory) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTFactory.initialize.selector,
            _weth,
            _ifoFactory,
            _feeDistributor
        );

        fnftFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IFNFTFactory(fnftFactory).setFeeReceiver(payable(msg.sender));
        IFNFTFactory(fnftFactory).setPriceOracle(_priceOracle);
        IOwnable(fnftFactory).transferOwnership(msg.sender);        

        proxyController.deployerUpdateProxy(FNFT_FACTORY, fnftFactory);

        emit ProxyDeployed(FNFT_FACTORY, fnftFactory, msg.sender);
    }

    /// @notice the function to deploy IFOFactory
    /// @param _logic the implementation
    function deployIFOFactory(
        address _logic
    ) external onlyOwner returns (address ifoFactory) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(IFOFactory.initialize.selector);

        ifoFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IIFOFactory(ifoFactory).setFeeReceiver(payable(msg.sender));
        IOwnable(ifoFactory).transferOwnership(msg.sender);        

        proxyController.deployerUpdateProxy(IFO_FACTORY, ifoFactory);

        emit ProxyDeployed(IFO_FACTORY, ifoFactory, msg.sender);
    }

    /// @notice the function to deploy PriceOracle
    /// @param _logic the implementation
    function deployPriceOracle(address _logic) external onlyOwner returns (address priceOracle) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            PriceOracle.initialize.selector
        );

        priceOracle = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(priceOracle).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(PRICE_ORACLE, priceOracle);

        emit ProxyDeployed(PRICE_ORACLE, priceOracle, msg.sender);
    }

    /// @notice the function to deploy FeeDistributor
    /// @param _logic the implementation
    function deployFeeDistributor(address _logic, address lpStaking, address treasury) external onlyOwner returns (address feeDistributor) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FeeDistributor.__FeeDistributor__init__.selector,
            lpStaking,
            treasury
        );

        feeDistributor = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(feeDistributor).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(FEE_DISTRIBUTOR, feeDistributor);

        emit ProxyDeployed(FEE_DISTRIBUTOR, feeDistributor, msg.sender);
    }

    /// @notice the function to deploy FNFTCollectionFactory
    /// @param _logic the implementation
    function deployFNFTCollectionFactory(
        address _logic,         
        address _weth, 
        address _priceOracle, 
        address feeDistributor
    ) external onlyOwner returns (address factory) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTCollectionFactory.__FNFTCollectionFactory_init.selector,
            _weth,
            feeDistributor
        );

        factory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IFNFTCollectionFactory(factory).setPriceOracle(_priceOracle);
        IOwnable(factory).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(FNFT_COLLECTION_FACTORY, factory);

        emit ProxyDeployed(FNFT_COLLECTION_FACTORY, factory, msg.sender);
    }

    /// @notice the function to deploy LPStaking
    /// @param _logic the implementation
    function deployLPStaking(address _logic, address stakingTokenProvider) external onlyOwner returns (address lpStaking) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            LPStaking.__LPStaking__init.selector,
            stakingTokenProvider
        );

        lpStaking = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(lpStaking).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(LP_STAKING, lpStaking);

        emit ProxyDeployed(LP_STAKING, lpStaking, msg.sender);
    }

    /// @notice the function to deploy StakingTokenProvider
    /// @param _logic the implementation
    function deployStakingTokenProvider(address _logic, address uniswapV2Factory, address defaultPairedToken, string memory defaultPrefix) external onlyOwner returns (address stakingTokenProvider) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            StakingTokenProvider.__StakingTokenProvider_init.selector,
            uniswapV2Factory,
            defaultPairedToken,
            defaultPrefix
        );

        stakingTokenProvider = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(stakingTokenProvider).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(STAKING_TOKEN_PROVIDER, stakingTokenProvider);

        emit ProxyDeployed(STAKING_TOKEN_PROVIDER, stakingTokenProvider, msg.sender);
    }
}
