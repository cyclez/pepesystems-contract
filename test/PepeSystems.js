const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PepeSystems", function () {
    let pepeSystems;
    let owner;
    let addr1;
    let addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        const PepeSystems = await ethers.getContractFactory("PepeSystems");
        pepeSystems = await PepeSystems.deploy();
    });

    it("should mint tokens on presaleDelegationPurchase", async function () {
        const tokenId1 = 1;
        const tokenId2 = 2;
        const tokenIds = [tokenId1, tokenId2];

        await pepeSystems.setSaleStatus(1); // Set sale status to PRESALE
        await pepeSystems.setPresaleMaxMint(2); // Set presale max mint to 2
        await pepeSystems.setLowFee(0.03); // Set low fee to 0.03 ether

        const purchaseTx = await pepeSystems.presaleDelegationPurchase(tokenIds, {
            value: ethers.utils.parseEther("0.06"), // Send 0.06 ether (0.03 ether per token)
        });

        // Check transaction events
        await expect(purchaseTx)
            .to.emit(pepeSystems, "Transfer") // Expect Transfer event to be emitted
            .withArgs(owner.address, addr1.address, tokenId1) // Check the event parameters
            .to.emit(pepeSystems, "Transfer")
            .withArgs(owner.address, addr1.address, tokenId2);

        // Check token ownership
        expect(await pepeSystems.ownerOf(tokenId1)).to.equal(addr1.address);
        expect(await pepeSystems.ownerOf(tokenId2)).to.equal(addr1.address);

        // Check token count
        expect(await pepeSystems.balanceOf(addr1.address)).to.equal(2);

        // Check mintedTokens count
        expect(await pepeSystems.mintedTokens()).to.equal(2);
    });

    it("should mint tokens on presaleOwnershipPurchase", async function () {
        const tokenId1 = 1;
        const tokenId2 = 2;
        const tokenIds = [tokenId1, tokenId2];

        await pepeSystems.setSaleStatus(1); // Set sale status to PRESALE
        await pepeSystems.setPresaleMaxMint(2); // Set presale max mint to 2
        await pepeSystems.setLowFee(0.03); // Set low fee to 0.03 ether

        const purchaseTx = await pepeSystems.presaleOwnershipPurchase(tokenIds, {
            value: ethers.utils.parseEther("0.06"), // Send 0.06 ether (0.03 ether per token)
        });

        // Check transaction events
        await expect(purchaseTx)
            .to.emit(pepeSystems, "Transfer") // Expect Transfer event to be emitted
            .withArgs(owner.address, addr1.address, tokenId1) // Check the event parameters
            .to.emit(pepeSystems, "Transfer")
            .withArgs(owner.address, addr1.address, tokenId2);

        // Check token ownership
        expect(await pepeSystems.ownerOf(tokenId1)).to.equal(addr1.address);
        expect(await pepeSystems.ownerOf(tokenId2)).to.equal(addr1.address);

        // Check token count
        expect(await pepeSystems.balanceOf(addr1.address)).to.equal(2);

        // Check mintedTokens count
        expect(await pepeSystems.mintedTokens()).to.equal(2);
    });

    it("should mint tokens on publicPurchase", async function () {
        await pepeSystems.setSaleStatus(2); // Set sale status to PUBLIC
        await pepeSystems.setPublicMaxMint(2); // Set public max mint to 2
        await pepeSystems.setbaseFee(0.04); // Set base fee to 0.04 ether

        const purchaseTx = await pepeSystems.publicPurchase(2, {
            value: ethers.utils.parseEther("0.08"), // Send 0.08 ether (0.04 ether per token)
        });

        // Check transaction events
        await expect(purchaseTx)
            .to.emit(pepeSystems, "Transfer") // Expect Transfer event to be emitted
            .withArgs(owner.address, addr1.address, 1) // Check the event parameters
            .to.emit(pepeSystems, "Transfer")
            .withArgs(owner.address, addr1.address, 2);

        // Check token ownership
        expect(await pepeSystems.ownerOf(1)).to.equal(addr1.address);
        expect(await pepeSystems.ownerOf(2)).to.equal(addr1.address);

        // Check token count
        expect(await pepeSystems.balanceOf(addr1.address)).to.equal(2);

        // Check mintedTokens count
        expect(await pepeSystems.mintedTokens()).to.equal(2);
    });

    it("should mint team reserve tokens", async function () {
        const tokenId1 = 1;
        const tokenId2 = 2;
        const tokenIds = [tokenId1, tokenId2];

        await pepeSystems.setSaleStatus(1); // Set sale status to PRESALE
        await pepeSystems.setPresaleMaxMint(2); // Set presale max mint to 2
        await pepeSystems.setLowFee(0.03); // Set low fee to 0.03 ether

        await pepeSystems.mintTeamReserve(addr1.address, 2, {
            from: owner.address,
        });

        // Check token ownership
        expect(await pepeSystems.ownerOf(tokenId1)).to.equal(addr1.address);
        expect(await pepeSystems.ownerOf(tokenId2)).to.equal(addr1.address);

        // Check token count
        expect(await pepeSystems.balanceOf(addr1.address)).to.equal(2);

        // Check mintedTokens count
        expect(await pepeSystems.mintedTokens()).to.equal(2);
    });
});
