// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/INexus.sol";

contract MindGameStore is
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeMath for uint256;

    struct SaleRound {
        address addressNFT;
        uint256 price;
        uint256 amount;
        uint256 start;
        uint256 end;
        uint256 delay; // Buy delay
        uint256 limit; // Buy amount limit
        address acceptToken;
        bool onlyWhitelisted;
        bool paused;
        uint256 sold;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address private _storeWallet;

    mapping(uint256 => mapping(address => bool)) private _whitelisted;
    mapping(uint256 => SaleRound) private _rounds;
    mapping(uint256 => mapping(address => uint256)) private _bought;
    mapping(uint256 => mapping(address => uint256)) private _latest;

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

    function setWallet(address _address) external onlyRole(ADMIN_ROLE) {
        _storeWallet = _address;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function updateWhiteListed(
        address[] memory _addresses,
        uint256 roundId,
        bool allowed
    ) external onlyRole(ADMIN_ROLE) {
        for (uint256 a = 0; a < _addresses.length; a++) {
            _whitelisted[roundId][_addresses[a]] = allowed;
        }
    }

    function pauseSaleRound(uint256 roundId, bool _paused)
        external
        onlyRole(PAUSER_ROLE)
    {
        _rounds[roundId].paused = _paused;
    }

    function nftForRoundId(uint256 roundId) external view returns (address) {
        return _rounds[roundId].addressNFT;
    }

    function availableForRoundId(uint256 roundId)
        external
        view
        returns (uint256)
    {
        if (_rounds[roundId].amount > _rounds[roundId].sold) {
            return _rounds[roundId].amount.sub(_rounds[roundId].sold);
        }
        return 0;
    }

    function upsertSaleRound(
        uint256 roundId,
        address _addressNFT,
        uint256 _price,
        uint256 _amount,
        uint256 _start,
        uint256 _end,
        uint256 _delay,
        uint256 _limit,
        address _acceptToken,
        bool _onlyWhitelisted,
        bool _paused
    ) external onlyRole(ADMIN_ROLE) {
        SaleRound storage round = _rounds[roundId];
        require(
            round.amount == 0 || block.timestamp <= round.start,
            "Cannot update started round"
        );
        round.addressNFT = _addressNFT;
        round.price = _price;
        round.amount = _amount;
        round.start = _start;
        round.end = _end;
        round.delay = _delay;
        round.limit = _limit;
        round.acceptToken = _acceptToken;
        round.onlyWhitelisted = _onlyWhitelisted;
        round.paused = _paused;
        round.sold = 0;
    }

    function purchase(
        uint256 roundId,
        uint256 tokenId,
        string memory uri
    ) external whenNotPaused nonReentrant {
        SaleRound storage round = _rounds[roundId];
        uint256 bought = _bought[roundId][msg.sender].add(1);
        require(round.paused == false, "Paused");
        require(
            round.start <= block.timestamp && block.timestamp <= round.end,
            "Round period outbound"
        );
        require(round.amount > round.sold, "OutOfStock");
        require(
            round.onlyWhitelisted == false || _whitelisted[roundId][msg.sender],
            "Not in whitelisted"
        );
        require(round.limit == 0 || bought <= round.limit, "Limit Reach");
        require(
            round.delay == 0 ||
                block.timestamp <=
                _latest[roundId][msg.sender].add(round.delay),
            "Slow down"
        );
        require(round.price > 0, "Round not ready");
        require(_storeWallet != address(0), "Store not ready");

        _bought[roundId][msg.sender] = bought;
        _latest[roundId][msg.sender] = block.timestamp;
        round.sold++;

        IERC20(round.acceptToken).transferFrom(
            msg.sender,
            _storeWallet,
            round.price
        );

        INexus(round.addressNFT).safeMint(msg.sender, tokenId, uri);
    }
}
