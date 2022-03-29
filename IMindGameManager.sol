// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMindGameManager {
    function validateAntiSnipe(address _to, uint256 _value)
        external
        view
        returns (bool allow, string memory message);
}
