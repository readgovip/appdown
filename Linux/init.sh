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
apt update && apt install -y sudo > /dev/null 2>&1
REQUIRED_CMDS=("curl" "tmux" "btop" "unzip" "vnstat" "wget" "dpkg" "awk" "sed" "sysctl" "jq")
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

#安装X-cmd
eval "$(curl https://get.x-cmd.com)"

#设置北京时区
sudo timedatectl set-timezone Asia/Shanghai

# 设置TMUX自动启动,检查并添加tmux自动连接命令到~/.bash_profile
check_tmux() {
    local target_file=~/.bash_profile
    local tmux_cmd='tmux attach -t 0 || tmux new -s 0'
    local tmux_cmdstr='if [ -z "$TMUX" ]; then
    tmux attach -t 0 || tmux new -s 0
fi'

    # 确保目标文件存在
    if [ ! -f "$target_file" ]; then
        touch "$target_file"
        # 先写入加载 .bashrc 的行
        echo '[ -f ~/.bashrc ] && source ~/.bashrc' > "$target_file"
        echo "$tmux_cmdstr" >> "$target_file"
        echo -e "\033[33mbash_profile 创建并配置成功（已加入加载 .bashrc）\033[0m"
    else
        # 检查是否已存在加载 .bashrc 的行
        if ! grep -q 'source ~/.bashrc' "$target_file" && ! grep -q '\. ~/.bashrc' "$target_file"; then
            # 在文件开头插入一行
            sed -i '1i [ -f ~/.bashrc ] && source ~/.bashrc' "$target_file"
            echo -e "\033[33m已向 bash_profile 添加加载 .bashrc\033[0m"
        fi
        # 检查是否已包含 tmux 命令
        if ! grep -qF "$tmux_cmd" "$target_file"; then
            echo "$tmux_cmdstr" >> "$target_file"
            echo -e "\033[33m已向 bash_profile 添加 tmux 自动启动\033[0m"
        fi
    fi
    return 0
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

check_tmux
show_tipmsg
eval "$(curl https://raw.githubusercontent.com/readgovip/appdown/refs/heads/main/Linux/bbr/bbr.sh)"
