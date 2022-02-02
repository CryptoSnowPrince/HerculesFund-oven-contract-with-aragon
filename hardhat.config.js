/* global ethers task */
require('@nomiclabs/hardhat-waffle')
const { resolve } = require("path");
const { getSelectors, FacetCutAction } = require('./scripts/libraries/diamond.js')

const { config: dotenvConfig } = require("dotenv");
const { HardhatUserConfig } = require("hardhat/config");
const { NetworkUserConfig } = require("hardhat/types");
const { BigNumber, utils, constants, ContractTransaction, Wallet, Contract } = require("ethers");
const LibPoolTokenArtifact = require('./artifacts/contracts/libraries/LibPoolToken.sol/LibPoolToken.json')
const LibAddRemoveTokenArtifact = require('./artifacts/contracts/libraries/LibAddRemoveToken.sol/LibAddRemoveToken.json')
const LibPoolEntryJoinArtifact = require('./artifacts/contracts/libraries/LibPoolEntryJoin.sol/LibPoolEntryJoin.json')
const LibPoolEntryExitArtifact = require('./artifacts/contracts/libraries/LibPoolEntryExit.sol/LibPoolEntryExit.json')
const LibPoolMathArtifact = require('./artifacts/contracts/libraries/LibPoolMath.sol/LibPoolMath.json')
const LibWeightsArtifact = require('./artifacts/contracts/libraries/LibWeights.sol/LibWeights.json')
const LibSafeApproveArtifact = require('./artifacts/contracts/libraries/LibSafeApprove.sol/LibSafeApprove.json')
const PProxiedFactoryArtifact = require('./artifacts/contracts/factory/PProxiedFactory.sol/PProxiedFactory.json')
dotenvConfig({ path: resolve(__dirname, "./.env") });

const { deployBalancerFactory, deployAndGetLibObject, linkArtifact } =require("./utils");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html


// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const INFURA_API_KEY = process.env.INFURA_API_KEY || "";
const KOVAN_PRIVATE_KEY = process.env.KOVAN_PRIVATE_KEY || "";
const KOVAN_PRIVATE_KEY_SECONDARY = process.env.KOVAN_PRIVATE_KEY_SECONDARY || "";
const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY || "";
const RINKEBY_PRIVATE_KEY_SECONDARY = process.env.RINKEBY_PRIVATE_KEY_SECONDARY || "";
const MAINNET_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY || "";
const MAINNET_PRIVATE_KEY_SECONDARY = process.env.MAINNET_PRIVATE_KEY_SECONDARY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "bsctest",
  networks: {
    local: {
      url: "http://127.0.0.1:7545",
      // accounts: [process.env.PRIVATEKEYLOCAL]
    },
    bsctest: {
      url: "https://data-seed-prebsc-1-s1.binance.org",
      accounts: [process.env.PRIVATEKEY]
    },
    bsc: {
      url: "https://speedy-nodes-nyc.moralis.io/9f1fe98d210bc4fca911bee2/bsc/mainnet",
      accounts: [process.env.PRIVATEKEY]
    }
  },
  solidity: {
    compilers: [{
      version: "0.8.9"
    },{
      version: "0.6.2"
    },{
      version: "0.6.0"
    }],
    settings: {
      optimizer: {
        enabled: true,
        runs: 1500
      }
    }
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 1500
    }
  }
}

task("deploy-pie-smart-pool-factory", "deploys a pie smart pool factory")
  .addParam("balancerFactory", "Address of the balancer factory")
  .addParam("stringLibraries", "Addresses of libraries")
  .setAction(async(taskArgs, { ethers, run }) => {
    const signers = await ethers.getSigners();
    // const factory = await (new PProxiedFactoryFactory(signers[0])).deploy();
    // console.log(`Factory deployed at: ${factory.address}`);
    const stringLibraries = taskArgs.stringLibraries
    // deploy cut facet
    const cutFacet = await run("deploy-pie-smart-pool-cut-facet");
    // const cutFacet = "0x5D77eF11746e3A033c3a8a24AaAD2368eFe07401";
    // deploy PProxiedFactory
    const PProxiedFactory = await ethers.getContractFactory('PProxiedFactory', signers[0])
    const factory = await PProxiedFactory.deploy()
    const factoryContract = await ethers.getContractAt('PProxiedFactory', factory.address)
    console.log('factory deploy tx: ', factory.address)

    const diamond = await run("deploy-smartpool-with-libraries", {cutFacet, stringLibraries});
    // const diamond = "0xF47d1b6a5353B930331F492B0238F167AAC81251"
    // deploy facets
    await run("deploy-pie-smart-pool-facets", {diamond, cutFacet, stringLibraries});
    // await run("deploy-pie-smart-pool-facets-from-deployed", {diamond, cutFacet});
    //init diamond
    const diamondInitAndAdmin = await ethers.getContractAt('IPV2SmartPool', diamond)
    await diamondInitAndAdmin.init(await signers[0].getAddress(), "IMPL", "IMPLSYMBOL", "1337");
    console.log("diamond initialized");

    
    // smart pool init2
    // await run("init2-smart-pool", {smartPool: smartPoolAddress, cutFacet});
    const bFactory = await ethers.getContractAt('IBPool', taskArgs.balancerFactory)
    console.log(bFactory);
    

    await factory.init(taskArgs.balancerFactory, diamond);
    return {factory: factory.address, cutFacet: cutFacet};
});

task("deploy-pie-smart-pool-cut-facet", "deploy a cut facet")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    // const cutFacet = await (new DiamondCutFacetFactory(signers[0])).deploy();
    const CutFacet = await ethers.getContractFactory('DiamondCutFacet')
    const cutFacet = await CutFacet.deploy()
    console.log(`cutFacet deployed at: ${cutFacet.address}`);
    return cutFacet.address;
});

task("deploy-pie-smart-pool-facets", "deploy facets")
  .addParam("diamond", "diamond address")
  .addParam("cutFacet", "cut facet address")
  .addParam("stringLibraries", "addresses of libraries")
  .setAction(async(taskArgs, { ethers, run }) => {
    const signers = await ethers.getSigners();
    const libraries = JSON.parse(taskArgs.stringLibraries);
    // const libraries = await run("deploy-libraries");
    // const libraries: any = await run("deploy-libraries-and-get-object");

    // deploy diamondInit
    // const diamondInit = await (new DiamondInitFactory(signers[0])).deploy()
    const DiamondInit = await ethers.getContractFactory('DiamondInit')
    const diamondInit = await DiamondInit.deploy()
    await diamondInit.deployed()
    console.log('DiamondInit deployed:', diamondInit.address)

    console.log('Deploying facets')
    const LoupeFacetName = [
      'DiamondLoupeFacet',
    ]
    const cut = []
    const FacetNames = [
      'DiamondLoupeFacet',
      'InitFacet',
      'AdminFacet',
      'PoolEntryFacet',
      'PoolExitFacet',
      'TokenWeightFacet',
      'ViewFacet',
    ]
    for (const FacetName of FacetNames) {
      let Facet = null
      if(FacetName === "PoolEntryFacet") {
        Facet = await ethers.getContractFactory(FacetName, {libraries: {LibPoolEntryJoin: libraries["LibPoolEntryJoin"]}})
      }
      else if(FacetName === "PoolExitFacet") {
        Facet = await ethers.getContractFactory(FacetName, {libraries: {LibPoolEntryExit: libraries["LibPoolEntryExit"]}})
      }
      else if(FacetName === "TokenWeightFacet") {
        Facet = await ethers.getContractFactory(FacetName, {libraries: {LibAddRemoveToken: libraries["LibAddRemoveToken"], LibWeights: libraries["LibWeights"]}})
      }
      else if(FacetName === "ViewFacet") {
        Facet = await ethers.getContractFactory(FacetName, {libraries: {LibPoolMath: libraries["LibPoolMath"]}})
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
    const diamondCut = await ethers.getContractAt('IDiamondCut', taskArgs.diamond)
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
});

task("deploy-pie-smart-pool-facets-from-deployed", "deploy facets")
  .addParam("diamond", "diamond address")
  .addParam("cutFacet", "cut facet address")
  .setAction(async(taskArgs, { ethers, run }) => {
    const signers = await ethers.getSigners();
    const diamond = await ethers.getContractAt('IPV2SmartPool', taskArgs.diamond)
    await diamond.setCut(taskArgs.cutFacet, signers[0].getAddress())
    const diamondInit = await ethers.getContractAt("DiamondInit", "0xf01eFa71528aE1745af445f1160eDe910cdF7Fad") // local 0x772D7d54c371049886e651ca9B9BC4fa96000f33
    const cut = []
    const FacetNames = [
      'DiamondLoupeFacet',
      'InitFacet',
      'AdminFacet',
      'PoolEntryFacet',
      'PoolExitFacet',
      'TokenWeightFacet',
      'ViewFacet',
    ]
    for (const FacetName of FacetNames) {
      let Facet = null
      // if(FacetName === "DiamondLoupeFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0xD436a7a0F323e2c51Cc1B48B064F00e18E17a0cB")
      // }
      // else if(FacetName === "InitFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0x40D12eDcccE10cf606935f81aaE694A9f3F3f7f6")
      // }
      // else if(FacetName === "AdminFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0xBf210665ad96B7054f627d52AAF8234EB2EAC0Ab")
      // }
      // else if(FacetName === "PoolEntryFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0xFe11cafc870ABAEeD80b4A95C28e5031C7cCaE2D")
      // }
      // else if(FacetName === "PoolExitFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0xBC4A9709E875c84973905F1332Ee022aE8cF9217")
      // }
      // else if(FacetName === "TokenWeightFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0x3aB5027EfAED18F2cA7e611c1519b26CeAEa67E5")
      // }
      // else if(FacetName === "ViewFacet") {
      //   Facet = await ethers.getContractAt(FacetName, "0x70C6Aaf50F95Acab749910411bE6d8a65c4e0B0a")
      // }

      if(FacetName === "DiamondLoupeFacet") {
        Facet = await ethers.getContractAt(FacetName, "0x685169a5635a0c3c884279D59717ABb122E13A40")
      }
      else if(FacetName === "InitFacet") {
        Facet = await ethers.getContractAt(FacetName, "0x73190E487d78926cA94E2D1D2115Ac1766e7bBC6")
      }
      else if(FacetName === "AdminFacet") {
        Facet = await ethers.getContractAt(FacetName, "0xddC97c18806eCE4692011B17EE85739900dd18d7")
      }
      else if(FacetName === "PoolEntryFacet") {
        Facet = await ethers.getContractAt(FacetName, "0x3cd2E3D6Eb27F4b9dF097C0964614c65fB6a88fb")
      }
      else if(FacetName === "PoolExitFacet") {
        Facet = await ethers.getContractAt(FacetName, "0xf745B144C29db50dcAD1FFeABB3A0907D976f8E7")
      }
      else if(FacetName === "TokenWeightFacet") {
        Facet = await ethers.getContractAt(FacetName, "0x6Cc61005A2756362a742aDe4Ef1E70200ffA220f")
      }
      else if(FacetName === "ViewFacet") {
        Facet = await ethers.getContractAt(FacetName, "0xbE4F86622016A53DaF8632f1da73944553898D53")
      }
      cut.push({
        facetAddress: Facet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(Facet)
      })
    }
    console.log(cut);

    // upgrade diamond with facets
    // console.log('Diamond Cut:', cut)
    const diamondCut = await ethers.getContractAt('IDiamondCut', taskArgs.diamond)
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
    console.log('Completed diamond cut from deployed')
});

task("deploy-pool-from-factory", "deploys a pie smart pool from the factory")
  .addParam("cutFacet")
  .addParam("factory")
  .addParam("allocation", "path to allocation configuration")
  .setAction(async(taskArgs, { ethers, run }) => {
    const signers = await ethers.getSigners();
    const factory2 = new Contract(taskArgs.factory, PProxiedFactoryArtifact.abi, signers[0]);
    const factory = await ethers.getContractAt('PProxiedFactory', taskArgs.factory)
    const allocation = require(taskArgs.allocation);

    const name = allocation.name;
    const symbol = allocation.symbol
    const initialSupply = ethers.utils.parseEther(allocation.initialSupply);
    const cap = ethers.utils.parseEther(allocation.cap);
    const tokens = allocation.tokens;


    const tokenAddresses = [];
    const tokenAmounts = [];
    const tokenWeights = [];

    for (const token of tokens) {
      tokenAddresses.push(token.address);
      tokenWeights.push(ethers.utils.parseEther(token.weight).div(2));

      // Calc amount
      const amount = BigNumber.from(Math.floor((allocation.initialValue / token.value * token.weight / 100 * allocation.initialSupply * 10 ** token.decimals)).toString());
      tokenAmounts.push(amount);
      // Approve factory to spend token
      const tokenContract = await ethers.getContractAt("IERC20", token.address);
      const allowance = await tokenContract.allowance(await signers[0].getAddress(), factory.address);
      if(allowance.lt(amount)) {
        const approveTx = await tokenContract.approve(factory.address, constants.WeiPerEther);
        console.log(`Approved: ${token.address} tx: ${approveTx.hash}`);
        await approveTx.wait(1);
      }
      else {
        console.log("already approved");
      }
    }

    const tx = await factory.newProxiedSmartPool(name, symbol, initialSupply, tokenAddresses, tokenAmounts, tokenWeights, cap);
    console.log(1);
    const receipt = await tx.wait(); // wait for 2 confirmations
    console.log(2);
    const event = receipt.events.pop();
    console.log(3);
    console.log(`Deployed smart pool : ${event.args[0]}`);
    console.log(event);
    await run("deploy-pie-smart-pool-facets-from-deployed", {diamond: event.args[0], cutFacet: taskArgs.cutFacet});
    console.log("event args: ", event.args[0]);
    const smartPool = await ethers.getContractAt("IPV2SmartPool", event.args[0])
    await smartPool.init(event.args[1], name, symbol, initialSupply);
    await smartPool.setCap(cap);
    await smartPool.setPublicSwapSetter(signers[0].getAddress());
    await smartPool.setTokenBinder(signers[0].getAddress());
    await smartPool.setController(signers[0].getAddress());
    await smartPool.approveTokens();
    await smartPool.transfer(signers[0].getAddress(), initialSupply);
    return event.args[0];
});

task("deploy-pie-smart-pool", "deploys a pie smart pool")
  .setAction(async(taskArgs, { ethers, run }) => {
    const signers = await ethers.getSigners();

    console.log("deploying libraries");
    const libraries = await run("deploy-libraries");
    console.log("libraries deployed");
    console.table(libraries);
    const linkedArtifact = linkArtifact(Pv2SmartPoolArtifact, libraries);

    const smartpool = (await deployContract(signers[0], linkedArtifact, [], {
      gasLimit: 1000000000,
    }));

    console.log(`Pv2SmartPool deployed at: ${smartpool.address}`);

    return smartpool;
});

task("deploy-smartpool-with-libraries", "deploys a pie smart pool with libraries")
  .addParam("cutFacet", "addresses of cut facet")
  .addParam("stringLibraries", "addresses of libraries")
  .setAction(async(taskArgs, { ethers, run, deployments }) => {
    const signers = await ethers.getSigners();
    const libraries = JSON.parse(taskArgs.stringLibraries)
    console.log(libraries);
    // const linkedArtifact = linkArtifact(Pv2SmartPoolArtifact, libraries);
    // const smartpool = (await deployContract(signers[0] as Wallet, linkedArtifact, [], {
    //   gasLimit: 100000000,
    // })) as Pv2SmartPool;
    // const {deploy} = deployments;
    // const smartpool = (await deploy("PV2SmartPool", {contractName: "PV2SmartPool", from: await signers[0].getAddress()}));
    // deploy Diamond
    const Diamond = await ethers.getContractFactory('PV2SmartPool')
    const diamond = await Diamond.deploy()
    await diamond.deployed()
    await diamond.setCut(taskArgs.cutFacet, signers[0].getAddress())
    console.log('Diamond(Pv2SmartPool) deployed:', diamond.address)

    return diamond.address;
});

task("init-smart-pool", "initialises a smart pool")
  .addParam("smartPool", "Smart pool address")
  .addParam("pool", "Balancer pool address (should have tokens binded)")
  .addParam("name", "Name of the token")
  .addParam("symbol", "Symbol of the token")
  .addParam("initialSupply", "Initial supply of the token")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const smartpool = Pv2SmartPoolFactory.connect(taskArgs.smartPool, signers[0]);
    const tx = await smartpool.init(taskArgs.pool, taskArgs.name, taskArgs.symbol, utils.ethers.utils.parseEther(taskArgs.initialSupply));
    const receipt = await tx.wait(1);

    console.log(`Smart pool initialised: ${receipt.transactionHash}`);
});

task("init2-smart-pool", "initialises a smart pool")
  .addParam("smartPool", "Smart pool address")
  .addParam("cutFacet", "Smart pool cutFacet address")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const smartpool = Pv2SmartPoolFactory.connect(taskArgs.smartPool, signers[0]);
    const tx0 = await smartpool.setCut(taskArgs.cutFacet, await signers[0].getAddress());
    const tx1 = await smartpool.approveTokens();
    const receipt0 = await tx0.wait(1);
    const receipt1 = await tx1.wait(1);

    console.log(`Smart pool initialised2: ${receipt0.transactionHash} ${receipt1.transactionHash}`);
});

task("deploy-smart-pool-implementation-complete")
  .addParam("implName")
  .setAction(async(taskArgs, { ethers, run }) => {
    const signers = await ethers.getSigners();

    // Deploy capped pool
    const implementation = await run("deploy-pie-smart-pool");

    console.log(`Implementation deployed at: ${implementation.address}`);
    // Init capped smart pool
    await run("init-smart-pool", {
      smartPool: implementation.address,
      pool: PLACE_HOLDER_ADDRESS,
      name: taskArgs.implName,
      symbol: taskArgs.implName,
      initialSupply: "1337"
    });

    return implementation;
});

task("deploy-smart-pool-complete")
  .addParam("balancerFactory", "Address of the balancer factory. defaults to mainnet balancer factory")
  .addParam("allocation", "path to allocation")
  .setAction(async(taskArgs, { ethers, run }) => {
    // deploy libraries
    console.log("deploying libraries");
    const libraries = await run("deploy-libraries-and-get-object");
    console.log("libraries deployed");
    console.table(libraries);
    const stringLibraries = JSON.stringify(libraries)

    // run deploy factory task
    const smartPoolFactoryReturn = await run("deploy-pie-smart-pool-factory", {balancerFactory: taskArgs.balancerFactory, stringLibraries});
    console.log(smartPoolFactoryReturn);
    // run deploy pool from factory task
    const smartPoolAddress = await run("deploy-pool-from-factory", { cutFacet: smartPoolFactoryReturn.cutFacet, factory: smartPoolFactoryReturn.factory, allocation: taskArgs.allocation });
    console.log(`new smart pool deployed: ${smartPoolAddress}`);
});

task("set-cap", "Sets the cap on a capped pool")
  .addParam("pool")
  .addParam("cap")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const smartpool = Pv2SmartPoolFactory.connect(taskArgs.pool, signers[0]);
    const tx = await smartpool.setCap(ethers.utils.parseEther(taskArgs.cap), {gasLimit: 2000000});

    console.log(`Cap set tx: ${tx.hash}`);
});


task("join-smart-pool")
  .addParam("pool")
  .addParam("amount")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const smartpool = Pv2SmartPoolFactory.connect(taskArgs.pool, signers[0]);

    // TODO fix this confusing line
    const tokens = await IbPoolFactory.connect(await smartpool.getBPool(), signers[0]).getCurrentTokens();

    for(const tokenAddress of tokens) {
      const token = Ierc20Factory.connect(tokenAddress, signers[0]);
      // TODO make below more readable
      console.log("approving tokens");
      await (await token.approve(smartpool.address, constants.MaxUint256)).wait(1);
    }
    const tx = await smartpool.joinPool(ethers.utils.parseEther(taskArgs.amount), {gasLimit: 2000000});
    const receipt = await tx.wait(1);

    console.log(`Pool joined tx: ${receipt.transactionHash}`)
});

task("approve-smart-pool")
  .addParam("pool")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const smartpool = Pv2SmartPoolFactory.connect(taskArgs.pool, signers[0]);

    // TODO fix this confusing line
    const tokens = await IbPoolFactory.connect(await smartpool.bPool(), signers[0]).getCurrentTokens();

    for(const tokenAddress of tokens) {
      const token = Ierc20Factory.connect(tokenAddress, signers[0]);
      // TODO make below more readable
      const receipt = await (await token.approve(smartpool.address, constants.MaxUint256)).wait(1);
      console.log(`${tokenAddress} approved tx: ${receipt.transactionHash}`);
    }
});

task("deploy-mock-token", "deploys a mock token")
  .addParam("name", "Name of the token")
  .addParam("symbol", "Symbol of the token")
  .addParam("decimals", "Amount of decimals", "18")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const factory = await new MockTokenFactory(signers[0]);
    const token = await factory.deploy(taskArgs.name, taskArgs.symbol, taskArgs.decimals);
    await token.mint(await signers[0].getAddress(), constants.WeiPerEther.mul(10000000000000));
    console.log(`Deployed token at: ${token.address}`);
    return token;
});

task("deploy-balancer-factory", "deploys a balancer factory")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const factoryAddress = await deployBalancerFactory(signers[0]);

    console.log(`Deployed balancer factory at: ${factoryAddress}`);
});

task("deploy-balancer-pool", "deploys a balancer pool from a factory")
  .addParam("factory", "Address of the balancer pool address")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const factory = await IbFactoryFactory.connect(taskArgs.factory, signers[0]);
    const tx = await factory.newBPool();
    const receipt = await tx.wait(2); // wait for 2 confirmations
    const event = receipt.events.pop();
    console.log(`Deployed balancer pool at : ${event.address}`);
});

task("balancer-bind-token", "binds a token to a balancer pool")
  .addParam("pool", "the address of the Balancer pool")
  .addParam("token", "address of the token to bind")
  .addParam("balance", "amount of token to bind")
  .addParam("weight", "denormalised weight (max total weight = 50, min_weight = 1 == 2%")
  .addParam("decimals", "amount of decimals the token has", "18")
  .setAction(async(taskArgs, { ethers }) => {
    // Approve token
    const signers = await ethers.getSigners();
    const account = await signers[0].getAddress();
    const pool = IbPoolFactory.connect(taskArgs.pool, signers[0]);

    const weight = parseUnits(taskArgs.weight, 18);
    // tslint:disable-next-line:radix
    const balance = utils.parseUnits(taskArgs.balance, parseInt(taskArgs.decimals));
    const token = await Ierc20Factory.connect(taskArgs.token, signers[0]);

    const allowance = await token.allowance(account, pool.address);

    if(allowance.lt(balance)) {
      await token.approve(pool.address, constants.MaxUint256);
    }

    const tx = await pool.bind(taskArgs.token, balance, weight, {gasLimit: 1000000});
    const receipt = await tx.wait(1);

    console.log(`Token bound tx: ${receipt.transactionHash}`);
});

task("balancer-unbind-token", "removed a balancer token from a pool")
  .addParam("pool", "the address of the balancer pool")
  .addParam("token", "the address of the token to unbind")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const account = await signers[0].getAddress();
    const pool = IbPoolFactory.connect(taskArgs.pool, signers[0]);

    const tx = await pool.unbind(taskArgs.token);
    const receipt = await tx.wait(1);

    console.log(`Token unbound tx: ${receipt.transactionHash}`);
});

task("balancer-set-controller")
  .addParam("pool")
  .addParam("controller")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const pool = IbPoolFactory.connect(taskArgs.pool, signers[0]);

    const tx = await pool.setController(taskArgs.controller);
    const receipt = await tx.wait(1);

    console.log(`Controller set tx: ${receipt.transactionHash}`);
});


task("deploy-libraries", "deploys all external libraries")
  .setAction(async(taskArgs, { ethers }) => {
    const signers = await ethers.getSigners();
    const libraries = [];

    libraries.push(await deployAndGetLibObject(LibAddRemoveTokenArtifact, signers[0]));
    libraries.push(await deployAndGetLibObject(LibPoolEntryJoinArtifact, signers[0]));
    libraries.push(await deployAndGetLibObject(LibPoolEntryExitArtifact, signers[0]));
    libraries.push(await deployAndGetLibObject(LibWeightsArtifact, signers[0]));
    libraries.push(await deployAndGetLibObject(LibPoolMathArtifact, signers[0]));

    return libraries;
  });

task("deploy-libraries-and-get-object")
  .setAction(async(taskArgs, { ethers, run }) => {
    const libraries = await run("deploy-libraries");

    const libObject = {};

    for (const lib of libraries) {
      libObject[lib.name] = lib.address;
    }

    return libObject;

  });

// Use only in testing!
internalTask("deploy-libraries-and-smartpool")
  .setAction(async(taskArgs, { ethers, run, deployments}) => {
    const {deploy} = deployments;
    const signers = await ethers.getSigners();
    const libraries = await run("deploy-libraries-and-get-object");

    console.log("libraries");
    console.log(libraries);

    const contract = (await deploy("PV2SmartPool", {contractName: "PV2SmartPool", from: await signers[0].getAddress(), libraries}));

    return Pv2SmartPoolFactory.connect(contract.address, signers[0]);
  });


task("deploy-mock-tokens", "deploys 2 mock tokens")
  .setAction(async(taskArgs, { ethers, run }) => {
    const token0 = await run("deploy-mock-token", {
      name: "token0",
      symbol: "TK0",
      decimals: "18"
    });
    const token1 = await run("deploy-mock-token", {
      name: "token1",
      symbol: "TK1",
      decimals: "18"
    });
});
// modify ./allocations/localhost/token.json

// task("deploy-balancer", "deploys a balancer factory and pool")
//   .setAction(async(taskArgs, { ethers, run }) => {
//     const factoryAddress = await run("deploy-balancer-factory");
//     const poolAddress = await run("deploy-balancer-pool", {
//       factoryAddress
//     });
//     console.log(`Deployed balancer factory at: ${poolAddress}`);
// });


// deploy seq
// npx hardhat deploy-mock-tokens
// npx hardhat deploy-balancer-factory
// bsctest // npx hardhat deploy-smart-pool-complete --balancer-factory 0x49674a89d6B7B417F789BF9c18efD453ab4E3575 --allocation ./allocations/localhost/token.json
// bsctest deployed smart pool pie: 0x64284C7f6f44DbfEfAa75d7c04945548D04Db20C
// local // npx hardhat deploy-smart-pool-complete --balancer-factory 0x610716De058841d85eB19185069d1EF3a1aE2142 --allocation ./allocations/localhost/token.json
// local // npx hardhat deploy-pool-from-factory --factory 0x27ED00B45B8cc0B1a8E4d9Ee2c31c324c05EF61F --allocation ./allocations/localhost/token.json
