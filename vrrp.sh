

yum install keepalived -y

# active
echo "vrrp_instance vrrp_group_1 {
     state MASTER
     interface eth0
     virtual_router_id 1
     priority 100
     authentication {
         auth_type PASS
         auth_pass password
     }
     virtual_ipaddress {
         192.168.168.3/24 brd 192.168.168.255 dev eth0
     }
}" > /etc/keepalived/keepalived.conf

# standby
echo "vrrp_instance vrrp_group_1 {
     state BACKUP
     interface eth0
     virtual_router_id 1
     priority 50
     authentication {
         auth_type PASS
         auth_pass password
     }
     virtual_ipaddress {
         192.168.168.3/24 brd 192.168.168.255 dev eth0
     }
}" > /etc/keepalived/keepalived.conf

systemctl enable keepalived && systemctl start keepalived

