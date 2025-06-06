#!/bin/bash


# 检测端口转发规则的函数
check_port_forwarding() {
    local port=$1

    if [[ -z "$port" ]]; then
        echo "请设置端口号。"
        return 1
    fi

    # 使用iptables命令检查NAT表中的PREROUTING链
    if iptables -t nat -L PREROUTING -n | grep -q "dpt:$port"; then
        echo "端口 $port 已设置转发规则。"
		exit 1
    fi
}

# 设置端口转发
turnOnNat(){
    # 开启端口转发
    sed -n '/^net.ipv4.ip_forward=1/'p /etc/sysctl.conf | grep -q "net.ipv4.ip_forward=1"
    if [ $? -ne 0 ]; then
        echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
		echo "端口转发开启成功。"
    fi
}

# 获取本机IP
getHostIp(){
	localIP=$(ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1 | grep -Ev '(^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.1[6-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.2[0-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.3[0-1]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$)')
	if [ "${localIP}" = "" ]; then
			localIP=$(ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1|head -n 1 )
	fi
	echo  "本机网卡IP [$localIP]"
}

# 获取参数
Action=$(echo "$1" | tr '[:upper:]' '[:lower:]')  # 将输入转换为小写
case "$Action" in
	"add" )
		# 判断参数有1个
		if [ $# = 1 ]; then
			echo "用法: $0 Add RemoteIp:RemotePort [LocalPort]"
			exit 1
		# 判断参数有2个
		elif [ $# = 2 ]; then
			# 提取RemoteIp和RemotePort
			RemoteIp_Port=$2
			RemoteIp=$(echo $RemoteIp_Port | cut -d ':' -f 1)
			RemotePort=$(echo $RemoteIp_Port | cut -d ':' -f 2)
			LocalPort=$RemotePort
		# 判断参数有3个
		else
			# 提取RemoteIp和RemotePort
			RemoteIp_Port=$2
			RemoteIp=$(echo $RemoteIp_Port | cut -d ':' -f 1)
			RemotePort=$(echo $RemoteIp_Port | cut -d ':' -f 2)
			LocalPort=$3
		fi
		# 检测端口是否存在
		check_port_forwarding $LocalPort
	    # 添加iptables规则
		iptables -t nat -I PREROUTING -p tcp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
		iptables -t nat -I POSTROUTING -p tcp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE
		iptables -t nat -I PREROUTING -p udp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
		iptables -t nat -I POSTROUTING -p udp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE
		echo "已添加端口转发: 从本地端口 $LocalPort 到 $RemoteIp:$RemotePort"
		;;
   "del" )
		# 判断参数有1个
		if [ $# = 1 ]; then
			echo "用法: $0 Del RemoteIp:RemotePort [LocalPort]"
			exit 1
		# 判断参数有2个
		elif [ $# = 2 ]; then
			# 提取RemoteIp和RemotePort
			RemoteIp_Port=$2
			RemoteIp=$(echo $RemoteIp_Port | cut -d ':' -f 1)
			RemotePort=$(echo $RemoteIp_Port | cut -d ':' -f 2)
			LocalPort=$RemotePort
		# 判断参数有3个
		else
			# 提取RemoteIp和RemotePort
			RemoteIp_Port=$2
			RemoteIp=$(echo $RemoteIp_Port | cut -d ':' -f 1)
			RemotePort=$(echo $RemoteIp_Port | cut -d ':' -f 2)
			LocalPort=$3
		fi
		# 删除iptables规则
		iptables -t nat -D PREROUTING -p tcp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
		iptables -t nat -D POSTROUTING -p tcp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE
		iptables -t nat -D PREROUTING -p udp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
		iptables -t nat -D POSTROUTING -p udp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE
		echo "已删除端口转发: 从本地端口 $LocalPort 到 $RemoteIp:$RemotePort"
		;;
   "info" )
		echo "##############################当前iptables配置##############################"
		iptables -L PREROUTING -n -t nat --line-number
		iptables -L POSTROUTING -n -t nat --line-number
		;;
   "open" )
		echo "##############################启动iptables端口转发##########################"
		turnOnNat
		;;
esac
