1/ bash <(curl -s "https://raw.githubusercontent.com/ltrtuan/proxy/master/3proxy.sh")
2/  systemctl restart 3proxy
3/  systemctl status 3proxy.service
4/ Sau khi add Ipv6 vào interface . Run systemctl restart network và systemctl is-active network active
5/ Test Ipv6 add thành công  ping6 -c1 2A00:0C98:2060:A000:0000:0000:0000:0001