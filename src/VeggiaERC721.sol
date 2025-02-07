// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC721TransferLock} from "./ERC721TransferLock.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title VeggiaERC721
 * @author @VeggiesLabs
 * @notice A contract for the Veggia NFTs.
 * @dev This contract is based on the ERC721 standard with additional features.
 */
contract VeggiaERC721 is
	ERC721,
	ERC721Burnable,
	ERC721TransferLock,
	ERC721Royalty,
	Ownable
{
	/* -------------------------------------------------------------------------- */
	/*                                   Storage                                  */
	/* -------------------------------------------------------------------------- */

	/* ---------------------------- Bytes32 storages ---------------------------- */
	/**
	 * @notice The limit of available free caps per account.
	 */
	uint256 public freeMintLimit;
	/**
	 * @notice The cooldown time to unlock a new freeMint3.
	 * @dev Default is 12 hours.
	 */
	uint256 public freeMintCooldown;
	/**
	 * @dev The current token ID.
	 */
	uint256 public tokenId;
	/**
	 * @notice The address that will receive the caps sale revenue.
	 */
	address public feeReceiver;
	/**
	 * @notice The address that sign the mintWithSignature message.
	 */
	address public capsSigner;
	/**
	 * @notice The price of the premium pack.
	 *         1 NFT mint + 12 caps + 3 premium caps.
	 */
	uint256 public premiumPackPrice;

	/* ------------------------------ Bytes storage ----------------------------- */
	/**
	 * @notice The ERC721 base URI.
	 */
	string private baseURI;

	/* ---------------------------- Mappings storage ---------------------------- */
	/**
	 * @notice A mapping of the last free mint timestamp of an account.
	 */
	mapping(address => uint256) public lastMintTimestamp;
	/**
	 * @notice A mapping of the paid caps balance of an account.
	 */
	mapping(address => uint256) public paidCapsBalanceOf;
	/**
	 * @notice A mapping of the paid premium caps balance of an account.
	 */
	mapping(address => uint256) public paidPremiumCapsBalanceOf;
	/**
	 * @notice A mapping that store if an account has already minted a token.
	 * @dev Used to lock the 3rd token of the first mint of an account.
	 */
	mapping(address => bool) public hasMinted;
	/**
	 * @notice A mapping that store if a signature has already been used.
	 */
	mapping(address => mapping(uint256 => bool)) public signatureMintsOf;
	/**
	 * @notice A mapping of the caps price by quantity.
	 */
	mapping(uint256 => uint256) public capsPriceByQuantity;
	/**
	 * @notice A mapping of the premium caps price by quantity.
	 */
	mapping(uint256 => uint256) public premiumCapsPriceByQuantity;

    /* -------------------------------- Constants ------------------------------- */

	/**
	 * @notice The name of the token.
     * @dev Using _ to avoid conflict with the name() function.
	 */
	string private constant _name = "Veggia";
	/**
	 * @notice The symbol of the token.
     * @dev Using _ to avoid conflict with the symbol() function.
	 */
	string private constant _symbol = "VGIA";

	/* -------------------------------------------------------------------------- */
	/*                                   Errors                                   */
	/* -------------------------------------------------------------------------- */
	/// @dev Throws if the account has insufficient caps balance.
	error INSUFFICIENT_CAPS_BALANCE();
	/// @dev Throws if the value sent is not enough.
	error NOT_ENOUGH_VALUE();
	/// @dev Throws if the value sent is not the expected one.
	error WRONG_VALUE();
	/// @dev Throws if the caps quantity is less than 3
	error UNKNOWN_PRICE_FORE(uint256 quantity, bool isPremium);
	/// @dev Throws if the quantity is not the expected one.
	error WRONG_CAPS_QUANTITY();
	/// @dev Throws if the fee transfer failed.
	error FEE_TRANSFER_FAILED();
	/// @dev Throws if the contract is already initialized.
	error ALREADY_INITIALIZED();
	/// @dev Throws if the signature is invalid.
	error INVALID_SIGNATURE();
	/// @dev Throws if the signature as already been used.
	error SIGNATURE_REUSED();
	/// @dev Throws if the sender is not the expected one.
	error INVALID_SENDER(address sender, address expected);
	/// @dev Throws if the free mint limit is not a multiple of 3.
	error FREE_MINT_LIMIT_MUST_BE_MULTIPLE_OF_3();

	/* -------------------------------------------------------------------------- */
	/*                                   Events                                   */
	/* -------------------------------------------------------------------------- */
	event BaseURIChanged(string newBaseURI);
	event CapsPriceChanged(uint256 indexed quantity, uint256 newPrice);
	event PremiumCapsPriceChanged(uint256 indexed quantity, uint256 newPrice);
	event PremiumPackPriceChanged(uint256 newPrice);
	event FreeMintLimitChanged(uint256 newLimit);
	event FreeMintCooldownChanged(uint256 newCooldown);
	event FeeReceiverChanged(address newFeeReceiver);
	event CapsSignerChanged(address newSigner);
	event LockedFirstMintToken(uint256 tokenId);
	event CapsOpened(
		address indexed account,
		uint256 tokenId,
		bool premium,
		bool isPack
	);
	event MintedWithSignature(
		address indexed account,
		bytes message,
		bytes signature
	);
	event DefaultRoyaltyChanged(address receiver, uint96 feeNumerator);

	/* -------------------------------------------------------------------------- */
	/*                                 Constructor                                */
	/* -------------------------------------------------------------------------- */
	constructor(
		address _feeReceiver,
		string memory _baseUri
	) ERC721("Veggia", "VGIA") Ownable(msg.sender) {
		baseURI = _baseUri;
		feeReceiver = _feeReceiver;
	}

	/* -------------------------------------------------------------------------- */
	/*                             Proxy init funciton                            */
	/* -------------------------------------------------------------------------- */

	/**
	 * @notice Initialize the contract.
	 * @param _owner The owner of the contract.
	 * @param _feeReceiver The address that will receive the caps price.
	 * @param _capsSigner The address that can sign the mintWithSignature message.
	 * @param _baseUri The base URI of the token.
	 */
	function initialize(
		address _owner,
		address _feeReceiver,
		address _capsSigner,
		string memory _baseUri
	) external {
		/// @dev Skips owner verification as the proxy is already ownable.
		/// @dev Skips initialization check as the proxy handles the initialization check internally.

		_transferOwnership(_owner);

		baseURI = _baseUri;
		capsSigner = _capsSigner;
		feeReceiver = _feeReceiver;

		// Must be a multiple of 3
		freeMintLimit = 6;
		freeMintCooldown = 12 hours;

		// Prices
		capsPriceByQuantity[3] = 0.0003 ether;
		capsPriceByQuantity[9] = 0.0006 ether;
		capsPriceByQuantity[30] = 0.0018 ether;
		premiumCapsPriceByQuantity[3] = 0.0009 ether;
		premiumCapsPriceByQuantity[9] = 0.00225 ether;
		premiumCapsPriceByQuantity[30] = 0.0054 ether;
		premiumPackPrice = 0.0036 ether;

		// Set the default royalty to 0
		_setDefaultRoyalty(_feeReceiver, 0);
	}

	/* -------------------------------------------------------------------------- */
	/*                             External functions                             */
	/* -------------------------------------------------------------------------- */

	/**
	 * @notice Open 3 caps that mints 1 new token each.
	 * @dev Free mint is only allowed once per {freeMintCooldown} seconds with a maximum of {freeMintLimit} staked caps.
	 */
	function freeMint3() external {
		/// @dev Cache the values to avoid multiple SLOADs
		uint256 _freeMintLimit = freeMintLimit;
		uint256 _freeMintCooldown = freeMintCooldown;

		// Time elapsed since the last mint
		uint256 elapsedTime = block.timestamp - lastMintTimestamp[msg.sender];

		// Full elapsed intervals since the last mint (each interval gives 3 caps)
		/// @dev DIV op floor the result
		uint256 intervals = elapsedTime / _freeMintCooldown;

		// Total accumulated caps balance
		uint256 totalCaps = intervals * 3;
		if (totalCaps > _freeMintLimit) {
			totalCaps = _freeMintLimit;
		}

		// Check if there is at least one full mint right available
		if (totalCaps < 3) revert INSUFFICIENT_CAPS_BALANCE();

		// Consume 3 caps on the total accumulated balance
		uint256 leftoverCaps = totalCaps - 3;

		// Amount of intervals left after the 3 caps consumption
		uint256 leftoverIntervals = leftoverCaps / 3;

		// Partial rest of the currently active interval
		uint256 remainderTime = elapsedTime % _freeMintCooldown;

		// If the eslaed time is more the waiting time limit, ignore excess waiting time
		if (elapsedTime >= _freeMintCooldown * (_freeMintLimit / 3)) {
			remainderTime = 0;
		}

		// New "lastMintTimestamp" = start from block.timestamp
		// minus leftoverIntervals intervals
		// minus remainderTime (to avoid double-counting the partially started interval)
		lastMintTimestamp[msg.sender] =
			block.timestamp -
			(leftoverIntervals * _freeMintCooldown) -
			remainderTime;

		// Mint the NFTs
		_open3CapsForSender(false);
	}

	/**
	 * @notice Open 3 caps that mints 1 new token each.
	 * @param isPremium Whether the caps is premium or not.
	 */
	function mint3(bool isPremium) external {
		uint256 balance = isPremium
			? paidPremiumCapsBalanceOf[msg.sender]
			: paidCapsBalanceOf[msg.sender];

		if (balance < 3) {
			revert INSUFFICIENT_CAPS_BALANCE();
		}

		/// @dev We can safely subtract 3 from the balance because we already checked
		///      that the balance is at least 3.
		unchecked {
			if (isPremium) {
				paidPremiumCapsBalanceOf[msg.sender] -= 3;
			} else {
				paidCapsBalanceOf[msg.sender] -= 3;
			}
		}

		// Mint the NFTs
		_open3CapsForSender(isPremium);
	}

	/**
	 * @notice Open a caps that mint 3 new tokens to the message sender using an authorized signature.
	 * @param signature The signature that authorizes the mint.
	 * @param message The signed message containing the mint information.
	 *                  - address to: The address to mint the tokens to.
	 *                  - uint256 index: The index of the mint.
	 *                  - bool isPremium: Whether the mint is premium or not.
	 */
	function mint3WithSignature(
		bytes memory signature,
		bytes calldata message
	) external {
		// Verify the signature
		bytes32 messageHash = keccak256(message);
		address recoveredSigner = ECDSA.recover(messageHash, signature);
		if (recoveredSigner != capsSigner) revert INVALID_SIGNATURE();

		// Decode the message
		(address to, uint256 index, bool isPremium) = abi.decode(
			message,
			(address, uint256, bool)
		);

		// Check if the signature has already been used
		if (signatureMintsOf[to][index]) revert SIGNATURE_REUSED();

		// Check if the sender is the expected one
		/// @dev Only the "to" address can use the signature
		if (to != msg.sender) revert INVALID_SENDER(msg.sender, to);

		// Mark the signature as used
		signatureMintsOf[to][index] = true;

		// Mint the NFTs
		_open3CapsForSender(isPremium);

		emit MintedWithSignature(msg.sender, message, signature);
	}

	/**
	 * @notice Buy a caps with the price of {capsPrice}.
	 * @param isPremium Whether the caps is premium or not.
	 * @param quantity The quantity of caps to buy.
	 * @dev The quantity must be a multiple of 3 because each mint opens 3 caps.
	 */
	function buyCaps(bool isPremium, uint256 quantity) external payable {
		if (quantity % 3 != 0) revert WRONG_CAPS_QUANTITY();

		uint256 price = isPremium
			? premiumCapsPriceByQuantity[quantity]
			: capsPriceByQuantity[quantity];

		if (price == 0) revert UNKNOWN_PRICE_FORE(quantity, isPremium);
		if (msg.value != price) revert WRONG_VALUE();

		unchecked {
			if (isPremium) {
				paidPremiumCapsBalanceOf[msg.sender] += quantity;
			} else {
				paidCapsBalanceOf[msg.sender] += quantity;
			}
		}

		// Transfer the caps price to the fee receiver at the end of the function for
		// consistency with the typical CEI pattern.
		(bool success, ) = payable(feeReceiver).call{value: msg.value}("");
		if (!success) revert FEE_TRANSFER_FAILED();
	}

	/**
	 * @notice Buy a premium pack with the price of {premiumPackPrice}.
	 * @dev The premium pack contains 1 NFT mint + 12 caps + 3 premium caps.
	 */
	function buyPremiumPack() external payable {
		if (msg.value != premiumPackPrice) revert WRONG_VALUE();

		// Give the caps to the buyer (12 caps because 12 is a multiple of 3)
		paidCapsBalanceOf[msg.sender] += 12;
		// Give the premium caps to the buyer
		paidPremiumCapsBalanceOf[msg.sender] += 3;

		// Mint the NFT in the pack
		/// @dev open a single caps directly because the premium pack contains 1 NFT mint
		uint256 _tokenId = tokenId; // Cache the tokenId in memory
		_safeMint(msg.sender, _tokenId);

		// tokenId can be safely incremented
		unchecked {
			tokenId++;
		}

		// Transfer the caps price to the fee receiver
		(bool success, ) = payable(feeReceiver).call{value: msg.value}("");
		if (!success) revert FEE_TRANSFER_FAILED();

		// Emit the CapsOpened event corresponding to the minted token
		emit CapsOpened(msg.sender, _tokenId, false, true);
	}

	/**
	 * @notice Burn a token.
	 * @param _tokenId The ID of the token to burn.
	 */
	function burn(uint256 _tokenId) public override {
		/**
		 * @dev Bypass the transfer lock for the burn function because we want to allow the
		 *      owner to burn his transfer locked tokens.
		 */
		ERC721._update(address(0), _tokenId, _msgSender());
	}

	/**
	 * @notice Burn a batch of tokens.
	 * @param tokenIds The IDs of the tokens to burn.
	 */
	function batchBurn(uint256[] memory tokenIds) external {
		// Cache the length to avoid accessing array's length in the loop
		uint256 length = tokenIds.length;
		for (uint256 i; i != length; ) {
			/**
			 * @dev Bypass the transfer lock for the burn function because we want to allow the
			 *      owner to burn his transfer locked tokens, it also save a lot of gas here.
			 */
			ERC721._update(address(0), tokenIds[i], _msgSender());

			unchecked {
				i++;
			}
		}
	}

	/* -------------------------------------------------------------------------- */
	/*                               View functions                               */
	/* -------------------------------------------------------------------------- */

	/**
	 * @notice Get the caps balance of an account.
	 * @param account The account to check the caps balance.
	 * @return The caps balance of the account.
	 */
	function capsBalanceOf(address account) public view returns (uint256) {
		/// @dev DIV op floor the result
		uint256 freeCapsBalance = ((block.timestamp -
			lastMintTimestamp[account]) / freeMintCooldown) * 3;

		// Limit the free caps balance to the free mint limit
		freeCapsBalance = freeCapsBalance > freeMintLimit
			? freeMintLimit
			: freeCapsBalance;

		// Return the sum of paid and free caps balance
		return
			paidCapsBalanceOf[account] +
			paidPremiumCapsBalanceOf[account] +
			freeCapsBalance;
	}

	/* -------------------------------- Overrides ------------------------------- */

	/**
	 * @dev Override _baseURI to return the base URI.
	 * @return The base URI.
	 */
	function _baseURI() internal view virtual override returns (string memory) {
		return baseURI;
	}

	/**
	 * @dev Override supportsInterface to add ERC721Royalty.
	 * @param interfaceId The interface identifier.
	 * @return Whether the interface is supported.
	 */
	function supportsInterface(
		bytes4 interfaceId
	) public view override(ERC721, ERC721Royalty) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	/**
	 * @dev See {IERC721Metadata-name}.
	 */
	function name() public pure override returns (string memory) {
		return _name;
	}

	/**
	 * @dev See {IERC721Metadata-symbol}.
	 */
	function symbol() public pure override returns (string memory) {
		return _symbol;
	}

	/* -------------------------------------------------------------------------- */
	/*                            Only owner functions                            */
	/* -------------------------------------------------------------------------- */

	/**
	 * @notice Set the base URI.
	 * @param _baseUri The new base URI.
	 */
	function setBaseURI(string memory _baseUri) external onlyOwner {
		baseURI = _baseUri;
		emit BaseURIChanged(_baseUri);
	}

	/**
	 * @notice Set the caps price.
	 * @param price The new caps price.
	 */
	function setCapsPrice(uint256 quantity, uint256 price) external onlyOwner {
		capsPriceByQuantity[quantity] = price;
		emit CapsPriceChanged(quantity, price);
	}

	/**
	 * @notice Set the premium caps price.
	 * @param price The new premium caps price.
	 */
	function setPremiumCapsPrice(
		uint256 quantity,
		uint256 price
	) external onlyOwner {
		premiumCapsPriceByQuantity[quantity] = price;
		emit PremiumCapsPriceChanged(quantity, price);
	}

	/**
	 * @notice Set the premium pack price.
	 * @param price The new premium pack price.
	 */
	function setPremiumPackPrice(uint256 price) external onlyOwner {
		premiumPackPrice = price;
		emit PremiumPackPriceChanged(price);
	}

	/**
	 * @notice Set the free mint limit.
	 * @param limit The new free mint limit.
	 */
	function setFreeMintLimit(uint256 limit) external onlyOwner {
		if (limit % 3 != 0) revert FREE_MINT_LIMIT_MUST_BE_MULTIPLE_OF_3();
		freeMintLimit = limit;
		emit FreeMintLimitChanged(limit);
	}

	/**
	 * @notice Set the free mint cooldown.
	 * @param cooldown The new free mint cooldown.
	 */
	function setFreeMintCooldown(uint256 cooldown) external onlyOwner {
		freeMintCooldown = cooldown;
		emit FreeMintCooldownChanged(cooldown);
	}

	/**
	 * @notice Set the fee receiver.
	 * @param receiver The new fee receiver.
	 */
	function setFeeReceiver(address receiver) external onlyOwner {
		feeReceiver = receiver;
		emit FeeReceiverChanged(receiver);
	}

	/**
	 * @notice Set the signer.
	 * @param _capsSigner The new signer.
	 */
	function setCapsSigner(address _capsSigner) external onlyOwner {
		capsSigner = _capsSigner;
		emit CapsSignerChanged(_capsSigner);
	}

	/**
	 * @notice Set the default royalty.
	 * @param _receiver The receiver of the royalty.
	 * @param _feeNumerator The fee numerator of the royalty.
	 */
	function setDefaultRoyalty(
		address _receiver,
		uint96 _feeNumerator
	) external onlyOwner {
		_setDefaultRoyalty(_receiver, _feeNumerator);
		emit DefaultRoyaltyChanged(_receiver, _feeNumerator);
	}

	/* -------------------------------------------------------------------------- */
	/*                             Internal functions                             */
	/* -------------------------------------------------------------------------- */

	/**
	 * @dev Override the _update function to resolve inheritance conflict and
	 *      ensures locked tokens cannot be transferred.
	 * @param to The address to transfer the token to.
	 * @param token The token ID to transfer.
	 * @param auth The authorizer of the transfer.
	 */
	function _update(
		address to,
		uint256 token,
		address auth
	) internal override(ERC721, ERC721TransferLock) returns (address) {
		// Use the implementation from ERC721TransferLock
		return ERC721TransferLock._update(to, token, auth);
	}

	/* -------------------------------------------------------------------------- */
	/*                              Private functions                             */
	/* -------------------------------------------------------------------------- */

	/**
	 * @notice Open a caps that mints 3 new token to the message sender.
	 */
	function _open3CapsForSender(bool isPremium) private {
		// Cache the tokenId in memory
		uint256 _tokenId = tokenId;

		_safeMint(msg.sender, _tokenId);
		_safeMint(msg.sender, _tokenId + 1);
		_safeMint(msg.sender, _tokenId + 2);
		_lockFirstMintToken(_tokenId + 2);

		// Increment the tokenId
		/// @dev tokenId can be safely incremented
		unchecked {
			tokenId += 3;
		}

		// Emit the CapsOpened events
		emit CapsOpened(msg.sender, _tokenId, isPremium, false);
		emit CapsOpened(msg.sender, _tokenId + 1, isPremium, false);
		emit CapsOpened(msg.sender, _tokenId + 2, isPremium, false);
	}

	/**
	 * @notice Lock a token if it is the first msg.sender mint.
	 * @dev The goal is to lock the 3rd token of the first mint of an account.
	 * @param _tokenId The token ID to lock.
	 */
	function _lockFirstMintToken(uint256 _tokenId) private {
		if (hasMinted[msg.sender] == false) {
			_lockToken(_tokenId);
			hasMinted[msg.sender] = true;

			emit LockedFirstMintToken(_tokenId);
		}
	}
}
