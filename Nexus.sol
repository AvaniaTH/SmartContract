// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact contact@avania.io
contract Nexus is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    uint256 internal _count;

    mapping(address => bool) private _markets;
    mapping(uint256 => address) private _marketIndexs;
    uint256 private _marketCount;

    mapping(address => uint256) private _whitelisted;
    mapping(address => uint256) private _minted;
    mapping(uint256 => bool) private _suspended;

    bool private _canTransferDirectly;

    event TransferDirectUpdated(bool allowed);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __ERC721_init("Nexus", "Nexus");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(
        address to,
        uint256 tokenId,
        string memory uri
    ) public onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        require(
            hasRole(MANAGER_ROLE, msg.sender) ||
                hasRole(MINTER_ROLE, msg.sender) ||
                isMarketAddress(msg.sender) ||
                isMarketAddress(from) ||
                isMarketAddress(to) ||
                _canTransferDirectly == true,
            "NFT: Not allow direct transfer"
        );
        require(_suspended[tokenId] == false, "NFT: Suspended");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function updateTransferDirect(bool allowed)
        external
        onlyRole(MANAGER_ROLE)
    {
        _canTransferDirectly = allowed;
        emit TransferDirectUpdated(allowed);
    }

    function updateSuspendToken(uint256 _tokenId, bool suspended)
        external
        onlyRole(MANAGER_ROLE)
    {
        _suspended[_tokenId] = suspended;
    }

    function addMarket(address _market) external onlyRole(MANAGER_ROLE) {
        require(isMarketAddress(_market) == false, "NFT: Market was build");
        _markets[_market] = true;
        _marketIndexs[_marketCount] = _market;
        _marketCount = _marketCount + 1;
    }

    function isMarketAddress(address _address) internal view returns (bool) {
        return _markets[_address];
    }

    function approveMarkets() external {
        for (uint256 m = 0; m < _marketCount; m++) {
            setApprovalForAll(_marketIndexs[m], true);
        }
    }
}
