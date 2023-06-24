// SPDX-License-Identifier: MIT

import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../lib/DelegationRegistry.sol";
import "../lib/IDelegationRegistry.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.17;

contract PepeSystems is ERC721A, ERC721ABurnable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Address for address;
    string public pepeUrl;
    uint256 public supply = 12222;
    uint256 public teamReserve = 222;
    uint256 public claimReserve;
    uint256 public publicMinted;
    uint256 public claimMinted;
    uint256 public teamMinted;
    uint256 public publicMaxMint = 10;
    uint256 public baseFee = 0.04 ether;
    uint256 public lowFee = 0.03 ether;
    uint256 public pepeBaseFee;
    uint256 public pepeLowFee;
    bool public revealed = false;
    bytes32 public claimListRoot = 0x0;
    mapping(address => bool) claimed;
    address constant delegateCashContract =
        0x00000000000076A84feF008CDAbe6409d2FE638B;
    address constant pepeTokenContract =
        0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address public UniSwapV2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant pepeEthPair = 0xA43fe16908251ee70EF74718545e4FE6C5cCEc9f;
    address ceo = 0x0000000000000000000000000000000000000000;
    address cto = 0x0000000000000000000000000000000000000000;
    DelegationRegistry reg;

    enum SaleStatus {
        OFF,
        PUBLIC,
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
    function publicDelegatedPurchase(
        uint256 pepes,
        address wallet
    ) public payable {
        require(saleStatus == SaleStatus.PUBLIC, "Public sale is off");
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            publicMinted + pepes <= supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(pepes <= publicMaxMint, "max 10 tokens x tx");
        bool isDelegatedValue = isDelegated();
        require(isDelegatedValue, "connected wallet has no delegations");
        if (pepes == publicMaxMint) {
            require(
                msg.value >= lowFee * (pepes - 1),
                "Insufficient funds for purchase"
            );
        } else {
            require(
                msg.value >= lowFee * pepes,
                "Insufficient funds for purchase"
            );
        }
        _mint(wallet, pepes);
    }

    /// @notice Mint a pepe by public mint
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchase(uint256 pepes) public payable {
        require(saleStatus == SaleStatus.PUBLIC, "Public sale is off");
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            publicMinted + pepes <= supply - teamReserve - claimReserve,
            "Public Sale supply maxed out"
        );
        require(pepes <= publicMaxMint, "max 10 tokens x tx");
        if (pepes == publicMaxMint) {
            require(
                msg.value >= lowFee * (pepes - 1),
                "Insufficient funds for purchase"
            );
        } else {
            require(
                msg.value >= lowFee * pepes,
                "Insufficient funds for purchase"
            );
        }
        _mint(msg.sender, pepes);
    }

    function claimPurchase(bytes32[] calldata proof) public payable {
        require(saleStatus == SaleStatus.CLAIM, "Claim is OFF");
        require(
            claimMinted <= claimReserve,
            "Claim reserve already fully minted"
        );
        require(_totalMinted() + 1 < supply, "Supply is full");
        require(verifyClaimList(proof), "Not on Claim List");
        require(_getAux(msg.sender) < 1, "Pepe already claimed");
        ++claimMinted;
        _setAux(msg.sender, 1);
        _mint(msg.sender, 1);
    }

    /// @notice Reserves specified number of pepes to a wallet
    /// @param pepes - total number of pepes to reserve (must be less than teamReserve size)
    function mintTeamReserve(uint256 pepes) external onlyOwner {
        require(_totalMinted() + pepes <= supply, "supply is full");
        require(
            teamMinted + pepes <= teamReserve,
            "Team reserve already fully minted"
        );
        require(pepes <= teamReserve, "minting too many");
        teamMinted += pepes;
        _mint(msg.sender, pepes);
    }

    /// @notice Gift a give number of pepes into a specific wallet
    /// @param wallet - wallet address to mint to
    /// @param pepes - total number of pepes to gift
    function gitfTeamReserve(address wallet, uint256 pepes) external onlyOwner {
        require(_totalMinted() + pepes <= supply, "supply is full");
        require(
            teamMinted + pepes <= teamReserve,
            "Team reserve already fully minted"
        );
        require(pepes <= teamReserve, "minting too many");
        teamMinted += pepes;
        _mint(wallet, pepes);
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

    /// @notice internal function to verify claimlist
    function verifyClaimList(
        bytes32[] calldata proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verifyCalldata(proof, claimListRoot, leaf);
    }

    /// @notice Check if wallet is on claimListRoot
    /// @param proof - proof that wallet is on claimListRoot
    function isOnCLaimList(
        bytes32[] calldata proof
    ) external view returns (bool) {
        return verifyClaimList(proof);
    }

    function approvePepe(uint256 amount) external {
        IERC20(pepeTokenContract).approve(address(this), amount);
    }

    function calculateTokensFromEth(
        address uniswapRouterAddress,
        address tokenAddress,
        uint256 ethAmount
    ) external view returns (uint256) {
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            uniswapRouterAddress
        );

        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddress;

        uint256[] memory amounts = uniswapRouter.getAmountsOut(ethAmount, path);
        return amounts[1];
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
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        require(payable(ceo).send(balance / 2));
        require(payable(cto).send(balance / 2));
    }

    /// @notice Token URI
    /// @param tokenId - token Id of pepe to retreive metadata for
    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721A, IERC721A) returns (string memory) {
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
