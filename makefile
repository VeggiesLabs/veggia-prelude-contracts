include .env
export

all: 
	forge install

deploy-testnet:
	bash script/testnet/deployAll

upgrade-testnet:
	bash script/testnet/upgradeTo

deploy-erc20-testnet:
	forge create src/ERC20.sol:MyToken \
        --account veggiaDeployer \
        --rpc-url ${ABSTRACT_TESTNET_URL} \
        --chain 11124 \
        --zksync \
        --verify \
        --verifier zksync \
        --verifier-url https://api-explorer-verify.testnet.abs.xyz/contract_verification
