#!/bin/sh
ETH="eth0"
TEMP=`/sbin/ip -6 addr | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80 | cut -f1-4 -d':'`
SUBNET=`ifconfig | grep $TEMP | awk '{print $4}'`

random() {
        tr </dev/urandom -dc A-Za-z0-9 | head -c5
        echo
}
get_list_ip() {
      ip a | grep inet6 | grep "scope global" | awk ' {print $2}' | cut -d'/' -f 1 > /root/list_ip.txt

}
install_3proxy() {
    echo "Installing 3proxy"
    URL="https://raw.githubusercontent.com/hautph/vinahost/main/3proxy-0.9.4.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    mv 3proxy-0.9.4 3proxy
    cd 3proxy
    make -f Makefile.Linux
    mkdir -p /etc/3proxy/{bin,logs,stat}
    cp ./bin/3proxy /bin/3proxy
    cp ./scripts/init.d/3proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
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
    get_list_ip
    first=30000
    COUNT=`ip a | grep inet6 | grep "scope global" | awk ' {print $2}' | cut -d'/' -f 1 | wc -l`
    for ((i=1;i< $COUNT ;i ++)); do
        ip=`sed -n "${i}p" /root/list_ip.txt`
        port=$((first + i))
        echo "usr$(random)/pass$(random)/$IP4/$port/$ip"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
        while read line
        do
                ipv6=`echo $line | cut -d"/" -f5`
                echo "ifconfig $ETH inet6 add $ipv6/$SUBNET"
        done < ${WORKDATA}
}
sendmail()
{
    name=`hostnamectl | grep hostname | awk '{printf $3}'`
    cat /home/vinahost/data.txt | awk -F "/" {'print $3"/"$4"/"$1"/"$2"/"$5'} | sed 's/usr//g' | sed 's/pass//g' > /root/info.txt
    echo "Thông tin VPS MMO $name " | mail -s "Thông tin VPS MMO $name" -a /root/info.txt -S smtp=e.vinahost.vn -S smtp-auth=login -S smtp-auth-user=USER_SMTP -S smtp-auth-password=PASS_SMTP -S from="VPS MMO Infomation<mmo-info@vina-host.com>" support.team@vinahost.vn danht@vinahost.vn
}
echo "installing apps"
yum -y install gcc net-tools bsdtar zip psmisc iptables-services mailx >/dev/null

install_3proxy

echo "working folder = /home/vinahost"
WORKDIR="/home/vinahost"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

/usr/sbin/ifdown $ETH
/usr/sbin/ifup $ETH

echo "Checking ipv4 & ipv6"

IP4=$(curl -4 -s icanhazip.com)


gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
#chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/etc/3proxy/3proxy.cfg
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

bash /etc/rc.local

gen_proxy_file_for_user

sendmail

