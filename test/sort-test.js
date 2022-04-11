const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Sort Test", function () {
  let _dlobex;

  before(async () => {
    const Gen20Token = await ethers.getContractFactory("Gen20Token");
    const hbar_token = await Gen20Token.deploy(2000, "HBAR", "HBAR");
    await hbar_token.deployed();

    const husd_token = await Gen20Token.deploy(2000, "HUSD", "HUSD");
    await husd_token.deployed();

    const DLOBEX = await ethers.getContractFactory("DLOBEX");
    _dlobex = await DLOBEX.deploy(hbar_token.address, husd_token.address);
    await _dlobex.deployed();
  });

  it ("Buy Prices Sorted Test", async function () {
    await _dlobex.add_price(100, true);
    await _dlobex.add_price(101, true);
    await _dlobex.add_price(99, true);
    const prices = await _dlobex.buy_prices();
    expect(prices[0]).to.equal(101);
    expect(prices[1]).to.equal(100);
    expect(prices[2]).to.equal(99);
  });

  it ("Sell Prices Sorted Test", async function () {
    await _dlobex.add_price(100, false);
    await _dlobex.add_price(101, false);
    await _dlobex.add_price(99, false);
    const prices = await _dlobex.sell_prices();
    expect(prices[0]).to.equal(99);
    expect(prices[1]).to.equal(100);
    expect(prices[2]).to.equal(101);
  });
});
