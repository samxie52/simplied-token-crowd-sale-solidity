// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Extended is IERC20 {


    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * @param to The address to assign the new tokens to.
     * @param amount The amount of tokens to create.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Destroys `amount` tokens from `from`, deducting from the caller's
     * allowance.
     *
     * @param from The address to destroy tokens from.
     * @param amount The amount of tokens to destroy.
     */
    function burnFrom(address from, uint256 amount) external;

    /**
     * @dev Pauses all token transfers.
     */
    function pause() external;

    /**
     * @dev Unpauses all token transfers.
     */
    function unpause() external;

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     * @return True if the contract is paused, and false otherwise.
     */
    function paused() external view returns (bool);

    /**
     * @dev Returns the maximum supply of the token.
     * @return The maximum supply of the token.
     */
    function maxSupply() external view returns (uint256);


    /**
     * @dev Returns true if the contract can mint the specified amount of tokens, and false otherwise.
     * @param amount The amount of tokens to mint.
     * @return True if the contract can mint the specified amount of tokens, and false otherwise.
     */
    function canMint(uint256 amount) external view returns (bool);

    /**
     * @dev Emitted when `amount` tokens are minted to `to` by `minter`.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     * @param minter The address that minted the tokens.
     */
    event TokenMinted(address indexed to, uint256 amount, address indexed minter);

    /**
     * @dev Emitted when `amount` tokens are burned from `from` by `burner`.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     * @param burner The address that burned the tokens.
     */
    event TokenBurned(address indexed from, uint256 amount, address indexed burner);

    /**
     * @dev Emitted when the maximum supply of the token is updated.
     * @param oldMaxSupply The old maximum supply of the token.
     * @param newMaxSupply The new maximum supply of the token.
     */
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);
}