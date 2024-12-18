// test/EvilToken.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EvilToken", function () {
    let EvilToken, evilToken, owner, addr1, addr2;
    const initialSupply = ethers.parseEther("25000000000"); // 25 billion tokens
    // const tradeMilestone = ethers.parseEther("1000000"); // 1 million tokens milestone
    const milestoneBurnRate = 1; // 0.1% of the milestone

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        EvilToken = await ethers.getContractFactory("EvilToken");
        evilToken = await EvilToken.deploy("EvilToken", "EVIL", initialSupply);
        await evilToken.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the correct initial values", async function () {
            const totalSupply = await evilToken.totalSupply();
            expect(totalSupply).to.equal(initialSupply);
        });

        it("Should assign the total supply to the owner", async function () {
            const ownerBalance = await evilToken.balanceOf(owner.address);
            expect(ownerBalance).to.equal(initialSupply);
        });

        it("Should allow transfers between accounts", async function () {
            const transferAmount = ethers.parseEther("1000");

            await evilToken.transfer(addr1.address, transferAmount);
            const addr1Balance = await evilToken.balanceOf(addr1.address);

            expect(addr1Balance).to.equal(transferAmount);
        });

        it("Should trigger milestone burns", async function () {
            const tradeMilestone = await evilToken.tradeMilestone();
            const transferAmount = tradeMilestone + (ethers.parseEther("1"));
        
            // Transfer to trigger milestone
            await evilToken.transfer(addr1.address, transferAmount);
        
            // Check burned tokens
            const totalBurned = await evilToken.totalBurned();
            expect(totalBurned).to.be.gt(0);
        
            // Verify emitted TokensBurned event
            await expect(evilToken.transfer(addr2.address, ethers.parseEther("500")))
            .to.emit(evilToken, "TokensBurned");
        });

        it("Should reset milestone after burn", async function () {
            const tradeMilestone = await evilToken.tradeMilestone();
        
            // Transfer to trigger milestone
            await evilToken.transfer(addr1.address, tradeMilestone);
        
            // Check current milestone is reset
            const currentMilestone = await evilToken.currentMilestone();
            expect(currentMilestone).to.equal(0);
        });
    });
});
