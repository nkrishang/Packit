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
  beforeEach(async () => {
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
  });

  it("Should register an asset with the right owner.", async function() {
    const addresses = await ethers.getSigners();

    const vendor = addresses[1];
    const vendorAddr = await vendor.getAddress();

    const forSale = true;
    const price = ethers.utils.parseEther('5');
    const collateral = ethers.utils.parseEther('2.5');

    const description = "The fastest gaming ultrabook";
    const assetID = ethers.utils.keccak256(ethers.utils.hashMessage(description + `${vendorAddr}`));

    await market.connect(vendor).registerAsset(forSale, price, collateral, assetID);

    expect(await market.ownershipRecord[assetID]).to.equal(vendorAddr);
  });
})
