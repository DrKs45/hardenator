###-----------------------------------------------------------------------------------------------
### IPV4 INIT
## Delete all rules
/usr/sbin/iptables  -F
## Delete user chains
/usr/sbin/iptables  -X


###-----------------------------------------------------------------------------------------------

## DNS (needed at the beginning for ipset)
/usr/sbin/iptables  -A OUTPUT -p tcp --dport 53 -j ACCEPT
/usr/sbin/iptables  -A OUTPUT -p udp --dport 53 -j ACCEPT

### INPUT RULES
/usr/sbin/iptables  -A INPUT -i lo -j ACCEPT
/usr/sbin/iptables  -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## SSH - IP whitelisting
/usr/sbin/iptables  -A INPUT -p tcp --dport $SSH_PORT --source "internal_IP_address"  -j ACCEPT

## For local testing, to be removed in production
/usr/sbin/iptables  -A INPUT -p tcp --dport $SSH_PORT --source "test_vm_ip"  -j ACCEPT

## DNS MX 
/usr/sbin/iptables  -A INPUT -p tcp --dport 53 --source "mx_server_ip"  -j ACCEPT
/usr/sbin/iptables  -A INPUT -p udp --dport 53 --source "mx_server_ip"  -j ACCEPT

## 

## Zabbix 
/usr/sbin/iptables  -A INPUT -p tcp --dport 10050 --source "zabbix_server_ip"  -j ACCEPT
## Centreon
/usr/sbin/iptables  -A INPUT -p tcp --dport 5669 --source "centreon_server_ip"  -j ACCEPT
## Grafana
/usr/sbin/iptables  -A INPUT -p tcp --dport 3000 --source "grafana_server_ip"  -j ACCEPT

###-----------------------------------------------------------------------------------------------
### OUTPUT RULES
/usr/sbin/iptables  -A OUTPUT -o lo -j ACCEPT
/usr/sbin/iptables  -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## NTP
/usr/sbin/iptables  -A OUTPUT -p udp --dport 123 -j ACCEPT

## Linux updates
# 443 ports
/usr/sbin/iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
# 80 ports
/usr/sbin/iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

###-----------------------------------------------------------------------------------------------
### DROP ALL OTHERS
/usr/sbin/iptables  -P FORWARD DROP
/usr/sbin/iptables  -P INPUT DROP
/usr/sbin/iptables  -P OUTPUT DROP

###-----------------------------------------------------------------------------------------------
### IPV6 INIT
## Delete all rules
/usr/sbin/ip6tables -F
## Delete user chains
/usr/sbin/ip6tables  -X
### Block ALL IPv6
/usr/sbin/ip6tables  -P FORWARD DROP
/usr/sbin/ip6tables  -P INPUT DROP
/usr/sbin/ip6tables  -P OUTPUT DROP

###-----------------------------------------------------------------------------------------------