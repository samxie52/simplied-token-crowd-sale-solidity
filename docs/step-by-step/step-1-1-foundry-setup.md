# Step 1.1: 项目初始化和Foundry配置

## 🎯 功能概述

建立完整的Foundry开发环境和项目结构，为ERC20代币众筹平台奠定坚实的技术基础。本步骤将配置现代化的Solidity开发工具链，包括编译器、测试框架、依赖管理和自动化脚本。

## 📋 前置条件

- 操作系统：Linux、macOS 或 Windows (WSL2)
- Git版本控制工具
- 网络连接（用于下载依赖）
- 基础的命令行操作能力

## 🔧 技术栈和工具

### 核心开发工具
- **Foundry** - 现代化Solidity开发框架
  - `forge` - 智能合约编译和测试
  - `cast` - 区块链交互命令行工具  
  - `anvil` - 本地测试网络
- **OpenZeppelin Contracts** - 企业级安全合约库
- **Solidity ^0.8.19** - 智能合约开发语言

### 构建和部署工具
- **Make** - 自动化构建脚本
- **Git** - 版本控制
- **GitHub** - 代码托管和协作

## 📁 目标项目结构

```
simplied-token-crowd-sale-solidity/
├── contracts/                      # 智能合约源码
│   ├── TokenCrowdsale.sol          # 主众筹合约
│   ├── CrowdsaleToken.sol          # ERC20代币合约
│   ├── WhitelistManager.sol        # 白名单管理合约
│   ├── TokenVesting.sol            # 代币释放合约
│   ├── RefundVault.sol             # 退款管理合约
│   ├── interfaces/                 # 合约接口定义
│   │   ├── ICrowdsale.sol
│   │   ├── ITokenVesting.sol
│   │   └── IWhitelistManager.sol
│   └── utils/                      # 工具合约
│       ├── CrowdsaleConstants.sol
│       └── TestUtils.sol
├── test/                           # 测试文件
│   ├── unit/                       # 单元测试
│   ├── integration/                # 集成测试
│   ├── fuzz/                       # 模糊测试
│   ├── benchmark/                  # 性能测试
│   └── utils/                      # 测试工具
├── script/                         # 部署和脚本
│   ├── Deploy.s.sol                # 部署脚本
│   ├── ConfigureCrowdsale.s.sol    # 配置脚本
│   └── UpgradeContracts.s.sol      # 升级脚本
├── web/                            # 前端界面
│   ├── index.html                  # 主页面
│   ├── js/                         # JavaScript文件
│   ├── css/                        # 样式文件
│   └── assets/                     # 静态资源
├── docs/                           # 项目文档
│   ├── step-by-step/              # 分步实现文档
│   ├── api/                        # API文档
│   └── security/                   # 安全审计文档
├── lib/                            # Foundry依赖库（自动生成）
├── out/                            # 编译输出（自动生成）
├── cache/                          # 编译缓存（自动生成）
├── foundry.toml                    # Foundry配置文件
├── Makefile                        # 自动化构建脚本
├── remappings.txt                  # 依赖库映射
├── .gitignore                      # Git忽略文件
├── .env.example                    # 环境变量示例
├── README.md                       # 项目说明文档
└── DEVELOPMENT.md                  # 开发实践指南
```

## 🚀 详细实现步骤

### Step 1: Foundry工具链安装

#### 1.1 安装Foundry

**Linux/macOS用户：**
```bash
# 使用官方安装脚本
curl -L https://foundry.paradigm.xyz | bash

# 重新加载shell配置
source ~/.bashrc
# 或
source ~/.zshrc

# 安装最新版本
foundryup
```

**Windows用户（使用WSL2）：**
```bash
# 在WSL2终端中执行相同命令
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

#### 1.2 验证安装

```bash
# 验证Foundry工具安装成功
forge --version
cast --version
anvil --version

# 期望输出类似：
# forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)
# cast 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)
# anvil 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)
```

### Step 2: 项目初始化

#### 2.1 创建项目目录

**方式1：直接创建新项目（推荐）**
```bash
# forge init 会自动创建目录、初始化Git仓库、安装forge-std
forge init simplied-token-crowd-sale-solidity
cd simplied-token-crowd-sale-solidity
```

**方式2：在现有目录中初始化**
```bash
# 如果目录已存在或需要自定义目录结构
mkdir simplied-token-crowd-sale-solidity
cd simplied-token-crowd-sale-solidity
forge init --force .  # --force 覆盖现有文件
```

> 📝 **注意**: `forge init` 会自动执行以下操作：
> - 初始化 Git 仓库 (`git init`)
> - 创建基础项目结构 (`src/`, `test/`, `script/`)  
> - 生成 `foundry.toml` 配置文件
> - 安装 `forge-std` 依赖库
> - 创建 `.gitignore` 文件
> - 生成示例合约和测试文件

#### 2.2 调整项目结构

```bash
# forge init 默认创建 src/ 目录，我们需要改为 contracts/
mv src contracts

# 删除默认生成的示例文件
rm contracts/Counter.sol
rm script/Counter.s.sol  
rm test/Counter.t.sol

# 创建我们需要的目录结构
mkdir -p contracts/{interfaces,utils}
mkdir -p test/{unit,integration,fuzz,benchmark,utils}
mkdir -p web/{js,css,assets}
mkdir -p docs/{step-by-step,api,security}
```

### Step 3: 配置foundry.toml

创建和配置Foundry的核心配置文件：

```bash
# 创建foundry.toml配置文件
cat > foundry.toml << 'EOF'
[profile.default]
# 基础配置
src = "contracts"
out = "out"
libs = ["lib"]
test = "test"
script = "script"
cache_path = "cache"

# Solidity编译器配置
solc = "0.8.19"
auto_detect_solc = false
optimizer = true
optimizer_runs = 200
via_ir = false

# 测试配置
verbosity = 2
fuzz = { runs = 1000 }
gas_limit = 9223372036854775807
gas_price = 20000000000

# 格式化配置
[fmt]
line_length = 100
tab_width = 4
bracket_spacing = true
int_types = "long"
multiline_func_header = "all"
quote_style = "double"
number_underscore = "thousands"

# 测试相关配置
[fuzz]
runs = 10000
max_test_rejects = 65536
seed = '0x3e8'
dictionary_weight = 40
include_storage = true
include_push_bytes = true

# RPC端点配置
[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
goerli = "${GOERLI_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
polygon = "${POLYGON_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
optimism = "${OPTIMISM_RPC_URL}"
localhost = "http://localhost:8545"

# Etherscan API配置（用于合约验证）
[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
goerli = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
polygon = { key = "${POLYGONSCAN_API_KEY}", url = "https://api.polygonscan.com/" }
arbitrum = { key = "${ARBISCAN_API_KEY}", url = "https://api.arbiscan.io/" }
optimism = { key = "${OPTIMISTIC_ETHERSCAN_API_KEY}", url = "https://api-optimistic.etherscan.io/" }

# Gas报告配置
[gas_reports]
"*" = { ignore = false }
EOF
```

### Step 4: 安装OpenZeppelin依赖库

#### 4.1 安装OpenZeppelin Contracts

```bash
# 安装OpenZeppelin Contracts库
forge install OpenZeppelin/openzeppelin-contracts

# 安装OpenZeppelin Contracts Upgradeable（可选，为将来升级准备）
forge install OpenZeppelin/openzeppelin-contracts-upgradeable

# 安装Solmate（高效的Solidity库）
forge install transmissions11/solmate

# 安装Forge标准库
forge install foundry-rs/forge-std
```

#### 4.2 配置依赖映射

创建`remappings.txt`文件：

```bash
cat > remappings.txt << 'EOF'
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
@solmate/=lib/solmate/src/
forge-std/=lib/forge-std/src/
@contracts/=contracts/
@test/=test/
@script/=script/
EOF
```

### Step 5: 创建Makefile构建脚本

创建功能强大的Makefile自动化脚本：

```bash
cat > Makefile << 'EOF'
# ========================================
# Foundry代币众筹平台 - 自动化构建脚本
# ========================================

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
GREEN := \033[0;32m
YELLOW := \033[0;33m  
RED := \033[0;31m
NC := \033[0m # No Color

# 项目配置
PROJECT_NAME := TokenCrowdsale
SOLC_VERSION := 0.8.19

# 网络配置
LOCAL_RPC := http://localhost:8545
SEPOLIA_RPC := ${SEPOLIA_RPC_URL}
MAINNET_RPC := ${MAINNET_RPC_URL}

# ========================================
# 开发命令
# ========================================

.PHONY: help
help: ## 显示帮助信息
	@echo "$(GREEN)=== ERC20代币众筹平台构建脚本 ===$(NC)"
	@echo ""
	@echo "$(YELLOW)开发命令:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: install
install: ## 安装项目依赖
	@echo "$(GREEN)安装Foundry依赖库...$(NC)"
	forge install OpenZeppelin/openzeppelin-contracts
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable
	forge install transmissions11/solmate
	forge install foundry-rs/forge-std
	@echo "$(GREEN)依赖安装完成!$(NC)"

.PHONY: build
build: ## 编译智能合约
	@echo "$(GREEN)编译智能合约...$(NC)"
	forge build
	@echo "$(GREEN)编译完成!$(NC)"

.PHONY: clean
clean: ## 清理编译缓存
	@echo "$(YELLOW)清理编译缓存...$(NC)"
	forge clean
	@echo "$(GREEN)清理完成!$(NC)"

.PHONY: rebuild
rebuild: clean build ## 重新编译

# ========================================
# 测试命令
# ========================================

.PHONY: test
test: ## 运行所有测试
	@echo "$(GREEN)运行测试套件...$(NC)"
	forge test -vvv

.PHONY: test-unit
test-unit: ## 运行单元测试
	@echo "$(GREEN)运行单元测试...$(NC)"
	forge test --match-path "test/unit/**" -vvv

.PHONY: test-integration  
test-integration: ## 运行集成测试
	@echo "$(GREEN)运行集成测试...$(NC)"
	forge test --match-path "test/integration/**" -vvv

.PHONY: test-fuzz
test-fuzz: ## 运行模糊测试
	@echo "$(GREEN)运行模糊测试...$(NC)"
	forge test --match-path "test/fuzz/**" -vvv

.PHONY: test-gas
test-gas: ## 生成Gas报告
	@echo "$(GREEN)生成Gas使用报告...$(NC)"
	forge test --gas-report

.PHONY: test-coverage
test-coverage: ## 生成测试覆盖率报告
	@echo "$(GREEN)生成测试覆盖率报告...$(NC)"
	forge coverage

# ========================================
# 代码质量
# ========================================

.PHONY: fmt
fmt: ## 格式化代码
	@echo "$(GREEN)格式化Solidity代码...$(NC)"
	forge fmt

.PHONY: lint
lint: ## 代码静态分析
	@echo "$(GREEN)运行代码静态分析...$(NC)"
	@if command -v slither > /dev/null; then \
		slither contracts/; \
	else \
		echo "$(YELLOW)警告: Slither未安装，跳过静态分析$(NC)"; \
		echo "$(YELLOW)安装命令: pip3 install slither-analyzer$(NC)"; \
	fi

.PHONY: security
security: ## 安全检查
	@echo "$(GREEN)运行安全检查...$(NC)"
	@make lint
	@echo "$(GREEN)请考虑运行额外的安全工具如MythX$(NC)"

# ========================================
# 本地开发
# ========================================

.PHONY: anvil
anvil: ## 启动本地测试网络
	@echo "$(GREEN)启动Anvil本地测试网络...$(NC)"
	anvil --host 0.0.0.0 --port 8545 --chain-id 31337

.PHONY: deploy-local
deploy-local: ## 部署到本地网络
	@echo "$(GREEN)部署合约到本地网络...$(NC)"
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url $(LOCAL_RPC) \
		--broadcast \
		-vvv

# ========================================
# 测试网部署
# ========================================

.PHONY: deploy-sepolia
deploy-sepolia: ## 部署到Sepolia测试网
	@echo "$(GREEN)部署合约到Sepolia测试网...$(NC)"
	@if [ -z "$(SEPOLIA_RPC_URL)" ]; then \
		echo "$(RED)错误: SEPOLIA_RPC_URL环境变量未设置$(NC)"; \
		exit 1; \
	fi
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url $(SEPOLIA_RPC) \
		--broadcast \
		--verify \
		-vvv

.PHONY: verify-sepolia
verify-sepolia: ## 验证Sepolia上的合约
	@echo "$(GREEN)验证Sepolia合约...$(NC)"
	@echo "$(YELLOW)请手动运行验证命令或使用forge verify-contract$(NC)"

# ========================================
# 主网部署（谨慎操作）
# ========================================

.PHONY: deploy-mainnet
deploy-mainnet: ## 部署到以太坊主网（需确认）
	@echo "$(RED)警告: 即将部署到以太坊主网!$(NC)"
	@echo "$(YELLOW)请确保:$(NC)"
	@echo "  1. 已完成完整测试"
	@echo "  2. 已进行安全审计"
	@echo "  3. 环境变量配置正确"
	@echo "  4. 有足够的ETH支付Gas费"
	@read -p "确认继续? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url $(MAINNET_RPC) \
		--broadcast \
		--verify \
		-vvv

# ========================================
# 工具命令
# ========================================

.PHONY: console
console: ## 启动Foundry控制台
	@echo "$(GREEN)启动Foundry控制台...$(NC)"
	forge console

.PHONY: gas-estimate
gas-estimate: ## 估算Gas使用量
	@echo "$(GREEN)估算合约Gas使用量...$(NC)"
	forge test --gas-report --json > gas-report.json
	@echo "$(GREEN)Gas报告已保存到 gas-report.json$(NC)"

.PHONY: size-check
size-check: ## 检查合约大小
	@echo "$(GREEN)检查合约字节码大小...$(NC)"
	forge build --sizes

.PHONY: doc
doc: ## 生成文档
	@echo "$(GREEN)生成合约文档...$(NC)"
	forge doc --build

.PHONY: tree
tree: ## 显示依赖树
	@echo "$(GREEN)显示依赖关系树...$(NC)"
	forge tree

# ========================================
# 前端开发
# ========================================

.PHONY: serve-frontend
serve-frontend: ## 启动前端开发服务器
	@echo "$(GREEN)启动前端开发服务器...$(NC)"
	@if command -v python3 > /dev/null; then \
		cd web && python3 -m http.server 8000; \
	elif command -v python > /dev/null; then \
		cd web && python -m http.server 8000; \
	else \
		echo "$(RED)错误: 未找到Python，无法启动开发服务器$(NC)"; \
		echo "$(YELLOW)请安装Python或使用其他HTTP服务器$(NC)"; \
	fi

# ========================================
# 初始化和设置
# ========================================

.PHONY: setup-env
setup-env: ## 设置环境变量文件
	@echo "$(GREEN)创建环境变量模板...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN).env文件已创建，请填写必要的配置$(NC)"; \
	else \
		echo "$(YELLOW).env文件已存在$(NC)"; \
	fi

.PHONY: init-project
init-project: install setup-env ## 初始化完整项目
	@echo "$(GREEN)项目初始化完成!$(NC)"
	@echo "$(YELLOW)下一步:$(NC)"
	@echo "  1. 填写 .env 文件中的配置"
	@echo "  2. 运行 make build 编译合约"
	@echo "  3. 运行 make test 执行测试"

# ========================================
# 清理命令
# ========================================

.PHONY: clean-all
clean-all: clean ## 深度清理（包括依赖）
	@echo "$(YELLOW)深度清理项目...$(NC)"
	rm -rf lib/
	rm -rf out/
	rm -rf cache/
	@echo "$(GREEN)深度清理完成!$(NC)"

# ========================================
# CI/CD相关
# ========================================

.PHONY: ci-test
ci-test: ## CI环境测试
	@echo "$(GREEN)CI环境测试...$(NC)"
	forge test --no-match-path "test/fuzz/**"

.PHONY: ci-build
ci-build: ## CI环境构建
	@echo "$(GREEN)CI环境构建...$(NC)"
	forge build

.PHONY: pre-commit
pre-commit: fmt lint test ## 提交前检查
	@echo "$(GREEN)提交前检查完成!$(NC)"
EOF
```

### Step 6: 创建环境变量配置

#### 6.1 创建.env.example模板

```bash
cat > .env.example << 'EOF'
# ========================================
# ERC20代币众筹平台 - 环境变量配置
# ========================================

# RPC节点配置
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY  
GOERLI_RPC_URL=https://eth-goerli.g.alchemy.com/v2/YOUR-API-KEY
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR-API-KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR-API-KEY
OPTIMISM_RPC_URL=https://opt-mainnet.g.alchemy.com/v2/YOUR-API-KEY

# 区块链浏览器API密钥（用于合约验证）
ETHERSCAN_API_KEY=YOUR-ETHERSCAN-API-KEY
POLYGONSCAN_API_KEY=YOUR-POLYGONSCAN-API-KEY
ARBISCAN_API_KEY=YOUR-ARBISCAN-API-KEY
OPTIMISTIC_ETHERSCAN_API_KEY=YOUR-OPTIMISTIC-ETHERSCAN-API-KEY

# 部署账户私钥（不要提交到版本控制！）
# 使用测试账户，不要使用包含真实资金的私钥
PRIVATE_KEY=0x0000000000000000000000000000000000000000000000000000000000000000
DEPLOYER_ADDRESS=0x0000000000000000000000000000000000000000

# 众筹配置参数
TOKEN_NAME=CrowdsaleToken
TOKEN_SYMBOL=CST
TOKEN_DECIMALS=18
INITIAL_SUPPLY=1000000000000000000000000  # 1,000,000 tokens with 18 decimals
CROWDSALE_RATE=1000  # 1 ETH = 1000 tokens
SOFT_CAP=50000000000000000000   # 50 ETH
HARD_CAP=500000000000000000000  # 500 ETH

# 时间配置（Unix时间戳）
PRESALE_START_TIME=1693526400    # 预售开始时间
PRESALE_END_TIME=1694131200      # 预售结束时间  
PUBLIC_SALE_START_TIME=1694131200 # 公开销售开始时间
PUBLIC_SALE_END_TIME=1695340800   # 公开销售结束时间

# 开发工具配置
REPORT_GAS=true
COINMARKETCAP_API_KEY=YOUR-COINMARKETCAP-API-KEY  # 用于Gas价格转换

# 前端配置
FRONTEND_PORT=8000
ENABLE_ANALYTICS=false

# 安全配置
ENABLE_MULTISIG=true
MULTISIG_THRESHOLD=2
MULTISIG_OWNERS=0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000
EOF
```

#### 6.2 创建.gitignore文件

```bash
cat > .gitignore << 'EOF'
# ========================================
# ERC20代币众筹平台 - Git忽略文件
# ========================================

# 环境变量和敏感信息
.env
.env.*
!.env.example
secrets.json

# Foundry输出目录
out/
cache/
broadcast/

# 依赖库目录（由forge管理）
lib/

# 编译缓存
*.cache/
cache_*

# 测试覆盖率报告
coverage/
lcov.info
*.lcov

# 日志文件
*.log
logs/

# 操作系统生成的文件
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE和编辑器文件
.vscode/
.idea/
*.swp
*.swo
*~

# Node.js相关（如果使用）
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
package-lock.json
yarn.lock

# Python相关（如果使用Python脚本）
__pycache__/
*.py[cod]
*$py.class
.Python
venv/
env/

# 临时文件
*.tmp
*.temp
temp/
tmp/

# 构建产物和报告
gas-report.json
gas-snapshot
.gas-snapshot
size-snapshot.json

# 安全扫描报告
slither-report.json
mythx-report.json
audit-reports/

# 部署记录
deployments/
deployed-contracts.json

# 测试产物
test-results/
junit.xml

# 文档生成
docs/build/
site/

# 备份文件
*.bak
*.backup

# 压缩文件
*.zip
*.tar.gz
*.rar

# 本地配置文件
local.config.js
local.settings.json
EOF
```

### Step 7: 创建基础项目文档

#### 7.1 创建README.md

```bash
cat > README.md << 'EOF'
# ERC20代币众筹平台 (TokenCrowdsale)

🚀 **基于 Solidity + Foundry 的去中心化众筹平台**

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.19-blue)](https://docs.soliditylang.org/)

## 📋 项目描述

这是一个功能完整的去中心化代币众筹平台，支持项目方通过发行 ERC20 代币进行资金募集。系统采用模块化智能合约架构，集成了白名单预售、公开销售、自动退款、代币释放等完整众筹流程。

## 🚀 快速开始

### 环境要求

- **Foundry** - Solidity 开发框架
- **Node.js 16+** - 前端依赖管理（可选）
- **Git** - 版本控制

### 安装和运行

1. **安装 Foundry**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **克隆和设置项目**
```bash
git clone <repository-url>
cd simplied-token-crowd-sale-solidity
make init-project
```

3. **编译和测试**
```bash
make build
make test
```

4. **启动本地开发**
```bash
# 终端1：启动本地区块链
make anvil

# 终端2：部署合约
make deploy-local

# 终端3：启动前端
make serve-frontend
```

## 📊 项目状态

- 🚧 **开发阶段**: Step 1.1 - 项目初始化完成
- 📈 **测试覆盖率**: 目标 >95%
- 🛡️ **安全审计**: 计划中
- 🌐 **前端界面**: 开发中

## 🤝 贡献指南

查看 [DEVELOPMENT.md](DEVELOPMENT.md) 了解详细的开发指南。

## 📝 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---
⭐ 如果这个项目对你有帮助，请给我们一个 Star！
EOF
```

#### 7.2 创建DEVELOPMENT.md

```bash
cat > DEVELOPMENT.md << 'EOF'
# 开发实践指南

## 🛠️ 开发工具链

本项目使用现代化的 Solidity 开发工具链：

- **Foundry**: 核心开发框架
- **OpenZeppelin**: 安全合约库
- **Slither**: 静态分析工具
- **Make**: 自动化构建

## 📋 开发工作流

### 日常开发命令

```bash
# 安装依赖
make install

# 编译合约
make build

# 运行测试
make test

# 代码格式化
make fmt

# 静态分析
make lint
```

### Git提交规范

使用 [Conventional Commits](https://conventionalcommits.org/) 规范：

```bash
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式化
refactor: 代码重构
test: 测试相关
chore: 构建/工具链相关
```

## 🧪 测试策略

- **单元测试**: 每个合约函数的独立测试
- **集成测试**: 多合约交互的端到端测试
- **模糊测试**: 随机输入的边界条件测试
- **安全测试**: 重入攻击、溢出等安全漏洞测试

## 📁 目录结构说明

```
contracts/          # 智能合约源码
├── interfaces/     # 合约接口定义
└── utils/          # 工具和常量合约

test/               # 测试文件
├── unit/           # 单元测试
├── integration/    # 集成测试
├── fuzz/           # 模糊测试
└── utils/          # 测试工具

script/             # 部署和配置脚本
web/                # 前端界面文件
docs/               # 项目文档
```

## 🚀 部署流程

1. **本地测试**: `make anvil` + `make deploy-local`
2. **测试网部署**: `make deploy-sepolia`  
3. **主网部署**: `make deploy-mainnet` (需要额外确认)

## 📝 代码规范

- 遵循 Solidity 官方风格指南
- 使用 NatSpec 格式的文档注释
- 函数命名采用 camelCase
- 常量使用 UPPER_SNAKE_CASE
- 私有函数添加下划线前缀

## 🔒 安全最佳实践

- 使用 OpenZeppelin 的安全合约
- 实施访问控制和权限管理
- 添加重入攻击防护
- 进行全面的边界条件测试
- 定期运行静态分析工具
EOF
```

### Step 8: 验证项目设置

#### 8.1 创建基础验证脚本

```bash
# 创建验证脚本
cat > scripts/verify-setup.sh << 'EOF'
#!/bin/bash

echo "🔍 验证Foundry项目设置..."

# 检查Foundry工具
echo "检查Foundry工具链..."
if command -v forge > /dev/null; then
    echo "✅ forge: $(forge --version)"
else
    echo "❌ forge 未安装"
    exit 1
fi

if command -v cast > /dev/null; then
    echo "✅ cast: $(cast --version)" 
else
    echo "❌ cast 未安装"
    exit 1
fi

if command -v anvil > /dev/null; then
    echo "✅ anvil: $(anvil --version)"
else
    echo "❌ anvil 未安装"  
    exit 1
fi

# 检查项目文件
echo -e "\n检查项目配置文件..."
if [ -f "foundry.toml" ]; then
    echo "✅ foundry.toml 存在"
else
    echo "❌ foundry.toml 不存在"
    exit 1
fi

if [ -f "remappings.txt" ]; then
    echo "✅ remappings.txt 存在"
else
    echo "❌ remappings.txt 不存在"
    exit 1
fi

if [ -f "Makefile" ]; then
    echo "✅ Makefile 存在"
else
    echo "❌ Makefile 不存在"
    exit 1
fi

# 检查依赖库
echo -e "\n检查依赖库..."
if [ -d "lib/openzeppelin-contracts" ]; then
    echo "✅ OpenZeppelin Contracts 已安装"
else
    echo "❌ OpenZeppelin Contracts 未安装"
    echo "运行: forge install OpenZeppelin/openzeppelin-contracts"
fi

if [ -d "lib/forge-std" ]; then
    echo "✅ Forge Standard Library 已安装"
else
    echo "❌ Forge Standard Library 未安装"
    echo "运行: forge install foundry-rs/forge-std"
fi

# 尝试编译
echo -e "\n测试编译..."
if forge build > /dev/null 2>&1; then
    echo "✅ 项目编译成功"
else
    echo "❌ 项目编译失败"
    echo "运行 'forge build' 查看详细错误信息"
fi

echo -e "\n🎉 项目设置验证完成！"
echo "下一步："
echo "1. 配置 .env 文件"
echo "2. 开始开发合约"
echo "3. 编写测试用例"
EOF

# 赋予执行权限
chmod +x scripts/verify-setup.sh
```

#### 8.2 运行验证

```bash
# 创建scripts目录
mkdir -p scripts

# 运行验证脚本
bash scripts/verify-setup.sh
```

### Step 9: Git配置和首次提交

由于 `forge init` 已经初始化了Git仓库，我们需要重新配置提交历史：

```bash
# 查看当前Git状态
git status
git log --oneline  # 查看forge init创建的初始提交

# 添加我们的配置文件
git add .

# 创建我们的配置提交（如果需要，可以修改之前的提交）
git commit -m "feat: initialize foundry project with openzeppelin dependencies

- Setup complete Foundry development environment
- Configure foundry.toml with optimization and testing settings
- Install OpenZeppelin contracts and forge-std dependencies  
- Create comprehensive Makefile for automation
- Setup project directory structure (contracts/ instead of src/)
- Configure environment variables and .gitignore
- Add initial project documentation

✅ Step 1.1 completed successfully"

# 如果需要推送到远程仓库
# git remote add origin <your-repository-url>
# git branch -M main  
# git push -u origin main
```

> 💡 **Git最佳实践提示**:
> - `forge init` 已经创建了基础的 `.gitignore`，但我们的版本更完整
> - 如果你想要清理的Git历史，可以删除 `.git` 目录后重新 `git init`
> - 确保 `.env` 文件不会被提交（已在.gitignore中配置）

## ✅ 验证步骤

### 1. 工具链验证

```bash
# 检查Foundry版本
forge --version
cast --version
anvil --version

# 期望输出: 版本信息正常显示
```

### 2. 项目编译验证

```bash
# 编译项目（即使没有合约文件也应该成功）
make build
# 或
forge build

# 期望输出: 编译成功，无错误
```

### 3. 依赖库验证

```bash
# 检查依赖库安装
ls lib/

# 期望看到:
# forge-std/
# openzeppelin-contracts/
# openzeppelin-contracts-upgradeable/  
# solmate/
```

### 4. 测试环境验证

```bash
# 运行空的测试套件
make test
# 或
forge test

# 期望输出: 测试运行成功（即使没有测试文件）
```

### 5. Makefile功能验证

```bash
# 测试各种make命令
make help        # 显示帮助信息
make clean       # 清理缓存
make fmt         # 格式化代码（空项目）
make tree        # 显示依赖树
```

### 6. 本地网络验证

```bash
# 在一个终端启动anvil
make anvil

# 在另一个终端测试连接
cast block-number --rpc-url http://localhost:8545

# 期望输出: 返回区块号（通常是0）
```

## 📋 输出交付物

完成 Step 1.1 后，应该包含以下文件和配置：

### ✅ 核心配置文件
- [x] `foundry.toml` - Foundry主配置文件
- [x] `remappings.txt` - 依赖库映射配置
- [x] `Makefile` - 自动化构建脚本
- [x] `.gitignore` - Git忽略文件配置
- [x] `.env.example` - 环境变量模板

### ✅ 项目文档
- [x] `README.md` - 项目主要说明文档
- [x] `DEVELOPMENT.md` - 开发实践指南
- [x] `docs/1.1.md` - 本步骤详细文档

### ✅ 目录结构
- [x] `contracts/` - 合约源码目录及子目录
- [x] `test/` - 测试文件目录及子目录  
- [x] `script/` - 部署脚本目录
- [x] `web/` - 前端文件目录及子目录
- [x] `docs/` - 文档目录及子目录
- [x] `scripts/` - 项目脚本目录

### ✅ 依赖库安装
- [x] `lib/openzeppelin-contracts/` - OpenZeppelin标准合约库
- [x] `lib/openzeppelin-contracts-upgradeable/` - 可升级合约库
- [x] `lib/solmate/` - 高效Solidity合约库
- [x] `lib/forge-std/` - Forge标准测试库

## 🚨 常见问题和解决方案

### 问题1: Foundry安装失败

**症状**: `curl -L https://foundry.paradigm.xyz | bash` 执行失败

**解决方案**:
```bash
# 方案1: 手动下载安装脚本
wget https://foundry.paradigm.xyz -O foundry-install
chmod +x foundry-install  
./foundry-install

# 方案2: 使用GitHub Release直接下载
# 访问 https://github.com/foundry-rs/foundry/releases
```

### 问题2: 依赖库安装失败

**症状**: `forge install` 命令失败或库文件不完整

**解决方案**:
```bash
# 清理并重新安装
rm -rf lib/
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install transmissions11/solmate
forge install foundry-rs/forge-std
```

### 问题3: 编译失败

**症状**: `forge build` 报错

**解决方案**:
```bash
# 检查Solidity版本兼容性
forge --version

# 清理缓存重新编译
forge clean
forge build

# 检查remappings.txt配置是否正确
```

### 问题4: 权限问题

**症状**: 脚本执行权限不足

**解决方案**:
```bash
# 赋予脚本执行权限
chmod +x scripts/*.sh
chmod +x Makefile  # 如果需要

# 或者使用bash直接执行
bash scripts/verify-setup.sh
```

## 🎯 下一步行动

完成 Step 1.1 后，开发者应该：

1. **验证环境**: 运行 `bash scripts/verify-setup.sh` 确保所有配置正确
2. **配置环境变量**: 复制 `.env.example` 到 `.env` 并填写必要配置
3. **熟悉工具**: 尝试运行各种 `make` 命令，了解项目工作流
4. **准备下一步**: 开始 Step 1.2 - ERC20代币合约开发

## 💡 最佳实践提醒

- **版本控制**: 始终使用有意义的提交信息，遵循 Conventional Commits 规范
- **环境隔离**: 不要将 `.env` 文件提交到版本控制系统
- **依赖管理**: 定期更新依赖库，但要确保兼容性
- **自动化**: 充分利用 Makefile 提供的自动化命令，提高开发效率
- **文档维护**: 随着项目发展，及时更新文档和配置

---

## 📚 参考资源

- [Foundry官方文档](https://book.getfoundry.sh/)
- [OpenZeppelin合约库](https://docs.openzeppelin.com/contracts/)
- [Solidity官方文档](https://docs.soliditylang.org/)
- [以太坊开发最佳实践](https://consensys.github.io/smart-contract-best-practices/)

---

**Git Commit**: `feat: initialize foundry project with openzeppelin dependencies`

**完成状态**: ✅ Step 1.1 - 项目初始化和Foundry配置已完成

**下一步**: [Step 1.2: ERC20代币合约开发](docs/1.2.md)