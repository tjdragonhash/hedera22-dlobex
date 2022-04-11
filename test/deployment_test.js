const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Deployment Test", function () {
  let _owner;
  let _participant;

  let _hbar_token;
  let _husd_token;
  let _dlobex;

  before(async () => {
    const [owner, adr1] = await ethers.getSigners();
    _owner = owner;
    _participant = adr1;

    const Gen20Token = await ethers.getContractFactory("Gen20Token");
    _hbar_token = await Gen20Token.deploy(2000, "HBAR", "HBAR");
    await _hbar_token.deployed();
    console.log("_hbar_token address:", _hbar_token.address);

    _husd_token = await Gen20Token.deploy(2000, "HUSD", "HUSD");
    await _husd_token.deployed();
    console.log("_husd_token address:", _husd_token.address);

    const DLOBEX = await ethers.getContractFactory("DLOBEX");
    _dlobex = await DLOBEX.deploy(_hbar_token.address, _husd_token.address);
    await _dlobex.deployed();
  });

  it("Token addresses must match the above", async function () {
    expect(await _dlobex.base_token()).to.equal(_hbar_token.address);
    expect(await _dlobex.term_token()).to.equal(_husd_token.address);
  });

  it("Add participant", async function () {
    await expect(_dlobex.add_participant(_participant.address)).to.
      emit(_dlobex, 'ParticipantAddedEvent').
      withArgs(_participant.address);
    expect(await _dlobex.is_participant_allowed(_participant.address)).to.equal(true);
  });

  it("Remove participant", async function () {
    await expect(_dlobex.remove_participant(_participant.address)).to.
      emit(_dlobex, 'ParticipantRemovedEvent').
      withArgs(_participant.address);
    expect(await _dlobex.is_participant_allowed(_participant.address)).to.equal(false);
  });

  it("Start Trading", async function () {
    await expect(_dlobex.start_trading()).to.emit(_dlobex, 'TradingStartedEvent');
  });

  it("Stop Trading", async function () {
    await expect(_dlobex.stop_trading()).to.emit(_dlobex, 'TradingStoppedEvent');
  });
});
