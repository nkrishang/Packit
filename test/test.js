const { expect } = require("chai");

describe("Market", function() {

  it("Should register an asset with the right owner.", async function() {

    const Market = await ethers.getContractFactory("Market");
    const market = await Market.deploy();

    await market.deployed();
    const addresses = await ethers.getSigners();

    const vendor = addresses[1];
    const vendorAddr = await vendor.getAddress();

    const forSale = true;
    const price = ethers.utils.parseEther('5');
    const collateral = ethers.utils.parseEther('2.5');
    
    const description = "The fastest gaming ultrabook";
    const assetID = ethers.utils.keccak256(description + `${vendorAddr}`);

    await market.connect(vendor).registerAsset(forSale, price, collateral, assetID);

    expect(await market.ownershipLedger[assetID]).to.equal(vendorAddr);
  });
})