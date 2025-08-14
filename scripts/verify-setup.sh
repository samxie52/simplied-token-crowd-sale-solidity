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
