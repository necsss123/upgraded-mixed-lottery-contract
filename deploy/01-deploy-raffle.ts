import {DeployFunction} from "hardhat-deploy/types"
import {HardhatRuntimeEnvironment} from "hardhat/types"
// @ts-ignore
import { ethers } from "hardhat"

import { VRFCoordinatorV2_5Mock } from "../typechain-types"

import {
    networkConfig,
    developmentChains,
    BLOCK_CONFIRMATIONS,
}  from "../helper-hardhat-config"

import verify from "../utils/verify"

const VRF_SUB_FUND_AMOUNT = ethers.parseEther("2")

const deployRaffle: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
  ) {
    // @ts-ignore
    const { deployments, getNamedAccounts, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    let vrfCoordinatorV2plusAddress, subscriptionId, vrfCoordinatorV2plusMock

    

    if(chainId == 31337){
        vrfCoordinatorV2plusMock = await ethers.getContractAt(
            "VRFCoordinatorV2_5Mock",
            //"0x5FbDB2315678afecb367f032d93F642f64180aa3"
            (await deployments.get("VRFCoordinatorV2_5Mock")).address,
        )

        vrfCoordinatorV2plusAddress = vrfCoordinatorV2plusMock.target

        const transactionResponse = await vrfCoordinatorV2plusMock.createSubscription()

        const transactionReceipt = await transactionResponse.wait(1)

        // const log = transactionReceipt!.logs[0]
        // const eventFragment = vrfCoordinatorV2plusMock.interface.getEvent("SubscriptionCreated")
        // const decodedLog = vrfCoordinatorV2plusMock.interface.decodeEventLog(eventFragment,log.data,log.topics)
        // const subscriptionId = decodedLog.subId;

        // subscriptionId = transactionReceipt!.logs[0].args.subId
        // https://ethereum.stackexchange.com/questions/152652/how-to-access-the-event-args-while-testing-using-ethers-v6
        subscriptionId = BigInt(transactionReceipt!.logs[0].topics[1])

        // console.log(`subscriptionId: ${subscriptionId}`)
        await vrfCoordinatorV2plusMock.fundSubscription(subscriptionId, VRF_SUB_FUND_AMOUNT)
        
    

    }else{
        vrfCoordinatorV2plusAddress = networkConfig[network.config.chainId!]["vrfCoordinatorV2plus"]
        subscriptionId = networkConfig[network.config.chainId!]["subscriptionId"]
    }

    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : BLOCK_CONFIRMATIONS

    const args: any[] = [
        vrfCoordinatorV2plusAddress,
        networkConfig[network.config.chainId!]["entranceFee"],
        networkConfig[network.config.chainId!]["gasLane"],
        subscriptionId,
        networkConfig[network.config.chainId!]["callbackGasLimit"],
        networkConfig[network.config.chainId!]["interval"],
    ]
        
    const feeData = await ethers.provider.getFeeData();
    const raffle = await deploy("Raffle", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: waitBlockConfirmations,
        gasPrice: feeData.gasPrice?.toString(),
    })
    // 本地测试需要，测试网上则注释掉
    await vrfCoordinatorV2plusMock!.addConsumer(subscriptionId!.toString(), raffle.address)

    // deploying "Raffle" (tx: 0xaf0bd767a854beaa3f23fe8247a92abbbfb00ae5a8a66a36b48ae08432a02785)...: deployed at 0xCd55364e64f6567f6A3Da6e65E88c6e3b2cc5A6E with 2166903 gas

    // Verify the deployment
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(raffle.address, args)
    }


  }    
  export default deployRaffle
  deployRaffle.tags = ["all", "raffle"]









