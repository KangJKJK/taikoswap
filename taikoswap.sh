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

# Git 초기화
print_command "Git 저장소를 초기화 중..."
if [ ! -d .git ]; then
  git init
fi

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
print_command "Foundry 설정 파일을 생성 중..."
cat <<EOF > foundry.toml
[profile]
chain_id = 167000

[profile.compiler]
solc_version = "0.8.19"

[profile.rpc]
url = "https://rpc.mainnet.taiko.xyz"

[profile.remappings]
"uniswap-v3" = "lib/uniswap-v3/contracts/"
"openzeppelin" = "lib/openzeppelin-contracts/contracts/"
"forge-std" = "lib/forge-std/src/"
EOF

# .gitignore 파일 생성
print_command ".gitignore 파일을 설정 중..."
cat <<EOF > .gitignore
# Ignore directories
/lib/
/scripts/*.log
/scripts/*.json
/scripts/*.solc

# Ignore environment files
.env
EOF

# .env 파일을 Git에 추가하고 커밋
print_command "Git에 .env 파일을 추가하고 커밋 중..."
# .gitignore에서 .env 항목 제거
sed -i '/\.env/d' .gitignore
# .env 파일을 Git에 추가
git add .env
git commit -m "Add .env file" || true  # 실패해도 계속 진행

# Git 상태 정리 및 초기 커밋
print_command "Git에 파일을 추가하고 초기 커밋 중..."
git add .
git commit -m "Initial commit: add .env, foundry.toml, .gitignore" || true  # 실패해도 계속 진행

# 서브모듈 제거 함수
remove_submodule() {
  local submodule_path=$1
  
  # 서브모듈 경로가 존재할 때만 처리
  if git config --file .gitmodules --get-regexp path | grep "$submodule_path"; then
    echo "Removing submodule at $submodule_path"

    # 서브모듈 제거
    git submodule deinit -f "$submodule_path" || true
    git rm -f "$submodule_path" || true
    rm -rf ".git/modules/$submodule_path" || true
  else
    echo "Submodule at $submodule_path does not exist, skipping."
  fi
}

# 기존 서브모듈 제거
remove_submodule "lib/forge-std"
remove_submodule "lib/uniswap-v3"
remove_submodule "lib/openzeppelin-contracts"

# 라이브러리 설치 명령
print_command "라이브러리를 설치 중..."
forge install foundry-rs/forge-std --no-commit || true
forge install uniswap/v3-periphery --no-commit || true
forge install OpenZeppelin/openzeppelin-contracts --no-commit || true

# Git 상태 정리 후, 라이브러리 설치 완료 커밋
print_command "Git에 파일을 추가하고 커밋 중..."
git add --force lib/forge-std
git add --force lib/uniswap-v3
git add --force lib/openzeppelin-contracts
git commit -m "Add libraries without committing the libraries themselves" || true

# 계약 및 스크립트 디렉토리 생성
print_command "디렉토리 및 계약 파일을 설정 중..."
mkdir -p scripts contracts

# UniswapV3Swap 계약 생성
cat <<EOF > contracts/UniswapV3Swap.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "uniswap-v3/contracts/interfaces/ISwapRouter.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

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
import "uniswap-v3/contracts/interfaces/ISwapRouter.sol";
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
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
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
forge build || true

# UniswapV3Swap 계약을 배포
print_command "UniswapV3Swap 계약을 배포 중..."
forge script scripts/DeployUniV3Swap.s.sol --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --verify -vvvv || true

# WETH를 ETH로 스왑
print_command "WETH를 ETH로 스왑 중..."
forge script scripts/SwapWETHToETH.s.sol --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --gas-price 100000000 --gas-limit 36312 || true

# 테스트 실행
print_command "테스트를 실행 중..."
forge test --gas-report || true

echo -e "${GREEN}모든 작업이 완료되었습니다.${RESET}"
echo -e "${GREEN}스크립트작성자-https://t.me/kjkresearch${RESET}"
