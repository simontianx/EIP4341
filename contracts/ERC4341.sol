// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC4341.sol";
import "./IERC4341Receiver.sol";

contract ERC4341 is IERC4341, Ownable {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mappring from account to phrases by phraseId
    mapping(address => mapping(uint256 => uint256[])) private _phrases;

    // Mappring from account to phrase counts
    mapping(address => uint256) private _phraseCounts;

    /**
     * @dev See {IERC4341-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual override returns (uint256) {
        require(
            account != address(0),
            "ERC4341: balance query for the zero address"
        );
        return _balances[id][account];
    }

    /**
     * @dev See {IERC4341-balanceOfPhrase}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOfPhrase(
        address account
    ) public view virtual override returns (uint256) {
        require(
            account != address(0),
            "ERC4341: balance query for the zero address"
        );
        return _phraseCounts[account];
    }

    /**
     * @dev See {IERC4341-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(
            accounts.length == ids.length,
            "ERC4341: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC4341-setApprovalForAll}.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        require(
            _msgSender() != operator,
            "ERC4341: setting approval status for self"
        );

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC4341-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC4341-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC4341: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC4341-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(to != address(0), "ERC4341: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC4341: transfer caller is not owner nor approved"
        );

        _beforeTokenTransfer(from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC4341: insufficient balance for transfer"
            );
            _balances[id][from] = fromBalance - amount;
            _balances[id][to] += amount;
        }

        emit TransferBatch(from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(from, to, ids, amounts, data);
    }

    /**
     * @dev See {IERC4341-safePhraseTransferFrom}.
     */
    function safePhraseTransferFrom(
        address from,
        address to,
        uint256[] memory phrase,
        bytes memory data
    ) public virtual override {
        require(to != address(0), "ERC4341: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC4341: transfer caller is not owner nor approved"
        );

        _beforeTokenTransfer(from, to, phrase, _asSingletonArray(1), data);

        for (uint256 i = 0; i < phrase.length; ++i) {
            uint256 id = phrase[i];
            _balances[id][from]--;
            _balances[id][to]++;
        }

        uint256 nextPid = _phraseCounts[to] + 1;
        _phrases[to][nextPid] = phrase;
        _phraseCounts[to] = nextPid;

        emit TransferBatch(from, to, phrase, _asSingletonArray(1));

        _doSafeBatchTransferAcceptanceCheck(
            from,
            to,
            phrase,
            _asSingletonArray(1),
            data
        );
    }

    /**
     * @dev See {IERC4341-retrievePhrase}.
     */
    function retrievePhrase(
        address owner,
        uint256 phraseId
    ) public view virtual override returns (uint256[] memory) {
        return _phrases[owner][phraseId];
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC4341Receiver-onERC4341Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC4341: transfer to the zero address");

        _beforeTokenTransfer(
            from,
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        uint256 fromBalance = _balances[id][from];
        require(
            fromBalance >= amount,
            "ERC4341: insufficient balance for transfer"
        );
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit Transfer(from, to, id, amount);

        _doSafeTransferAcceptanceCheck(from, to, id, amount, data);
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC4341Receiver-onERC4341Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC4341: mint to the zero address");

        _beforeTokenTransfer(
            address(0),
            account,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        _balances[id][account] += amount;
        emit Transfer(address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(address(0), account, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc4341.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC4341Receiver-onERC4341BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC4341: mint to the zero address");
        require(
            ids.length == amounts.length,
            "ERC4341: ids and amounts length mismatch"
        );

        _beforeTokenTransfer(address(0), to, ids, amounts, data);

        for (uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC4341: burn from the zero address");

        _beforeTokenTransfer(
            account,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ""
        );

        uint256 accountBalance = _balances[id][account];
        require(
            accountBalance >= amount,
            "ERC4341: burn amount exceeds balance"
        );
        _balances[id][account] = accountBalance - amount;

        emit Transfer(account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc4341.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC4341: burn from the zero address");
        require(
            ids.length == amounts.length,
            "ERC4341: ids and amounts length mismatch"
        );

        _beforeTokenTransfer(account, address(0), ids, amounts, "");

        for (uint i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(
                accountBalance >= amount,
                "ERC4341: burn amount exceeds balance"
            );
            _balances[id][account] = accountBalance - amount;
        }

        emit TransferBatch(account, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC4341Receiver(to).onERC4341Received(from, id, amount, data)
            returns (bytes4 response) {
                if (
                    response != IERC4341Receiver(to).onERC4341Received.selector
                ) {
                    revert("ERC4341: ERC4341Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC4341: transfer to non ERC4341Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC4341Receiver(to).onERC4341BatchReceived(
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response !=
                    IERC4341Receiver(to).onERC4341BatchReceived.selector
                ) {
                    revert("ERC4341: ERC4341Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC4341: transfer to non ERC4341Receiver implementer");
            }
        }
    }

    function _asSingletonArray(
        uint256 element
    ) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
