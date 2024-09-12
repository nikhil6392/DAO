const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("daoDeployment", (m) => {
 
  const daoContract = m.contract("DAO", []);

  return { daoContract };
});
