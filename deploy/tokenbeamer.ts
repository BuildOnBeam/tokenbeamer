import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const TOKEN_CONTRACT = "TokenBeamer";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  console.log(`\n>> Preparing deployment of ${TOKEN_CONTRACT}...\n`);

  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // deploy
  await deploy(TOKEN_CONTRACT, {
    from: deployer,
    log: true,
    waitConfirmations: 1,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [],
        },
      },
    },
  });

  console.log(`\n>> Deployment of ${TOKEN_CONTRACT} finished.\n`);
};

export default func;

func.id = "tokenbeamer";
func.tags = ["tokenbeamer", TOKEN_CONTRACT];
