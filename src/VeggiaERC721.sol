// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721TransferLock} from "./ERC721TransferLock.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract VeggiaERC721 is ERC721, ERC721Burnable, ERC721TransferLock, ERC721Royalty, Ownable {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /* ---------------------------- Bytes32 storages ---------------------------- */
    /**
     * @notice The limit of available free mint per account.
     */
    uint256 public freeMintLimit;
    /**
     * @notice The cooldown time to unlock a new free mint.
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
     *         1 NFT mint + 10 caps + 3 premium caps.
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

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    /// @dev Throws if the account has insufficient caps balance.
    error INSUFFICIENT_CAPS_BALANCE();
    /// @dev Throws if the value sent is not enough.
    error NOT_ENOUGH_VALUE();
    /// @dev Throws if the value sent is not the expected one.
    error WRONG_VALUE();
    /// @dev Throws if the quantity is not the expected one.
    error WRONG_CAPS_AMOUNT();
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
    event CapsOpened(address indexed account, uint256 tokenId, bool premium, bool isPack);
    event MintedWithSignature(address indexed account, bytes message, bytes signature);

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor(address _feeReceiver, string memory _baseUri) ERC721("Veggia", "VEGGIA") Ownable(msg.sender) {
        baseURI = _baseUri;
        feeReceiver = _feeReceiver;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Proxy init funciton                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Initialize the contract.
     * @param _feeReceiver The address that will receive the caps price.
     * @param _baseUri The base URI of the token.
     */
    function initialize(address owner, address _feeReceiver, address _capsSigner, string memory _baseUri) external {
        if (freeMintLimit != 0) revert ALREADY_INITIALIZED();

        _transferOwnership(owner);

        baseURI = _baseUri;
        capsSigner = _capsSigner;
        feeReceiver = _feeReceiver;

        freeMintLimit = 2;
        freeMintCooldown = 12 hours;

        // Prices
        capsPriceByQuantity[1] = 0.0003 ether;
        capsPriceByQuantity[3] = 0.0006 ether;
        capsPriceByQuantity[10] = 0.0018 ether;
        premiumCapsPriceByQuantity[1] = 0.0009 ether;
        premiumCapsPriceByQuantity[3] = 0.00225 ether;
        premiumCapsPriceByQuantity[10] = 0.0054 ether;
        premiumPackPrice = 0.0036 ether;

        // Set the default royalty to 0
        _setDefaultRoyalty(feeReceiver, 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                             External functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Open a caps that mints 3 new token for free.
     * @dev Free mint is only allowed once per {freeMintCooldown} seconds with a maximum of {freeMintLimit} staked caps.
     */
    function freeMint() external {
        uint256 _freeMintLimit = freeMintLimit;
        uint256 _freeMintCooldown = freeMintCooldown;

        // Calculate the elapsed time since the last mint
        uint256 elapsedTime = block.timestamp - lastMintTimestamp[msg.sender];

        // Calculate total accumulated rights (limited to `freeMintLimit`)
        uint256 totalCapsBalance = elapsedTime / _freeMintCooldown;
        if (totalCapsBalance > _freeMintLimit) {
            totalCapsBalance = _freeMintLimit;
        }

        // Check if there is at least one full mint right available
        if (totalCapsBalance == 0) revert INSUFFICIENT_CAPS_BALANCE();

        if (elapsedTime / _freeMintCooldown > _freeMintLimit) {
            lastMintTimestamp[msg.sender] = block.timestamp - _freeMintCooldown * (_freeMintLimit - 1);
        } else {
            lastMintTimestamp[msg.sender] =
                block.timestamp - (_freeMintCooldown * (totalCapsBalance - 1)) - (elapsedTime % _freeMintCooldown);
        }

        // Mint the NFTs
        _openCapsForSender(false);
    }

    /**
     * @notice Open a caps that mints 3 new token.
     * @param isPremium Whether the caps is premium or not.
     */
    function mint(bool isPremium) external {
        uint256 balance;
        balance = isPremium ? paidPremiumCapsBalanceOf[msg.sender] : paidCapsBalanceOf[msg.sender];

        if (balance == 0) {
            revert INSUFFICIENT_CAPS_BALANCE();
        }

        unchecked {
            if (isPremium) {
                paidPremiumCapsBalanceOf[msg.sender]--;
            } else {
                paidCapsBalanceOf[msg.sender]--;
            }
        }
        _openCapsForSender(isPremium);
    }

    /**
     * @notice Mint a new token using a signature.
     * @param signature The signature to verify.
     * @param message The message to sign.
     */
    function mintWithSignature(bytes memory signature, bytes calldata message) external {
        // Verify the signature
        bytes32 messageHash = keccak256(message);
        address recoveredSigner = ECDSA.recover(messageHash, signature);
        if (recoveredSigner != capsSigner) revert INVALID_SIGNATURE();

        (address to, uint256 index, bool isPremium) = abi.decode(message, (address, uint256, bool));
        if (signatureMintsOf[to][index]) revert SIGNATURE_REUSED();

        signatureMintsOf[to][index] = true;

        if (to != msg.sender) revert INVALID_SENDER(msg.sender, to);

        // Mint the NFTs
        _openCapsForSender(isPremium);

        emit MintedWithSignature(msg.sender, message, signature);
    }

    /**
     * @notice Buy a caps with the price of {capsPrice}.
     * @param isPremium Whether the caps is premium or not.
     * @param quantity The quantity of caps to buy.
     */
    function buyCaps(bool isPremium, uint256 quantity) external payable {
        uint256 price = isPremium ? premiumCapsPriceByQuantity[quantity] : capsPriceByQuantity[quantity];
        if (price == 0) revert WRONG_CAPS_AMOUNT();
        if (msg.value != price) revert WRONG_VALUE();

        // Transfer the caps price to the fee receiver
        (bool success,) = payable(feeReceiver).call{value: price}("");
        if (!success) revert FEE_TRANSFER_FAILED();

        unchecked {
            if (isPremium) {
                paidPremiumCapsBalanceOf[msg.sender] += quantity;
            } else {
                paidCapsBalanceOf[msg.sender] += quantity;
            }
        }
    }

    /**
     * @notice Buy a premium pack with the price of {premiumPackPrice}.
     */
    function buyPack() external payable {
        if (msg.value != premiumPackPrice) revert WRONG_VALUE();

        // Give the caps to the buyer
        paidCapsBalanceOf[msg.sender] += 10;
        // Give the premium caps to the buyer
        paidPremiumCapsBalanceOf[msg.sender] += 3;

        // Mint the NFT in the pack
        _mint(msg.sender, tokenId);
        tokenId++;

        // Transfer the caps price to the fee receiver
        (bool success,) = payable(feeReceiver).call{value: premiumPackPrice}("");
        if (!success) revert FEE_TRANSFER_FAILED();

        // Emit the CapsOpened
        emit CapsOpened(msg.sender, tokenId - 1, false, true);
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
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i != length;) {
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
        // DIV op floor the result
        uint256 freeCapsBalance = (block.timestamp - lastMintTimestamp[account]) / freeMintCooldown;
        freeCapsBalance = freeCapsBalance > freeMintLimit ? freeMintLimit : freeCapsBalance;

        // Return the sum of paid and free caps balance
        return paidCapsBalanceOf[account] + paidPremiumCapsBalanceOf[account] + freeCapsBalance;
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
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
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
    function setPremiumCapsPrice(uint256 quantity, uint256 price) external onlyOwner {
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
    function _update(address to, uint256 token, address auth)
        internal
        override(ERC721, ERC721TransferLock)
        returns (address)
    {
        // Use the implementation from ERC721TransferLock
        return ERC721TransferLock._update(to, token, auth);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Private functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Open a caps that mints 3 new token to the message sender.
     */
    function _openCapsForSender(bool isPremium) private {
        _mint(msg.sender, tokenId);
        tokenId++;
        _mint(msg.sender, tokenId);
        tokenId++;
        _mint(msg.sender, tokenId);
        _lockFirstMintToken(tokenId);
        tokenId++;

        // Emit the CapsOpened events
        emit CapsOpened(msg.sender, tokenId - 3, isPremium, false);
        emit CapsOpened(msg.sender, tokenId - 2, isPremium, false);
        emit CapsOpened(msg.sender, tokenId - 1, isPremium, false);
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
