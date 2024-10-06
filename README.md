# 四分之一的幸运抽奖 --- 混合智能合约（中文版）

### 规则说明

参与人数一共52人，参与者进入一轮抽奖时，将付出**3美元**到奖金池中，并选择一个从**0~99**的竞猜整数。开始抽奖时，总奖金池累计**156美元**。

开始抽奖，从预言机网络获得从0~99的随机整数，称为头奖数字，经过个位与十位数字调换处理得到另一个头奖数字。比如预言机网络返回**37**，
那么**73**就是第2个头奖数字。6则对应60。如果返回的头奖数字是像33这种十位数字和个位数字相等的，那么另一个头奖数字则是用99减去该数
字得到66，同理**22**则对应**77**。

#### 获奖判断：

1. 正常情况下每轮抽奖将选出52名参与者的四分之一，也就是13人得奖。头奖奖金48美元，如果只有1位参与者获得头奖，那么其它12人将
   平分108美元，每人获得9美元。如果没有人获得头像，那么本轮抽奖的中奖人数为12人，每人获得13美元。如果有n位获得头奖，那么有**13-n**个
   人获得次奖，头奖奖金变更为156-9*(13-n)，每名头奖获得者将得到(156-9*(13-n))/n的奖金。

2. 头奖判定：猜中预言机网络返回随机数的人直接判定为头奖。如果没有人选中该数字，则判断是否有人选中第2个头奖数字，选中的判定
   为头奖。如果有人选中第1个幸运数字，判定为头奖，即便还有人选中第2个幸运数字，那么选中的人依然被判定获得次奖。比如预言机返回的
   随机数是47，猜中的人直接判定为头奖，如果没有人猜中，则判断是否有人猜中74，猜中74的判定为头奖。如果已经有人猜中47的情况下，还
   有人猜中74，那么猜中74的判定为次奖。如果52个人没有人猜中47与74，那么将选出12名次奖中奖者，每人分到13美元。

3. 次奖判定：根据第1个幸运数字十位与个位之间的绝对值来判断，比如第1个幸运数字是47，十位与个位数字的绝对值是3，同时十位数小于
   个位数数字，那么将筛选除头奖以外的参与者中，是否有选中[3、14、25、36、58、69]这几个数字的，判定为次奖。检查一下这时的中奖
   人数有没有达到13人，如果没有，则判断是否有选中[96、85、63、52、41、30]的参与者，判定为次奖。检查中奖人数，如果依然没有达到
   13人，则设立新的绝对值评判标准。因为十位数4减去个位数7是负数，所以新的绝对值是3减1等于2，将判断是否有选中[2、13、24、35、46、57、68、79]
   的参与者，判定为次奖。检查人数，如果还是不到13人，则继续判断是否有选中[97、86、75、64、53、42、31、20]的参与者，以此类推。
   如果返回的幸运数字是74，则先判断是否有选中[96、85、63、52、41、30]的参与者，再判断是否有选中[3、14、25、36、58、69]的
   参与者。如果中奖人数还是不够13人，由于十位数7减去个位数4是正数，新的绝对值是3加1等于4，判定是否有选中[40、51、62、73、84、95]
   的参与者，再判断是否有选中[4、15、26、37、48、59]的中奖者。

# One-quarter lucky draw --- hybrid smart contract(English version)

### Rules

There are 52 participants in total. When a participant enters a round of lottery, he/she will pay **3 USD**
into the prize pool and choose a guessing integer from **0~99**. When the lottery starts, the total prize
pool is **156 USD**.

Start the lottery, get a random integer from 0 to 99 from the oracle network, called the first prize number,
and get another first prize number by swapping the ones and tens digits. For example, if the oracle network
returns **37**, then **73** is the second first prize number. 6 corresponds to 60. If the first prize number
returned is 33, where the tens and ones digits are equal, then the other first prize number is 99 minus the
number to get 66. Similarly, **22** corresponds to **77**.

#### Award judgment:

1. Normally, one quarter of the 52 participants will be selected in each round of lottery, that is, 13 people
   will win prizes. The first prize is $48. If only one participant wins the first prize, the other 12 people will
   split $108 equally, and each person will receive $9. If no one wins the head portrait, the number of winners
   in this round of lottery will be 12, and each person will receive $13. If **n** people win the first prize, then
   **13-n** people will win the second prize, and the first prize will be changed to 156-9*(13-n). Each first prize
   winner will receive a prize of (156-9*(13-n))/n.

2. First prize determination: The person who guesses the random number returned by the oracle network is directly
   determined as the first prize. If no one chooses the number, it is determined whether someone has chosen the second
   first prize number, and the selected number is determined as the first prize. If someone chooses the first lucky
   number, it is determined as the first prize. Even if someone else chooses the second lucky number, the selected
   number is still determined to be the second prize. For example, if the random number returned by the oracle is 47,
   the person who guesses it is directly determined as the first prize. If no one guesses it, it is determined whether
   someone guesses 74, and the person who guesses 74 is determined as the first prize. If someone has already guessed
   47, and someone else guesses 74, then the person who guesses 74 is determined as the second prize. If no one among
   the 52 people guesses 47 and 74, then 12 second prize winners will be selected, and each person will receive $13.

3. Second prize determination: Determine based on the absolute value between the tens and ones of the first lucky
   number. For example, if the first lucky number is 47, the absolute value of the tens and ones is 3, and the tens
   is smaller than the ones. Then, among the participants other than the first prize, we will screen whether there
   are any participants who have selected the numbers [3, 14, 25, 36, 58, 69], and determine them as second prizes.
   Check whether the number of winners has reached 13. If not, determine whether there are any participants who have
   selected [96, 85, 63, 52, 41, 30], and determine them as second prizes. Check the number of winners. If it still
   has not reached 13, set a new absolute value judgment standard. Because the tens digit 4 minus the ones digit 7
   is a negative number, the new absolute value is 3 minus 1 equals 2. We will determine whether there are any participants
   who have selected [2, 13, 24, 35, 46, 57, 68, 79], and determine them as second prizes. Check the number of people.
   If there are still less than 13 people, continue to determine whether there are participants who have selected
   [97, 86, 75, 64, 53, 42, 31, 20], and so on.
   If the lucky number returned is 74, first determine whether there are participants who have selected
   [96, 85, 63, 52, 41, 30], and then determine whether there are participants who have selected [3, 14, 25, 36, 58, 69].
   If the number of winners is still less than 13, since the tens digit 7 minus the ones digit 4 is a positive number,
   the new absolute value is 3 plus 1 equals 4, determine whether there are participants who have selected
   [40, 51, 62, 73, 84, 95], and then determine whether there are winners who have selected [4, 15, 26, 37, 48, 59].
