#!/bin/bash

echo "=============================="
echo "Git 初始化 + 提交 + 推送脚本"
echo "=============================="

# 函数：验证输入是否为空
validate_input() {
    local prompt="$1"
    local error_msg="$2"
    local allow_empty="${3:-0}" # 默认不允许空输入
    local input_value
    
    while true; do
        read -p "$prompt" input_value
        
        if [[ -z "$input_value" && $allow_empty -eq 0 ]]; then
            echo "❌ $error_msg"
        else
            break
        fi
    done
    
    echo "$input_value"
}

# 设置 Git 用户邮箱
echo
echo "🔧 配置 Git 用户邮箱为 xxxxxxx@qq.com"
git config --global user.email "xxxxxxx@qq.com"
read -p "✅ 按 Enter 继续..."

# 初始化 Git 仓库
echo
echo "🔧 初始化 Git 仓库 (git init)"
git init
read -p "✅ 按 Enter 继续..."

# 添加所有文件 - 改进检测逻辑
echo
echo "📦 添加所有文件到暂存区 (git add ./)"
git add ./git/

# 改进的文件变更检测逻辑
echo "🔍 检查文件变更..."
if git diff --cached --quiet && git diff --quiet; then
    echo "⚠️ 没有检测到文件变更，跳过提交步骤"
    skip_commit=true
else
    echo "✅ 检测到文件变更"
    skip_commit=false
    read -p "✅ 按 Enter 继续..."
fi

# 输入 commit 描述 - 加强验证
if [ "$skip_commit" = false ]; then
    echo
    commit_msg=$(validate_input "📝 请输入本次提交的描述: " "提交描述不能为空")
    git commit -m "$commit_msg"
    read -p "✅ 按 Enter 继续..."
fi

# 分支管理
echo
echo "🌿 分支管理"
current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ -z "$current_branch" ]; then
    echo "ℹ️ 当前没有创建任何分支"
    branch_default="master"
    echo "🟢 默认分支名: $branch_default (直接回车将使用此默认值)"
else
    echo "ℹ️ 当前分支: $current_branch"
    branch_default=$current_branch
fi

branch_name=$(validate_input "📌 请输入目标分支名称 (默认: $branch_default): " "分支名称不能为空" 1)
if [[ -z "$branch_name" ]]; then
    branch_name=$branch_default
fi

# 检查分支名称合法性
while [[ ! "$branch_name" =~ ^[a-zA-Z0-9_./-]+$ ]]; do
    echo "❌ 分支名称包含非法字符，仅允许字母/数字/下划线/点/斜线/连字符"
    branch_name=$(validate_input "📌 请重新输入分支名称: " "分支名称不能为空")
done

# 检查分支是否存在
if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
    echo "🆕 创建新分支: $branch_name"
    
    # 获取当前提交的哈希值
    current_commit=$(git rev-parse HEAD)
    if [ -z "$current_commit" ]; then
        echo "❌ 无法获取当前提交的哈希值"
        exit 1
    fi
    
    # 直接基于提交创建分支，避免引用歧义
    git branch "$branch_name" "$current_commit"
    
    # 验证分支是否创建成功
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        echo "❌ 分支创建失败，请检查错误信息"
        exit 1
    fi
fi

# 切换到目标分支 - 修复分离头指针问题
if [ -n "$current_branch" ] && [ "$current_branch" != "$branch_name" ]; then
    echo "↪️ 切换到分支 $branch_name"
    
    # 修复：使用分支名而不是引用路径
    git checkout "$branch_name"
    
    # 验证是否切换成功
    new_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ "$new_branch" != "$branch_name" ]; then
        echo "❌ 切换分支失败，当前分支为: $new_branch"
        exit 1
    fi
elif [ -z "$current_branch" ]; then
    # 处理初始提交后没有分支的情况
    echo "↪️ 切换到分支 $branch_name"
    git checkout -b "$branch_name"
    
    # 验证是否切换成功
    new_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ "$new_branch" != "$branch_name" ]; then
        echo "❌ 切换分支失败，当前分支为: $new_branch"
        exit 1
    fi
fi
read -p "✅ 按 Enter 继续..."

# 设置远程仓库信息 - 加强验证
echo
while true; do
    remote_url=$(validate_input "🌐 请输入远程仓库地址 (如 git@github.com:xxx/xxx.git 或 https://...): " "仓库地址不能为空")
    
    # 验证仓库地址格式
    if [[ ! "$remote_url" =~ (git@.+:.*|https?://.+\.git)$ ]]; then
        echo "❌ 远程仓库地址格式不正确，需为 git@... 或 https://... 格式"
        continue
    fi
    
    # 测试远程仓库连接
    echo "🔍 测试远程仓库连接..."
    if git ls-remote "$remote_url" --quiet 2>/dev/null; then
        echo "✅ 远程仓库连接成功"
        break
    else
        echo "❌ 无法连接到远程仓库，请检查地址或网络连接"
        read -p "是否继续使用此地址? [y/N] " continue_with_address
        if [[ "$continue_with_address" =~ ^[Yy]$ ]]; then
            break
        fi
    fi
done

remote_name=$(validate_input "🔖 请输入远程仓库的别名 (例如 origin ): " "别名不能为空")

# 令牌管理 - 增强版 (全局化和选项化)
echo
echo "🔑 令牌管理选项"
token=""
if [ -f ~/.git_token ]; then
    source ~/.git_token
    echo "已加载全局令牌配置 (来自 ~/.git_token)"
fi

if [ -n "$GIT_GLOBAL_TOKEN" ]; then
    read -p "是否使用全局令牌 $GIT_GLOBAL_TOKEN? [Y/n] " use_global_token
    if [[ ! "$use_global_token" =~ ^[Nn]$ ]]; then
        token=$GIT_GLOBAL_TOKEN
        echo "🛡️ 使用全局令牌"
    fi
fi

if [ -z "$token" ]; then
    echo "请选择令牌处理方式:"
    echo "1) 从列表选择现有令牌"
    echo "2) 输入新令牌"
    echo "3) 跳过令牌"
    read -p "请输入选项 [1-3]: " token_option
    
    case "$token_option" in
        1)
            # 列出可用的令牌配置文件
            token_files=()
            while IFS= read -r -d $'\0' file; do
                token_files+=("$file")
            done < <(find ~ -maxdepth 1 -name ".git_token*" -print0 2>/dev/null)
            
            if [ ${#token_files[@]} -eq 0 ]; then
                echo "❌ 没有找到令牌配置文件"
            else
                echo "可用的令牌配置:"
                for i in "${!token_files[@]}"; do
                    printf "%d) %s\n" "$((i+1))" "${token_files[$i]}"
                done
                
                while true; do
                    read -p "请选择配置文件编号: " token_file_num
                    
                    # 验证输入是否为整数
                    if [[ "$token_file_num" =~ ^[0-9]+$ ]]; then
                        # 转换为数组索引
                        token_file_index=$((token_file_num-1))
                        
                        # 验证索引是否在范围内
                        if [ "$token_file_index" -ge 0 ] && [ "$token_file_index" -lt "${#token_files[@]}" ]; then
                            token_file="${token_files[$token_file_index]}"
                            
                            # 检查文件是否存在
                            if [ -f "$token_file" ]; then
                                # 安全地加载令牌文件
                                if source "$token_file" 2>/dev/null; then
                                    token=$GIT_GLOBAL_TOKEN
                                    echo "✅ 已加载令牌"
                                    break
                                else
                                    echo "❌ 加载令牌失败: $token_file"
                                    read -p "是否继续选择? [y/N] " continue_choice
                                    [[ "$continue_choice" =~ ^[Yy]$ ]] || break
                                fi
                            else
                                echo "❌ 文件不存在: $token_file"
                                read -p "是否继续选择? [y/N] " continue_choice
                                [[ "$continue_choice" =~ ^[Yy]$ ]] || break
                            fi
                        else
                            echo "❌ 无效的编号，请输入 1 到 ${#token_files[@]} 之间的数字"
                        fi
                    else
                        echo "❌ 请输入有效的数字编号"
                    fi
                done
            fi
            ;;
        2)
            token=$(validate_input "🔐 请输入访问令牌: " "令牌不能为空")
            
            # 询问是否保存为全局配置
            read -p "是否保存此令牌为全局配置? [y/N] " save_token
            if [[ "$save_token" =~ ^[Yy]$ ]]; then
                token_file_name=$(validate_input "请输入配置文件名称 [默认: .git_token]: " "文件名不能为空" 1)
                token_file_name=${token_file_name:-".git_token"}
                echo "GIT_GLOBAL_TOKEN=\"$token\"" > "${HOME}/${token_file_name}"
                echo "✅ 令牌已保存到 ${HOME}/${token_file_name}"
                
                # 添加文件权限保护
                chmod 600 "${HOME}/${token_file_name}"
                echo "🔒 已设置文件权限 (仅当前用户可读写)"
            fi
            ;;
        3)
            echo "跳过令牌配置"
            ;;
        *)
            echo "❌ 无效选项，跳过令牌配置"
            ;;
    esac
fi

if [ -n "$token" ]; then
    # 处理不同协议的令牌插入
    if [[ $remote_url == https://* ]]; then
        # HTTPS协议: https://token@host.com/...
        updated_url="${remote_url/https:\/\//https:\/\/$token@}"
        
        # 安全处理，避免重复添加
        if [[ "$updated_url" != "$remote_url" ]]; then
            remote_url="$updated_url"
            # 安全显示地址（隐藏令牌）
            safe_url=$(echo "$remote_url" | sed -E 's/(https?:\/\/)[^@]+@/\1***@/')
            echo "🛡️ 已更新带令牌的远程地址: $safe_url"
        fi
    elif [[ $remote_url == git@* ]]; then
        # SSH协议: git@host.com -> https://token@host.com
        remote_url=$(echo "$remote_url" | sed -E 's/git@([^:]+):(.*)/https:\/\/'"$token"'@\1\/\2/')
        # 安全显示地址（隐藏令牌）
        safe_url=$(echo "$remote_url" | sed -E 's/(https?:\/\/)[^@]+@/\1***@/')
        echo "🛡️ 已更新带令牌的远程地址: $safe_url"
    else
        # 处理其他协议
        echo "⚠️ 不支持的协议类型，将跳过令牌处理"
    fi
fi

# 添加远程仓库
if git remote get-url "$remote_name" &> /dev/null; then
    echo "🔄 更新远程仓库 $remote_name 的 URL"
    git remote set-url "$remote_name" "$remote_url"
else
    echo "🔗 添加远程仓库 $remote_name"
    git remote add "$remote_name" "$remote_url"
fi
read -p "✅ 按 Enter 继续..."

# 推送到远程分支
echo
echo "🚀 正在推送到远程仓库 ($remote_name $branch_name)..."
if git push "$remote_name" "refs/heads/$branch_name"; then
    echo "✅ 推送成功！"
else
    echo "❌ 推送失败，请检查错误信息"
    exit 1
fi
read -p "✅ 上传完成后按 Enter 继续..."

# 标签管理 - 优化警告及时性和验证逻辑
echo
read -p "🏷️ 是否要创建标签? [y/N] " need_tag
if [[ $need_tag =~ ^[Yy]$ ]]; then
    while true; do
        tag_name=$(validate_input "📌 请输入标签名称 (例如 v1.0.0): " "标签名称不能为空")
        
        # 仅验证标签是否为合法标识符（字母、数字、连字符、下划线、点号）
        if [[ ! "$tag_name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            echo "❌ 标签名称包含非法字符，仅允许字母/数字/下划线/点/连字符"
            continue
        fi
        
        # 检查标签是否与分支同名
        if git show-ref --verify --quiet refs/heads/"$tag_name"; then
            echo "❌ 标签名称 '$tag_name' 与分支名称冲突"
            read -p "是否继续使用此名称? [y/N] " continue_with_name
            if [[ ! "$continue_with_name" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        # 检查标签是否已存在
        if git tag --list | grep -q "^${tag_name}$"; then
            echo "❌ 标签 '$tag_name' 已存在"
            read -p "是否覆盖已存在的标签? [y/N] " overwrite_tag
            if [[ "$overwrite_tag" =~ ^[Yy]$ ]]; then
                # 删除现有标签
                git tag -d "$tag_name" >/dev/null 2>&1
                echo "♻️ 已删除现有标签 '$tag_name'"
                break
            else
                continue
            fi
        else
            break
        fi
    done
    
    tag_msg=$(validate_input "📝 请输入标签描述 (可选，直接回车跳过): " "" 1)
    
    # 创建标签
    if [ -z "$tag_msg" ]; then
        git tag "$tag_name"
    else
        git tag -a "$tag_name" -m "$tag_msg"
    fi
    
    echo "🚀 推送标签到远程仓库..."
    # 使用完整引用路径避免冲突
    if git push "$remote_name" "refs/tags/$tag_name"; then
        echo "✅ 标签推送成功！"
    else
        echo "❌ 标签推送失败"
    fi
fi

echo
echo "✅ 所有操作已完成！"
