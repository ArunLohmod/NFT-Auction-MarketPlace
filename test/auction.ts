import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Auction, MyToken } from "../typechain-types";

describe("NFT auction marketplace", function () {
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr3: SignerWithAddress;
  let nftToken: MyToken;
  let marketPlace: Auction;

  before(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const myToken = await ethers.getContractFactory("MyToken");
    nftToken = await myToken.deploy();
    await nftToken.deployed();

    const auction = await ethers.getContractFactory("Auction");
    marketPlace = await auction.deploy(nftToken.address, owner.address);

    // minting nfts for addr1
    await nftToken.safeMint(addr1.address);
    await nftToken.safeMint(addr1.address);
  });

  it("should check the address of nft", async function () {
    expect(await marketPlace.TokenX()).to.equal(nftToken.address);
  });
  it("addr1 should have 2 nfts", async function () {
    expect(await nftToken.balanceOf(addr1.address)).to.equal(2);
  });

  it("should revert if someone other than owner is putting nft on auction", async function () {
    await expect(marketPlace.createSaleAuction(0, ethers.utils.parseEther("1")))
      .to.be.reverted;
  });

  it("addr1 will put token 0 for auction", async function () {
    await nftToken.connect(addr1).setApprovalForAll(marketPlace.address, true);
    await marketPlace
      .connect(addr1)
      .createSaleAuction(0, ethers.utils.parseEther("1"));

    expect(await nftToken.ownerOf(0)).to.equal(marketPlace.address);
    expect(await marketPlace.auctionStatusCheck(0)).to.equal(true);
    expect(await marketPlace.totalAuction()).to.equal(1);
    expect(
      (await marketPlace.conductedAuctions(addr1.address)).toString()
    ).to.be.equal("0");
  });
  it("should revert if bid is less than previous bid", async function () {
    await expect(
      marketPlace
        .connect(addr2)
        .placeBid(0, { value: ethers.utils.parseEther("1") })
    ).to.be.reverted;
  });
  it("should transfer the nft to the highest bidder", async function () {
    await marketPlace
      .connect(addr2)
      .placeBid(0, { value: ethers.utils.parseEther("2") });
    await marketPlace
      .connect(addr3)
      .placeBid(0, { value: ethers.utils.parseEther("3") });

    await marketPlace.connect(addr1).finishAuction(0);

    expect(await nftToken.ownerOf(0)).to.equal(addr3.address);
    expect(
      (await marketPlace.participatedAuctions(addr2.address)).toString()
    ).to.equal("0");
    expect(
      (await marketPlace.participatedAuctions(addr3.address)).toString()
    ).to.equal("0");
    expect(
      (await marketPlace.collectedArtsList(addr3.address)).toString()
    ).to.equal("0");
  });

  it("can not bid if the auction is over", async function () {
    await expect(
      marketPlace
        .connect(addr2)
        .placeBid(0, { value: ethers.utils.parseEther("2") })
    ).to.be.reverted;
  });
});
