// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract MindGameManager is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeMath for uint256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => bool) private _beneficiary;

    uint256 private _limitReceived;
    uint256 private _limitUntil;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function setBeneficiary(address beneficiary, bool allow)
        external
        onlyRole(ADMIN_ROLE)
    {
        _beneficiary[beneficiary] = allow;
    }

    function setBeneficiaries(address[] memory beneficiaries, bool allow)
        external
        onlyRole(ADMIN_ROLE)
    {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _beneficiary[beneficiaries[i]] = allow;
        }
    }

    function setLimitReceived(uint256 limit) external onlyRole(ADMIN_ROLE) {
        _limitReceived = limit;
    }

    function setLimitTimeUntil(uint256 until) external onlyRole(ADMIN_ROLE) {
        _limitUntil = until;
    }

    function validateAntiSnipe(address _to, uint256 _value)
        external
        view
        returns (bool allow, string memory message)
    {
        if (block.timestamp < _limitUntil) {
            if (_beneficiary[_to] == false) {
                return (false, "Receiver is not a beneficiary");
            }
            if (_value > _limitReceived) {
                return (false, "Beneficiary has reached the limit");
            }
        }
        return (true, "");
    }
}
