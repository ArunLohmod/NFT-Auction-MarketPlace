import { ethers } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();

  const myToken = await ethers.getContractFactory("MyToken");
  const nftToken = await myToken.deploy();
  await nftToken.deployed();

  const auction = await ethers.getContractFactory("Auction");
  const marketPlace = await auction.deploy(nftToken.address, owner.address);
  await marketPlace.deployed();

  console.log(`nft contract is deployed to ${nftToken.address}`);

  console.log(
    `marketPlace of nft ${nftToken.address} and owner ${owner.address} is deployed to ${marketPlace.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
