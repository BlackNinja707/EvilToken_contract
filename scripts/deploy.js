const hre = require("hardhat");

async function main() {
    const EvilToken = await hre.ethers.getContractFactory("EvilToken");
    const evilToken = await EvilToken.deploy("EvilToken", "EVIL", ethers.parseEther("25000000000"));
    await evilToken.waitForDeployment();

    console.log("EvilToken deployed to:", evilToken.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
    