// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./StakingModule.sol";
import "./VestingModule.sol";

contract EvilMergedToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    uint256 public constant TOTAL_SUPPLY = 25_000_000_000 * 10**18; // 25 Billion
    uint256 public constant STAKING_POOL = 2_500_000_000 * 10**18; // 10% for staking

    // Burn Mechanism
    uint256 public tradeMilestone;
    uint256 public milestoneBurnRate;
    uint256 public totalBurned;
    uint256 public currentMilestone;

    // Fee Structure
    uint256 public liquidityFee;
    uint256 public marketingFee;
    uint256 public communityFee;

    address public liquidityWallet;
    address public marketingWallet;
    address public daoTreasury;

    StakingModule public stakingModule;
    VestingModule public vestingModule;

    mapping(address => bool) public isExcludedFromFees;

    // Events
    event TokensBurned(uint256 amount);
    event FeeDistributed(uint256 liquidity, uint256 marketing, uint256 community);
    event TransactionFeesUpdated(uint256 liquidityFee, uint256 marketingFee, uint256 communityFee);
    event FeeWalletsUpdated(address liquidityWallet, address marketingWallet, address daoTreasury);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        string memory name,
        string memory symbol,
        address _liquidityWallet,
        address _marketingWallet,
        address _daoTreasury,
        address stakingModuleAddress,
        address vestingModuleAddress
    ) public initializer {
        require(
            _liquidityWallet != address(0) &&
            _marketingWallet != address(0) &&
            _daoTreasury != address(0) &&
            stakingModuleAddress != address(0) &&
            vestingModuleAddress != address(0),
            "Invalid addresses"
        );

        __ERC20_init(name, symbol);
        __Ownable_init();

        _mint(msg.sender, TOTAL_SUPPLY);

        liquidityWallet = _liquidityWallet;
        marketingWallet = _marketingWallet;
        daoTreasury = _daoTreasury;

        // Initialize Fees
        liquidityFee = 50; // 0.5%
        marketingFee = 25; // 0.25%
        communityFee = 25; // 0.25%

        stakingModule = StakingModule(stakingModuleAddress);
        vestingModule = VestingModule(vestingModuleAddress);

        isExcludedFromFees[msg.sender] = true;

        // Initialize Burn Parameters
        tradeMilestone = 1_000_000 * 10**18; // Example milestone
        milestoneBurnRate = 1; // 0.1%
    }

    // Burn Mechanism
    function _checkAndBurnMilestone(uint256 amount) internal {
        currentMilestone += amount;
        if (currentMilestone >= tradeMilestone) {
            uint256 burnAmount = (currentMilestone * milestoneBurnRate) / 1000;
            _burn(address(this), burnAmount);
            totalBurned += burnAmount;
            currentMilestone = 0;

            emit TokensBurned(burnAmount);
        }
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
        totalBurned += amount;

        emit TokensBurned(amount);
    }

    // Transfer with Fees and Burn
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 netAmount = amount;

        if (!isExcludedFromFees[sender] && !isExcludedFromFees[recipient]) {
            uint256 fees = _applyFees(sender, amount);
            netAmount -= fees;
        }

        _checkAndBurnMilestone(netAmount);
        super._transfer(sender, recipient, netAmount);
    }

    function _applyFees(address sender, uint256 amount) internal returns (uint256) {
        uint256 liquidityShare = (amount * liquidityFee) / 10000;
        uint256 marketingShare = (amount * marketingFee) / 10000;
        uint256 communityShare = (amount * communityFee) / 10000;

        if (liquidityShare > 0) super._transfer(sender, liquidityWallet, liquidityShare);
        if (marketingShare > 0) super._transfer(sender, marketingWallet, marketingShare);
        if (communityShare > 0) super._transfer(sender, daoTreasury, communityShare);

        emit FeeDistributed(liquidityShare, marketingShare, communityShare);

        return liquidityShare + marketingShare + communityShare;
    }

    // Admin Functions
    function updateMilestoneParams(uint256 _tradeMilestone, uint256 _milestoneBurnRate) external onlyOwner {
        tradeMilestone = _tradeMilestone;
        milestoneBurnRate = _milestoneBurnRate;
    }

    function updateFees(
        uint256 _liquidityFee,
        uint256 _marketingFee,
        uint256 _communityFee
    ) external onlyOwner {
        require(_liquidityFee + _marketingFee + _communityFee <= 500, "Fees too high"); // Max 5%
        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;
        communityFee = _communityFee;

        emit TransactionFeesUpdated(liquidityFee, marketingFee, communityFee);
    }

    function updateFeeWallets(
        address _liquidityWallet,
        address _marketingWallet,
        address _daoTreasury
    ) external onlyOwner {
        liquidityWallet = _liquidityWallet;
        marketingWallet = _marketingWallet;
        daoTreasury = _daoTreasury;

        emit FeeWalletsUpdated(liquidityWallet, marketingWallet, daoTreasury);
    }

    function setFeeExemption(address account, bool exempted) external onlyOwner {
        isExcludedFromFees[account] = exempted;
    }

    // Staking Functions
    function stake(uint256 amount) external {
        _transfer(msg.sender, address(stakingModule), amount);
        stakingModule.stake(msg.sender, amount);
    }

    function claimRewards() external {
        uint256 reward = stakingModule.claimRewards(msg.sender);
        _mint(msg.sender, reward);
    }
}
