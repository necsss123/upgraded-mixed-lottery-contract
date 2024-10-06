import {DeployFunction} from "hardhat-deploy/types"
import {HardhatRuntimeEnvironment} from "hardhat/types"

// @ts-ignore
import { ethers } from "hardhat"

const BASE_FEE = ethers.parseEther("0.2") 

const GAS_PRICE_LINK = 1e9

const WEI_PER_UNIT_LINK = 4483000000000000

const deployMocks: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
  ) {
    // @ts-ignore
    const { deployments, getNamedAccounts, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    if(chainId == 31337){
        const args = [BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK]

        log("Local network detected! Deploying mocks...")
        await deploy("VRFCoordinatorV2_5Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks Deployed!")
        log("--------------------------------------------")

        log("You are deploying to a local network, you'll need a local network running to interact")
        log(
            "Please run `yarn hardhat console --network localhost` to interact with the deployed smart contracts!"
        )
        log("----------------------------------")
    }

  }

export default deployMocks
deployMocks.tags = ["all", "mocks"]

