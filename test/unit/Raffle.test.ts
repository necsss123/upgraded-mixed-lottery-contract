import { assert, expect } from "chai"
// @ts-ignore
import { network, deployments, ethers }from "hardhat"
import { developmentChains, networkConfig} from "../../helper-hardhat-config"
import { Raffle, VRFCoordinatorV2_5Mock } from "../../typechain-types"
import { BigNumberish } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers"

// 十位大于个位-0，十位小于个位-1，相等2
function getAbs(n: number) :{abs: number, sign: number}{
    let units: number,tens: number,abs: number,res: number
    units = n % 10
    tens = Math.floor(n/10)
    res = tens-units
    if(res > 0){
        return {abs: res, sign: 0}
    }else if(res < 0){
        return {abs: Math.abs(res), sign: 1}
    }else{
        return {abs: 0, sign: 2 }
    }

}

function getRandom(): number {
    return Math.floor(Math.random() * 99);
}

!developmentChains.includes(network.name)
    ?describe.skip: describe("Raffle Unit Tests",function(){
        let raffle: Raffle
        let raffleContract: Raffle
        let vrfCoordinatorV2plusMock: VRFCoordinatorV2_5Mock
        let entranceFee: BigNumberish
        let interval: number
        let player: HardhatEthersSigner
        let deployer: HardhatEthersSigner
        let accounts: HardhatEthersSigner[]

        const chainId = network.config.chainId!
        
        beforeEach(async () => {
            accounts = await ethers.getSigners()
            // deployer = accounts[0]
            player = accounts[1]
            await deployments.fixture(["mocks","raffle"]) // ["all"] 也可以
            // raffle = await ethers.getContractAt("Raffle",(await deployments.get("Raffle")).address)
            raffleContract = await ethers.getContractAt("Raffle",(await deployments.get("Raffle")).address)
            raffle = raffleContract.connect(player)
            vrfCoordinatorV2plusMock = await ethers.getContractAt(
                "VRFCoordinatorV2_5Mock",
                (await deployments.get("VRFCoordinatorV2_5Mock")).address
            )
            entranceFee = await raffle.getEntranceFee()
            interval = Number(await raffle.getInterval())

        })

        describe("constructor",function(){
            it("initializes the raffle correctly", async function(){
                const raffleState = (await raffle.getRaffleState()).toString()
                assert.equal(raffleState, "0")
                assert.equal(interval.toString(), networkConfig[chainId]["interval"])
                assert.equal(entranceFee.toString(), networkConfig[chainId]["entranceFee"])
            })
        })

        describe("enterRaffle",function(){
            it("reverts when you don't pay enough",async ()=>{
                await expect(raffle.enterRaffle(37,1,4,1728046533)).to.be.revertedWithCustomError(raffle,"Raffle__NotEnoughETHEntered")
            })

            it("records players when they enter", async function(){
                await raffle.enterRaffle(14,1,3,1728046535,{value: entranceFee})
                const playerFromContract = await raffle.getParticipant(0)
                assert.equal(playerFromContract, player.address)
            })

            it("emits event on enter", async function(){
                await expect(raffle.enterRaffle(75,0,2,1728046698,{value: entranceFee})).to.emit(raffle,"RaffleEnter")
            })

            it("doesn't allow entrance when raffle is calculating", async function(){
                await raffle.enterRaffle(83,0,5,1728046758,{value: entranceFee})
                await network.provider.send("evm_increaseTime", [interval+1])
                await network.provider.send("evm_mine", [])
                await raffle.performUpkeep("0x") 
                await expect(
                    raffle.enterRaffle(91,0,8,1728046812,{value: entranceFee}),
                ).to.be.revertedWithCustomError(raffle, "Raffle__NotOpen")
            })

            it("no entry allowed when the number of participants is full", async function(){
                const additionalEntrances = 52
                const startingAccountIndex = 1
                for(let i = startingAccountIndex; i< startingAccountIndex + additionalEntrances; i++){
                    const accountConnectedRaffle = raffle.connect(accounts[i])
                    await accountConnectedRaffle.enterRaffle(36,1,3,1728058563,{ value: entranceFee }) 
                }
                // const full = (await raffle.getIsitFull()).toString()
                // assert.equal(full,"true")
                await expect(
                    raffle.enterRaffle(91,0,8,1728046812,{value: entranceFee}),
                ).to.be.revertedWithCustomError(raffle, "Raffle__Full")
            })
        })

        describe("checkUpkeep", function(){
            it("returns false if people haven't sent any ETH", async function(){
                await network.provider.send("evm_increaseTime", [interval+1])
                await network.provider.send("evm_mine", [])
                const { upkeepNeeded } = await raffle.checkUpkeep.staticCall("0x")
                assert(!upkeepNeeded)
            })
            it("returns false if raffle isn't open", async function(){
                await raffle.enterRaffle(83,0,5,1728047463,{value: entranceFee})
                await network.provider.send("evm_increaseTime", [interval+1])
                await network.provider.send("evm_mine", [])
                await raffle.performUpkeep("0x")
                const raffleState = (await raffle.getRaffleState()).toString()
                const { upkeepNeeded } = await raffle.checkUpkeep.staticCall("0x")
                assert.equal(raffleState, "1")
                assert.equal(upkeepNeeded, false)
            })
            it("returns false if enough time hasn't passed", async function() {
                // const raffleInitTimestamp = await raffle.getLatestTimeStamp()
                
                // let blockTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp
                await raffle.enterRaffle(49,1,5,1728047663,{value: entranceFee})

                await network.provider.send("evm_increaseTime", [interval - 3])
                await network.provider.send("evm_mine", [])
                // await network.provider.request({ method: "evm_mine", params: [] })
                const { upkeepNeeded } = await raffle.checkUpkeep.staticCall("0x")
                assert(!upkeepNeeded)
            })
            it("returns true if enough time has passed, has eth, and is open", async function(){
                await raffle.enterRaffle(23,1,1,1728047763,{value: entranceFee})
                await network.provider.send("evm_increaseTime", [interval + 1])
                await network.provider.send("evm_mine", [])
                const { upkeepNeeded } = await raffle.checkUpkeep.staticCall("0x")
                assert(upkeepNeeded)
            })
        })

        describe("performUpkeep",function(){
            it("it can only run if checkupkeep is true",async function(){
                await raffle.enterRaffle(24,1,2,1728047963,{ value: entranceFee })
                await network.provider.send("evm_increaseTime", [interval + 1])
                await network.provider.send("evm_mine", [])
                const tx = await raffle.performUpkeep("0x")
                assert(tx)
            })

            it("reverts when checkUpkeep is false", async function () {
                const expectedBalance = await raffle.getContractBalance(); 
                const expectedNumPlayers = await raffle.getNumberOfPlayers();  
                const expectedRaffleState = await raffle.getRaffleState(); 

                await expect(raffle.performUpkeep("0x")).to.be.revertedWithCustomError(
                    raffle,
                    "Raffle__UpkeepNotNeeded",
                ).withArgs(expectedBalance,expectedNumPlayers,expectedRaffleState)
            })

            it("updates the raffle state, emits and event, and calls the vrf coordinator", async function () {
                await raffle.enterRaffle(24,1,2,1728057963,{ value: entranceFee })
                await network.provider.send("evm_increaseTime", [interval+ 1])
                await network.provider.send("evm_mine", [])
                const txResponse = await raffle.performUpkeep("0x")
                const txReceipt = await txResponse.wait(1)
                // const requestId = txReceipt!.logs[1].args.requestId
                const requestId = txReceipt!.logs[1].topics[1]
                console.log(``)
                const raffleState = await raffle.getRaffleState()
                assert(Number(requestId) > 0)
                assert(raffleState.toString() == "1")
            })
        })

        describe("fulfillRandomWords", function () {
            beforeEach(async function () {
                await raffle.enterRaffle(36,1,3,1728058963,{ value: entranceFee })
                await network.provider.send("evm_increaseTime", [interval + 1])
                await network.provider.send("evm_mine", [])
            })

            it("can only be called after performUpkeep", async function () {
                // 升级为模糊测试
                await expect(
                    vrfCoordinatorV2plusMock.fulfillRandomWords(0, raffle.target),
                ).to.be.revertedWithCustomError(vrfCoordinatorV2plusMock, "InvalidRequest")
                await expect(
                    vrfCoordinatorV2plusMock.fulfillRandomWords(1, raffle.target),
                ).to.be.revertedWithCustomError(vrfCoordinatorV2plusMock, "InvalidRequest")
            })

            it("picks winners, resets the raffle, and sends money",async function () {
                const additionalEntrances = 51
                const startingAccountIndex = 2
                const randomsArr : Array<number> = []
                const signsArr : Array<number> = []
                const absArr : Array<number> = []
                for(let i = 0; i<additionalEntrances; i++){
                    const val = getRandom()
                    const {abs, sign} = getAbs(val)
                    randomsArr.push(val)
                    signsArr.push(sign)
                    absArr.push(abs)
                }
                for(let i = startingAccountIndex; i< startingAccountIndex + additionalEntrances; i++){
                    const index = i - 2
                    const accountConnectedRaffle = raffle.connect(accounts[i])
                    const timestamp = 1728058963+10*index
                    await accountConnectedRaffle.enterRaffle(randomsArr[index],signsArr[index],absArr[index],timestamp,{ value: entranceFee }) 
                }

                // await new Promise<void>(async (resolve, reject) => {
                //     // ["WinnersPicked(uint8,uint8)"]
                //     raffle.once(raffle.filters.WinnersPicked, async (luckyNum1,luckyNum2) => {
                //         console.log("WinnersPicked event fired!")
                //         try{
                //             console.log(`luckyNum1: ${luckyNum1}  luckyNum2: ${luckyNum2}`)
                //             resolve()
                //         }catch(e){
                //             reject(e)
                //         }
                //     })
                    
                // })
            })
        })
    }

)