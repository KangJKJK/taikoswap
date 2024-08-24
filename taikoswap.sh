#!/bin/bash

# 굵은 글씨 및 색상 설정
BOLD=$(tput bold)
RESET=$(tput sgr0)
YELLOW=$(tput setaf 3)

# 명령어 출력 함수
print_command() {
  echo -e "${BOLD}${YELLOW}$1${RESET}"
}

# 홈 디렉토리로 이동
cd $HOME

# Cargo 설치
print_command "Cargo를 설치 중..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"

# NVM과 Node 설치
print_command "NVM과 Node를 설치 중..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

# NVM 디렉토리 설정
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

# NVM 초기화 스크립트 로드
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
elif [ -s "/usr/local/share/nvm/nvm.sh" ]; then
    . "/usr/local/share/nvm/nvm.sh"
else
    echo "오류: nvm.sh 파일을 찾을 수 없습니다!"
    exit 1
fi

# NVM bash 자동 완성 로드
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Node 버전 관리자 사용
print_command "Node 버전 관리자를 사용 중..."
nvm install node
nvm use node

# Node와 npm 버전 확인
node -v
npm -v

# gblend 도구 설치
print_command "gblend 도구를 설치 중..."
cargo install gblend

# gblend 실행
print_command "gblend를 실행 중..."
gblend

# 프로젝트 종속성 설치
print_command "종속성을 설치 중..."
npm install

# dotenv 패키지 설치
print_command "dotenv 패키지를 설치 중..."
npm install dotenv

# 기존 hardhat.config.js 파일 삭제
print_command "hardhat.config.js 파일을 삭제 중..."
rm hardhat.config.js

# 새로운 hardhat.config.js 파일 생성
print_command "hardhat.config.js 파일을 업데이트 중..."
cat <<EOF > hardhat.config.js
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-vyper");
require("dotenv").config();

module.exports = {
  defaultNetwork: "fluent_devnet1",
  networks: {
    fluent_devnet1: {
      url: 'https://rpc.dev.thefluent.xyz/',
      chainId: 20993,
      accounts: [\`0x\${process.env.DEPLOYER_PRIVATE_KEY}\`],
    },
  },
  solidity: {
    version: '0.8.19',
  },
  vyper: {
    version: "0.3.0",
  },
};
EOF

# 사용자에게 EVM 지갑 개인 키 입력 요청
read -p "EVM 지갑 개인 키를 입력하세요 (0x 제외): " WALLET_PRIVATE_KEY

# .env 파일 생성
print_command ".env 파일을 생성 중..."
cat <<EOF > .env
DEPLOYER_PRIVATE_KEY=$WALLET_PRIVATE_KEY
EOF

# 스마트 계약 컴파일
print_command "스마트 계약을 컴파일 중..."
npm run compile

# 스마트 계약 배포
print_command "스마트 계약을 배포 중..."
npm run deploy

echo -e "${GREEN}모든 작업이 완료되었습니다.${NC}"
echo -e "${GREEN}스크립트작성자-https://t.me/kjkresearch${NC}"

