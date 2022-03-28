// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IMindGameManager.sol";

/// @custom:security-contact contact@avania.io
contract Nova is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl {
    using SafeMath for uint256;
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant BANKER_ROLE = keccak256("BANKER_ROLE");

    IMindGameManager private _mindGameManager;
    bool private _enableAntiSnipe;

    mapping(address => uint256) private _receivers;

    constructor() ERC20("Nova", "NOVA") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        _grantRole(BANKER_ROLE, msg.sender);
        _mint(msg.sender, 230000000 * 10**decimals());
    }

    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    function setMindGameManager(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _mindGameManager = IMindGameManager(_address);
    }

    function setAntiSnipe(bool _enable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _enableAntiSnipe = _enable;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) {
        if (
            _enableAntiSnipe == true && address(_mindGameManager) != address(0)
        ) {
            bool allow;
            string memory message;

            uint256 total = _receivers[to].add(amount);
            (allow, message) = _mindGameManager.validateAntiSnipe(to, total);
            require(allow == true, message);
            _receivers[to] = total;
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
