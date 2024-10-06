// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

error Raffle__NotEnoughETHEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__Full();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    enum SubResSymbol {
        POSITIVE,
        NEGATIVE,
        ZERO
    }

    struct Participant {
        address payable player;
        uint8 selectedNum;
        SubResSymbol selectedNumSubResSymbol; // 前端链下计算
        uint8 abs; // 前端链下计算
        uint8 absDiffFromLuckyNum; // 默认全是0
        uint256 participatedTimeStamp; // 用户选好数字参与进来那一刻的时间戳，由前端传进来
    }

    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_interval;
    IVRFCoordinatorV2Plus private immutable i_vrfCoordinator;
    uint8 private constant REQUEST_CONFIRMATIONS = 3;
    uint8 private constant NUM_WORDS = 1;
    uint8 private constant Num_PARTICIPANTS = 52;
    uint256 private constant Num_PRIZEPOOLAMOUNT = 156000000000000000000;

    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;

    Participant[] private s_participants;
    bool private s_full;

    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

    event WinnersPicked(uint8 indexed luckyNum1, uint8 indexed luckyNum2);

    constructor(
        address vrfCoordinator,
        uint256 entranceFee,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        i_entranceFee = entranceFee;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        s_full = false;
        i_interval = interval;
    }

    function enterRaffle(
        uint8 _selectedNum,
        SubResSymbol _selectedNumSubResSymbol,
        uint8 _abs,
        uint256 _participatedTimeStamp
    ) public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        if (s_full == true) {
            revert Raffle__Full();
        }

        s_participants.push(
            Participant(
                payable(msg.sender),
                _selectedNum,
                _selectedNumSubResSymbol,
                _abs,
                0,
                _participatedTimeStamp
            )
        );

        if (s_participants.length == Num_PARTICIPANTS) {
            s_full = true;
        }

        // 把函数名反过来命名Event
        emit RaffleEnter(msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasBalance = address(this).balance > 0;
        // upkeepNeeded = (isOpen && timePassed && s_full && hasBalance);
        upkeepNeeded = (isOpen && timePassed && hasBalance);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint8 luckyNum = uint8(randomWords[0] % 100); // 0~99
        (uint8 luckyNum1, uint8 luckyNum2, uint8 abs, SubResSymbol absSymbol) = splitLuckyNums(
            luckyNum
        );

        (
            Participant[] memory winnersWhoGuessedTheLuckyNum,
            uint8 numOfJackpotWinners
        ) = pickTheFirstPrizeWinners(luckyNum1, luckyNum2);
        // 剩下的非幸运数字中奖者数量
        uint8 theNumOfOtherWinners = numOfWinnersWhoDidNotGuessTheLuckyNum(
            uint8(winnersWhoGuessedTheLuckyNum.length)
        );
        // 没有猜中2个幸运数字的参与者
        Participant[] memory theOtherParticipants = differenceOfTwoArrs(
            winnersWhoGuessedTheLuckyNum,
            s_participants
        );

        // 通过绝对值进行筛选剩余非幸运数字中奖者
        Participant[] memory nonLuckyNumWinners = getNonLuckyNumWinners(
            theOtherParticipants,
            theNumOfOtherWinners,
            luckyNum1,
            abs,
            absSymbol
        );

        // 获得完整的中奖者名单，13人---只有一个人猜中头奖的前提下，12人---无人猜中头奖

        // 将头奖资金打给头奖获得者 和 猜中luckyNum2的非头奖获得者
        if (numOfJackpotWinners != 0) {
            uint256 jackpotPrize = 48000000000000000000 / numOfJackpotWinners;
            for (uint8 i = 0; i < winnersWhoGuessedTheLuckyNum.length; i++) {
                if (i < numOfJackpotWinners) {
                    (bool success, ) = winnersWhoGuessedTheLuckyNum[i].player.call{
                        value: jackpotPrize
                    }("");
                    if (!success) {
                        revert Raffle__TransferFailed();
                    }
                } else {
                    (bool success, ) = winnersWhoGuessedTheLuckyNum[i].player.call{
                        value: 9000000000000000000
                    }("");
                    if (!success) {
                        revert Raffle__TransferFailed();
                    }
                }
            }

            // 将奖金打给非头奖获得者
            for (uint8 i = 0; i < nonLuckyNumWinners.length; i++) {
                (bool success, ) = nonLuckyNumWinners[i].player.call{value: 9000000000000000000}(
                    ""
                );
                if (!success) {
                    revert Raffle__TransferFailed();
                }
            }
        } else {
            for (uint8 i = 0; i < nonLuckyNumWinners.length; i++) {
                (bool success, ) = nonLuckyNumWinners[i].player.call{value: 113000000000000000000}(
                    ""
                );
                if (!success) {
                    revert Raffle__TransferFailed();
                }
            }
        }

        s_raffleState = RaffleState.OPEN;
        s_full = false;
        s_lastTimeStamp = block.timestamp;
        delete s_participants;

        // address payable recentWinner = s_participants[indexOfWinner];
        // s_recentWinner = recentWinner;
        // s_raffleState = RaffleState.OPEN;
        // s_participants = new address payable[](0); // 大小为0的数组
        // s_lastTimeStamp = block.timestamp;
        // (bool success, ) = recentWinner.call{value: address(this).balance}("");
        // if (!success) {
        //     revert Raffle__TransferFailed();
        // }
        emit WinnersPicked(luckyNum1, luckyNum2);
    }

    // 对幸运数字进行分裂处理，返回2个幸运数字，25->52  33->66
    function splitLuckyNums(
        uint8 luckyNum
    ) private pure returns (uint8 luckyNum1, uint8 luckyNum2, uint8 abs, SubResSymbol absSymbol) {
        luckyNum1 = luckyNum;
        int8 remainder = int8(luckyNum) % 10;
        int8 tens = int8(luckyNum) / 10;
        int8 subRes = tens - remainder;
        if (subRes > 0) {
            absSymbol = SubResSymbol.POSITIVE;
            abs = uint8(subRes);
        } else if (subRes < 0) {
            absSymbol = SubResSymbol.NEGATIVE;
            abs = uint8(-subRes);
        } else {
            absSymbol = SubResSymbol.ZERO;
            abs = 0;
        }
        if (remainder == tens) {
            luckyNum2 = 99 - luckyNum;
        } else {
            luckyNum2 = uint8(remainder) * 10 + uint8(tens);
        }
    }

    // 筛选符合2个幸运数字的获奖者 和 头奖获得者的数量
    function pickTheFirstPrizeWinners(
        uint8 luckyNum1,
        uint8 luckyNum2
    )
        private
        view
        returns (Participant[] memory winnersWhoGuessedTheLuckyNum, uint8 numOfJackpotWinners)
    {
        uint8 count = 0;
        for (uint i = 0; i < Num_PARTICIPANTS; i++) {
            if (s_participants[i].selectedNum == luckyNum1) {
                winnersWhoGuessedTheLuckyNum[count] = s_participants[i];
                count++;
            }
        }
        numOfJackpotWinners = uint8(winnersWhoGuessedTheLuckyNum.length);
        // 如果没有人选中luckyNum1，luckyNum2将作为头奖的幸运数字，筛选是否有人选中了luckyNum2
        if (winnersWhoGuessedTheLuckyNum.length == 0) {
            for (uint i = 0; i < Num_PARTICIPANTS; i++) {
                if (s_participants[i].selectedNum == luckyNum2) {
                    winnersWhoGuessedTheLuckyNum[count] = s_participants[i];
                    count++;
                }
            }
            numOfJackpotWinners = uint8(winnersWhoGuessedTheLuckyNum.length);
            // 如果有人选中luckyNum1，继续选出符合中奖条件，既猜中luckyNum2的非头奖获得者
        } else {
            for (uint i = 0; i < Num_PARTICIPANTS; i++) {
                if (s_participants[i].selectedNum == luckyNum2) {
                    winnersWhoGuessedTheLuckyNum[count] = s_participants[i];
                    count++;
                }
            }
        }
        return (winnersWhoGuessedTheLuckyNum, numOfJackpotWinners);
    }

    // 没有猜中2个幸运数字的获奖者人数
    function numOfWinnersWhoDidNotGuessTheLuckyNum(
        uint8 numOfWinnersWhoGuessedTheLuckyNum
    ) private pure returns (uint8 num) {
        numOfWinnersWhoGuessedTheLuckyNum == 0 ? num = 12 : num =
            13 -
            numOfWinnersWhoGuessedTheLuckyNum;
    }

    // 求2个数组之差
    function differenceOfTwoArrs(
        Participant[] memory arrTobeSubtracted,
        Participant[] memory arr
    ) private pure returns (Participant[] memory) {
        Participant[] memory result;
        uint8 index = 0;

        for (uint8 i = 0; i < arr.length; i++) {
            bool found = false;
            for (uint8 j = 0; j < arrTobeSubtracted.length; j++) {
                if (arr[i].player == arrTobeSubtracted[j].player) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                result[index] = arr[i];
                index++;
            }
        }
        return result;
    }

    // 筛选出剩下的没有猜中2个幸运数字的获奖者
    function getNonLuckyNumWinners(
        Participant[] memory theOtherParticipants,
        uint8 theNumOfOtherWinners,
        uint8 luckyNum1,
        uint8 abs,
        SubResSymbol symbol
    ) private returns (Participant[] memory theOtherWinners) {
        Participant[] memory lastResult;
        if (symbol != SubResSymbol.ZERO) {
            (
                Participant[] memory allOtherWinners,
                Participant[] memory theLastFilter
            ) = recursiveFilter(
                    symbol,
                    abs,
                    theNumOfOtherWinners,
                    theOtherParticipants,
                    0,
                    lastResult
                );
            require(
                allOtherWinners.length >= theNumOfOtherWinners,
                "Not enough non-lucky number winners were screened!"
            );
            uint8 extraWinnersNum = uint8(allOtherWinners.length) - theNumOfOtherWinners;
            if (extraWinnersNum != 0) {
                // 冒泡排序，按参与时间从早到晚进行排序
                uint8 len = uint8(theLastFilter.length) - 1;
                for (uint8 i = 0; i < len; i++) {
                    for (uint8 j = 0; j < len - 1 - i; j++) {
                        if (
                            theLastFilter[j].participatedTimeStamp >
                            theLastFilter[j + 1].participatedTimeStamp
                        ) {
                            Participant memory temp = theLastFilter[j + 1];
                            theLastFilter[j + 1] = theLastFilter[j];
                            theLastFilter[j] = temp;
                        }
                    }
                }
                Participant[] memory eliminationOfTheWinners;
                uint8 theIndexOfEliminationWinners = uint8(theLastFilter.length) -
                    theNumOfOtherWinners;
                for (uint8 i = 0; i < extraWinnersNum; i++) {
                    eliminationOfTheWinners[i] = theLastFilter[theIndexOfEliminationWinners];
                }

                theOtherWinners = differenceOfTwoArrs(eliminationOfTheWinners, allOtherWinners);
            }
        } else {
            for (uint8 i = 0; i < theOtherParticipants.length; i++) {
                uint8 absRes;
                int8 res = int8(theOtherParticipants[i].selectedNum) - int8(luckyNum1);
                res < 0 ? absRes = uint8(-res) : absRes = uint8(res);
                if (absRes > 50) {
                    absRes = 100 - absRes;
                }
                theOtherParticipants[i].absDiffFromLuckyNum = absRes;
            }
            // 对每个对象中的absDiffFromLuckyNum由小到大进行排序，越小说明离luckNum1越近
            uint8 minDiffAbs = theOtherParticipants[0].absDiffFromLuckyNum;
            uint8 minIndex = 0;
            Participant[] memory closestParticipant;
            for (uint8 i = 0; i < theNumOfOtherWinners; i++) {
                for (uint8 j = 1; j < theOtherParticipants.length; j++) {
                    if (theOtherParticipants[j].absDiffFromLuckyNum <= minDiffAbs) {
                        minDiffAbs = theOtherParticipants[j].absDiffFromLuckyNum;
                        minIndex = j;
                    }
                }
                closestParticipant[i] = theOtherParticipants[minIndex];
                theOtherParticipants[minIndex].absDiffFromLuckyNum = 50;
            }
            theOtherWinners = closestParticipant;
        }
    }

    function recursiveFilter(
        SubResSymbol symbol,
        uint8 abs,
        uint8 theNumOfOtherWinners,
        Participant[] memory theOtherParticipants,
        uint8 count,
        Participant[] memory lastResult
    )
        private
        returns (Participant[] memory result, Participant[] memory theLastFilterParticipants)
    {
        uint8 judementStandardAbs = abs;
        Participant[] memory theRestOfParticipants;
        uint8 theNumOfWinnersOfScreen;
        uint8 filterParticipantsNum = 0;
        uint8 lastResultCount = uint8(lastResult.length);

        if (judementStandardAbs != 0) {
            // 先按标准3进行筛选，由52 -> 41、74
            for (uint8 i = 0; i < theOtherParticipants.length; i++) {
                if (
                    judementStandardAbs == theOtherParticipants[i].abs &&
                    symbol == theOtherParticipants[i].selectedNumSubResSymbol
                ) {
                    lastResult[count] = theOtherParticipants[i];
                    lastResultCount++;
                    // lastResult.push(theOtherParticipants[i]);
                    theLastFilterParticipants[filterParticipantsNum] = theOtherParticipants[i];
                    filterParticipantsNum++;
                } else {
                    theRestOfParticipants[i] = theOtherParticipants[i];
                }
            }

            symbol == SubResSymbol.POSITIVE ? symbol = SubResSymbol.NEGATIVE : symbol = SubResSymbol
                .POSITIVE;
            count++;

            if (count % 2 == 0 && symbol == SubResSymbol.NEGATIVE) {
                judementStandardAbs++;
                judementStandardAbs == 10 ? judementStandardAbs = 0 : judementStandardAbs;
            } else if (count % 2 == 0 && symbol == SubResSymbol.POSITIVE) {
                judementStandardAbs--;
            }
            if (lastResult.length < theNumOfOtherWinners) {
                theNumOfWinnersOfScreen = theNumOfOtherWinners - uint8(lastResult.length);
                recursiveFilter(
                    symbol,
                    judementStandardAbs,
                    theNumOfWinnersOfScreen,
                    theRestOfParticipants,
                    count,
                    lastResult
                );
            } else {
                result = lastResult;
                return (result, theLastFilterParticipants);
            }
        } else {
            for (uint8 i = 0; i < theOtherParticipants.length; i++) {
                if (judementStandardAbs == theOtherParticipants[i].abs) {
                    // lastResult.push(theOtherParticipants[i]);
                    lastResult[count] = theOtherParticipants[i];
                    lastResultCount++;

                    theLastFilterParticipants[filterParticipantsNum] = theOtherParticipants[i];
                    filterParticipantsNum++;
                } else {
                    theRestOfParticipants[i] = theOtherParticipants[i];
                }
            }

            symbol == SubResSymbol.POSITIVE ? symbol = SubResSymbol.NEGATIVE : symbol = SubResSymbol
                .POSITIVE;
            count = count + 2;

            if (symbol == SubResSymbol.NEGATIVE) {
                judementStandardAbs = 9;
            } else if (symbol == SubResSymbol.POSITIVE) {
                judementStandardAbs = 1;
            }

            if (lastResult.length < theNumOfOtherWinners) {
                theNumOfWinnersOfScreen = theNumOfOtherWinners - uint8(lastResult.length);
                recursiveFilter(
                    symbol,
                    judementStandardAbs,
                    theNumOfWinnersOfScreen,
                    theRestOfParticipants,
                    count,
                    lastResult
                );
            } else {
                result = lastResult;
                return (result, theLastFilterParticipants);
            }
        }
    }

    // function filterTheRestOfWinners(
    //     Participant[] firstPrizeWinners
    // ) private returns (Participant[] otherWinners) {}

    // function thirteenWinners(uint8 luckyNum) private returns (uint8[]) {}

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getIsitFull() public view returns (bool) {
        return s_full;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getParticipant(uint8 index) public view returns (address) {
        return s_participants[index].player;
    }

    // function getRecentWinner() public view returns (address) {
    //     return s_recentWinner;
    // }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint8) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_participants.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint8) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
