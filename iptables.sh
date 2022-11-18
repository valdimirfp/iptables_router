#!/bin/bash
#Настроим iptables
#Сбросим старые настройки
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

#дропаем все по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#разрешаем межблочный обмен на локал хост
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#Разрешим ICMP всем
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A OUTPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A FORWARD -p icmp -m icmp --icmp-type 8 -j ACCEPT

#разрешить локальные соединения с динамических портов
iptables -A OUTPUT -p TCP --sport 32768:61000 -j ACCEPT
iptables -A OUTPUT -p UDP --sport 32768:61000 -j ACCEPT

# NEW Droping all invalid packets
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A FORWARD -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP

# Kali full access
iptables -A OUTPUT -p tcp -d 172.16.11.104 -j ACCEPT

# Разрешаем DNS
#iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 --dport 1024:65535 -j ACCEPT

#Разрешаем проходить пакетам по уже установленным соединениям
iptables -I FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Разрешить только те пакеты, которые мы запросили:
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -I OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#открываем SSH
iptables -A INPUT -p tcp -s 0.0.0.0/0 --dport=22 -j ACCEPT
#iptables -A INPUT -p tcp -s 192.168.10.0/24 --dport=22 -j ACCEPT

# открываем входящте запросы
iptables -A INPUT -p tcp -s 0.0.0.0/0 --dport=1443 -j ACCEPT
iptables -A INPUT -p tcp -s 0.0.0.0/0 --dport=81 -j ACCEPT

# разрешения для k8s
#iptables -A INPUT -p tcp -s 172.16.11.0/24 -j ACCEPT
#iptables -A OUTPUT -p tcp -s 172.16.11.0/24 -j ACCEPT
#iptables -A INPUT -p tcp -s 10.0.0.0/8 -j ACCEPT

#iptables -A INPUT -p tcp -s 172.16.1.0/24  -j ACCEPT

# разрешаем внутреннем хостам выходи на ружу
iptables -A FORWARD -i enp0s8 -p tcp --match multiport --dport 443,80,22 -j ACCEPT
#iptables -A FORWARD -i enp0s8 -p tcp -j ACCEPT

iptables -A FORWARD -i enp0s8 -s 172.16.11.0/24 -p tcp -j LOG --log-prefix '[iptables]-DROP ' --log-level 1
iptables -A FORWARD -i enp0s8 -s 172.16.11.0/24 -p tcp -j DROP

#Разрешаем исходящие соединения из локальной сети к интернет-хостам
iptables -A FORWARD -m conntrack --ctstate NEW -i enp0s8 -s 172.16.11.0/24 -j ACCEPT

#пробросим NAT
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

#проброс внутрь

# HaProxy01
## http
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 8380 -j DNAT --to-destination 172.16.11.71:80
iptables -A FORWARD -p tcp -d 172.16.11.71 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## HaProxy haproxy_stats
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 1011 -j DNAT --to-destination 172.16.11.71:1001
iptables -A FORWARD -p tcp -d 172.16.11.71 --dport 1001 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## ssh
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 2222 -j DNAT --to-destination 172.16.11.71:22
iptables -A FORWARD -p tcp -d 172.16.11.71 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#Kibana
## http
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 8180 -j DNAT --to-destination 172.16.11.110:80
iptables -A FORWARD -p tcp -d 172.16.11.110 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## https
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 2443 -j DNAT --to-destination 172.16.11.110:443
iptables -A FORWARD -p tcp -d 172.16.11.110 --dport 443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## ssh
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 2223 -j DNAT --to-destination 172.16.11.110:22
iptables -A FORWARD -p tcp -d 172.16.11.110 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT


#WEB-01
## web
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 8480 -j DNAT --to-destination 172.16.11.81:80
iptables -A FORWARD -p tcp -d 172.16.11.81 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## web_https
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 1443 -j DNAT --to-destination 172.16.11.81:443
iptables -A FORWARD -p tcp -d 172.16.11.81 --dport 443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## ssh
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 2422 -j DNAT --to-destination 172.16.11.81:22
iptables -A FORWARD -p tcp -d 172.16.11.81 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#WEB-02
## web
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 8280 -j DNAT --to-destination 172.16.11.82:80
iptables -A FORWARD -p tcp -d 172.16.11.82 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## ssh
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 2122 -j DNAT --to-destination 172.16.11.82:22
iptables -A FORWARD -p tcp -d 172.16.11.82 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#UBNTWS
## ssh
iptables -t nat -A PREROUTING -p tcp -s 0.0.0.0/0 --dport 2225 -j DNAT --to-destination 172.16.11.82:111
iptables -A FORWARD -p tcp -d 172.16.11.111 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#пишем в лог все дропы
iptables -N LOGGING
iptables -A INPUT -j LOGGING
iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4
iptables -A LOGGING -j DROP

## NEW Reject Forwarding  traffic
iptables -A OUTPUT -j REJECT
iptables -A FORWARD -j REJECT


# save config
#iptables-save > /etc/iptables.rules
sudo iptables-save > /etc/iptables.rules.v4
echo "iptables rules complete"
