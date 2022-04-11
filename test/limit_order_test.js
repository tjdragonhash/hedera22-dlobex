const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Limit Order Test", function () {
  let _owner;
  let _participant_1;
  let _participant_2;

  let _hbar_token;
  let _husd_token;
  let _dlobex;

  before(async () => {
    const [owner, adr1, adr2] = await ethers.getSigners();
    _owner = owner;
    _participant_1 = adr1;
    _participant_2 = adr2;

    const Gen20Token = await ethers.getContractFactory("Gen20Token");
    _hbar_token = await Gen20Token.deploy(1000000, "HBAR", "HBAR");
    await _hbar_token.deployed();
    console.log("_hbar_token address:", _hbar_token.address);

    _husd_token = await Gen20Token.deploy(1000000, "HUSD", "HUSD");
    await _husd_token.deployed();
    console.log("_husd_token address:", _husd_token.address);

    const DLOBEX = await ethers.getContractFactory("DLOBEX");
    _dlobex = await DLOBEX.deploy(_hbar_token.address, _husd_token.address);
    await _dlobex.deployed();

    // Let's transfer some tokens to participants
    await _hbar_token.transfer(_participant_1.address, 200000);
    await _hbar_token.transfer(_participant_2.address, 200000);
    await _husd_token.transfer(_participant_1.address, 200000);
    await _husd_token.transfer(_participant_2.address, 200000);

    await _dlobex.add_participant(_participant_1.address);
    await _dlobex.add_participant(_participant_2.address);
    await _dlobex.start_trading();

    await _husd_token.connect(_participant_1).approve(_dlobex.address, 10000);
    await _hbar_token.connect(_participant_2).approve(_dlobex.address, 10000);
  });

  it ("Test Validate Limit Order", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(1, true, 0, 1))
      .to.be.revertedWith("Amount must be > 0");
    await expect(_dlobex.connect(_participant_1).place_limit_order(1, true, 1, 0))
      .to.be.revertedWith("Price must be > 0");
  });

  it ("Place One Buy Limit Order", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(1, true, 10, 650))
      .to.emit(_dlobex, 'OrderPlacedEvent')
      .withArgs([1, 1, _participant_1.address, true, 10, 650]);
    await _dlobex.print_clob();
  });

  it ("Place Second Buy Limit Order at Same Price", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(2, true, 20, 650))
      .to.emit(_dlobex, 'OrderPlacedEvent')
      .withArgs([2, 2, _participant_1.address, true, 20, 650]);
    await _dlobex.print_clob();
  });

  it ("Place Third Sell Limit Order at Same Price", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(3, false, 20, 660))
      .to.emit(_dlobex, 'OrderPlacedEvent')  
      .withArgs([3, 3, _participant_1.address, false, 20, 660]);
    await _dlobex.print_clob();
  });

  it ("Test Cross Buy > Best Sell", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(4, true, 50, 670))
      .to.be.revertedWith("Crossed buy price > best sell price");
  });

  it ("Test Cross Sell < Best Buy", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(4, false, 50, 570))
      .to.be.revertedWith("Crossed sell price < best buy price");
  });

  it ("Matched Order Same Owner", async function () {
    await expect(_dlobex.connect(_participant_1).place_limit_order(4, false, 10, 650))
      .to.be.revertedWith("Cannot match own order");
  });
});
