const fs = require("fs")
const path = require("path")

// Get the broadcast directory path
const broadcastDir = path.join(__dirname, "../broadcast/DeployC3Caller.s.sol")

if (!fs.existsSync(broadcastDir)) {
    console.error("Error: Broadcast directory not found")
    console.error(`Expected directory: ${broadcastDir}`)
    process.exit(1)
}

// Get all chain ID directories
const chainDirs = fs.readdirSync(broadcastDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name)

if (chainDirs.length === 0) {
    console.error("Error: No chain directories found in broadcast/DeployC3Caller.s.sol/")
    process.exit(1)
}

let list = {}

// Process each chain directory
chainDirs.forEach(chainId => {
    if (chainId == 31337) return

    const runFilePath = path.join(broadcastDir, chainId, "run-latest.json")

    list[chainId] = {}

    if (!fs.existsSync(runFilePath)) {
        console.warn(`Warning: run-latest.json not found for chain ID ${chainId}`)
        return
    }
    
    console.log(`Processing chain ID: ${chainId}`)
    
    try {
        // Load the deployment data
        const deploymentData = require(runFilePath)
        
        // Process transactions to extract contract addresses
        deploymentData.transactions.forEach((tx) => {
            if (tx.transactionType === "CREATE" && tx.contractAddress) {
                const contractName = tx.contractName
                const contractAddress = tx.contractAddress

                switch (contractName) {
                    case "C3UUIDKeeper":
                        // const c3UUIDProxyTx = deploymentData.transactions[index + 1]
                        // list[chainId].c3UUIDProxy = c3UUIDProxyTx.contractAddress
                        list[chainId].uuidKeeper = contractAddress
                        break
                    case "C3Caller":
                        // const c3callerProxyTx = deploymentData.transactions[index + 1]
                        // list[chainId].c3callerProxy = c3callerProxyTx.contractAddress
                        list[chainId].c3caller = contractAddress
                        break
                    case "C3DAppManager":
                        // const c3DAppManagerProxyTx = deploymentData.transactions[index + 1]
                        // list[chainId].c3DAppManagerProxy = c3DAppManagerProxyTx.contractAddress
                        list[chainId].dappManager = contractAddress
                        break
                }
            }
        })
    } catch (error) {
        console.error(`Error processing chain ID ${chainId}:`, error.message)
    }
})

// Write the contract addresses file to the root directory
const outputPath = path.join(__dirname, "../contract-addresses.json")
fs.writeFileSync(outputPath, JSON.stringify(list, null, 2))

console.log(`Contract addresses file generated successfully for chain IDs: ${Object.keys(list).join(", ")}`)
console.log(`Output file: ${outputPath}`)
console.log(`Total chain IDs processed: ${Object.keys(list).length}`)
