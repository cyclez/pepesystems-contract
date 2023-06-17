// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../lib/DelegationRegistry.sol";
import "../lib/IDelegationRegistry.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.17;

contract PepeSystems is ERC721, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    string public pepeUrl;
    uint256 public supply = 12222;
    uint256 public teamReserve = 222;
    uint256 public claimReserve = 0;
    uint256 public publicMaxMint = 10;
    uint256 public presaleMaxMint = 3;

    uint256 public baseFee = 0.04 ether;
    uint256 public lowFee = 0.03 ether;

    bool public revealed = false;

    mapping(address => uint256) public presalePurchased;

    uint256 public mintedTokens = 0;
    uint256 public index = 0;
    mapping(uint256 => bool) public presaleTokensCheck;

    address baycContract = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address delegateCashContract = 0x00000000000076A84feF008CDAbe6409d2FE638B;
    address pepeTokenContract = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address ceo = 0x0000000000000000000000000000000000000000;
    address cto = 0x0000000000000000000000000000000000000000;
    DelegationRegistry reg;

    enum SaleStatus {
        OFF,
        PRESALE,
        PUBLIC,
        TEAM,
        CLAIM
    }

    SaleStatus public saleStatus;

    constructor() ERC721("Pepe Systems", "PS") {
        reg = DelegationRegistry(delegateCashContract);
    }

    /**
     * -----------  MINT FUNCTIONS -----------
     */

    /// @notice mint the ps ids with delegation discount
    /// @param tokenIds - list of tokens to mint
    function presaleDelegationPurchase(
        uint256[] calldata tokenIds,
        uint256 delegationId
    ) public payable {
        require(saleStatus == SaleStatus.PRESALE, "Pre-Sale is off");
        require(
            mintedTokens + tokenIds.length <=
                supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(
            presalePurchased[msg.sender] + tokenIds.length <= presaleMaxMint,
            "purchase limit per wallet reached"
        );
        require(tokenIds.length <= presaleMaxMint, "Max 3 tokens in Pre-Sale");
        require(
            msg.value >= (lowFee * tokenIds.length),
            "Insufficient funds for purchase"
        );

        uint256 tokenCount = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!presaleTokensCheck[tokenIds[i]]) {
                _mint(msg.sender, tokenIds[i]);
                presaleTokensCheck[tokenIds[i]] = true;
                ++tokenCount;
            }
        }
        require(tokenCount > 0, "All requested tokens are already minted");
        mintedTokens += tokenCount;
    }

    /// @notice mint the pepe ids without delegation discount
    /// @param tokenIds - list of tokens to mint
    function presaleOwnershipPurchase(
        uint256[] calldata tokenIds
    ) public payable {
        uint256[] memory ownershipCheck = ownsBAYCNFT(msg.sender, tokenIds);
        require(saleStatus == SaleStatus.PRESALE, "Pre-Sale is off");
        require(
            ownershipCheck.length == tokenIds.length,
            "You don't own some or all the tokens in input"
        );
        require(
            mintedTokens + tokenIds.length <=
                supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(
            presalePurchased[msg.sender] + tokenIds.length <= presaleMaxMint,
            "purchase limit per wallet reached"
        );
        require(tokenIds.length <= presaleMaxMint, "Max 3 tokens in Pre-Sale");
        require(
            msg.value >= lowFee * tokenIds.length,
            "Insufficient funds for purchase"
        );

        uint256 tokenCount = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!presaleTokensCheck[tokenIds[i]]) {
                _mint(msg.sender, tokenIds[i]);
                presaleTokensCheck[tokenIds[i]] = true;
                ++tokenCount;
            }
        }
        require(tokenCount > 0, "All requested tokens are already minted");
        mintedTokens += tokenCount;
    }

    /// @notice Mint a pepe by public mint
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchase(uint256 pepes) public payable {
        require(saleStatus == SaleStatus.PUBLIC, "Public sale is off");
        require(
            mintedTokens + pepes <= supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(pepes <= publicMaxMint, "max 10 tokens x tx");
        require(
            msg.value >= baseFee * pepes,
            "Insufficient funds for purchase"
        );

        for (uint256 i = 0; i < pepes; ++i) {
            findIndex(index);
            _mint(msg.sender, index);
            ++index;
        }
        presalePurchased[msg.sender] += pepes;
        mintedTokens += pepes;
    }

    /// @notice Reserves specified number of pepes to a wallet
    /// @param wallet - wallet address to reserve for
    /// @param pepes - total number of pepes to reserve (must be less than teamReserve size)
    function mintTeamReserve(address wallet, uint256 pepes) external onlyOwner {
        require(mintedTokens + pepes <= supply, "supply is full");
        require(pepes <= teamReserve, "Reserving too many");
        for (uint256 i = 0; i < pepes; ++i) {
            findIndex(index);
            _mint(wallet, index);
            ++index;
            teamReserve -= pepes;
        }
        mintedTokens += pepes;
    }

    /**
     * -----------  UTILITY FUNCTIONS -----------
     */

    function findIndex(uint256 _index) internal {
        while (presaleTokensCheck[_index]) {
            ++_index;
        }
        index = _index;
    }

    /// @notice Returns true if a wallet is delegated
    /// @param wallet - wallet to check
    function checkDelegatedBAYC(address wallet) internal returns (bool) {
        

    }

    /// @notice Checks if holder as
    /// @param wallet - wallet to check
    /// @param tokenIds - tokens to check
    function ownsBAYCNFT(
        address wallet,
        uint256[] calldata tokenIds
    ) internal view returns (uint256[] memory) {
        require(tokenIds.length <= 3, "Max 3 tokens in Pre-Sale");
        uint256[] memory result = new uint256[](tokenIds.length);
        IERC721 bayc = IERC721(baycContract);
        for (uint256 i = 0; i == tokenIds.length; ++i) {
            if (bayc.ownerOf(tokenIds[i]) == wallet) {
                result[i] = tokenIds[i];
            }
        }
        return result;
    }

    /**
     * -----------  SET FUNCTIONS -----------
     */

    /// @notice Set pepe url
    /// @param _pepeUrl new pepe s base url
    function setpepeUrl(string memory _pepeUrl) external onlyOwner {
        pepeUrl = _pepeUrl;
    }

    /// @notice set claimable reserve
    /// @param _claimReserve new reserved supply for free claim
    function setClaimReserve(uint256 _claimReserve) external onlyOwner {
        claimReserve = _claimReserve;
    }

    /// @notice Set publicMaxMint limit
    /// @param _publicMaxMint new mint limit per wallet
    function setPublicMaxMint(uint256 _publicMaxMint) external onlyOwner {
        publicMaxMint = _publicMaxMint;
    }

    /// @notice Set presaleMaxMint limit
    /// @param _presaleMaxMint new mint limit per wallet
    function setPresaleMaxMint(uint256 _presaleMaxMint) external onlyOwner {
        presaleMaxMint = _presaleMaxMint;
    }

    /// @notice Set purchase fee
    /// @param _baseFee new purchase fee price in Wei format
    function setbaseFee(uint256 _baseFee) external onlyOwner {
        baseFee = _baseFee;
    }

    /// @notice Set purchase fee
    /// @param _lowFee new purchase fee price in Wei format
    function setLowFee(uint256 _lowFee) external onlyOwner {
        lowFee = _lowFee;
    }

    /// @notice Set revealed
    /// @param _revealed if set to true metadata is formatted for reveal otherwise metadata is formatted for a preview
    function setRevealed(bool _revealed) external onlyOwner {
        revealed = _revealed;
    }

    /// @notice Set pepe status
    /// @param status new pepe status can be 0, 1, 2, 3, 4, 5 for Off, PreSale, Public Sale, Team and Claim statuses respectively
    function setSaleStatus(uint256 status) external onlyOwner {
        require(status <= uint256(SaleStatus.CLAIM), "Invalid SaleStatus");
        saleStatus = SaleStatus(status);
    }

    /// @notice Withdraw funds to team
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        require(payable(ceo).send(balance.mul(50).div(100)));
        require(payable(cto).send(balance.mul(50).div(100)));
    }

    /// @notice Token URI
    /// @param tokenId - token Id of pepe to retreive metadata for
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (bytes(pepeUrl).length <= 0) return "";
        return
            revealed
                ? string(abi.encodePacked(pepeUrl, tokenId.toString()))
                : string(abi.encodePacked(pepeUrl));
    }
}
