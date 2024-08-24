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

# taikoswap 디렉토리로 이동 또는 생성
print_command "디렉토리를 설정 중..."
mkdir -p /root/taikoswap
cd /root/taikoswap

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

# 기존 Foundry 설정 파일 삭제 (백업 없이 삭제)
if [ -f foundry.toml ]; then
  print_command "기존 foundry.toml 파일을 삭제 중..."
  rm foundry.toml
fi

# Foundry 설정 파일 작성
print_command "Foundry 설정 파일을 생성 중..."
cat <<EOF > foundry.toml
[rpc]
url = "https://rpc.mainnet.taiko.xyz"

[profile]
chain_id = 1

[profile.compiler]
solc_version = "0.8.19"

[remappings]
"forge-std/=lib/forge-std/src/"
"uniswap-v3/=lib/uniswap-v3/contracts/"
"openzeppelin/=lib/openzeppelin-contracts/contracts/"
EOF

# `forge-std`와 Uniswap V3의 라이브러리 수동 설치
print_command "라이브러리를 수동으로 설치 중..."
mkdir -p lib
cd lib

# `forge-std` 라이브러리 다운로드
print_command "forge-std 라이브러리 설치 중..."
mkdir -p forge-std
cd forge-std
curl -L https://github.com/foundry-rs/forge-std/archive/refs/heads/master.zip -o forge-std.zip
unzip forge-std.zip
rm forge-std.zip
mv forge-std-master/* .
rm -r forge-std-master
cd ..

# Uniswap V3 라이브러리 클론
print_command "Uniswap V3 라이브러리 설치 중..."
mkdir -p uniswap-v3
cd uniswap-v3
git clone https://github.com/uniswap/v3-periphery.git .
cd ..

# OpenZeppelin 라이브러리 다운로드
print_command "OpenZeppelin 라이브러리 설치 중..."
mkdir -p openzeppelin-contracts
cd openzeppelin-contracts
curl -L https://github.com/OpenZeppelin/openzeppelin-contracts/archive/refs/heads/master.zip -o openzeppelin-contracts.zip
unzip openzeppelin-contracts.zip
rm openzeppelin-contracts.zip
mv openzeppelin-contracts-master/* .
rm -r openzeppelin-contracts-master
cd ..

# 계약 및 스크립트 디렉토리 생성
print_command "디렉토리 및 계약 파일을 설정 중..."
mkdir -p scripts contracts

# UniswapV3Swap 계약 생성
cat <<EOF > contracts/UniswapV3Swap.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV3Swap {
    ISwapRouter public swapRouter;
    address public wethAddress;
    address public ethAddress;

    constructor(ISwapRouter _swapRouter, address _wethAddress, address _ethAddress) {
        swapRouter = _swapRouter;
        wethAddress = _wethAddress;
        ethAddress = _ethAddress;
    }

    function swapExactInputSingleHop(uint256 amountIn) external {
        IERC20(wethAddress).transferFrom(msg.sender, address(this), amountIn);
        IERC20(wethAddress).approve(address(swapRouter), amountIn);

        // Swap logic here...
    }
}
EOF

# UniswapV3Swap 배포 스크립트 생성
cat <<EOF > scripts/DeployUniV3Swap.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../contracts/UniswapV3Swap.sol";

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
cat <<EOF > scripts/SwapWETHToETH.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/UniswapV3Swap.sol";

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

# 스마트 계약 컴파일
print_command "스마트 계약을 컴파일 중..."
forge build

# UniswapV3Swap 계약을 배포
print_command "UniswapV3Swap 계약을 배포 중..."
forge script scripts/DeployUniV3Swap.s.sol --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --verify -vvvv

# WETH를 ETH로 스왑
print_command "WETH를 ETH로 스왑 중..."
forge script scripts/SwapWETHToETH.s.sol --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --gas-price 100000000 --gas-limit 36312

# 테스트 실행
print_command "테스트를 실행 중..."
forge test --gas-report

echo -e "${GREEN}모든 작업이 완료되었습니다.${RESET}"
echo -e "${GREEN}스크립트작성자-https://t.me/kjkresearch${RESET}"
