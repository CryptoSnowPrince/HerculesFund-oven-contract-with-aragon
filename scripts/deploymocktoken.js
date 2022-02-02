/* global ethers */
/* eslint prefer-const: "off" */

const { ethers } = require('hardhat')

console.log("mock token deploy started!");

async function deployMockToken() {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0];

  // deploy mock token0
  const Token0 = await ethers.getContractFactory('ERC20', contractOwner)
  const token0 = await Token0.deploy("token0", "TK0")
  // await token.mint(await contractOwner.getAddress(), constants.WeiPerEther.mul(10000000000000));
  // const token0Contract = await ethers.getContractAt('ERC20', token0.address)
  console.log('token0 deploy tx: ', token0.address)

  // deploy mock token1
  const Token1 = await ethers.getContractFactory('ERC20', contractOwner)
  const token1 = await Token1.deploy("token1", "TK1")
  // await token.mint(await contractOwner.getAddress(), constants.WeiPerEther.mul(10000000000000));
  // const token0Contract = await ethers.getContractAt('ERC20', token0.address)
  console.log('token1 deploy tx: ', token1.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
console.log("here", require.main === module);
if (true) {
  deployMockToken()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })
}

exports.deployMockToken = deployMockToken
