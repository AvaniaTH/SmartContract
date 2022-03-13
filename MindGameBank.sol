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

contract MindGameBank is
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeMath for uint256;

    struct SaleRound {
        uint256 amount;
        uint256 rate;
        uint256 start;
        uint256 end;
        uint256 limit; // Buy amount limit;
        address acceptToken;
        bool onlyWhitelisted;
        bool paused;
        uint256 sold;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BANKER_ROLE = keccak256("BANKER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event Exchanged(
        address indexed exchanger,
        uint256 inputAmount,
        uint256 outputToken
    );

    IERC20 private _bankToken;
    address private _bankAddress;

    mapping(uint256 => mapping(address => bool)) private _whitelisted;
    mapping(uint256 => SaleRound) private _rounds;
    mapping(uint256 => mapping(address => uint256)) private _bought;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(BANKER_ROLE, msg.sender);
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

    function setBankToken(address _address) external onlyRole(ADMIN_ROLE) {
        _bankToken = IERC20(_address);
    }

    function setBankAddress(address _address) external onlyRole(ADMIN_ROLE) {
        _bankAddress = _address;
    }

    function updateWhiteListed(
        address[] memory _addresses,
        uint256 roundId,
        bool allowed
    ) external onlyRole(BANKER_ROLE) {
        for (uint256 a = 0; a < _addresses.length; a++) {
            _whitelisted[roundId][_addresses[a]] = allowed;
        }
    }

    function upsertSaleRound(
        uint256 roundId,
        uint256 _amount,
        uint256 _rate,
        uint256 _start,
        uint256 _end,
        uint256 _limit,
        address _acceptToken,
        bool _onlyWhitelisted,
        bool _paused
    ) external onlyRole(BANKER_ROLE) {
        SaleRound storage round = _rounds[roundId];
        require(
            round.amount == 0 || block.timestamp < round.start,
            "Cannot update started round"
        );
        round.amount = _amount;
        round.rate = _rate;
        round.start = _start;
        round.end = _end;
        round.limit = _limit;
        round.acceptToken = _acceptToken;
        round.onlyWhitelisted = _onlyWhitelisted;
        round.paused = _paused;
        round.sold = 0;
    }

    function pauseSaleRound(uint256 roundId, bool _paused)
        external
        onlyRole(PAUSER_ROLE)
    {
        _rounds[roundId].paused = _paused;
    }

    function tokenUseForRoundId(uint256 roundId)
        external
        view
        returns (address)
    {
        return _rounds[roundId].acceptToken;
    }

    function availableExchangeForRoundId(uint256 roundId)
        external
        view
        returns (uint256)
    {
        SaleRound memory round = _rounds[roundId];
        uint256 bought = _bought[roundId][msg.sender];
        if (round.limit > bought) {
            return round.limit.sub(bought);
        }
        return 0;
    }

    function availableTokenForRoundId(uint256 roundId)
        external
        view
        returns (uint256)
    {
        if (_rounds[roundId].amount > _rounds[roundId].sold) {
            return _rounds[roundId].amount.sub(_rounds[roundId].sold);
        }
        return 0;
    }

    function exchange(uint256 roundId, uint256 inputAmount)
        external
        whenNotPaused
        nonReentrant
    {
        SaleRound storage round = _rounds[roundId];
        uint256 outputToken = inputAmount.mul(round.rate);
        uint256 tokenExchanged = _bought[roundId][msg.sender].add(outputToken);
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
        require(
            round.limit == 0 || tokenExchanged <= round.limit,
            "Limit Reach"
        );
        require(_bankAddress != address(0), "Round not ready");
        require(_bankToken.balanceOf(_bankAddress) > 0, "Token not ready");

        _bought[roundId][msg.sender] = tokenExchanged;

        IERC20 token = IERC20(round.acceptToken);
        token.transferFrom(msg.sender, _bankAddress, inputAmount);
        _bankToken.transferFrom(_bankAddress, msg.sender, outputToken);

        round.sold = round.sold.add(outputToken);

        emit Exchanged(msg.sender, inputAmount, outputToken);
    }
}
