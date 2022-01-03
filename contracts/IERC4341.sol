// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
    @title EIP-4341 Multi Ordered NFT Standard
    @dev See https://eips.ethereum.org/EIPS/eip-4341
 */
interface IERC4341 /* is IERC165 */ {
    /**
     * @dev Emitted when a token of `id` is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 id, uint256 amount);

    /**
     * @dev Emitted when a batch of tokens with ids `ids` is transferred from
     * `from` to `to`.
     */
    event TransferBatch(address indexed from, address indexed to, uint256[] ids, uint256[] amounts);

    /**
     * @dev Emitted when `owner` grants or revokes permission to `operator` to
     * transfer their tokens, according to `approved`.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Transfers `amount` tokens of token `id` from `from` to `to`.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev Transfers a batch of `amounts` of tokens of `ids` from `from` to `to`
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC4341Receiver-onERC4341BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] memory amounts, bytes calldata _data) external;

    /**
     * @dev Transfers a batch of tokens in a phrase from `from` to `to`
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC4341Receiver-onERC4341BatchReceived} and return the
     * acceptance magic value.
     */
    function safePhraseTransferFrom(address from, address to, uint256[] calldata phrase, bytes calldata data) external;

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev Returns the amount of phrases owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOfPhrase(address account) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc4341.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids) external view returns (uint256[] memory);

    /**
     * @dev Returns a phrase by `phraseId` for `owner`.
     */
    function retrievePhrase(address owner, uint256 phraseId) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
