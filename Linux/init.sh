#!/bin/bash

# 限制脚本仅支持基于 Debian/Ubuntu 的系统
if ! command -v apt-get &> /dev/null; then
    echo -e "\033[31m此脚本仅支持基于 Debian/Ubuntu 的系统，请在支持 apt-get 的系统上运行！\033[0m"
    exit 1
fi

# 检测系统架构
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
    echo -e "\033[31m(￣□￣)脚本只支持 ARM 和 x86_64 架构哦~ 您的系统架构是：$ARCH\033[0m"
    exit 1
fi


# 检查并安装必要的依赖
GITPROXY="https://host.wxgwxha.eu.org"
#sudo apt-get update -y && sudo apt-get upgrade -y
REQUIRED_CMDS=("tmux" "btop" "unzip" "vnstat" "curl" "wget" "dpkg" "awk" "sed" "sysctl" "jq")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "\033[33m缺少依赖：$cmd，正在安装...\033[0m"
		sudo apt-get update && sudo apt-get install -y $cmd > /dev/null 2>&1
        #sudo apt-get install -y -q $cmd > /dev/null 2>&1
    fi
done

if [ ! -f /usr/bin/gping ]; then
	echo -e "\033[33m缺少依赖：gping，正在安装...\033[0m"
	curl -s -L $GITPROXY/https://github.com/readgovip/appdown/raw/refs/heads/main/Linux/gping.tar.gz -o /tmp/gping.tar.gz && tar -zxf /tmp/gping.tar.gz -C /tmp/ >/dev/null 2>&1 && mv /tmp/gping /usr/bin/
fi

# 设置TMUX自动启动,检查并添加tmux自动连接命令到~/.bash_profile
check_tmux() {
    local target_file=~/.bash_profile  # 目标文件路径（用户的bash配置文件）
    local tmux_cmd='tmux attach -t 0 || tmux new -s 0'  # 要检测/添加的tmux命令
	local tmux_cmdstr='if [ -z "$TMUX" ]; then
    tmux attach -t 0 || tmux new -s 0
fi'
    
	# 1. 确保目标文件存在（不存在则自动创建空文件）
    if [ ! -f "$target_file" ]; then
        touch "$target_file"
		echo "$tmux_cmdstr" >> "$target_file"
		echo -e "\033[33mbash_profile文件创建成功!\033[0m"
	else
	    # 2. 检查文件中是否已包含目标tmux命令（使用固定字符串匹配，避免正则干扰）
		if ! grep -qF "$tmux_cmd" "$target_file"; then
			echo "$tmux_cmdstr" >> "$target_file"
			echo -e "\033[33mbash_profile文件添加成功!\033[0m"
		fi
    fi
	return 0  # 函数执行成功
}

#取IP和国家代码
IP=""
COUNTRY=""
NET_ENV="GLOBAL"
get_ip_country() {
    local url="${1:-https://v4.api.ipinfo.io/lite/me?token=6e5347148935f2}"
    local ip country_code
    
    # 获取并解析 JSON 数据
    if ! ip=$(curl -s -f "$url" | jq -r '.ip'); then
        echo "错误：无法获取或解析 JSON 数据" >&2
        return 1
    fi
    
    if ! country_code=$(curl -s -f "$url" | jq -r '.country_code'); then
        echo "错误：无法获取或解析 JSON 数据" >&2
        return 1
    fi
    
    # 检查字段是否有效
    if [[ -z "$ip" || -z "$country_code" ]]; then
        echo "错误：JSON 中缺少必要字段 (ip/country_code)" >&2
        return 1
    fi
    
    # 输出结果
	result="$ip $country_code" || exit 1
	IP=$(echo "$result" | cut -d' ' -f1)
	COUNTRY=$(echo "$result" | cut -d' ' -f2)
	# 判断是否等于 "CN"
	if [ "$COUNTRY" = "CN" ]; then
		NET_ENV="LOCAL"
	fi	
	echo -e "\033[36m当前网IP：\033[0m\033[1;32m$IP\033[0m"
	echo -e "\033[36m国家代码：\033[0m\033[1;32m$COUNTRY\033[0m"
	echo -e "\033[36m网络环境：\033[0m\033[1;32m$NET_ENV\033[0m"
}

# 设置 root 密码（参数为密码，可选，默认 88033054）
set_root_password() {
    local new_password="${1:-A88033054a}"

	# 是否ROOT用户
	if [ "$(id -u)" -ne 0 ]; then
		echo "当前用户不是 ROOT"
		echo "root:${new_password}" | chpasswd
		
	fi

    # 2. 使用 chpasswd 设置 root 密码（格式：root:密码）
    echo "root:${new_password}" | chpasswd

    # 3. 检查执行结果
    if [ $? -eq 0 ]; then
        echo "✅ root 密码已成功设置为：${new_password}"
        return 0  # 返回成功状态
    else
        echo "❌ 错误：设置 root 密码失败！请检查权限或命令兼容性。" >&2
        return 1
    fi
}

# 网络连通性检测函数,判断是否国内
check_network() {
    local target="www.youtube.com"  # 测试目标
    local timeout=1                 # 超时时间(秒)
    local max_attempts=2            # 最大尝试次数
    
    # 静默执行ping测试（抑制输出）
    if ping -c $max_attempts -W $timeout "$target" &> /dev/null; then
        echo "国外网"
        return 0  # 返回成功状态
    else
        echo "国内网"
        return 1  # 返回失败状态
    fi
}

show_tipmsg() {
	# 获取系统安装日期
	install_time=$(stat -c %y /etc/hostname)
	install_date=$(echo "$install_time" | awk '{print $1}')
	deadline=$(date -d "$install_date +30 days" +"%Y-%m-%d")
	# 输出结果
	echo -e "\033[36m安装日期：\033[0m\033[1;32m$install_date\033[0m"
	echo -e "\033[36m截止日期：\033[0m\033[1;32m$deadline\033[0m"
	
	# 获取当前 BBR 状态
	CURRENT_ALGO=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
	CURRENT_QDISC=$(sysctl net.core.default_qdisc | awk '{print $3}')
	echo -e "\033[36m拥塞控制：\033[0m\033[1;32m$CURRENT_ALGO\033[0m"
	echo -e "\033[36m队列管理：\033[0m\033[1;32m$CURRENT_QDISC\033[0m"
	get_ip_country
}

# sysctl 配置文件路径
SYSCTL_CONF="/etc/sysctl.d/99-joeyblog.conf"

# 函数：清理 sysctl.d 中的旧配置
clean_sysctl_conf() {
    sudo touch "$SYSCTL_CONF"
    sudo sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
    sudo sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
}

# 函数：询问是否永久保存更改
ask_to_save() {
    clean_sysctl_conf
    echo "net.core.default_qdisc=$QDISC" | sudo tee -a "$SYSCTL_CONF" > /dev/null
    echo "net.ipv4.tcp_congestion_control=$ALGO" | sudo tee -a "$SYSCTL_CONF" > /dev/null
    sudo sysctl --system > /dev/null 2>&1
    echo -e "\033[1;32m(☆^ー^☆) 更改已永久保存啦~\033[0m"
}

# 函数：获取已安装的 joeyblog 内核版本
get_installed_version() {
    dpkg -l | grep "linux-image" | grep "joeyblog" | awk '{print $2}' | sed 's/linux-image-//' | head -n 1
}

# 函数：智能更新引导加载程序
update_bootloader() {
    echo -e "\033[36m正在更新引导加载程序...\033[0m"
    if command -v update-grub &> /dev/null; then
        echo -e "\033[33m检测到 GRUB，正在执行 update-grub...\033[0m"
        if sudo update-grub; then
            echo -e "\033[1;32mGRUB 更新成功！\033[0m"
            return 0
        else
            echo -e "\033[1;31mGRUB 更新失败！\033[0m"
            return 1
        fi
    else
        echo -e "\033[33m未找到 'update-grub'。您的系统可能使用 U-Boot 或其他引导程序。\033[0m"
        echo -e "\033[33m在许多 ARM 系统上，内核安装包会自动处理引导更新，通常无需手动操作。\033[0m"
        echo -e "\033[33m如果重启后新内核未生效，您可能需要手动更新引导配置，请参考您系统的文档。\033[0m"
        return 0
    fi
}

# 函数：安全地安装下载的包
install_packages() {
    if ! ls /tmp/linux-*.deb &> /dev/null; then
        echo -e "\033[31m错误：未在 /tmp 目录下找到内核文件，安装中止。\033[0m"
        return 1
    fi
    
    echo -e "\033[36m开始卸载旧版内核... \033[0m"
    INSTALLED_PACKAGES=$(dpkg -l | grep "joeyblog" | awk '{print $2}' | tr '\n' ' ')
    if [[ -n "$INSTALLED_PACKAGES" ]]; then
        sudo apt-get remove --purge $INSTALLED_PACKAGES -y > /dev/null 2>&1
    fi

    echo -e "\033[36m开始安装新内核... \033[0m"
    if sudo dpkg -i /tmp/linux-*.deb && update_bootloader; then
        echo -e "\033[1;32m内核安装并配置完成！\033[0m"
        echo -n -e "\033[33m需要重启系统来加载新内核。是否立即重启？ (y/n): \033[0m"
        read -r REBOOT_NOW
        if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
            echo -e "\033[36m系统即将重启...\033[0m"
            sudo reboot
        else
            echo -e "\033[33m操作完成。请记得稍后手动重启 ('sudo reboot') 来应用新内核。\033[0m"
        fi
    else
        echo -e "\033[1;31m内核安装或引导更新失败！系统可能处于不稳定状态。请不要重启并寻求手动修复！\033[0m"
    fi
}

# 函数：检查并安装最新版本
install_latest_version() {
    echo -e "\033[36m正在从 GitHub 获取最新版本信息...\033[0m"
    BASE_URL="https://host.wxgwxha.eu.org/https://api.github.com/repos/byJoey/Actions-bbr-v3/releases"
    RELEASE_DATA=$(curl -sL "$BASE_URL")
    if [[ -z "$RELEASE_DATA" ]]; then
        echo -e "\033[31m从 GitHub 获取版本信息失败。请检查网络连接或 API 状态。\033[0m"
        return 1
    fi

    local ARCH_FILTER=""
    [[ "$ARCH" == "aarch64" ]] && ARCH_FILTER="arm64"
    [[ "$ARCH" == "x86_64" ]] && ARCH_FILTER="x86_64"

    LATEST_TAG_NAME=$(echo "$RELEASE_DATA" | jq -r --arg filter "$ARCH_FILTER" 'map(select(.tag_name | test($filter; "i"))) | sort_by(.published_at) | .[-1].tag_name')

    if [[ -z "$LATEST_TAG_NAME" || "$LATEST_TAG_NAME" == "null" ]]; then
        echo -e "\033[31m未找到适合当前架构 ($ARCH) 的最新版本。\033[0m"
        return 1
    fi
    echo -e "\033[36m检测到最新版本：\033[0m\033[1;32m$LATEST_TAG_NAME\033[0m"

    INSTALLED_VERSION=$(get_installed_version)
    echo -e "\033[36m当前已安装版本：\033[0m\033[1;32m${INSTALLED_VERSION:-"未安装"}\033[0m"

    CORE_LATEST_VERSION="${LATEST_TAG_NAME#x86_64-}"
    CORE_LATEST_VERSION="${CORE_LATEST_VERSION#arm64-}"

    if [[ -n "$INSTALLED_VERSION" && "$INSTALLED_VERSION" == "$CORE_LATEST_VERSION"* ]]; then
        # 修复了此处的颜文字，将反引号 ` 替换为单引号 '
        echo -e "\033[1;32m(o'▽'o) 您已安装最新版本，无需更新！\033[0m"
        return 0
    fi

    echo -e "\033[33m发现新版本或未安装内核，准备下载...\033[0m"
    ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r --arg tag "$LATEST_TAG_NAME" '.[] | select(.tag_name == $tag) | .assets[].browser_download_url')
    
    rm -f /tmp/linux-*.deb

    for URL in $ASSET_URLS; do
        echo -e "\033[36m正在下载文件：$URL\033[0m"
        wget -q --show-progress "https://host.wxgwxha.eu.org/$URL" -P /tmp/ || { echo -e "\033[31m下载失败：$URL\033[0m"; return 1; }
    done
    
    install_packages
}

# 函数：安装指定版本
install_specific_version() {
    BASE_URL="https://host.wxgwxha.eu.org/https://api.github.com/repos/byJoey/Actions-bbr-v3/releases"
    RELEASE_DATA=$(curl -s "$BASE_URL")
    if [[ -z "$RELEASE_DATA" ]]; then
        echo -e "\033[31m从 GitHub 获取版本信息失败。请检查网络连接或 API 状态。\033[0m"
        return 1
    fi

    local ARCH_FILTER=""
    [[ "$ARCH" == "aarch64" ]] && ARCH_FILTER="arm64"
    [[ "$ARCH" == "x86_64" ]] && ARCH_FILTER="x86_64"
    
    MATCH_TAGS=$(echo "$RELEASE_DATA" | jq -r --arg filter "$ARCH_FILTER" '.[] | select(.tag_name | test($filter; "i")) | .tag_name')

    if [[ -z "$MATCH_TAGS" ]]; then
        echo -e "\033[31m未找到适合当前架构的版本。\033[0m"
        return 1
    fi

    echo -e "\033[36m以下为适用于当前架构的版本：\033[0m"
    IFS=$'\n' read -rd '' -a TAG_ARRAY <<<"$MATCH_TAGS"

    for i in "${!TAG_ARRAY[@]}"; do
        echo -e "\033[33m $((i+1)). ${TAG_ARRAY[$i]}\033[0m"
    done

    echo -n -e "\033[36m请输入要安装的版本编号（例如 1）：\033[0m"
    read -r CHOICE
    
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#TAG_ARRAY[@]} )); then
        echo -e "\033[31m输入无效编号，取消操作。\033[0m"
        return 1
    fi
    
    INDEX=$((CHOICE-1))
    SELECTED_TAG="${TAG_ARRAY[$INDEX]}"
    echo -e "\033[36m已选择版本：\033[0m\033[1;32m$SELECTED_TAG\033[0m"

    ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r --arg tag "$SELECTED_TAG" '.[] | select(.tag_name == $tag) | .assets[].browser_download_url')
    
    rm -f /tmp/linux-*.deb
    
    for URL in $ASSET_URLS; do
        echo -e "\033[36m下载中：$URL\033[0m"
        wget -q --show-progress "$URL" -P /tmp/ || { echo -e "\033[31m下载失败：$URL\033[0m"; return 1; }
    done

    install_packages
}

check_tmux
show_tipmsg

