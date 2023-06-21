#!/bin/sh
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

DEVICE=`ip -6 route ls | grep default | grep -Po '(?<=dev )(\S+)'`
del_ifconfig() {
	while read line
	do
		/usr/sbin/ip addr del $line/64 dev ens4
	done < /root/ipv6_list.txt
}

echo "" > /root/ipv6_list.txt
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
prefix=`echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"`
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	GEN_IP=`echo "$1:400:$prefix:$(ip64):$(ip64)"`
	echo $GEN_IP >> /root/ipv6_list.txt
	echo $GEN_IP
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth iponly\n" \
"#allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 }' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

#gen_iptables() {
#    cat <<EOF
#    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
#EOF
#}

gen_ifconfig() {
	while read line
	do
		ip=`echo $line | cut -f5 -d"/"`
		echo "ifconfig ens4 inet6 add $ip/64"
	done < ${WORKDATA}
}
echo "Change ipv6 address"

echo "Working folder = /home/vinahost"
WORKDIR="/home/vinahost"
WORKDATA="${WORKDIR}/data.txt"

#service iptables restart

#service network restart

echo "Checking ipv4 & ipv6"

IP4=$(curl -4 -s icanhazip.com)

IP6=$(curl -6 -s icanhazip.com | cut -f 1-4 -d":")

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

#echo "How many proxy do you want to create? Example 100"
#read COUNT

COUNT=500

FIRST_PORT=30000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
#gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh

gen_3proxy >/etc/3proxy/3proxy.cfg

#bash /home/vinahost/boot_iptables.sh
bash /home/vinahost/boot_ifconfig.sh
ulimit -n 10048
killall 3proxy
service 3proxy start

gen_proxy_file_for_user