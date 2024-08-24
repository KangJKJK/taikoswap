#!/bin/bash

# 굵은 글씨 및 색상 설정
BOLD=$(tput bold)
RESET=$(tput sgr0)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)

# 명령어 출력 함수
print_command() {
  echo -e "${BOLD}${YELLOW}$1${RESET}"
}

# 홈 디렉토리로 이동
cd $HOME

# Foundry 설치
print_command "Foundry를 설치 중..."
curl -L https://foundry.paradigm.xyz | bash
. "$HOME/.foundry/bin/foundryup"

# Foundry 명령어 경로 설정
export PATH="$HOME/.foundry/bin:$PATH"

# Foundry 버전 확인
print_command "Foundry 버전 확인 중..."
forge --version

# 사용자에게 개인 키 입력 요청
read -p "EVM 지갑 개인 키를 입력하세요 (0x 제외): " WALLET_PRIVATE_KEY

# .env 파일 생성
print_command ".env 파일을 생성 중..."
cat <<EOF > .env
PRIVATE_KEY=$WALLET_PRIVATE_KEY
EOF

# Foundry 설정 파일 작성
print_command "Foundry 설정 파일을 업데이트 중..."
cat <<EOF > foundry.toml
[profile]
rpc_url = "https://rpc.mainnet.taiko.xyz"

[compiler]
solc_version = "0.8.19"
EOF

# 스마트 계약 컴파일
print_command "스마트 계약을 컴파일 중..."
forge build

# UniswapV3Swap 배포 스크립트 생성
print_command "UniswapV3Swap 배포 스크립트를 생성 중..."
cat <<EOF > scripts/DeployUniV3Swap.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/UniswapV3Swap.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract DeployUniswapV3Swap is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        address wethAddress = 0xA51894664A773981C6C112C43ce576f315d5b1B6;
        address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEe;

        UniswapV3Swap swapContract = new UniswapV3Swap(swapRouter, wethAddress, ethAddress);

        vm.stopBroadcast();
    }
}
EOF

# WETH를 ETH로 스왑하는 스크립트 생성
print_command "WETH를 ETH로 스왑하는 스크립트를 생성 중..."
cat <<EOF > scripts/SwapWETHToETH.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/UniswapV3Swap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapWETHToETH is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        UniswapV3Swap swapContract = UniswapV3Swap(0xE638EC896e7Df929429e1165268D2316717Bb81d); // 배포된 계약 주소
        address wethAddress = 0xA51894664A773981C6C112C43ce576f315d5b1B6;
        uint256 amountIn = 0.00001e18; // 0.00001 WETH

        IERC20(wethAddress).approve(address(swapContract), amountIn);
        swapContract.swapExactInputSingleHop(amountIn);

        vm.stopBroadcast();
    }
}
EOF

# Foundry 스크립트 실행
print_command "UniswapV3Swap 계약을 배포 중..."
forge script scripts/DeployUniV3Swap.s.sol --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --verify -vvvv

print_command "WETH를 ETH로 스왑 중..."
forge script scripts/SwapWETHToETH.s.sol --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --gas-price 100000000 --gas-limit 36312

# 테스트 실행
print_command "테스트를 실행 중..."
forge test --gas-report

echo -e "${GREEN}모든 작업이 완료되었습니다.${RESET}"
echo -e "${GREEN}스크립트작성자-https://t.me/kjkresearch${RESET}"
