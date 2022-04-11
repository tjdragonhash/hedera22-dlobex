const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Market Order Test", function () {
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
  });

  it ("Basic Market Order Test", async function () {
    await _husd_token.connect(_participant_1).approve(_dlobex.address, 10000);
    await _hbar_token.connect(_participant_2).approve(_dlobex.address, 10000);

    await _dlobex.connect(_participant_1).place_limit_order(1, true, 50, 24);
    await _dlobex.connect(_participant_1).place_limit_order(2, true, 100, 23);
    await _dlobex.connect(_participant_1).place_limit_order(3, true, 200, 22); 
    
    await _dlobex.print_clob();

    await _dlobex.connect(_participant_2).place_market_order(false, 75); // full match
    await _dlobex.print_clob();

    const dbg = await _dlobex.debug();
    console.log("DBG: ", dbg);

    const nb_stl = await _dlobex.get_number_of_settlements();
    expect(nb_stl).to.equal(2);

    const stl1 = await _dlobex.get_settlement(0);
    console.log("stl1: ", stl1);
    expect(stl1.adr1).to.equal(_participant_1.address);
    expect(stl1.token1_amount).to.equal(50 * 24);
    expect(stl1.adr2).to.equal(_participant_2.address);
    expect(stl1.token2_amount).to.equal(50);
    expect(stl1.price).to.equal(24);

    const stl2 = await _dlobex.get_settlement(1);
    console.log("stl2: ", stl2);
    expect(stl2.token1_amount).to.equal(25 * 23);
    expect(stl2.token2_amount).to.equal(25);
    expect(stl2.price).to.equal(23);
  });
});
