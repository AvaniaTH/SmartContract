// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract NovaVesting is
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event RedeemTokenSuccess(
        address indexed investor,
        uint256 amount,
        address tokenAddress
    );

    enum INVEST_TYPE {
        SEEDER,
        PRIVATE,
        PUBLIC,
        ADVISOR,
        CORE_TEAM
    }

    struct InvestorInfo {
        uint256 investType;
        uint256 total;
        uint256 redeemed;
    }

    struct VestingInfo {
        uint256 time;
        uint256 percent;
    }

    mapping(address => InvestorInfo) private _investor;
    mapping(uint256 => mapping(uint256 => VestingInfo)) private _vesting;
    mapping(uint256 => uint256) private _vestingCount;

    address private _vestingWallet;
    address private _vestingTokenAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setWallet(address _address) external onlyRole(ADMIN_ROLE) {
        _vestingWallet = _address;
    }

    function setTokenAddress(address _address) external onlyRole(ADMIN_ROLE) {
        _vestingTokenAddress = _address;
    }

    function available() public view returns (uint256) {
        uint256 _available = 0;
        InvestorInfo memory info = _investor[msg.sender];
        if (info.total == 0) {
            return 0;
        }
        mapping(uint256 => VestingInfo) storage vest = _vesting[
            info.investType
        ];
        for (uint256 i = 0; i < _vestingCount[info.investType]; i++) {
            if (vest[i].time < block.timestamp) {
                _available = _available.add(
                    info.total.mul(vest[i].percent).div(100)
                );
            }
        }
        return _available.sub(info.redeemed);
    }

    function upsertVestingInfo(
        uint256 id,
        uint256[] memory times,
        uint256[] memory percents
    ) external onlyRole(ADMIN_ROLE) {
        require(times.length == percents.length, "Data invalid.");
        mapping(uint256 => VestingInfo) storage infos = _vesting[id];
        for (uint256 i = 0; i < times.length; i++) {
            infos[i] = VestingInfo(times[i], percents[i]);
        }
        for (uint256 i = times.length; i < _vestingCount[id]; i++) {
            infos[i] = VestingInfo(0, 0);
        }

        _vestingCount[id] = times.length;
    }

    function addInvestors(
        uint256 t,
        address[] memory _addresses,
        uint256[] memory amount
    ) external onlyRole(ADMIN_ROLE) {
        require(_addresses.length == amount.length, "Data invalid.");
        for (uint256 a = 0; a < _addresses.length; a++) {
            _investor[_addresses[a]] = InvestorInfo(t, amount[a], 0);
        }
    }

    function claimToken(uint256 amount) external nonReentrant whenNotPaused {
        uint256 _available = available();
        require(_available > 0, "Vest Empty");
        require(_available >= amount, "Vest not enough");
        require(_vestingTokenAddress != address(0), "Token not ready");
        require(_vestingWallet != address(0), "Wallet not ready");

        InvestorInfo storage info = _investor[msg.sender];
        info.redeemed = info.redeemed.add(amount);

        IERC20(_vestingTokenAddress).transferFrom(
            _vestingWallet,
            msg.sender,
            amount
        );

        emit RedeemTokenSuccess(msg.sender, amount, _vestingTokenAddress);
    }
}
