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
SOLC_VERSION := 0.8.28

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
