// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../lib/IDelegationRegistry.sol";

//PPPPPPPPPPPPPPPPP
//P::::::::::::::::P
//P::::::PPPPPP:::::P
//PP:::::P     P:::::P
//  P::::P     P:::::P  eeeeeeeeeeee    ppppp   ppppppppp       eeeeeeeeeeee
//  P::::P     P:::::Pee::::::::::::ee  p::::ppp:::::::::p    ee::::::::::::ee
//  P::::PPPPPP:::::Pe::::::eeeee:::::eep:::::::::::::::::p  e::::::eeeee:::::ee
//  P:::::::::::::PPe::::::e     e:::::epp::::::ppppp::::::pe::::::e     e:::::e
//  P::::PPPPPPPPP  e:::::::eeeee::::::e p:::::p     p:::::pe:::::::eeeee::::::e
//  P::::P          e:::::::::::::::::e  p:::::p     p:::::pe:::::::::::::::::e
//  P::::P          e::::::eeeeeeeeeee   p:::::p     p:::::pe::::::eeeeeeeeeee
//  P::::P          e:::::::e            p:::::p    p::::::pe:::::::e
//PP::::::PP        e::::::::e           p:::::ppppp:::::::pe::::::::e
//P::::::::P         e::::::::eeeeeeee   p::::::::::::::::p  e::::::::eeeeeeee
//P::::::::P          ee:::::::::::::e   p::::::::::::::pp    ee:::::::::::::e
//PPPPPPPPPP            eeeeeeeeeeeeee   p::::::pppppppp        eeeeeeeeeeeeee
//                                       p:::::p
//                                       p:::::p
//                                      p:::::::p
//                                      p:::::::p
//                                      p:::::::p
//                                      ppppppppp

//   SSSSSSSSSSSSSSS                                            tttt
// SS:::::::::::::::S                                        ttt:::t
//S:::::SSSSSS::::::S                                        t:::::t
//S:::::S     SSSSSSS                                        t:::::t
//S:::::S      yyyyyyy           yyyyyyy  ssssssssss   ttttttt:::::ttttttt        eeeeeeeeeeee       mmmmmmm    mmmmmmm       ssssssssss
//S:::::S       y:::::y         y:::::y ss::::::::::s  t:::::::::::::::::t      ee::::::::::::ee   mm:::::::m  m:::::::mm   ss::::::::::s
// S::::SSSS     y:::::y       y:::::yss:::::::::::::s t:::::::::::::::::t     e::::::eeeee:::::eem::::::::::mm::::::::::mss:::::::::::::s
//  SS::::::SSSSS y:::::y     y:::::y s::::::ssss:::::stttttt:::::::tttttt    e::::::e     e:::::em::::::::::::::::::::::ms::::::ssss:::::s
//    SSS::::::::SSy:::::y   y:::::y   s:::::s  ssssss       t:::::t          e:::::::eeeee::::::em:::::mmm::::::mmm:::::m s:::::s  ssssss
//       SSSSSS::::Sy:::::y y:::::y      s::::::s            t:::::t          e:::::::::::::::::e m::::m   m::::m   m::::m   s::::::s
//            S:::::Sy:::::y:::::y          s::::::s         t:::::t          e::::::eeeeeeeeeee  m::::m   m::::m   m::::m      s::::::s
//            S:::::S y:::::::::y     ssssss   s:::::s       t:::::t    tttttte:::::::e           m::::m   m::::m   m::::mssssss   s:::::s
//SSSSSSS     S:::::S  y:::::::y      s:::::ssss::::::s      t::::::tttt:::::te::::::::e          m::::m   m::::m   m::::ms:::::ssss::::::s
//S::::::SSSSSS:::::S   y:::::y       s::::::::::::::s       tt::::::::::::::t e::::::::eeeeeeee  m::::m   m::::m   m::::ms::::::::::::::s
//S:::::::::::::::SS   y:::::y         s:::::::::::ss          tt:::::::::::tt  ee:::::::::::::e  m::::m   m::::m   m::::m s:::::::::::ss
// SSSSSSSSSSSSSSS    y:::::y           sssssssssss              ttttttttttt      eeeeeeeeeeeeee  mmmmmm   mmmmmm   mmmmmm  sssssssssss
//                   y:::::y
//                  y:::::y
//                 y:::::y
//                y:::::y
//               yyyyyyy

error SaleIsOff();
error MaxSupplyReached();
error MaxPerTxReached();
error NoDelegations();
error InsufficientFunds();
error TransferFailed();
error NotWhitelisted();
error AlreadyClaimed();

contract PepeSystems is ERC721ABurnable, ERC721AQueryable, ERC2981, Ownable {
    using Strings for uint256;

    IDelegationRegistry reg;
    IERC20 pepe;

    string public baseURI;

    uint64 public baseFee = 0.025 ether;
    uint64 public lowFee = 0.02 ether;
    uint32 public claimsToMint;
    uint32 public publicMaxMint = 10;
    uint32 public maxSupply = 12222;
    uint32 public teamToMint = 222;

    bool public saleStatus;

    bytes32 public claimListRoot = 0x0;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public ceo = 0x0000000000000000000000000000000000000000;
    address public cto = 0x0000000000000000000000000000000000000000;

    constructor(
        address _delegateCashContract,
        address _pepeAddress,
        string memory _initBaseURI
    ) ERC721A("Pepe Systems", "PS") {
        reg = IDelegationRegistry(_delegateCashContract);
        pepe = IERC20(_pepeAddress);
        baseURI = _initBaseURI;
        _setDefaultRoyalty(msg.sender, 500); // 5%
    }

    modifier publicMintCompliance(uint256 amount) {
        if (!saleStatus) revert SaleIsOff();
        if (amount > publicMaxMint) revert MaxPerTxReached();
        if (_totalMinted() + amount > maxSupply - claimsToMint - teamToMint)
            revert MaxSupplyReached();
        _;
    }

    /**
     * -----------  MINT FUNCTIONS -----------
     */

    /// @notice Mint public sale
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchase(
        uint256 pepes
    ) public payable publicMintCompliance(pepes) {
        if (pepes == publicMaxMint) {
            if (msg.value < baseFee * (pepes - 1)) revert InsufficientFunds();
        } else {
            if (msg.value < baseFee * pepes) revert InsufficientFunds();
        }
        _mint(msg.sender, pepes);
    }

    /// @notice Mint public sale with $PEPE
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicPurchasePepe(
        uint256 pepes
    ) public payable publicMintCompliance(pepes) {
        uint256 pepeTokenPrice = calculateTokensFromEth(baseFee);
        uint256 pepeAmount;
        if (pepes == publicMaxMint) {
            pepeAmount = pepeTokenPrice * (pepes - 1);
        } else {
            pepeAmount = pepeTokenPrice * pepes;
        }
        if (!pepe.transferFrom(msg.sender, address(this), pepeAmount))
            revert TransferFailed();
        _mint(msg.sender, pepes);
    }

    /// @notice Mint in public with a delegated wallet
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicDelegatedPurchase(
        uint256 pepes,
        address vault,
        uint32 delegationType,
        address delegationContract,
        uint32 delegationTokenId,
        address destination
    ) public payable publicMintCompliance(pepes) {
        bool isDelegatedValue = checkDelegation(
            delegationType,
            vault,
            delegationContract,
            delegationTokenId
        );
        if (!isDelegatedValue) revert NoDelegations();
        if (pepes == publicMaxMint) {
            if (msg.value < lowFee * (pepes - 1)) revert InsufficientFunds();
        } else {
            if (msg.value < lowFee * pepes) revert InsufficientFunds();
        }
        _mint(destination, pepes);
    }

    /// @notice Mint public sale with $PEPE
    /// @notice Mint 10 and pay 9
    /// @param pepes - total number of pepes to mint (must be less than purchase limit)
    function publicDelegatedPurchasePepe(
        uint256 pepes,
        address vault,
        uint32 delegationType,
        address delegationContract,
        uint32 delegationTokenId,
        address destination
    ) public payable publicMintCompliance(pepes) {
        bool isDelegatedValue = checkDelegation(
            delegationType,
            vault,
            delegationContract,
            delegationTokenId
        );
        if (!isDelegatedValue) revert NoDelegations();

        uint256 pepeTokenPrice = calculateTokensFromEth(lowFee);
        uint256 pepeAmount;
        if (pepes == publicMaxMint) {
            pepeAmount = pepeTokenPrice * (pepes - 1);
        } else {
            pepeAmount = pepeTokenPrice * pepes;
        }
        if (!pepe.transferFrom(msg.sender, address(this), pepeAmount))
            revert TransferFailed();
        _mint(destination, pepes);
    }

    /// @notice MerkleTree Claim
    /// @param proof proof to verify wallet with root
    function claimPurchase(bytes32[] calldata proof) public {
        if (!saleStatus) revert SaleIsOff();
        if (_totalMinted() >= maxSupply) revert MaxSupplyReached();
        if (_getAux(msg.sender) != 0) revert AlreadyClaimed();
        if (!verifyClaimList(proof)) revert NotWhitelisted();
        --claimsToMint;
        _setAux(msg.sender, 1);
        _mint(msg.sender, 1);
    }

    /// @notice Reserves specified number of pepes to a wallet
    /// @param pepes - total number of pepes to reserve (must be less than teamReserve size)
    function mintTeamReserve(uint32 pepes) external onlyOwner {
        if (_totalMinted() + pepes > maxSupply) revert MaxSupplyReached();
        teamToMint -= pepes;
        _mint(msg.sender, pepes);
    }

    /// @notice Gift a give number of pepes into a specific wallet
    /// @param wallet - wallet address to mint to
    /// @param pepes - total number of pepes to gift
    function giftTeamReserve(address wallet, uint32 pepes) external onlyOwner {
        if (_totalMinted() + pepes > maxSupply) revert MaxSupplyReached();
        teamToMint -= pepes;
        _mint(wallet, pepes);
    }

    /**
     * -----------  UTILITY FUNCTIONS -----------
     */

    /// @notice external function to check if a wallet has already claim
    function hasClaimed(address wallet) external view returns (bool result) {
        return _getAux(wallet) != 0;
    }

    /// @notice check input delegation
    /// @param delType type of delegation
    /// @param vault delegation vault
    /// @param delContract delegation contract (if contract type delegation)
    /// @param delTokenId delegation token id (it token type delegation)
    function checkDelegation(
        uint32 delType,
        address vault,
        address delContract,
        uint32 delTokenId
    ) internal view returns (bool result) {
        if (delType == 1) {
            result = reg.checkDelegateForAll(msg.sender, vault);
        }
        if (delType == 2) {
            result = reg.checkDelegateForContract(
                msg.sender,
                vault,
                delContract
            );
        }
        if (delType == 3) {
            result = reg.checkDelegateForToken(
                msg.sender,
                vault,
                delContract,
                delTokenId
            );
        }
    }

    /// @notice internal function to verify claimlist
    function verifyClaimList(
        bytes32[] calldata proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verifyCalldata(proof, claimListRoot, leaf);
    }

    /// @notice calculate the amount in $PEPE from $ETH input
    /// @param ethAmount amount to convert
    function calculateTokensFromEth(
        uint256 ethAmount
    ) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(pepe);
        uint256[] memory amounts = IUniswapV2Router02(ROUTER).getAmountsOut(
            ethAmount,
            path
        );
        return amounts[1];
    }

    /// @notice base token uri
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /// @notice read token uri
    /// @param tokenId token id
    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721A, IERC721A) returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * -----------  SET FUNCTIONS -----------
     */

    /// @notice set baseURI
    /// @param _newBaseURI new baseURI
    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    /// @notice Set supply
    /// @param _maxSupply number of tokens in the supply
    function setSupply(uint32 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    /// @notice claimable token counter
    /// @param _claimsToMint number of claimable tokens
    function setClaimsToMint(uint32 _claimsToMint) external onlyOwner {
        claimsToMint = _claimsToMint;
    }

    /// @notice Set publicMaxMint limit
    /// @param _publicMaxMint new mint limit per wallet
    function setPublicMaxMint(uint32 _publicMaxMint) external onlyOwner {
        publicMaxMint = _publicMaxMint;
    }

    /// @notice Set purchase fee
    /// @param _baseFee new purchase fee price in Wei format
    function setBaseFee(uint64 _baseFee) external onlyOwner {
        baseFee = _baseFee;
    }

    /// @notice Set purchase fee
    /// @param _lowFee new purchase fee price in Wei format
    function setLowFee(uint64 _lowFee) external onlyOwner {
        lowFee = _lowFee;
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

    /// @notice set the secondary sales royalties % and receiver
    /// @param _receiver fee's receiver
    /// @param _feeNumerator fee's percentage
    function setDefaultRoyalty(
        address _receiver,
        uint96 _feeNumerator
    ) public onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /// @notice Withdraw funds to team and ambassadors
    /// @param ambassadors ambassadors wallets array
    /// @param percentages ambassadors percentages array
    function withdraw(
        address[] calldata ambassadors,
        uint256[] calldata percentages
    ) external onlyOwner {
        require(ambassadors.length == percentages.length, "Wrong length");

        uint256 balanceBefore = address(this).balance;
        uint256 tokenBalanceBefore = pepe.balanceOf(address(this));

        for (uint256 i; i < ambassadors.length; ) {
            uint256 amount = (balanceBefore * percentages[i]) / 10_000;
            (bool success, ) = payable(ambassadors[i]).call{value: amount}("");
            if (!success) revert TransferFailed();
            uint256 tokenAmount = (tokenBalanceBefore * percentages[i]) /
                10_000;
            if (!pepe.transfer(ambassadors[i], tokenAmount))
                revert TransferFailed();

            unchecked {
                ++i;
            }
        }

        uint256 balanceAfter = address(this).balance;
        (bool s, ) = payable(ceo).call{value: balanceAfter / 2}("");
        if (!s) revert TransferFailed();
        (bool a, ) = payable(cto).call{value: balanceAfter / 2}("");
        if (!a) revert TransferFailed();

        uint256 tokenBalanceAfter = pepe.balanceOf(address(this));

        if (!pepe.transfer(ceo, tokenBalanceAfter / 2)) revert TransferFailed();
        if (!pepe.transfer(cto, tokenBalanceAfter / 2)) revert TransferFailed();
    }

    /**
     * -----------  OTHERS FUNCTIONS -----------
     */

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC2981, ERC721A, IERC721A) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
