// SPDX-License-Identifier: MIT

import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
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

contract PepeSystems is
    ERC721A,
    ERC721ABurnable,
    ERC721AQueryable,
    Ownable,
    ReentrancyGuard
{
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
    bool public revealed = false;
    bytes32 public claimListRoot = 0x0;
    address constant delegateCashContract =
        0x00000000000076A84feF008CDAbe6409d2FE638B;
    address constant pepeTokenContract =
        0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address public UniSwapV2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public ceo = 0x0000000000000000000000000000000000000000;
    address public cto = 0x0000000000000000000000000000000000000000;
    DelegationRegistry reg;
    bool public saleStatus = false;

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
        require(saleStatus == true, "Sale is off");
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            publicMinted + pepes <= supply - teamReserve - claimReserve,
            "Pepe MAX supply reached"
        );
        require(pepes <= publicMaxMint, "Max 10 tokens x tx");
        bool isDelegatedValue = isDelegated();
        require(isDelegatedValue, "Connected wallet has no delegations");
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

    /// @notice Mint public sale with $PEPE
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicDelegatedPurchasePepe(uint256 pepes) public payable {
        require(saleStatus == true, "Sale is off");
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            publicMinted + pepes <= supply - teamReserve - claimReserve,
            "Public Sale supply maxed out"
        );
        bool isDelegatedValue = isDelegated();
        require(isDelegatedValue, "Connected wallet has no delegations");
        require(pepes <= publicMaxMint, "Max 10 tokens x tx");
        uint256 pepeTokenPrice = calculateTokensFromEth(lowFee);
        uint256 pepeAmount;
        if (pepes == publicMaxMint) {
            pepeAmount = pepeTokenPrice * (pepes - 1);
        } else {
            pepeAmount = pepeTokenPrice * pepes;
        }
        require(approvePepe(pepeAmount), "Amount not approved");
        require(
            IERC20(pepeTokenContract).transferFrom(
                msg.sender,
                address(this),
                pepeAmount
            ),
            "$PEPE transfer failed"
        );
        _mint(msg.sender, pepes);
    }

    /// @notice Mint public sale
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchase(uint256 pepes) public payable {
        require(saleStatus == true, "Sale is off");
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            publicMinted + pepes <= supply - teamReserve - claimReserve,
            "Public Sale supply maxed out"
        );
        require(pepes <= publicMaxMint, "Max 10 tokens x tx");
        if (pepes == publicMaxMint) {
            require(
                msg.value >= baseFee * (pepes - 1),
                "Insufficient funds for purchase"
            );
        } else {
            require(
                msg.value >= baseFee * pepes,
                "Insufficient funds for purchase"
            );
        }
        _mint(msg.sender, pepes);
    }

    /// @notice Mint public sale with $PEPE
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchasePepe(uint256 pepes) public payable {
        require(saleStatus == true, "Public sale is off");
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            publicMinted + pepes <= supply - teamReserve - claimReserve,
            "Public Sale supply maxed out"
        );
        require(pepes <= publicMaxMint, "Max 10 tokens x tx");
        uint256 pepeTokenPrice = calculateTokensFromEth(baseFee);
        uint256 pepeAmount;
        if (pepes == publicMaxMint) {
            pepeAmount = pepeTokenPrice * (pepes - 1);
        } else {
            pepeAmount = pepeTokenPrice * pepes;
        }
        require(approvePepe(pepeAmount), "Amount not approved");
        require(
            IERC20(pepeTokenContract).transferFrom(
                msg.sender,
                address(this),
                pepeAmount
            ),
            "$PEPE transfer failed"
        );
        _mint(msg.sender, pepes);
    }

    function claimPurchase(bytes32[] calldata proof) public payable {
        require(saleStatus == true, "Claim is OFF");
        require(
            claimMinted <= claimReserve,
            "Claim reserve already fully minted"
        );
        require(_totalMinted() + 1 < supply, "Supply is full");
        require(verifyClaimList(proof), "Not on Claim List");
        require(_getAux(msg.sender) < 1, "Pepe already claimed");
        unchecked {
            ++claimMinted;
        }
        _setAux(msg.sender, 1);
        _mint(msg.sender, 1);
    }

    /// @notice Reserves specified number of pepes to a wallet
    /// @param pepes - total number of pepes to reserve (must be less than teamReserve size)
    function mintTeamReserve(uint256 pepes) external onlyOwner {
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            teamMinted + pepes <= teamReserve,
            "Team reserve already fully minted"
        );
        require(pepes <= teamReserve, "Minting too many");
        unchecked {
            teamMinted += pepes;
        }
        _mint(msg.sender, pepes);
    }

    /// @notice Gift a give number of pepes into a specific wallet
    /// @param wallet - wallet address to mint to
    /// @param pepes - total number of pepes to gift
    function gitfTeamReserve(address wallet, uint256 pepes) external onlyOwner {
        require(_totalMinted() + pepes <= supply, "Supply is full");
        require(
            teamMinted + pepes <= teamReserve,
            "Team reserve already fully minted"
        );
        require(pepes <= teamReserve, "Minting too many");
        unchecked {
            teamMinted += pepes;
        }
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

    function approvePepe(uint256 amount) internal returns (bool) {
        bool check = IERC20(pepeTokenContract).approve(address(this), amount);
        return check;
    }

    function calculateTokensFromEth(
        uint256 ethAmount
    ) internal view returns (uint256) {
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            UniSwapV2RouterAddress
        );

        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = pepeTokenContract;

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

    /// @notice Set supply
    /// @param _supply number of tokens in the supply
    function setSupply(uint256 _supply) external onlyOwner {
        supply = _supply;
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

    /// @notice set claim list root
    /// @param _claimListRoot root of the claim list
    function setClaimListRoot(bytes32 _claimListRoot) external onlyOwner {
        claimListRoot = _claimListRoot;
    }

    /// @notice Set pepe status
    /// @param _saleStatus sale ON or OFF
    function setSaleStatus(bool _saleStatus) external onlyOwner {
        saleStatus = _saleStatus;
    }

    /// @notice set ceo wallet
    /// @param _ceo ceo wallet
    function setCeoWallet(address _ceo) external onlyOwner {
        ceo = _ceo;
    }

    /// @notice set cto wallet
    /// @param _cto cto wallet
    function setCtoWallet(address _cto) external onlyOwner {
        cto = _cto;
    }

    /// @notice Withdraw funds to team
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH funds to withdraw");
        require(payable(ceo).send(balance / 2));
        require(payable(cto).send(balance / 2));
        // Add ERC-20 token withdrawal code here
        uint256 tokenBalance = IERC20(pepeTokenContract).balanceOf(
            address(this)
        );
        require(tokenBalance > 0, "No token funds to withdraw");

        require(IERC20(pepeTokenContract).transfer(ceo, tokenBalance / 2));
        require(IERC20(pepeTokenContract).transfer(cto, tokenBalance / 2));
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
