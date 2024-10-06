import {run,artifacts} from "hardhat"

type InputSources = {
    [key: string]: {
        content: string;
    };
};

async function main() {
    const input = {
        language: "Solidity",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            outputSelection: {
                "*": {
                    "*": [
                        "abi",
                        "evm.bytecode",
                        "evm.deployedBytecode",
                        "evm.methodIdentifiers",
                    ],
                },
            },
        },
        sources: {} as InputSources,
    };



    // 读取合约文件并添加到输入中
    // const sources = await run("compile:solidity");

    const sources = await run("compile"); 

    // console.log(`sources: ${sources.toString()}`)

    // const fileNames = Object.keys(sources);
    // console.log(`fileName: ${fileNames[0]}`)


    // for (const fileName of fileNames) {
    //     const content = sources[fileName].source; // 获取合约代码
    //     input.sources[fileName] = {
    //         content,
    //     };
    // }

        // 获取所有合约的文件名
        const contracts = await artifacts.getAllFullyQualifiedNames();

        for (const contract of contracts) {
            const { sourceName } = await artifacts.readArtifact(contract); // 获取合约信息
            input.sources[contract.split(':')[1] + '.sol'] = { // 生成文件名
                content: sourceName,
            };
        }

    console.log(JSON.stringify(input, null, 2));
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});