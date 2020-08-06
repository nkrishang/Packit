const { expect } = require("chai");
const { ethers, config } = require("@nomiclabs/buidler");
const { readArtifact } = require("@nomiclabs/buidler/plugins");

// ref: https://github.com/nomiclabs/buidler/issues/611
function linkBytecode(artifact, libraries) {
  let bytecode = artifact.bytecode;

  for (const [fileName, fileReferences] of Object.entries(
    artifact.linkReferences
  )) {
    for (const [libName, fixups] of Object.entries(fileReferences)) {
      const addr = libraries[libName];
      if (addr === undefined) {
        continue;
      }

      for (const fixup of fixups) {
        bytecode =
          bytecode.substr(0, 2 + fixup.start * 2) +
          addr.substr(2) +
          bytecode.substr(2 + (fixup.start + fixup.length) * 2);
      }
    }
  }

  return bytecode;
}

describe("Market", function() {
  let market;
  let vendor;
  let customer;
  before(async () => {
    const Signatures = await ethers.getContractFactory("Signatures");
    const library = await Signatures.deploy();
    await library.deployed();

    const cArtifact = await readArtifact(config.paths.artifacts, "Market");
    const linkedBytecode = linkBytecode(cArtifact, { Signatures: library.address });
    const Market = await ethers.getContractFactory(
      cArtifact.abi,
      linkedBytecode
    );

    market = await Market.deploy();
    await market.deployed();

    const addresses = await ethers.getSigners();

    vendor = addresses[1];
    customer = addresses[2];
  });

  it("Should register an asset with the right owner.", async function() {
    
    const vendorAddr = await vendor.getAddress();

    const forSale = true;
    const price = ethers.utils.parseEther('5');
    const collateral = ethers.utils.parseEther('2.5');

    const description = "The fastest gaming ultrabook";
    const assetID = ethers.utils.keccak256(ethers.utils.hashMessage(description + `${vendorAddr}`));
    //console.log(assetID);

    await market.connect(vendor).registerAsset(forSale, price, collateral, assetID);

    expect(await market.getAssetOwner(assetID)).to.equal(vendorAddr);
  });

  it("Should create a transaction receipt upon purchase.", async function() {
    
    const vendorAddr = await vendor.getAddress();
    const customerAddr = await customer.getAddress();

    const description = "The fastest gaming ultrabook";
    const assetID = ethers.utils.keccak256(ethers.utils.hashMessage(description + `${vendorAddr}`));

    await market.connect(customer).purchase(vendorAddr, assetID, {
      value: ethers.utils.parseEther("7.5")
    });

    expect(await market.getTransactionRecipient(customerAddr, assetID)).to.equal(vendorAddr);
  })

  it("Should store and acknowledge the vendor signature", async function() {

    let customerAddr = await customer.getAddress();
    let vendorAddr = await vendor.getAddress();

    const description = "The fastest gaming ultrabook";
    const assetID = ethers.utils.keccak256(ethers.utils.hashMessage(description + `${vendorAddr}`));

    const hashValue = await market.connect(vendor).getAssetHash(customerAddr, assetID);
    const vendorSignature = await vendor.signMessage(hashValue);

    await market.connect(vendor).initiateSale(customerAddr, assetID, vendorSignature);

    expect(await market.getVendorSignature(customerAddr, assetID)).to.equal(vendorSignature);
    expect(await market.getVendorSent(customerAddr, assetID)).to.equal(true);

  });

  it("Should acknolwedge the customer's reception of asset upon verifying sale.", async function() {

    let customerAddr = await customer.getAddress();
    let vendorAddr = await vendor.getAddress();

    const description = "The fastest gaming ultrabook";
    const assetID = ethers.utils.keccak256(ethers.utils.hashMessage(description + `${vendorAddr}`));

    const hashValue = await market.connect(vendor).getAssetHash(customerAddr, assetID);

    await market.connect(customer).verifySale(assetID, hashValue);

    expect(await market.verifyOwnershipTransfer(vendorAddr, assetID)).to.equal(false);
    expect(await market.getAssetOwner(assetID)).to.equal(customerAddr);
    expect(await market.getCustomerReceived(customerAddr, assetID)).to.equal(true);
  })
})
