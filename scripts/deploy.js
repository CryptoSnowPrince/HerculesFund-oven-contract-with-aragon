/* global ethers */
/* eslint prefer-const: "off" */
require("@nomiclabs/hardhat-web3");

const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')
const LibPoolToken = require('../artifacts/contracts/libraries/LibPoolToken.sol/LibPoolToken.json')
const LibAddRemoveToken = require('../artifacts/contracts/libraries/LibAddRemoveToken.sol/LibAddRemoveToken.json')
const LibPoolEntryJoin = require('../artifacts/contracts/libraries/LibPoolEntryJoin.sol/LibPoolEntryJoin.json')
const LibPoolEntryExit = require('../artifacts/contracts/libraries/LibPoolEntryExit.sol/LibPoolEntryExit.json')
const LibPoolMath = require('../artifacts/contracts/libraries/LibPoolMath.sol/LibPoolMath.json')
const LibWights = require('../artifacts/contracts/libraries/LibWeights.sol/LibWeights.json')
const LibSafeApprove = require('../artifacts/contracts/libraries/LibSafeApprove.sol/LibSafeApprove.json')
const { ethers } = require('hardhat')
const balancerFactoryBytecode = require("./utils/balancerFactoryBytecode");
const balancerPoolBytecode = require("./utils/balancerPoolBytecode");

console.log("deploy started!");
const libraries = [LibPoolToken, LibAddRemoveToken, LibPoolEntryJoin, LibPoolEntryExit, LibPoolMath, LibWights, LibSafeApprove]

async function deployDiamond () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0];

  //deploy balancer factory and pool
  let balancerFactory = null
  if(true) {
    const factoryTx = await contractOwner.sendTransaction({data: balancerFactoryBytecode});
    // const factoryContract = await ethers.getContractAt('IbFactory', factoryTx.creates);
    // const tx = await factoryContract.newBPool();
    // const receipt = await tx.wait(2); // wait for 2 confirmations
    // const event = receipt.events.pop();
    balancerFactory = factoryTx.creates;
    console.log(`Deployed balancer pool at : ${balancerFactory}`);
    // const poolTx = (await signer.sendTransaction({data: balancerPoolBytecode, gasLimit: 8000000}));
  }

  // deploy libraries
  const libAddresses = {};
  for (let i = 0; i < libraries.length; i++) {
    const library = libraries[i];
    // const trx = (await accounts[0].sendTransaction({data: library.bytecode}));
    const Library = await ethers.getContractFactory(library.contractName)
    const deployedLibrary = await Library.deploy()
  // await trx.wait(1);
    console.log(`${library.contractName} deployed: ${deployedLibrary.address}`);
    libAddresses[library.contractName] = `${deployedLibrary.address}`
  }
  
  // deploy DiamondCutFacet
  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
  const diamondCutFacet = await DiamondCutFacet.deploy()
  await diamondCutFacet.deployed()
  console.log('DiamondCutFacet deployed:', diamondCutFacet.address)

  // // deploy PV2SmartPoolFactory
  // const PV2SmartPoolFactory = await ethers.getContractFactory('PV2SmartPoolFactory')
  // const pV2SmartPoolFactory = await PV2SmartPoolFactory.deploy()
  // await pV2SmartPoolFactory.deployed()
  // console.log('PV2SmartPoolFactory deployed:', pV2SmartPoolFactory.address)

  // deploy Diamond
  const Diamond = await ethers.getContractFactory('PV2SmartPool')
  const diamond = await Diamond.deploy(diamondCutFacet.address, contractOwner.address)
  await diamond.deployed()
  console.log('Diamond deployed:', diamond.address)

  // deploy DiamondInit
  // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
  // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
  const DiamondInit = await ethers.getContractFactory('DiamondInit')
  const diamondInit = await DiamondInit.deploy()
  await diamondInit.deployed()
  console.log('DiamondInit deployed:', diamondInit.address)

  // deploy facets
  console.log('')
  console.log('Deploying facets')
  const LoupeFacetName = [
    'DiamondLoupeFacet',
  ]
  const cut = []
  const Facet = await ethers.getContractFactory(LoupeFacetName[0])
  const facet = await Facet.deploy()
  await facet.deployed()
  console.log(`${LoupeFacetName} deployed: ${facet.address}`)
  cut.push({
    facetAddress: facet.address,
    action: FacetCutAction.Add,
    functionSelectors: getSelectors(facet)
  })
  const FacetNames = [
    'InitAndAdminFacet',
    'PoolEntryFacet',
    'PoolExitFacet',
    'TokenWeightFacet',
    'ViewFacet',
  ]
  for (const FacetName of FacetNames) {
    let Facet = null
    if(FacetName === "PoolEntryFacet") {
      Facet = await ethers.getContractFactory(FacetName, {libraries: {LibPoolEntryJoin: libAddresses["LibPoolEntryJoin"]}})
    }
    else if(FacetName === "PoolExitFacet") {
      Facet = await ethers.getContractFactory(FacetName, {libraries: {LibPoolEntryExit: libAddresses["LibPoolEntryExit"]}})
    }
    else if(FacetName === "TokenWeightFacet") {
      Facet = await ethers.getContractFactory(FacetName, {libraries: {LibAddRemoveToken: libAddresses["LibAddRemoveToken"], LibWeights: libAddresses["LibWeights"]}})
    }
    else if(FacetName === "ViewFacet") {
      Facet = await ethers.getContractFactory(FacetName, {libraries: {LibPoolMath: libAddresses["LibPoolMath"]}})
    }
    else {
      Facet = await ethers.getContractFactory(FacetName)
    }
    const facet = await Facet.deploy()
    await facet.deployed()
    console.log(`${FacetName} deployed: ${facet.address}`)
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    })
  }

  // upgrade diamond with facets
  // console.log('Diamond Cut:', cut)
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address)
  let tx
  let receipt
  // call to init function
  let functionCall = diamondInit.interface.encodeFunctionData('init')
  tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall)
  console.log('Diamond cut tx: ', tx.hash)
  receipt = await tx.wait()
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`)
  }
  console.log('Completed diamond cut')

  //init diamond
  const diamondInitAndAdmin = await ethers.getContractAt('IPV2SmartPool', diamond.address)
  await diamondInitAndAdmin.init(contractOwner.address, "IMPL", "IMPLSYMBOL", "1337");
  console.log("diamond initialized");

  // deploy PProxiedFactory
  const PProxiedFactory = await ethers.getContractFactory('PProxiedFactory', contractOwner)
  const factory = await PProxiedFactory.deploy()
  const factoryContract = await ethers.getContractAt('PProxiedFactory', factory.address)
  console.log('factory deploy tx: ', factory.address)

  //init factory
  await factoryContract.init(balancerFactory, diamond.address);
  console.log("factory initialized");
  console.log("All successed!");

  return diamond.address
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
console.log("here", require.main === module);
if (true) {
  deployDiamond()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })
}

exports.deployDiamond = deployDiamond
