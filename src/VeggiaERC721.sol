// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

contract VeggiaERC721 is ERC721, ERC721Burnable, ERC721Royalty, Ownable {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /* ----------------------------- Normal storages ---------------------------- */
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
     * @notice The price of an egg.
     */
    uint256 public eggPrice;
    /**
     * @notice The address that will receive the egg price.
     */
    address public feeReceiver;

    /* ------------------------------ Bytes storage ----------------------------- */
    string private baseURI;

    /* ---------------------------- Mappings storage ---------------------------- */
    mapping(address => uint256) public lastMintTimestamp;
    mapping(address => uint256) public paidEggBalanceOf;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    error INSUFFICIENT_EGG_BALANCE();
    error NOT_ENOUGH_VALUE();
    error FEE_TRANSFER_FAILED();
    error ALREADY_INITIALIZED();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event BaseURIChanged(string newBaseURI);
    event EggPriceChanged(uint256 newPrice);
    event FreeMintLimitChanged(uint256 newLimit);
    event FreeMintCooldownChanged(uint256 newCooldown);
    event FeeReceiverChanged(address newFeeReceiver);

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor(
        address _feeReceiver,
        string memory _baseUri
    ) ERC721("Veggia", "VEGGIA") Ownable(msg.sender) {
        baseURI = _baseUri;
        feeReceiver = _feeReceiver;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Proxy init funciton                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Initialize the contract.
     * @param _feeReceiver The address that will receive the egg price.
     * @param _baseUri The base URI of the token.
     */
    function initialize(
        address owner,
        address _feeReceiver,
        string memory _baseUri
    ) external {
        if(freeMintLimit != 0) revert ALREADY_INITIALIZED();
        
        _transferOwnership(owner);

        baseURI = _baseUri;
        feeReceiver = _feeReceiver;

        freeMintLimit = 2;
        freeMintCooldown = 12 hours;
        eggPrice = 0.001 ether;
    }

    /* -------------------------------------------------------------------------- */
    /*                             External functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Open an egg that mints 3 new token for free.
     * @dev Free mint is only allowed once per {freeMintCooldown} seconds with a maximum of {freeMintLimit} staked eggs.
     * @param to The address that will own the minted token.
     */
    function freeMint(address to) external {
        uint256 _freeMintLimit = freeMintLimit;
        uint256 _freeMintCooldown = freeMintCooldown;

        // Calculate the elapsed time since the last mint
        uint256 elapsedTime = block.timestamp - lastMintTimestamp[msg.sender];

        // Calculate total accumulated rights (limited to `freeMintLimit`)
        uint256 totalEggBalance = elapsedTime / _freeMintCooldown;
        if (totalEggBalance > _freeMintLimit) {
            totalEggBalance = _freeMintLimit;
        }

        // Check if there is at least one full mint right available
        if (totalEggBalance == 0) revert INSUFFICIENT_EGG_BALANCE();

        if (elapsedTime / _freeMintCooldown > _freeMintLimit) {
            lastMintTimestamp[msg.sender] =
                block.timestamp -
                _freeMintCooldown *
                (_freeMintLimit - 1);
        } else {
            lastMintTimestamp[msg.sender] =
                block.timestamp -
                (_freeMintCooldown * (totalEggBalance - 1)) -
                (elapsedTime % _freeMintCooldown);
        }

        // Mint the NFTs
        _mint(to, tokenId);
        tokenId++;
        _mint(to, tokenId);
        tokenId++;
        _mint(to, tokenId);
        tokenId++;
    }

    /**
     * @notice Mint a new token using the paid eggs.
     */
    function mint() external {
        if (paidEggBalanceOf[msg.sender] == 0)
            revert INSUFFICIENT_EGG_BALANCE();
        paidEggBalanceOf[msg.sender]--;
        _mint(msg.sender, tokenId);
        tokenId++;
    }

    /**
     * @notice Buy an egg with the price of {eggPrice}.
     */
    function buyEgg() external payable {
        if (msg.value < eggPrice) revert NOT_ENOUGH_VALUE();

        // Transfer the egg price to the fee receiver
        (bool success, ) = payable(feeReceiver).call{value: eggPrice}("");
        if (!success) revert FEE_TRANSFER_FAILED();

        paidEggBalanceOf[msg.sender]++;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Public function                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get the egg balance of an account.
     * @param account The account to check the egg balance.
     * @return The egg balance of the account.
     */
    function eggBalanceOf(address account) public view returns (uint256) {
        // DIV op floor the result
        uint256 freeEggBalance = (block.timestamp -
            lastMintTimestamp[account]) / freeMintCooldown;
        freeEggBalance = freeEggBalance > freeMintLimit
            ? freeMintLimit
            : freeEggBalance;

        // Return the sum of paid and free egg balance
        return paidEggBalanceOf[account] + freeEggBalance;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Overrides                                 */
    /* -------------------------------------------------------------------------- */

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
     * @notice Set the egg price.
     * @param price The new egg price.
     */
    function setEggPrice(uint256 price) external onlyOwner {
        eggPrice = price;
        emit EggPriceChanged(price);
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
}
