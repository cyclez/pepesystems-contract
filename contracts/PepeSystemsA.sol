// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/DelegationRegistry.sol";
import "../lib/IDelegationRegistry.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.17;

contract PepeSystems is ERC721A, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    string public pepeUrl;
    uint256 public supply = 12222;
    uint256 public teamReserve = 222;
    uint256 public claimReserve = 0;
    uint256 public publicMaxMint = 10;
    uint256 public baseFee = 0.04 ether;
    uint256 public lowFee = 0.03 ether;
    bool public revealed = false;
    uint256 public mintedTokens = 0;
    uint256 public index = 0;
    address delegateCashContract = 0x00000000000076A84feF008CDAbe6409d2FE638B;
    address pepeTokenContract = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address ceo = 0x0000000000000000000000000000000000000000;
    address cto = 0x0000000000000000000000000000000000000000;
    DelegationRegistry reg;

    enum SaleStatus {
        OFF,
        PUBLIC,
        TEAM,
        CLAIM
    }

    SaleStatus public saleStatus;

    constructor() ERC721A("Pepe Systems", "PS") {
        reg = DelegationRegistry(delegateCashContract);
    }

    /**
     * -----------  MINT FUNCTIONS -----------
     */

    /// @notice Mint in public with a delegated wallet
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicDelegatedPurchase(uint256 pepes) public payable {
        require(saleStatus == SaleStatus.PUBLIC, "Public sale is off");
        require(
            mintedTokens + pepes <= supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(pepes <= publicMaxMint, "max 10 tokens x tx");
        bool isDelegatedValue = isDelegated();
        require(isDelegatedValue, "connected wallet has no delegations");
        require(msg.value >= lowFee * pepes, "Insufficient funds for purchase");
        for (uint256 i = 0; i < pepes; ++i) {
            _safeMint(msg.sender, pepes);
            ++index;
        }
        mintedTokens += pepes;
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
        _mint(msg.sender, index);
        mintedTokens += pepes;
    }

    /// @notice Reserves specified number of pepes to a wallet
    /// @param pepes - total number of pepes to reserve (must be less than teamReserve size)
    function mintTeamReserve(uint256 pepes) external onlyOwner {
        require(mintedTokens + pepes <= supply, "supply is full");
        require(pepes <= teamReserve, "sinting too many");
        _mint(msg.sender, index);
        mintedTokens += pepes;
        teamReserve -= pepes;
    }

    /**
     * -----------  UTILITY FUNCTIONS -----------
     */

    /// @notice Checks if a connected wallet has delegations
    function isDelegated() internal view returns (bool) {
        bool result;
        IDelegationRegistry.DelegationInfo[] memory delegationInfos;
        delegationInfos = reg.getDelegationsByDelegate(msg.sender);
        if (delegationInfos.length != 0) {
            result = true;
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
    /// @param status new pepe status can be 0, 1, 2, 3 for Off, Public, Team and Claim statuses respectively
    function setSaleStatus(uint256 status) external onlyOwner {
        require(status <= uint256(SaleStatus.CLAIM), "Invalid SaleStatus");
        saleStatus = SaleStatus(status);
    }

    /// @notice Withdraw funds to team
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        require(payable(ceo).send(balance / 2));
        require(payable(cto).send(balance / 2));
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
