class TimeTraveler {
  snapshotID;
  ethereum;

  constructor(ethereum) {
    this.ethereum = ethereum;
  }

  async snapshot() {
    const snapshot = await this.ethereum.send("evm_snapshot", []);
    await this.mine_blocks(1);
    this.snapshotID = snapshot;
    return;
  }

  async revertSnapshot() {
    await this.ethereum.send("evm_revert", [this.snapshotID]);
    await this.mine_blocks(1);
    return;
  }

  async mine_blocks(amount) {
    for (let i = 0; i < amount; i++) {
      await this.ethereum.send("evm_mine", []);
    }
  }

  async increaseTime(amount) {
    await this.ethereum.send("evm_increaseTime", [amount]);
  }

  async setNextBlockTimestamp(timestamp) {
    await this.ethereum.send("evm_setNextBlockTimestamp", [timestamp]);
  }
}
