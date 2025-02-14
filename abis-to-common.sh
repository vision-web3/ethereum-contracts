#/bin/sh

set -e

# This is helper script to generate the corresponding ABIS to be consumed
# by the common package. It simply takes the main three abis, and generate
# the copies to be consumed by the different chains in common.

declare -a chains=(
        "avalanche"
        "bnb_chain"
        "celo"
        "cronos"
        "ethereum"
        "polygon"
        "sonic"
    )

ABI_PATH=abis
HUB_ABI_PATH=${ABI_PATH}/vision-hub.abi
FORWARDER_ABI_PATH=${ABI_PATH}/vision-forwarder.abi
TOKEN_ABI_PATH=${ABI_PATH}/vision-token.abi

OUT_ABIS_COMMON_PATH=${ABI_PATH}/common

mkdir -p ${OUT_ABIS_COMMON_PATH}

for chain in "${chains[@]}";
do
    echo "Generate files for $chain"
    cp ${HUB_ABI_PATH} ${OUT_ABIS_COMMON_PATH}/${chain}_vision_hub.abi
    cp ${FORWARDER_ABI_PATH} ${OUT_ABIS_COMMON_PATH}/${chain}_vision_forwarder.abi
    cp ${TOKEN_ABI_PATH} ${OUT_ABIS_COMMON_PATH}/${chain}_token_hub.abi
done

echo "Checkout ${OUT_ABIS_COMMON_PATH}"