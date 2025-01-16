#!/bin/bash

# 检查参数数量
if [ "$#" -ne 3 ]; then
    echo "用法: $0 Add LocalPort RemoteIp:RemotePort"
    exit 1
fi

# 获取参数
Action=$(echo "$1" | tr '[:upper:]' '[:lower:]')  # 将输入转换为小写

case "$Action" in
	"add")
		# 判断参数有1个
		if [[ "$#" -le 1 ]]; then
			echo "用法: $0 Add RemoteIp:RemotePort [LocalPort]"
			exit 1
		# 判断参数有2个
		elif [[ "$#" -le 2 ]]; then
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
		check_port_forwarding $LocalPort
		;;

   "del")
		# 判断参数有1个
		if [[ "$#" -le 1 ]]; then
			echo "用法: $0 Del RemoteIp:RemotePort [LocalPort]"
			exit 1
		# 判断参数有2个
		elif [[ "$#" -le 2 ]]; then
		
		# 判断参数有3个
		else
		
		fi
		;;
   
   "info")
		echo "淘宝网"
		;;
esac





# 检测端口转发规则的函数
check_port_forwarding() {
    local port=$1

    if [[ -z "$port" ]]; then
        echo "请提供端口号作为参数。"
        return 1
    fi

    # 使用iptables命令检查NAT表中的PREROUTING链
    if iptables -t nat -L PREROUTING -n | grep -q "dpt:$port"; then
        echo "端口 $port 已设置转发规则。"
		exit 1
    fi
}



# 根据操作选择添加或删除规则
if [[ "$Action" == "add" ]]; then
    # 添加iptables规则
    iptables -t nat -I PREROUTING -p tcp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
    iptables -t nat -I POSTROUTING -p tcp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE
    iptables -t nat -I PREROUTING -p udp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
    iptables -t nat -I POSTROUTING -p udp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE	
    echo "已添加端口转发: 从本地端口 $LocalPort 到 $RemoteIp:$RemotePort"
elif [[ "$Action" == "del" ]]; then
    # 删除iptables规则
    iptables -t nat -D PREROUTING -p tcp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
    iptables -t nat -D POSTROUTING -p tcp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE
    iptables -t nat -D PREROUTING -p udp --dport "$LocalPort" -j DNAT --to "$RemoteIp":"$RemotePort"
    iptables -t nat -D POSTROUTING -p udp -d "$RemoteIp" --dport "$RemotePort" -j MASQUERADE	
    echo "已删除端口转发: 从本地端口 $LocalPort 到 $RemoteIp:$RemotePort"
else
    echo "无效操作: $1。请使用 'Add' 或 'Del'。"
    exit 1
fi