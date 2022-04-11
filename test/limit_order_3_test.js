const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Limit Order Test II", function () {
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

    console.log("p1 address", _participant_1.address);
    console.log("p2 address", _participant_2.address);

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

  it ("Complex Matched Order", async function () {
    // We allow the smart contract to swap tokens up to given amount
    await _husd_token.connect(_participant_1).approve(_dlobex.address, 10000);
    await _hbar_token.connect(_participant_2).approve(_dlobex.address, 10000);
    
    await _dlobex.connect(_participant_1).place_limit_order(1, true, 50, 22); // 50 lots of HBAR/USD at 22 cents
    await _dlobex.connect(_participant_1).place_limit_order(2, true, 100, 21);
    await _dlobex.connect(_participant_1).place_limit_order(3, true, 150, 20);
    await _dlobex.print_clob();

    // _participant_2 wants to sell 175 lots at 22
    // _participant_1 (buyer) sends 1100 cents
    // _participant_2 (seller) sends 50 HBAR
    await _dlobex.connect(_participant_2).place_limit_order(6, false, 175, 22);
    await _dlobex.print_clob();

    expect(await _husd_token.balanceOf(_participant_1.address)).to.equal(200000 - 1100);
    expect(await _husd_token.balanceOf(_participant_2.address)).to.equal(200000 + 1100);

    expect(await _hbar_token.balanceOf(_participant_1.address)).to.equal(200000 + 50);
    expect(await _hbar_token.balanceOf(_participant_2.address)).to.equal(200000 - 50);
  });

  it ("Get Settlement Instructions", async function () {
    const nb_setl = await _dlobex.get_number_of_settlements();
    for(let i = 0; i < nb_setl; i++) {
      const setl = await _dlobex.get_settlement(i);
      console.log(setl);
    }
  });

  it ("Reset", async function () {
    await _dlobex.print_clob();
    await _dlobex.reset();
    await _dlobex.print_clob();
  });
});
