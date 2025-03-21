// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title VeggiaBtcPool
 * @author @VeggiesLabs
 * @notice A contract holding the Veggia BTC rewards.
 */
contract VeggiaBtcPool is Ownable2Step, EIP712 {
    using SafeERC20 for IERC20;

    /**
     * @notice A struct that represents a withdraw request.
     * @dev Used to allow anyone to request a withdraw of the rewards.
     * @param to The address that will receive the wBTC.
     * @param amount The amount of wBTC to mint.
     */
    struct WithdrawRequest {
        address to;
        uint256 amount;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */
    IERC20 public wBTC;
    address public rewardSigner;
    mapping(bytes32 => bool) public usedSignatures;

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice The EIP712 domain separator.
     */
    bytes32 private constant _WITHDRAWREQUEST_TYPEHASH = keccak256("WithdrawRequest(address to,uint256 amount)");

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event RewardSignerChanged(address newSigner);
    event RewardWithdrawn(address indexed to, uint256 indexed amount, bytes indexed signature);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Throws if the signature is invalid.
    error INVALID_SENDER(address sender, address expected);
    /// @dev Throws if the signature as already been used.
    error SIGNATURE_REUSED();
    /// @dev Throws if the signature is invalid.
    error INVALID_SIGNATURE();

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */

    constructor(IERC20 _wBTC, address _rewardSigner) Ownable(msg.sender) EIP712("VeggiaBtcPool", "1") {
        wBTC = _wBTC;
        rewardSigner = _rewardSigner;
    }

    /**
     * @notice Withdraw the rewards.
     * @param req The withdraw request.
     * @param signature The signature of the request.
     */
    function withdrawRewards(WithdrawRequest calldata req, bytes calldata signature) external {
        // Ensure the sender is the intended recipient.
        if (req.to != msg.sender) {
            revert INVALID_SENDER(msg.sender, req.to);
        }

        // Check if this mint request has already been processed.
        if (usedSignatures[keccak256(signature)]) {
            revert SIGNATURE_REUSED();
        }

        // Compute the EIP712 digest for the mint request.
        bytes32 digest = hashMintRequest(req);

        // Recover the signer from the digest and signature.
        address recoveredSigner = ECDSA.recover(digest, signature);
        if (recoveredSigner != rewardSigner) {
            revert INVALID_SIGNATURE();
        }

        // Mark the signature as used.
        usedSignatures[keccak256(signature)] = true;

        // Transfer the wBTC to the recipient.
        wBTC.safeTransfer(req.to, req.amount);

        // Emit the event.
        emit RewardWithdrawn(req.to, req.amount, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Only owner features                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Deposit wBTC into the pool.
     * @param _amount The amount of wBTC to deposit.
     */
    function deposit(uint256 _amount) external onlyOwner {
        // Transfer the wBTC to this contract
        wBTC.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Withdraw wBTC from the pool
     * @param _amount The amount of wBTC to withdraw
     */
    function withdraw(uint256 _amount) external onlyOwner {
        // Transfer the wBTC to the owner
        wBTC.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Set the reward signer
     * @param _rewardSigner The new reward signer
     */
    function setRewardSigner(address _rewardSigner) external onlyOwner {
        rewardSigner = _rewardSigner;
        emit RewardSignerChanged(_rewardSigner);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal function                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Hash a mint request.
     * @param req The mint request to hash.
     */
    function hashMintRequest(WithdrawRequest calldata req) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(_WITHDRAWREQUEST_TYPEHASH, req.to, req.amount)));
    }
}
