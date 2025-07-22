#!/bin/bash

echo "=============================="
echo "Git 初始化 + 提交 + 推送脚本"
echo "=============================="

# 设置 Git 用户邮箱（你可以按需修改或取消这个步骤）
echo
echo "🔧 配置 Git 用户邮箱为 2508551589@qq.com"
git config --global user.email "2508551589@qq.com"
read -p "✅ 按 Enter 继续..."

# 初始化 Git 仓库
echo
echo "🔧 初始化 Git 仓库 (git init)"
git init
read -p "✅ 按 Enter 继续..."

# 添加所有文件
echo
echo "📦 添加所有文件到暂存区 (git add ./)"
git add ./
read -p "✅ 按 Enter 继续..."

# 输入 commit 描述
echo
read -p "📝 请输入本次提交的描述: " commit_msg
git commit -m "$commit_msg"
read -p "✅ 按 Enter 继续..."

# 设置远程仓库信息
echo
read -p "🌐 请输入远程仓库地址（如 git@github.com:xxx/xxx.git 或 https://...）: " remote_url
read -p "🔖 请输入远程仓库的别名（例如 origin 或 FASTLIO2_ROS2）: " remote_name

# 添加远程仓库（若已存在则跳过）
if git remote get-url "$remote_name" &> /dev/null; then
    echo "⚠️ 已存在远程名 $remote_name，将更新其 URL..."
    git remote set-url "$remote_name" "$remote_url"
else
    echo "🔗 添加远程仓库 $remote_name"
    git remote add "$remote_name" "$remote_url"
fi
read -p "✅ 按 Enter 继续..."

# 推送到 master 分支
echo
echo "🚀 正在推送到远程仓库 ($remote_name master)..."
git push "$remote_name" master
read -p "✅ 上传完成后按 Enter 退出..."

echo
echo "✅ 所有操作已完成！"

