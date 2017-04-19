#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================
#       System Required: CentOS/Debian/Ubuntu
#       Description: iptables 封禁 BT、PT、SPAM（垃圾邮件）和自定义端口、关键词
#       Version: 1.0.0
#       Blog: https://doub.io/shell-jc2/
#=================================================

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"

smtp_port="25,26,465,587"
pop3_port="109,110,995"
imap_port="143,218,220,993"
other_port="24,50,57,105,106,158,209,1109,24554,60177,60179"
key_word="torrent
.torrent
peer_id=
announce
info_hash
get_peers
find_node
BitTorrent
announce_peer
BitTorrent protocol
announce.php?passkey=
bt
magnet:"

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_BT(){
	Cat_KEY_WORDS
	BT_KEY_WORDS=$(echo -e "$Ban_KEY_WORDS_list"|grep "torrent")
}
check_SPAM(){
	Cat_PORT
	SPAM_PORT=$(echo -e "$Ban_PORT_list"|grep "${smtp_port}")
}
Cat_PORT(){
	Ban_PORT_list=$(iptables -t filter -L OUTPUT -nvx --line-numbers|grep "REJECT"|awk '{print $13}')
}
Cat_KEY_WORDS(){
	#Ban_KEY_WORDS_list=$(iptables -t mangle -L OUTPUT -nvx --line-numbers|grep "DROP"|awk '{print $13}'|sed 's/\"//g')
	Ban_KEY_WORDS_text=$(iptables -t mangle -L OUTPUT -nvx --line-numbers|grep "DROP")
	if [[ ! -z ${Ban_KEY_WORDS_text} ]]; then
		Ban_KEY_WORDS_num=$(echo -e "${Ban_KEY_WORDS_text}"|wc -l)
		for((integer = 1; integer <= ${Ban_KEY_WORDS_num}; integer++))
			do
				Ban_KEY_WORDS_list="${Ban_KEY_WORDS_list}"$(echo -e "${Ban_KEY_WORDS_text}"|sed -n "${integer}p"|perl -e 'while($_=<>){ /\"(.*)\"/; print $1;}')"\n"
		done
	else
		Ban_KEY_WORDS_list=""
	fi
}
View_PORT(){
	Cat_PORT
	echo -e "===============${Red_background_prefix} 当前已封禁 端口 ${Font_color_suffix}==============="
	echo -e "$Ban_PORT_list" && echo && echo -e "==============================================="
}
View_KEY_WORDS(){
	Cat_KEY_WORDS
	echo -e "==============${Red_background_prefix} 当前已封禁 关键词 ${Font_color_suffix}=============="
	echo -e "$Ban_KEY_WORDS_list" && echo -e "==============================================="
}
View_ALL(){
	echo
	View_PORT
	View_KEY_WORDS
	echo
}
Save_iptables_v4(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	elif [[ ${release} == "debian" ]]; then
		iptables-save > /etc/iptables.up.rules
		cat > /etc/network/if-pre-up.d/iptables<<-EOF
#!/bin/bash
/sbin/iptables-restore < /etc/iptables.up.rules
EOF
		chmod +x /etc/network/if-pre-up.d/iptables
	elif [[ ${release} == "ubuntu" ]]; then
		iptables-save > /etc/iptables.up.rules
		echo -e "\npre-up iptables-restore < /etc/iptables.up.rules
post-down iptables-save > /etc/iptables.up.rules" >> /etc/network/interfaces
		chmod +x /etc/network/interfaces
	fi
}
Save_iptables_v4_v6(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
		chkconfig --level 2345 iptables on
		chkconfig --level 2345 ip6tables on
	elif [[ ${release} == "debian" ]]; then
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		cat > /etc/network/if-pre-up.d/iptables<<-EOF
#!/bin/bash
/sbin/iptables-restore < /etc/iptables.up.rules
/sbin/ip6tables-restore < /etc/ip6tables.up.rules
EOF
		chmod +x /etc/network/if-pre-up.d/iptables
	elif [[ ${release} == "ubuntu" ]]; then
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		echo -e "\npre-up iptables-restore < /etc/iptables.up.rules
post-down iptables-save > /etc/iptables.up.rules
pre-up ip6tables-restore < /etc/ip6tables.up.rules
post-down ip6tables-save > /etc/ip6tables.up.rules" >> /etc/network/interfaces
		chmod +x /etc/network/interfaces
	fi
}
Set_key_word() { $1 -t mangle -$3 OUTPUT -m string --string "$2" --algo bm --to 65535 -j DROP; }
Set_tcp_port() {
	[[ "$1" = "$v4iptables" ]] && $1 -t filter -$3 OUTPUT -p tcp -m multiport --dports "$2" -m state --state NEW,ESTABLISHED -j REJECT --reject-with icmp-port-unreachable
	[[ "$1" = "$v6iptables" ]] && $1 -t filter -$3 OUTPUT -p tcp -m multiport --dports "$2" -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
}
Set_udp_port() { $1 -t filter -$3 OUTPUT -p udp -m multiport --dports "$2" -j DROP; }
Set_BT_Code_v4(){
	key_word_num=$(echo -e "${key_word}"|wc -l)
	for((integer = 1; integer <= ${key_word_num}; integer++))
		do
			i=$(echo -e "${key_word}"|sed -n "${integer}p")
			Set_key_word $v4iptables "$i" $s
	done
}
Set_BT_Code_v4_v6(){
	key_word_num=$(echo -e "${key_word}"|wc -l)
	for((integer = 1; integer <= ${key_word_num}; integer++))
		do
			i=$(echo -e "${key_word}"|sed -n "${integer}p")
			Set_key_word $v4iptables "$i" $s
			Set_key_word $v6iptables "$i" $s
	done
}
Set_SPAM_Code_v4(){
	for i in ${smtp_port} ${pop3_port} ${imap_port} ${other_port}; do Set_tcp_port $v4iptables "$i" $s && Set_udp_port $v4iptables "$i" $s; done
}
Set_SPAM_Code_v4_v6(){
	for i in ${smtp_port} ${pop3_port} ${imap_port} ${other_port}; do for j in $v4iptables $v6iptables; do Set_tcp_port $j "$i" $s && Set_udp_port $j "$i" $s; done; done
}
Set_BT(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_BT_Code_v4_v6
		Save_iptables_v4_v6
	elif [[ -n "$v4iptables" ]]; then
		Set_BT_Code_v4
		Save_iptables_v4
	fi
}
Set_SPAM(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_SPAM_Code_v4_v6
		Save_iptables_v4_v6
	elif [[ -n "$v4iptables" ]]; then
		Set_SPAM_Code_v4
		Save_iptables_v4
	fi
}
Set_ALL(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_BT_Code_v4_v6
		Set_SPAM_Code_v4_v6
		Save_iptables_v4_v6
	elif [[ -n "$v4iptables" ]]; then
		Set_BT_Code_v4
		Set_SPAM_Code_v4
		Save_iptables_v4
	fi
}
Ban_BT(){
	check_BT
	[[ ! -z ${BT_KEY_WORDS} ]] && echo -e "${Error} 检测到已封禁BT、PT 关键词，无需再次封禁 !" && exit 0
	s="A"
	Set_BT
	View_ALL
	echo -e "${Info} 已封禁BT、PT 关键词 !"
}
Ban_SPAM(){
	check_SPAM
	[[ ! -z ${SPAM_PORT} ]] && echo -e "${Error} 检测到已封禁SPAM(垃圾邮件) 端口，无需再次封禁 !" && exit 0
	s="A"
	Set_SPAM
	View_ALL
	echo -e "${Info} 已封禁SPAM(垃圾邮件) 端口 !"
}
Ban_ALL(){
	check_BT
	check_SPAM
	s="A"
	if [[ -z ${BT_KEY_WORDS} ]]; then
		if [[ -z ${SPAM_PORT} ]]; then
			Set_ALL
			View_ALL
			echo -e "${Info} 已封禁BT、PT 关键词 和 SPAM(垃圾邮件) 端口 !"
		else
			Set_BT
			View_ALL
			echo -e "${Info} 已封禁BT、PT 关键词 !"
		fi
	else
		if [[ -z ${SPAM_PORT} ]]; then
			Set_SPAM
			View_ALL
			echo -e "${Info} 已封禁SPAM(垃圾邮件) 端口 !"
		else
			echo -e "${Error} 检测到已封禁BT、PT 关键词 和 SPAM(垃圾邮件) 端口，无需再次封禁 !" && exit 0
		fi
	fi
}
UnBan_BT(){
	check_BT
	[[ -z ${BT_KEY_WORDS} ]] && echo -e "${Error} 检测到未封禁BT、PT 关键词，请检查 !" && exit 0
	s="D"
	Set_BT
	View_ALL
	echo -e "${Info} 已解封BT、PT 关键词 !"
}
UnBan_SPAM(){
	check_SPAM
	[[ -z ${SPAM_PORT} ]] && echo -e "${Error} 检测到未封禁SPAM(垃圾邮件) 端口，请检查 !" && exit 0
	s="D"
	Set_SPAM
	View_ALL
	echo -e "${Info} 已解封SPAM(垃圾邮件) 端口 !"
}
UnBan_ALL(){
	check_BT
	check_SPAM
	s="D"
	if [[ ! -z ${BT_KEY_WORDS} ]]; then
		if [[ ! -z ${SPAM_PORT} ]]; then
			Set_ALL
			View_ALL
			echo -e "${Info} 已解封BT、PT 关键词 和 SPAM(垃圾邮件) 端口 !"
		else
			Set_BT
			View_ALL
			echo -e "${Info} 已解封BT、PT 关键词 !"
		fi
	else
		if [[ ! -z ${SPAM_PORT} ]]; then
			Set_SPAM
			View_ALL
			echo -e "${Info} 已解封SPAM(垃圾邮件) 端口 !"
		else
			echo -e "${Error} 检测到未封禁BT、PT 关键词和 SPAM(垃圾邮件) 端口，请检查 !" && exit 0
		fi
	fi
}
ENTER_Ban_PORT(){
	echo -e "请输入欲封禁的 端口（单端口/多端口/连续端口段）
 ${Green_font_prefix}========示例说明========${Font_color_suffix}
 单端口：25（单个端口）
 多端口：25,26,465,587（多个端口用英文逗号分割）
 连续端口段：25:587（25-587之间的所有端口）" && echo
	stty erase '^H' && read -p "(回车默认取消):" PORT
	[[ -z "${PORT}" ]] && echo "已取消..." && exit 0
}
ENTER_Ban_KEY_WORDS(){
	echo -e "请输入欲封禁的 关键词（域名等）
 ${Green_font_prefix}========示例说明========${Font_color_suffix}
 关键词：youtube，即禁止访问任何包含关键词 youtube 的域名。
 关键词：youtube.com，即禁止访问任何包含关键词 youtube.com 的域名（泛域名屏蔽）。
 关键词：www.youtube.com，即禁止访问任何包含关键词 www.youtube.com 的域名（子域名屏蔽）。
 更多效果自行测试（如关键词 .zip 即可禁止下载任何 .zip 后缀的文件）。" && echo
	stty erase '^H' && read -p "(回车默认取消):" KEY_WORDS
	[[ -z "${KEY_WORDS}" ]] && echo "已取消..." && exit 0
}
ENTER_UnBan_PORT(){
	echo -e "请输入欲解封的 端口（根据上面的列表输入完整准确的 端口，包括逗号、冒号）" && echo
	stty erase '^H' && read -p "(回车默认取消):" PORT
	[[ -z "${PORT}" ]] && echo "已取消..." && exit 0
}
ENTER_UnBan_KEY_WORDS(){
	echo -e "请输入欲解封的 关键词（根据上面的列表输入完整准确的 关键词）" && echo
	stty erase '^H' && read -p "(回车默认取消):" KEY_WORDS
	[[ -z "${KEY_WORDS}" ]] && echo "已取消..." && exit 0
}
Set_PORT(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_tcp_port $v4iptables $PORT $s
		Set_udp_port $v4iptables $PORT $s
		Set_tcp_port $v6iptables $PORT $s
		Set_udp_port $v6iptables $PORT $s
		Save_iptables_v4_v6
	elif [[ -n "$v4iptables" ]]; then
		Set_tcp_port $v4iptables $PORT $s
		Set_udp_port $v4iptables $PORT $s
		Save_iptables_v4
	fi
}
Set_KEY_WORDS(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_key_word $v4iptables "$KEY_WORDS" $s
		Set_key_word $v6iptables "$KEY_WORDS" $s
		Save_iptables_v4_v6
	elif [[ -n "$v4iptables" ]]; then
		Set_key_word $v4iptables "$KEY_WORDS" $s
		Set_key_word $v6iptables "$KEY_WORDS" $s
		Save_iptables_v4
	fi
}
Ban_PORT(){
	s="A"
	ENTER_Ban_PORT
	Set_PORT
	View_ALL
	echo -e "${Info} 已封禁端口 ${PORT} !"
}
Ban_KEY_WORDS(){
	s="A"
	ENTER_Ban_KEY_WORDS
	Set_KEY_WORDS
	View_ALL
	echo -e "${Info} 已封禁端口 ${KEY_WORDS} !"
}
UnBan_PORT(){
	s="D"
	View_PORT
	[[ -z ${Ban_PORT_list} ]] && echo -e "${Error} 检测到未封禁任何 端口，请检查 !" && exit 0
	ENTER_UnBan_PORT
	Set_PORT
	View_ALL
	echo -e "${Info} 已解封端口 ${PORT} !"
}
UnBan_KEY_WORDS(){
	s="D"
	View_KEY_WORDS
	[[ -z ${Ban_KEY_WORDS_list} ]] && echo -e "${Error} 检测到未封禁任何 关键词，请检查 !" && exit 0
	ENTER_UnBan_KEY_WORDS
	Set_KEY_WORDS
	View_ALL
	echo -e "${Info} 已解封端口 ${KEY_WORDS} !"
}
check_iptables(){
	v4iptables=`iptables -V`
	v6iptables=`ip6tables -V`
	if [[ ! -z ${v4iptables} ]]; then
		v4iptables="iptables"
		if [[ ! -z ${v6iptables} ]]; then
			v6iptables="ip6tables"
		fi
	else
		echo -e "${Error} 未安装 iptables 防火墙 !
请安装 iptables防火墙：
CentOS 系统：yum install iptables -y
Debian / Ubuntu 系统：apt-get install iptables -y"
	fi
}
check_sys
check_iptables
action=$1
if [[ ! -z $action ]]; then
	[[ $action = "banbt" ]] && Ban_BT && exit 0
	[[ $action = "banspam" ]] && Ban_SPAM && exit 0
	[[ $action = "banall" ]] && Ban_ALL && exit 0
	[[ $action = "unbanbt" ]] && UnBan_BT && exit 0
	[[ $action = "unbanspam" ]] && UnBan_SPAM && exit 0
	[[ $action = "unbanall" ]] && UnBan_ALL && exit 0
fi
echo && echo -e "请输入一个数字来选择选项

  ${Green_font_prefix}0.${Font_color_suffix} 查看 当前封禁列表
————————————
  ${Green_font_prefix}1.${Font_color_suffix} 封禁 BT、PT
  ${Green_font_prefix}2.${Font_color_suffix} 封禁 SPAM(垃圾邮件)
  ${Green_font_prefix}3.${Font_color_suffix} 封禁 BT、PT+SPAM
  ${Green_font_prefix}4.${Font_color_suffix} 封禁 自定义  端口
  ${Green_font_prefix}5.${Font_color_suffix} 封禁 自定义关键词
————————————
  ${Green_font_prefix}6.${Font_color_suffix} 解封 BT、PT
  ${Green_font_prefix}7.${Font_color_suffix} 解封 SPAM(垃圾邮件)
  ${Green_font_prefix}8.${Font_color_suffix} 解封 BT、PT+SPAM
  ${Green_font_prefix}9.${Font_color_suffix} 解封 自定义  端口
 ${Green_font_prefix}10.${Font_color_suffix} 解封 自定义关键词
————————————" && echo
stty erase '^H' && read -p " 请输入数字 [0-10]:" num
case "$num" in
	0)
	View_ALL
	;;
	1)
	Ban_BT
	;;
	2)
	Ban_SPAM
	;;
	3)
	Ban_ALL
	;;
	4)
	Ban_PORT
	;;
	5)
	Ban_KEY_WORDS
	;;
	6)
	UnBan_BT
	;;
	7)
	UnBan_SPAM
	;;
	8)
	UnBan_ALL
	;;
	9)
	UnBan_PORT
	;;
	10)
	UnBan_KEY_WORDS
	;;
	*)
	echo "请输入正确数字 [0-10]"
	;;
esac