// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC721TransferLock} from "./ERC721TransferLock.sol";

import {IPyth} from "@pythnetwork/IPyth.sol";
import {PythStructs} from "@pythnetwork/PythStructs.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradable/contracts/utils/cryptography/EIP712Upgradeable.sol";

/**
 * @title VeggiaERC721
 * @author @VeggiesLabs
 * @notice A contract for the Veggia NFTs.
 * @dev This contract is based on the ERC721 standard with additional features.
 */
contract VeggiaERC721 is ERC721, ERC721Burnable, ERC721TransferLock, ERC721Royalty, Ownable2Step, EIP712Upgradeable {
    using ECDSA for bytes32;

    /* -------------------------------------------------------------------------- */
    /*                                   Structs                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice A struct that represents a mint request.
     * @dev Used to validate the mintWithSignature message.
     * @param to The address that will receive the minted tokens.
     * @param index The index of the mint request.
     * @param isPremium Whether the mint request is for premium caps or not.
     */
    struct MintRequest {
        address to;
        uint256 index;
        bool isPremium;
    }

    /**
     * @notice A struct that represents a super pass update request.
     * @dev Used to validate the updateSuperPassWithSignature message.
     * @param owner The account to update the super pass.
     * @param unlocked Whether to lock or unlock the super pass.
     */
    struct UpdateSuperPassRequest {
        address owner;
        uint256 index;
        bool unlocked;
    }

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
    address public authoritySigner;
    /**
     * @notice The price of the premium pack.
     *         1 NFT mint + 12 caps + 3 premium caps.
     */
    uint256 public premiumPackUsdPrice;
    /**
     * @notice The Pyth contract address.
     */
    IPyth public pyth;

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
    mapping(uint256 => uint256) public capsUsdPriceByQuantity;
    /**
     * @notice A mapping of the premium caps price by quantity.
     */
    mapping(uint256 => uint256) public premiumCapsUsdPriceByQuantity;
    /**
     * @notice A mapping of the super pass status of an account.
     */
    mapping(address => bool) public hasSuperPass;
    /**
     * @notice A mapping of the super pass signature used.
     */
    mapping(bytes32 => bool) public superPassSignatureUsed;

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
    /**
     * @dev The EIP712 domain separator.
     */
    bytes32 private constant _MINTREQUEST_TYPEHASH = keccak256("MintRequest(address to,uint256 index,bool isPremium)");
    /**
     * @dev The EIP712 domain separator.
     */
    bytes32 private constant _UPDATESUPERPASSREQUEST_TYPEHASH =
        keccak256("UpdateSuperPassRequest(address owner,uint256 index,bool unlocked)");

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    /// @dev Throws if the account has insufficient caps balance.
    error INSUFFICIENT_CAPS_BALANCE();
    /// @dev Throws if the value sent is not enough.
    error NOT_ENOUGH_VALUE();
    /// @dev Throws if the value refund failed.
    error VALUE_REFUND_FAILED();
    /// @dev Throws if the caps quantity is less than 3
    error UNKNOWN_CAPS_PRICE_FOR(uint256 quantity, bool isPremium);
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
    /// @dev Throws if the address is the zero address.
    error ZERO_ADDRESS();
    /// @dev Throws if the cooldown is set to 0.
    error ZERO_COOLDOWN();
    /// @dev Throws when trying to transfer a locked token.
    error CANT_TRANSFER_WITHOUT_SUPER_PASS(address auth, uint256 token);
    /// @dev Throws when trying to approve a locked token.
    error CANT_APPROVE_WITHOUT_SUPER_PASS();

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
    event AuthoritySignerChanged(address newSigner);
    event LockedFirstMintToken(uint256 indexed tokenId);
    event CapsOpened(address indexed account, uint256 indexed tokenId, bool premium, bool isPack);
    event MintedWithSignature(address indexed account, MintRequest req, bytes signature);
    event DefaultRoyaltyChanged(address receiver, uint96 feeNumerator);
    event SuperPassUpdated(address indexed owner, bool indexed unlocked, bytes signature);

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor() ERC721("Veggia", "VGIA") Ownable(msg.sender) {
        _disableInitializers();
    }

    /* -------------------------------------------------------------------------- */
    /*                             Proxy init funciton                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Initialize the contract.
     * @param _owner The owner of the contract.
     * @param _feeReceiver The address that will receive the caps price.
     * @param _authoritySigner The address that can sign the mintWithSignature message.
     * @param _baseUri The base URI of the token.
     * @param _pyth The Pyth contract address.
     */
    function initialize(
        address _owner,
        address _feeReceiver,
        address _authoritySigner,
        address _pyth,
        string memory _baseUri,
        string memory eip712Version
    ) external initializer {
        /// @dev Skips owner verification as the proxy is already ownable.

        // Init EIP712
        __EIP712_init("Veggia", eip712Version);

        // Transfer the ownership to the owner
        _transferOwnership(_owner);

        baseURI = _baseUri;
        authoritySigner = _authoritySigner;
        feeReceiver = _feeReceiver;

        // Must be a multiple of 3
        freeMintLimit = 6;
        freeMintCooldown = 24 hours;

        // Prices in USD with 18 decimals
        premiumCapsUsdPriceByQuantity[3] = 1.99 ether;
        premiumCapsUsdPriceByQuantity[9] = 4.99 ether;
        premiumCapsUsdPriceByQuantity[30] = 9.99 ether;
        premiumPackUsdPrice = 99.99 ether;

        // Pyth
        pyth = IPyth(_pyth);

        // Set the default royalty to 3% in bas
        _setDefaultRoyalty(_feeReceiver, 300);
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
        lastMintTimestamp[msg.sender] = block.timestamp - (leftoverIntervals * _freeMintCooldown) - remainderTime;

        // Mint the NFTs
        _open3CapsForSender(false);
    }

    /**
     * @notice Open 3 caps that mints 1 new token each.
     * @param isPremium Whether the caps is premium or not.
     */
    function mint3(bool isPremium) external {
        uint256 balance = isPremium ? paidPremiumCapsBalanceOf[msg.sender] : paidCapsBalanceOf[msg.sender];

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
     * @param req The mint request containing the mint information.
     * @param signature The signature that authorizes the mint.
     */
    function mint3WithSignature(MintRequest calldata req, bytes calldata signature) external {
        // Ensure the sender is the intended recipient.
        if (req.to != msg.sender) {
            revert INVALID_SENDER(msg.sender, req.to);
        }

        // Check if this mint request has already been processed.
        if (signatureMintsOf[req.to][req.index]) {
            revert SIGNATURE_REUSED();
        }

        // Compute the EIP712 digest for the mint request.
        bytes32 digest = hashMintRequest(req);

        // Recover the signer from the digest and signature.
        address recoveredSigner = ECDSA.recover(digest, signature);
        if (recoveredSigner != authoritySigner) {
            revert INVALID_SIGNATURE();
        }

        // Mark the signature as used.
        signatureMintsOf[req.to][req.index] = true;

        // Proceed with minting.
        _open3CapsForSender(req.isPremium);

        emit MintedWithSignature(msg.sender, req, signature);
    }

    /**
     * @notice Buy a caps with the price of {capsPrice}.
     * @param isPremium Whether the caps is premium or not.
     * @param quantity The quantity of caps to buy.
     * @dev The quantity must be a multiple of 3 because each mint opens 3 caps.
     */
    function buyCaps(bool isPremium, uint256 quantity, bytes[] calldata priceUpdate) external payable {
        if (quantity % 3 != 0) revert WRONG_CAPS_QUANTITY();

        uint256 usdPrice = isPremium ? premiumCapsUsdPriceByQuantity[quantity] : capsUsdPriceByQuantity[quantity];
        if (usdPrice == 0) revert UNKNOWN_CAPS_PRICE_FOR(quantity, isPremium);

        (uint256 ethUsdPrice, uint256 pythFee) = getEthUsdPythPrice(priceUpdate);
        uint256 ethWeiBuyPrice = (usdPrice * 1e18) / ethUsdPrice;
        if (msg.value < ethWeiBuyPrice + pythFee) revert NOT_ENOUGH_VALUE();

        unchecked {
            if (isPremium) {
                paidPremiumCapsBalanceOf[msg.sender] += quantity;
            } else {
                paidCapsBalanceOf[msg.sender] += quantity;
            }
        }

        // Transfer the caps price to the fee receiver at the end of the function for
        // consistency with the typical CEI pattern.
        (bool feeTransferSuccess,) = payable(feeReceiver).call{value: ethWeiBuyPrice}("");
        if (!feeTransferSuccess) revert FEE_TRANSFER_FAILED();

        // Refund the excess value to the msg.sender
        if (msg.value > ethWeiBuyPrice + pythFee) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - ethWeiBuyPrice - pythFee}("");
            if (!refundSuccess) revert VALUE_REFUND_FAILED();
        }
    }

    /**
     * @notice Buy a premium pack with the price of {premiumPackPrice}.
     * @dev The premium pack contains 1 NFT mint + 12 caps + 3 premium caps.
     */
    function buyPremiumPack(bytes[] calldata priceUpdate) external payable {
        (uint256 ethUsdPrice, uint256 pythFee) = getEthUsdPythPrice(priceUpdate);
        uint256 ethWeiBuyPrice = (premiumPackUsdPrice * 1e18) / ethUsdPrice;
        if (msg.value < ethWeiBuyPrice + pythFee) revert NOT_ENOUGH_VALUE();

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
        (bool success,) = payable(feeReceiver).call{value: ethWeiBuyPrice}("");
        if (!success) revert FEE_TRANSFER_FAILED();

        // Refund the excess value to the msg.sender
        if (msg.value > ethWeiBuyPrice + pythFee) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - ethWeiBuyPrice - pythFee}("");
            if (!refundSuccess) revert VALUE_REFUND_FAILED();
        }

        // Emit the CapsOpened event corresponding to the minted token
        emit CapsOpened(msg.sender, _tokenId, false, true);
    }

    /**
     * @notice Lock/unlock the super pass for an account.
     * @param req The super pass update request.
     * @param signature The signature that authorizes the unlock.
     */
    function updateSuperPassWithSignature(UpdateSuperPassRequest calldata req, bytes calldata signature) external {
        // Compute the EIP712 digest for the unlock request.
        bytes32 digest = hashUpdateSuperPassRequest(req);

        // Recover the signer from the digest and signature.
        address recoveredSigner = ECDSA.recover(digest, signature);
        if (recoveredSigner != authoritySigner) {
            revert INVALID_SIGNATURE();
        }

        // Check if the signature has already been used.
        if (superPassSignatureUsed[digest]) {
            revert SIGNATURE_REUSED();
        }

        // Update the super pass status.
        hasSuperPass[req.owner] = req.unlocked;

        // Update the super pass signature used.
        superPassSignatureUsed[digest] = true;

        // Emit the SuperPassUpdated event.
        emit SuperPassUpdated(req.owner, req.unlocked, signature);
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
        for (uint256 i; i != length;) {
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
        uint256 freeCapsBalance = ((block.timestamp - lastMintTimestamp[account]) / freeMintCooldown) * 3;

        // Limit the free caps balance to the free mint limit
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

    /**
     * @notice Hash a mint request.
     * @param req The mint request to hash.
     */
    function hashMintRequest(MintRequest calldata req) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(_MINTREQUEST_TYPEHASH, req.to, req.index, req.isPremium)));
    }

    /**
     * @notice Hash a mint request.
     * @param req The mint request to hash.
     */
    function hashUpdateSuperPassRequest(UpdateSuperPassRequest calldata req) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(_UPDATESUPERPASSREQUEST_TYPEHASH, req.owner, req.index, req.unlocked))
        );
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
    function setCapsUsdPrice(uint256 quantity, uint256 price) external onlyOwner {
        if (quantity % 3 != 0) revert WRONG_CAPS_QUANTITY();
        capsUsdPriceByQuantity[quantity] = price;
        emit CapsPriceChanged(quantity, price);
    }

    /**
     * @notice Set the premium caps price.
     * @param price The new premium caps price.
     */
    function setPremiumCapsUsdPrice(uint256 quantity, uint256 price) external onlyOwner {
        if (quantity % 3 != 0) revert WRONG_CAPS_QUANTITY();
        premiumCapsUsdPriceByQuantity[quantity] = price;
        emit PremiumCapsPriceChanged(quantity, price);
    }

    /**
     * @notice Set the premium pack price.
     * @param price The new premium pack price.
     */
    function setPremiumPackUsdPrice(uint256 price) external onlyOwner {
        premiumPackUsdPrice = price;
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
        if (cooldown == 0) revert ZERO_COOLDOWN();
        freeMintCooldown = cooldown;
        emit FreeMintCooldownChanged(cooldown);
    }

    /**
     * @notice Set the fee receiver.
     * @param receiver The new fee receiver.
     */
    function setFeeReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        feeReceiver = receiver;
        emit FeeReceiverChanged(receiver);
    }

    /**
     * @notice Set the signer.
     * @param _authoritySigner The new signer.
     */
    function setAuthoritySigner(address _authoritySigner) external onlyOwner {
        if (_authoritySigner == address(0)) revert ZERO_ADDRESS();
        authoritySigner = _authoritySigner;
        emit AuthoritySignerChanged(_authoritySigner);
    }

    /**
     * @notice Set the default royalty.
     * @param _receiver The receiver of the royalty.
     * @param _feeNumerator The fee numerator of the royalty.
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
        emit DefaultRoyaltyChanged(_receiver, _feeNumerator);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal functions                             */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------- Overrides ------------------------------- */

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
        address from = _ownerOf(token);

        if (from != address(0) && !hasSuperPass[from]) {
            revert CANT_TRANSFER_WITHOUT_SUPER_PASS(from, token);
        }

        // Use the implementation from ERC721TransferLock
        return ERC721TransferLock._update(to, token, auth);
    }

    /**
     * @dev Override the _approve function to prevent approving locked tokens.
     * @dev Locking the approval prevent a user to list a NFT on a marketplace while the NFT is locked.
     * @param to The address to approve.
     * @param token The token ID to approve.
     * @param auth The authorizer of the approval.
     * @param emitEvent Whether to emit the Approval event.
     */
    function _approve(address to, uint256 token, address auth, bool emitEvent) internal override {
        address from = _ownerOf(token);

        // If The authorizer is not address(0) and the address to approve is not address(0)
        // and the from address is not the super pass owner, revert
        if (!hasSuperPass[from] && auth != address(0) && to != address(0)) {
            revert CANT_APPROVE_WITHOUT_SUPER_PASS();
        }

        // Use the implementation from ERC721
        ERC721._approve(to, token, auth, emitEvent);
    }

    /**
     * @dev Override the _setApprovalForAll function to prevent approving locked tokens.
     * @param owner The owner of the tokens.
     * @param operator The operator to approve.
     * @param approved Whether the operator is approved or not.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal override {
        if (!hasSuperPass[owner]) {
            revert CANT_APPROVE_WITHOUT_SUPER_PASS();
        }

        // Use the implementation from ERC721
        ERC721._setApprovalForAll(owner, operator, approved);
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

    /**
     * @notice Update Pyth price for price ID and return the price.
     * @param priceUpdate The encoded data to update the contract with the latest price
     */
    function getEthUsdPythPrice(bytes[] calldata priceUpdate) private returns (uint256 _price, uint256 _fee) {
        // Submit a priceUpdate to the Pyth contract to update the on-chain price.
        // Updating the price requires paying the fee returned by getUpdateFee.
        // WARNING: These lines are required to ensure the getPriceNoOlderThan call below succeeds. If you remove them, transactions may fail with "0x19abf40e" error.
        _fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{value: _fee}(priceUpdate);

        // Read the current price from a price feed if it is less than 60 seconds old.
        // Each price feed (e.g., ETH/USD) is identified by a price feed ID.
        // The complete list of feed IDs is available at https://pyth.network/developers/price-feed-ids
        bytes32 priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // ETH/USD
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeedId, 60);

        // Convert the price to a uint256 with 18 decimals.
        int256 intPrice;
        if (price.expo < 0) {
            // For negative exponent, divide by 10**(-expo)
            intPrice = (int256(price.price) * 1e18) / int256(10 ** uint256(-int256(price.expo)));
        } else {
            // For non-negative exponent, multiply by 10**expo
            intPrice = int256(price.price) * 1e18 * int256(10 ** uint256(int256(price.expo)));
        }

        _price = uint256(intPrice < 0 ? int256(0) : intPrice);
    }
}
