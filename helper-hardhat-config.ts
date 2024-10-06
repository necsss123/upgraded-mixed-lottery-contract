// @ts-ignore
import {ethers} from "hardhat"

export interface networkConfigItem {
    name?: string
    subscriptionId?: string 
    gasLane?: string 
    interval?: string 
    entranceFee?: string 
    callbackGasLimit?: string 
    vrfCoordinatorV2plus?: string
  }

  export interface networkConfigInfo {
    [key: number]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
    31337: {
        name: "localhost",
        gasLane: "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae", 
        interval: "30",
        entranceFee: ethers.parseEther("3").toString(),   // ethers.utils.parseEther("3"),  3 ETH "3000000000000000000"
        callbackGasLimit: "500000", // 500,000 gas
    },
    12227332: {
        name: "NeoX T4",
        gasLane: "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae",   // sepolia 500gwei key hash
        subscriptionId: "102764618357577415192321788315192347422620231223760019320611939924705533878226",
        interval: "30",
        entranceFee: ethers.parseEther("3").toString(),
        callbackGasLimit: "500000",
        vrfCoordinatorV2plus: "0x9ddfaca8183c41ad55329bdeed9f6a8d53168b1b",
    }
}

export const developmentChains = ["hardhat", "localhost"]

export const BLOCK_CONFIRMATIONS = 6


