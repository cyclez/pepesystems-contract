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
    bytes32 public claimList = 0x0;
    mapping(address => bool) claimed;
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
            totalSupply() + pepes <= supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(pepes <= publicMaxMint, "max 10 tokens x tx");
        bool isDelegatedValue = isDelegated();
        require(isDelegatedValue, "connected wallet has no delegations");
        require(msg.value >= lowFee * pepes, "Insufficient funds for purchase");
        for (uint256 i = 0; i < pepes; ++i) {
            _safeMint(msg.sender, pepes);
        }
    }

    /// @notice Mint a pepe by public mint
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchase(uint256 pepes) public payable {
        require(saleStatus == SaleStatus.PUBLIC, "Public sale is off");
        require(
            totalSupply() + pepes <= supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(pepes <= publicMaxMint, "max 10 tokens x tx");
        require(
            msg.value >= baseFee * pepes,
            "Insufficient funds for purchase"
        );
        _safeMint(msg.sender, pepes);
    }

    function claimPurchase(bytes32[] memory proof) public payable {
        require(saleStatus == SaleStatus.CLAIM, "Claim is OFF");
        require(totalSupply() + 1 <= supply - teamReserve - claimReserve);
        require(verifyClaimList(msg.sender, proof), "Not on Claim List");
        require(!claimed[msg.sender], "Pepe already claimed");
        _safeMint(msg.sender, 1);
        claimed[msg.sender] = true;
        --claimReserve;
    }

    /// @notice Reserves specified number of pepes to a wallet
    /// @param pepes - total number of pepes to reserve (must be less than teamReserve size)
    function mintTeamReserve(uint256 pepes) external onlyOwner {
        require(totalSupply() + pepes <= supply, "supply is full");
        require(pepes <= teamReserve, "minting too many");
        _safeMint(msg.sender, pepes);
        teamReserve -= pepes;
    }

    /// @notice Gift a give number of pepes into a specific wallet
    /// @param wallet - wallet address to mint to
    /// @param pepes - total number of pepes to gift
    function gitfTeamReserve(address wallet, uint256 pepes) external onlyOwner {
        require(totalSupply() + pepes <= supply, "supply is full");
        require(pepes <= teamReserve, "minting too many");
        _safeMint(wallet, pepes);
        teamReserve -= pepes;
    }

    /**
     * -----------  UTILITY FUNCTIONS -----------
     */

    /// @notice internal function checking if a connected wallet has delegations
    function isDelegated() internal view returns (bool) {
        bool result;
        IDelegationRegistry.DelegationInfo[] memory delegationInfos;
        delegationInfos = reg.getDelegationsByDelegate(msg.sender);
        if (delegationInfos.length != 0) {
            result = true;
        }
        return result;
    }

    /// @dev internal function to verify claimlist
    function verifyClaimList(
        address wallet,
        bytes32[] memory proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(wallet));
        return MerkleProof.verify(proof, claimList, leaf);
    }

    /// @notice Check if wallet is on claimList
    /// @param proof - proof that wallet is on claimList
    function isOnCLaimList(
        address wallet,
        bytes32[] memory proof
    ) external view returns (bool) {
        return verifyClaimList(wallet, proof);
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

    /// @notice set team reserve
    /// @param _teamReserve new reserved supply for the team
    function setTeamReserve(uint256 _teamReserve) external onlyOwner {
        teamReserve = _teamReserve;
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
    /// @param _status new pepe status can be 0, 1, 2, 3 for Off, Public, Team and Claim statuses respectively
    function setSaleStatus(uint256 _status) external onlyOwner {
        saleStatus = SaleStatus(_status);
    }

    /// @notice Set supply
    /// @param _supply number of tokens in the supply
    function setSupply(uint256 _supply) external onlyOwner {
        supply = _supply;
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
