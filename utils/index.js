const ethers = require("ethers");
const balancerFactoryBytecode = require("./balancerFactoryBytecode");
const balancerPoolBytecode = require("./balancerPoolBytecode");
const TimeTraveler = require("./TimeTraveler");


const deployBalancerFactory = async (signer) => {
  const tx = (await signer.sendTransaction({data: balancerFactoryBytecode}));
  return tx.creates;
};

const deployBalancerPool = async (signer) => {
  const tx = (await signer.sendTransaction({data: balancerPoolBytecode, gasLimit: 8000000}));
  return tx.creates;
};

const simpleDeploy = async (artifact, signer) => {
  const tx = (await signer.sendTransaction({data: artifact.bytecode}));
  await tx.wait(1);

  const contractAddress = tx.creates;

  return contractAddress;
};

const deployAndGetLibObject = async (artifact, signer) => {
  const contractAddress = await simpleDeploy(artifact, signer);
  return {name: artifact.contractName, address: contractAddress};
};

const linkArtifact = (artifact, libraries) => {
  for (const library of Object.keys(artifact.linkReferences)) {
    // Messy
    let libPositions = artifact.linkReferences[library];
    const libName = Object.keys(libPositions)[0];
    libPositions = libPositions[libName];

    const libContract = libraries.find((lib) => lib.name === libName);

    if (libContract === undefined) {
      throw new Error(`${libName} not deployed`);
    }

    const libAddress = libContract.address.replace("0x", "");

    for (const position of libPositions) {
      artifact.bytecode =
        artifact.bytecode.substr(0, 2 + position.start * 2) +
        libAddress +
        artifact.bytecode.substr(2 + (position.start + position.length) * 2);
    }
  }

  return artifact;
};

{TimeTraveler};

module.exports = {
  deployBalancerFactory,
  deployBalancerPool,
  simpleDeploy,
  deployAndGetLibObject,
  linkArtifact
}