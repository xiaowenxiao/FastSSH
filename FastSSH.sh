#!/bin/bash

# 配置文件路径
CONFIG_FILE=".FastSSH.conf"

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}错误：配置文件 $CONFIG_FILE 不存在${NC}"
    exit 1
fi

# 检查是否安装了 expect
if ! command -v expect &>/dev/null; then
    echo -e "${RED}错误：未安装 expect，请先安装：${NC}"
    echo -e "${YELLOW}Ubuntu/Debian:${NC} sudo apt-get install expect"
    echo -e "${YELLOW}CentOS/RHEL:${NC} sudo yum install expect"
    exit 1
fi

# 显示服务器列表
show_servers() {
    clear
    echo
    echo -e "${BLUE}🌎 SSH Server List ${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
#    echo

    # 使用计数器来跟踪行号
    local counter=1
    
    # 处理每种类型的服务器
    for type in "dev" "test" "prod" "other"; do
        local title=""
        local icon=""
        
        # 设置标题和图标
        case $type in
            "dev")
                title="Development Servers"
                icon="🛠️"
                ;;
            "test")
                title="Test Servers"
                icon="🧪"
                ;;
            "prod")
                title="Production Servers"
                icon="🚀"
                ;;
            "other")
                title="Other Servers"
                icon="💻"
                ;;
        esac
        
        local first_in_group=true
        
        while IFS='|' read -r name ip port user pass note || [ -n "$name" ]; do
            # 跳过注释行
            [[ $name == \#* ]] && continue
            
            # 确定服务器类型
            local server_type="other"
            [[ $name == *"dev"* ]] && server_type="dev"
            [[ $name == *"test"* ]] && server_type="test"
            [[ $name == *"prod"* ]] && server_type="prod"
            
            # 如果不是当前处理的类型，跳过
            [[ $server_type != $type ]] && continue
            
            # 显示分组标题
            if [ "$first_in_group" = true ]; then
                echo -e "\n ${BOLD}${icon} ${title}${NC}"
                echo -e " ${GRAY}────────────────────────────────────────────${NC}"
                first_in_group=false
            fi

            # 格式化编号（去掉空格）
            local id
            if [ $counter -lt 10 ]; then
                id="[${counter}]"
            else
                id="[${counter}]"
            fi

            # 格式化显示
            printf " ${CYAN}%-4s${NC} %-16s ${YELLOW}%-22s${NC} ${PURPLE}%-8s${NC} ${GREEN}%s${NC}\n" \
                   "$id" \
                   "$name" \
                   "$ip:$port" \
                   "$user" \
                   "$note"

            ((counter++))
        done <"$CONFIG_FILE"
    done

    echo
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 连接到服务器
connect_server() {
    local server_num=$1
    
    # 使用 awk 根据行号获取服务器信息
    local server_info=$(awk -v num="$server_num" '
        BEGIN { count=0 }
        !/^#/ { 
            count++
            if (count == num) { 
                print $0
                exit
            }
        }' "$CONFIG_FILE")

    if [ -z "$server_info" ]; then
        echo -e "${RED}❌ Error: Server #$server_num not found${NC}"
        sleep 2
        return 1  # 返回错误而不是退出
    fi

    # 解析服务器信息
    IFS='|' read -r name ip port user pass note <<<"$server_info"

    echo -e "${GREEN}🔄 Connecting to ${BOLD}$name${NC} ${GREEN}($ip)...${NC}"

    # 首先尝试使用 SSH 密钥直接连接
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$user@$ip" exit 2>/dev/null; then
        # 如果密钥验证成功，直接使用 ssh 命令
        ssh -p "$port" "$user@$ip"
        exit 0  # 成功连接后退出
    fi

    # 导出变量供 expect 使用
    export SSH_USER="$user"
    export SSH_HOST="$ip"
    export SSH_PORT="$port"
    export SSH_PASS="$pass"

    # 如果密钥验证失败，则使用密码登录
    temp_expect=$(mktemp)
    cat >"$temp_expect" <<'EOF'
#!/usr/bin/expect -f

# 从环境变量获取信息
set user $env(SSH_USER)
set host $env(SSH_HOST)
set port $env(SSH_PORT)
set pass $env(SSH_PASS)

# 完全禁用输出
log_user 0
set timeout 30

# 启动 SSH
spawn ssh -o PreferredAuthentications=password -p $port $user@$host

# 处理所有可能的提示
expect {
    "yes/no" {
        send "yes\r"
        exp_continue
    }
    "password:" {
        send "$pass\r"
        # 等待登录完成
        expect {
            "Permission denied" {
                send_user "❌ Error: Invalid password\n"
                exit 1
            }
            -re "(\$|#|>)" {
                log_user 1
                interact
            }
            timeout {
                send_user "❌ Error: Connection timeout\n"
                exit 1
            }
        }
    }
    timeout {
        send_user "❌ Error: Connection timeout\n"
        exit 1
    }
}
EOF

    # 执行 expect 脚本
    chmod +x "$temp_expect"
    "$temp_expect"
    
    # 清理
    rm -f "$temp_expect"
    unset SSH_USER SSH_HOST SSH_PORT SSH_PASS

    # 直接退出脚本
    exit 0
}

# 主程序
while true; do
    show_servers
    echo
    echo -e "${YELLOW}📝 Commands:${NC}"
    echo -e "  ${GRAY}• Enter server number to connect${NC}"
    echo -e "  ${GRAY}• Press 'q' to quit${NC}"
    echo
    read -p $'\033[1;32m👉 Enter your choice: \033[0m' choice

    case $choice in
        [Qq])
            echo -e "${GREEN}👋 Thanks for using! Goodbye!${NC}"
            exit 0
            ;;
        [0-9]*)
            connect_server "$choice" || continue  # 如果连接失败就继续循环
            ;;
        *)
            echo -e "${RED}❌ Invalid input! Please try again.${NC}"
            sleep 2
            continue
            ;;
    esac
done
