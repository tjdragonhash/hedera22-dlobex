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

  it ("Basic Matched Sell Order", async function () {
     // We allow the smart contract to swap tokens up to given amount
     await _husd_token.connect(_participant_1).approve(_dlobex.address, 1100);
     await _hbar_token.connect(_participant_2).approve(_dlobex.address, 50);
    
    _dlobex.connect(_participant_1).place_limit_order(5, true, 50, 22); // 50 lots of HBAR/USD at 22 cents
    await _dlobex.print_clob();

    // There is an existing buy order for 10 lots of HBAR/USD at 22 cents
    // Seller is matching this exact order
    // _participant_1 buys 50 HBAR for 50 * 22 cents
    // _participant_1 (buyer) sends 1100 cents
    // _participant_2 (seller) sends 50 HBAR
 
    await _dlobex.print_clob();
    
    await expect(_dlobex.connect(_participant_2).place_limit_order(6, false, 50, 22))
      .to.emit(_dlobex, 'SettlementInstruction')
      .withArgs(_participant_1.address, 1100, _husd_token.address, _participant_2.address, 50, _hbar_token.address, 22);
    
    await _dlobex.print_clob();

    expect(await _husd_token.balanceOf(_participant_1.address)).to.equal(200000 - 1100);
    expect(await _husd_token.balanceOf(_participant_2.address)).to.equal(200000 + 1100);

    expect(await _hbar_token.balanceOf(_participant_1.address)).to.equal(200000 + 50);
    expect(await _hbar_token.balanceOf(_participant_2.address)).to.equal(200000 - 50);
  });

  it ("Basic Matched Buy Order", async function () {
    // We allow the smart contract to swap tokens up to given amount
    await _hbar_token.connect(_participant_1).approve(_dlobex.address, 50);
    await _husd_token.connect(_participant_2).approve(_dlobex.address, 1100);
    
    await _dlobex.connect(_participant_1).place_limit_order(7, false, 50, 22); // 50 lots of HBAR/USD at 22 cents
    await _dlobex.print_clob();

    // There is an existing sell order for 10 lots of HBAR/USD at 22 cents
    // Buyer is matching this exact order
    // _participant_1 sells 50 HBAR for 50 * 22 cents
    // _participant_1 (seller) sends 50 HBAR
    // _participant_2 (buyer) sends 50 * 22 cents

    await _dlobex.print_clob();
    
    await expect(_dlobex.connect(_participant_2).place_limit_order(8, true, 50, 22))
      .to.emit(_dlobex, 'SettlementInstruction')
      .withArgs(_participant_1.address, 50, _hbar_token.address, _participant_2.address, 1100, _husd_token.address, 22);
    
    await _dlobex.print_clob();

    expect(await _husd_token.balanceOf(_participant_1.address)).to.equal(200000);
    expect(await _husd_token.balanceOf(_participant_2.address)).to.equal(200000);

    expect(await _hbar_token.balanceOf(_participant_1.address)).to.equal(200000);
    expect(await _hbar_token.balanceOf(_participant_2.address)).to.equal(200000);
  });

  it ("Basic Matched Failed Approve Amount", async function () {
    // We allow the smart contract to swap tokens up to given amount
    await _husd_token.connect(_participant_1).approve(_dlobex.address, 1100);
    await _hbar_token.connect(_participant_2).approve(_dlobex.address, 49);
    
    _dlobex.connect(_participant_1).place_limit_order(9, true, 50, 22); // 50 lots of HBAR/USD at 22 cents
    await _dlobex.print_clob();

    await _dlobex.print_clob();
    
    await expect(_dlobex.connect(_participant_2).place_limit_order(10, false, 50, 22))
    .to.be.revertedWith("{Buy} Not enough funds for settlement from order_owner");
    
    await _dlobex.print_clob();

    expect(await _husd_token.balanceOf(_participant_1.address)).to.equal(200000);
    expect(await _husd_token.balanceOf(_participant_2.address)).to.equal(200000);

    expect(await _hbar_token.balanceOf(_participant_1.address)).to.equal(200000);
    expect(await _hbar_token.balanceOf(_participant_2.address)).to.equal(200000);
  });
});
