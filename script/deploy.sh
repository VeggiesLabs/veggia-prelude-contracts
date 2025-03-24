#!/bin/bash

# Load environment variables
source .env

export HD_PATHS="m/44'/60'/${LEDGER_ACCOUNT_INDEX}'/0/0"

# Define environment variables
if [ "$TESTNET" = "true" ]; then
  export RPC_URL=$TESTNET_RPC_URL
  export VERIFY_URL=$TESTNET_VERIFY_URL
  export CHAIN_ID=$TESTNET_CHAIN_ID
  export FEE_RECEIVER=$TESTNET_FEE_RECEIVER
  export OWNER=$TESTNET_OWNER
  export SERVER_SIGNER=$TESTNET_SERVER_SIGNER
  export VEGGIA_BASE_URI=$TESTNET_VEGGIA_BASE_URI
  export PYTH_CONTRACT=$TESTNET_PYTH_CONTRACT
  export API_KEY=$TESTNET_API_KEY
  IS_MAINNET=false
  COLOR="\x1b[31m"
else
  export RPC_URL=$MAINNET_RPC_URL
  export VERIFY_URL=$MAINNET_VERIFY_URL
  export CHAIN_ID=$MAINNET_CHAIN_ID
  export FEE_RECEIVER=$MAINNET_FEE_RECEIVER
  export OWNER=$MAINNET_OWNER
  export SERVER_SIGNER=$MAINNET_SERVER_SIGNER
  export VEGGIA_BASE_URI=$MAINNET_VEGGIA_BASE_URI
  export PYTH_CONTRACT=$MAINNET_PYTH_CONTRACT
  export API_KEY=$MAINNET_API_KEY
  IS_MAINNET=true
  COLOR="\x1b[32m"
fi

printf "\x1b[34m======================================================\n"
printf "==            Mainnet deployment: ${COLOR}${IS_MAINNET}\x1b[34m            ===\n"
printf "======================================================\x1b[0m\n"
printf "\x1b[35mCHAIN_ID\x1b[0m: \x1b[36m$CHAIN_ID\x1b[0m\n"
printf "\x1b[35mRPC_URL\x1b[0m: \x1b[36m$RPC_URL\x1b[0m\n"
printf "\x1b[35mFEE_RECEIVER\x1b[0m: \x1b[36m$FEE_RECEIVER\x1b[0m\n"
printf "\x1b[35mOWNER\x1b[0m: \x1b[36m$OWNER\x1b[0m\n"
printf "\x1b[35mSERVER_SIGNER\x1b[0m: \x1b[36m$SERVER_SIGNER\x1b[0m\n"
printf "\x1b[35mPYTH_CONTRACT\x1b[0m: \x1b[36m$PYTH_CONTRACT\x1b[0m\n"
printf "\x1b[35mVEGGIA_BASE_URI\x1b[0m: \x1b[36m$VEGGIA_BASE_URI\x1b[0m\n"
printf "\x1b[35mHD_PATHS\x1b[0m: \x1b[36m$HD_PATHS\x1b[0m\n"
printf "\x1b[35mVERIFY_URL\x1b[0m: \x1b[36m$VERIFY_URL\x1b[0m\n"
printf "\x1b[35mAPI_KEY\x1b[0m: \x1b[36m$API_KEY\x1b[0m\n"

printf "\n\n"

# Prompt to continue
read -p "Do you want to continue? (y/n) " -n 1 -r

# Deploy contracts
forge script script/deployAll.s.sol:DeployAll --slow --broadcast --ledger --hd-paths $HD_PATHS --ffi --zksync --rpc-url $RPC_URL --chain $CHAIN_ID --verify --verifier etherscan --verifier-url $VERIFY_URL --etherscan-api-key $API_KEY
