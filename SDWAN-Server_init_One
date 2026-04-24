#!/bin/bash
# ==============================================================================
# Debian 12 OpenVPN + SmartDNS + PBR (Policy-Based Routing) Initialization Script
# ==============================================================================

# 遇到任何错误自动退出
set -e

# ==================== 全局配置 (Global Variables) ====================
# 环境变量将在脚本执行时通过交互式输入获取
INNER_IP=""
INNER_IP_MASK=""
INNER_GW=""

OUT_IP=""
OUT_IP_MASK=""
OUT_GW=""

SCRIPT_DIR="/root/script"
# ====================================================================

# 控制台日志美化
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

log_info() { echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $1"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"; }

# ==================== 0. 安装前确认与网络检查 ====================
check_env() {
    if [ "$(id -u)" != "0" ]; then
        log_error "This script must be run as root."
        exit 1
    fi

    # 动态获取网卡名
    INNER_IF=$(ip addr show | awk -v var="${INNER_IP}" '$0 ~ var {print $NF}')
    OUT_IF=$(ip addr show | awk -v var="${OUT_IP}" '$0 ~ var {print $NF}') 

    if [ -z "$INNER_IF" ] || [ -z "$OUT_IF" ]; then
        log_error "Could not find network interfaces for IPs: $INNER_IP or $OUT_IP."
        exit 1
    fi

    log_info "Detected Inner Interface: $INNER_IF"
    log_info "Detected Outer Interface: $OUT_IF"
}

# ==================== 1. 系统更新与软件安装 ====================
install_software() {
    log_info "Updating system and installing packages..."
    apt-get update && apt-get upgrade -y
    apt-get install -y ca-certificates openvpn wireguard wget iptables vim iperf3 \
        dnsutils traceroute tcpdump curl ipset ntpdate lsof bash-completion \
        systemd-resolved smartdns cron
    log_info "Software installation finished."
}

# ==================== 2. 时间与时区设置 ====================
setup_time() {
    log_info "Setting timezone to Asia/Shanghai..."
    timedatectl set-timezone Asia/Shanghai
    ntpdate ntp1.aliyun.com || log_warn "ntpdate failed, ignoring..."
    log_info "Current time is: $(date +'%Y-%m-%d %H:%M:%S')"
}

# ==================== 3. 系统内核参数调整 ====================
setup_sysctl() {
    log_info "Configuring sysctl (IP Forward, BBR, rp_filter)..."
    
    # 清理旧配置，腾出位置
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/net.ipv4.conf.*.rp_filter/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

    # 统一追加新配置
    cat <<EOF >> /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.${INNER_IF}.rp_filter=0
net.ipv4.conf.${OUT_IF}.rp_filter=0
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p > /dev/null 2>&1
    log_info "Sysctl configuration applied."
}

# ==================== 4. 生成辅助脚本 ====================
generate_scripts() {
    log_info "Generating utility scripts in $SCRIPT_DIR..."
    mkdir -p "$SCRIPT_DIR"

    # ========= 4.1 update-iplist.sh =========
    cat << 'EOF' > "$SCRIPT_DIR/update-iplist.sh"
#!/bin/sh
DATE=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="/root/script/update.log"

mkdir -p /root/script /tmp/china-ip/
if ! wget -P /tmp/china-ip/ https://raw.githubusercontent.com/metowolf/iplist/master/data/special/china.txt; then
    echo "$DATE: IPs file download failed, Exit !" >> "$LOG_FILE"
    exit 1
fi
echo "$DATE: IPs file download successful." >> "$LOG_FILE"

# 格式化列表为 ipset
grep -vE '^#|^&}' /tmp/china-ip/china.txt > /tmp/china-ip/ip.txt
sed -i 's/^/add chnroute /g' /tmp/china-ip/ip.txt
mv -f /tmp/china-ip/ip.txt /root/script/chnroute-ipset
echo "$DATE: Format conversion done" >> "$LOG_FILE"
EOF

    # 巧妙补充变量避免被前面的单引号跳过
    echo "echo \"add chnroute $INNER_IP nomatch\" >> /root/script/chnroute-ipset" >> "$SCRIPT_DIR/update-iplist.sh"
    
    cat << 'EOF' >> "$SCRIPT_DIR/update-iplist.sh"
echo "$DATE: Add inner_ip nomatch to chnroute-ipset successfully" >> "$LOG_FILE"

# 重新加载 ipset
if ! ipset -n list chnroute >/dev/null 2>&1; then
    ipset create chnroute hash:net
fi
ipset flush chnroute
ipset restore -f /root/script/chnroute-ipset
echo "$DATE: Reloading ipset-list successfully" >> "$LOG_FILE"

rm -rf /tmp/china-ip
ip_number=$(wc -l < /root/script/chnroute-ipset)
echo "-------------------------------------------------------------------------------------" >> "$LOG_FILE"
echo "$DATE: Update ipset list completely. Total IPs: $ip_number" >> "$LOG_FILE"
echo "-------------------------------------------------------------------------------------" >> "$LOG_FILE"
EOF
    chmod +x "$SCRIPT_DIR/update-iplist.sh"

    # ========= 4.2 update-domainlist.sh =========
    cat << 'EOF' > "$SCRIPT_DIR/update-domainlist.sh"
#!/bin/sh
DATE=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="/root/script/update.log"

mkdir -p /tmp/smartdns/
if ! wget -O /tmp/smartdns/china.conf https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf; then
    echo "$DATE: Domain file download failed, EXIT !" >> "$LOG_FILE"
    exit 1
fi
echo "$DATE: Domian file download successful." >> "$LOG_FILE"  

sed -e 's/server=/nameserver /g' -e 's/114.114.114.114/china/g' /tmp/smartdns/china.conf > /tmp/smartdns/address.conf
cp -a /tmp/smartdns/address.conf /root/script/cndomainlist.conf
mkdir -p /etc/smartdns
mv -f /tmp/smartdns/address.conf /etc/smartdns/cndomainlist.conf
echo "$DATE: File converted to smartDNS .conf format." >> "$LOG_FILE"

rm -rf /tmp/smartdns/
domain_number=$(wc -l < /etc/smartdns/cndomainlist.conf)       
echo "-------------------------------------------------------------------------------------" >> "$LOG_FILE"
echo "$DATE: Update domain list completely. Total domains: $domain_number" >> "$LOG_FILE"
echo "-------------------------------------------------------------------------------------" >> "$LOG_FILE"
systemctl restart smartdns.service
EOF
    chmod +x "$SCRIPT_DIR/update-domainlist.sh"

    # ========= 4.3 baseconfig.sh =========
    # 注意这里使用 EOF 生成，以暴露顶层脚本中的环境变量
    cat << EOF > "$SCRIPT_DIR/baseconfig.sh"
#!/bin/bash

# 设置 IP 源进源出策略 (GZTEL & HK)
ip route flush table 10
ip rule add from $INNER_IP table 10 pref 32765 2>/dev/null || true
ip route add default via $INNER_GW dev $INNER_IF src $INNER_IP table 10

ip route flush table 11
ip rule add from $OUT_IP table 11 pref 32764 2>/dev/null || true
ip route add default via $OUT_GW dev $OUT_IF src $OUT_IP table 11

# 清理原有 Iptables
iptables -t filter -F
iptables -t filter -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t nat -F
iptables -t nat -X

# 开启 SNAT
iptables -t nat -A POSTROUTING -o $INNER_IF -j SNAT --to-source $INNER_IP
iptables -t nat -A POSTROUTING -o $OUT_IF -j SNAT --to-source $OUT_IP
   
# 开机载入 ipset
if [ -s /root/script/chnroute-ipset ]; then
    ipset create chnroute hash:net 2>/dev/null || true
    ipset restore -f /root/script/chnroute-ipset
    ipset add chnroute $INNER_IP nomatch 2>/dev/null || true
else
    echo "chnroute-ipset missing, triggering update-iplist.sh..."
    bash /root/script/update-iplist.sh
fi

# 检查 SmartDNS 列表
if [ ! -s /etc/smartdns/cndomainlist.conf ]; then
    bash /root/script/update-domainlist.sh
fi

# Ip标记 Iptables mangle  
iptables -t mangle -I PREROUTING -m set --match-set chnroute dst -j MARK --set-mark 1
iptables -t mangle -I OUTPUT -m set --match-set chnroute dst -j MARK --set-mark 1

# 分流策略
ip route add default via $INNER_GW dev $INNER_IF src $INNER_IP table 100 2>/dev/null || true
ip rule add fwmark 1 table 100 pref 32763 2>/dev/null || true

# dns-server 路由源 IP
ip route add 119.29.29.29/32 via $INNER_GW dev $INNER_IF src $INNER_IP 2>/dev/null || true
EOF
    chmod +x "$SCRIPT_DIR/baseconfig.sh"
}

# ==================== 5. 配置 Systemd & 计划任务 ====================
setup_systemd_cron() {
    log_info "Configuring systemd units & cron jobs..."
    cat <<EOF > /etc/systemd/system/baseconfig.service
[Unit]
Description=Baseconfig Init Script
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $SCRIPT_DIR/baseconfig.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable baseconfig.service

    # 构建并覆盖定时任务，避免原先存在的重复插入问题
    (crontab -l 2>/dev/null | grep -v "update-domainlist\|update-iplist" || true; \
     echo "0 2 * * sun sh $SCRIPT_DIR/update-domainlist.sh"; \
     echo "1 2 * * sun sh $SCRIPT_DIR/update-iplist.sh" \
    ) | crontab -
}

# ==================== 6. 配置 systemd-resolved (释放53) ====================
setup_resolved() {
    log_info "Configuring systemd-resolved to release port 53..."
    systemctl stop systemd-resolved || true

    sed -i '/DNS=/d' /etc/systemd/resolved.conf
    sed -i '/DNSStubListener=/d' /etc/systemd/resolved.conf
    echo "DNS=8.8.8.8" >> /etc/systemd/resolved.conf
    echo "DNSStubListener=no" >> /etc/systemd/resolved.conf

    rm -f /etc/resolv.conf
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf

    systemctl start systemd-resolved
}

# ==================== 7. 配置 SmartDNS ====================
setup_smartdns() {
    log_info "Configuring SmartDNS..."
    cat <<EOF > /etc/smartdns/smartdns.conf
server-name smartdns
bind :53@tun0 -no-speed-check
cache-size 32768
cache-persist yes
cache-file /tmp/smartdns.cache
serve-expired no
prefetch-domain yes
speed-check-mode none
force-AAAA-SOA yes
force-qtype-SOA 65
dualstack-ip-selection no
log-level info
log-file /var/log/smartdns/smartdns.log
log-size 128k
log-num 1
server 119.29.29.29 -group china -exclude-default-group
server 8.8.8.8
conf-file /etc/smartdns/cndomainlist.conf
EOF
    systemctl enable smartdns
}

# ==================== 8. 配置 OpenVPN ====================
setup_openvpn() {
    log_info "Configuring OpenVPN Profiles & Certificates..."
    rm -rf /etc/openvpn/*

    cat << 'EOF' > /etc/openvpn/ca.crt
-----BEGIN CERTIFICATE-----
MIIDSzCCAjOgAwIBAgIUM9FcQ8dLF0UUxuaY+aKf3URrBWwwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0EwHhcNMjQwNTI3MTAzMzA4WhcNMzQw
NTI1MTAzMzA4WjAWMRQwEgYDVQQDDAtFYXN5LVJTQSBDQTCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAJm3u+rBsjfm3vdWqhZvQt21s9J9c6AbIzUTPuY4
JLwDQZaZzfAnozxKVMP8Bn46EkUmDTeLuHpANM/9KfqMPf3qDi6lTn0NG4rJAS8D
J2QfYeR6oBBwtTiXb1onVC8dwh47uD0tRj7tarxsyUs0UOYERW3eq41o0tvAWXTd
051CAiJM9uOzXSX1QU6YA8WqJL2Ro7+vAd2J7Q1Y74x4tb19DaUQNCeFP6BFvzbl
8JxRow6wCfsicWFDCMm4dJopgo+AwpctYgeZhLGhCMrbe3ce6NxvhboxadJdUBiC
RMgZJRV/fQVlpTTKoxZkiQ1xrjG4Kr10tB0vYwXCutx0sMcCAwEAAaOBkDCBjTAd
BgNVHQ4EFgQURPfT76ER5jLQnNXS2Q0PAU6bV4swUQYDVR0jBEowSIAURPfT76ER
5jLQnNXS2Q0PAU6bV4uhGqQYMBYxFDASBgNVBAMMC0Vhc3ktUlNBIENBghQz0VxD
x0sXRRTG5pj5op/dRGsFbDAMBgNVHRMEBTADAQH/MAsGA1UdDwQEAwIBBjANBgkq
hkiG9w0BAQsFAAOCAQEAQoj/yEuKKSST0+xTRR8eLYPIjEVENagLOEPXijXt49Pr
RRcnNV+I3Ns+fzgbyHV2XcRLGx9p8uLjQQfl6xbBb20ejYGfOFrBJuDg0jEnxBp3
DOaOS9UTANAyMYHMFSPKQt0hXQjoargJJhxfic2zob3OxcADwhWQblfU9XECEGfE
wdJVfB4U0lZkoZAgA/9F8+LGAWnwrDLFUJlx57eVa7XUmFt9FoqOd2M9A0JT0edS
MDruenxaxpv2O4TFcfGdCJNSdzQ0PDYDr224SchyKrIPfvOUOtRyoR/1fLeJr+hM
jQJJ9RL3oRPrur59lqTlgGKGewpHyzLYRpFBGFpcPg==
-----END CERTIFICATE-----
EOF

    cat << 'EOF' > /etc/openvpn/server.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            32:2c:a8:56:c1:e5:b7:df:7a:e9:6d:87:c1:24:3c:00
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=Easy-RSA CA
        Validity
            Not Before: May 27 10:46:11 2024 GMT
            Not After : May 22 10:46:11 2044 GMT
        Subject: CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:ae:ae:8d:ec:c6:7a:4f:97:bf:f3:80:8c:70:2a:
                    53:d1:0c:d5:2e:ee:f1:93:73:20:5b:bb:91:7a:60:
                    f0:b5:a8:07:ee:08:13:8b:a8:03:50:7f:17:d6:42:
                    23:42:c1:7d:dc:39:df:f9:1c:d1:3d:ed:70:2f:1a:
                    0b:ba:ac:fa:8a:d8:bb:86:bc:0a:bb:07:81:14:42:
                    d8:a7:5b:77:ea:5d:ac:56:76:87:a2:59:5e:23:3a:
                    ee:fa:bb:29:4f:5c:ea:3d:8f:dc:c6:4c:6d:da:14:
                    4c:41:b2:c3:15:08:a2:6e:1b:12:9e:af:e2:84:03:
                    b5:1f:80:23:4b:84:9f:e9:a4:89:9c:55:cb:04:d0:
                    b4:51:07:0f:49:f0:4b:55:3d:bb:b3:2a:32:a7:3a:
                    8c:24:be:ca:cf:c5:53:d1:bb:4a:ff:c6:18:60:71:
                    5c:ee:21:7e:bc:31:20:9f:0c:2a:ea:5d:2b:0e:e7:
                    9e:df:a0:f4:dc:f9:20:ce:01:8c:07:af:08:b2:dd:
                    4c:b8:d0:18:55:76:df:e4:f8:bb:ee:a2:3b:63:5e:
                    04:27:b2:f5:e9:3e:ef:5f:97:e4:9f:d2:97:f1:26:
                    13:25:16:59:94:54:d5:e1:b5:e4:fc:2e:44:12:66:
                    8d:97:ca:0d:92:ac:f0:30:ee:1c:d0:aa:d2:9a:36:
                    fb:c5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Subject Key Identifier: 
                95:7E:C2:09:B1:76:D3:02:59:9D:FF:75:99:59:10:7C:F5:D0:1A:67
            X509v3 Authority Key Identifier: 
                keyid:44:F7:D3:EF:A1:11:E6:32:D0:9C:D5:D2:D9:0D:0F:01:4E:9B:57:8B
                DirName:/CN=Easy-RSA CA
                serial:33:D1:5C:43:C7:4B:17:45:14:C6:E6:98:F9:A2:9F:DD:44:6B:05:6C
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Key Usage: 
                Digital Signature, Key Encipherment
            Netscape Comment: 
                Easy-RSA (3.0.8) Generated Certificate
            Netscape Cert Type: 
                SSL Server
            X509v3 Subject Alternative Name: 
                DNS:server
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        7d:c5:b7:ff:10:9c:c3:b5:54:7c:84:14:48:1b:04:98:e3:92:
        6b:f9:46:d5:2d:10:be:82:44:e1:06:be:71:f3:06:ec:af:1f:
        71:86:40:be:fb:55:35:ba:8b:ac:e9:08:17:fe:27:04:09:30:
        67:ca:26:0d:2f:75:c7:f9:a7:ba:a0:28:9e:bd:8e:b0:90:73:
        78:5c:90:25:30:35:de:cd:82:44:4d:42:f4:f8:f3:ba:54:5f:
        05:2b:b8:f2:87:39:14:00:b8:d5:0b:3e:dd:a7:92:3f:10:9e:
        c2:df:4e:56:af:bb:0d:0e:a3:97:6d:1a:18:92:80:ea:7d:a9:
        47:07:5f:67:ad:99:3c:f4:1b:3f:08:12:14:31:cf:10:d5:d7:
        d4:6b:4f:28:5d:0f:08:2e:35:eb:d3:60:5e:72:39:e9:65:a7:
        15:05:3d:77:ea:25:ee:e9:cf:6c:29:fd:f9:3f:2f:5f:50:74:
        2b:e6:ce:25:5b:cc:2d:9e:c9:96:f1:54:27:da:8c:10:42:da:
        c8:df:d7:05:7d:34:06:ad:3f:0a:75:77:fc:da:5f:84:24:a9:
        4d:f4:94:01:e1:02:c0:35:1b:ac:5e:ad:27:c4:18:b2:51:8d:
        25:39:d2:fc:79:47:6f:5a:da:0c:8f:18:ca:c2:cc:c6:cd:1a:
        cc:69:47:f7
-----BEGIN CERTIFICATE-----
MIIDsTCCApmgAwIBAgIQMiyoVsHlt9966W2HwSQ8ADANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtFYXN5LVJTQSBDQTAeFw0yNDA1MjcxMDQ2MTFaFw00NDA1MjIx
MDQ2MTFaMBExDzANBgNVBAMMBnNlcnZlcjCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAK6ujezGek+Xv/OAjHAqU9EM1S7u8ZNzIFu7kXpg8LWoB+4IE4uo
A1B/F9ZCI0LBfdw53/kc0T3tcC8aC7qs+orYu4a8CrsHgRRC2Kdbd+pdrFZ2h6JZ
XiM67vq7KU9c6j2P3MZMbdoUTEGywxUIom4bEp6v4oQDtR+AI0uEn+mkiZxVywTQ
tFEHD0nwS1U9u7MqMqc6jCS+ys/FU9G7Sv/GGGBxXO4hfrwxIJ8MKupdKw7nnt+g
9Nz5IM4BjAevCLLdTLjQGFV23+T4u+6iO2NeBCey9ek+71+X5J/Sl/EmEyUWWZRU
1eG15PwuRBJmjZfKDZKs8DDuHNCq0po2+8UCAwEAAaOB/zCB/DAJBgNVHRMEAjAA
MB0GA1UdDgQWBBSVfsIJsXbTAlmd/3WZWRB89dAaZzBRBgNVHSMESjBIgBRE99Pv
oRHmMtCc1dLZDQ8BTptXi6EapBgwFjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0GCFDPR
XEPHSxdFFMbmmPmin91EawVsMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAsGA1UdDwQE
AwIFoDA1BglghkgBhvhCAQ0EKBYmRWFzeS1SU0EgKDMuMC44KSBHZW5lcmF0ZWQg
Q2VydGlmaWNhdGUwEQYJYIZIAYb4QgEBBAQDAgZAMBEGA1UdEQQKMAiCBnNlcnZl
cjANBgkqhkiG9w0BAQsFAAOCAQEAfcW3/xCcw7VUfIQUSBsEmOOSa/lG1S0QvoJE
4Qa+cfMG7K8fcYZAvvtVNbqLrOkIF/4nBAkwZ8omDS91x/mnuqAonr2OsJBzeFyQ
JTA13s2CRE1C9PjzulRfBSu48oc5FAC41Qs+3aeSPxCewt9OVq+7DQ6jl20aGJKA
6n2pRwdfZ62ZPPQbPwgSFDHPENXX1GtPKF0PCC4169NgXnI56WWnFQU9d+ol7unP
bCn9+T8vX1B0K+bOJVvMLZ7JlvFUJ9qMEELayN/XBX00Bq0/CnV3/NpfhCSpTfSU
AeECwDUbrF6tJ8QYslGNJTnS/HlHb1raDI8YysLMxs0azGlH9w==
-----END CERTIFICATE-----
EOF

    cat << 'EOF' > /etc/openvpn/server.key
-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCuro3sxnpPl7/z
gIxwKlPRDNUu7vGTcyBbu5F6YPC1qAfuCBOLqANQfxfWQiNCwX3cOd/5HNE97XAv
Ggu6rPqK2LuGvAq7B4EUQtinW3fqXaxWdoeiWV4jOu76uylPXOo9j9zGTG3aFExB
ssMVCKJuGxKer+KEA7UfgCNLhJ/ppImcVcsE0LRRBw9J8EtVPbuzKjKnOowkvsrP
xVPRu0r/xhhgcVzuIX68MSCfDCrqXSsO557foPTc+SDOAYwHrwiy3Uy40BhVdt/k
+LvuojtjXgQnsvXpPu9fl+Sf0pfxJhMlFlmUVNXhteT8LkQSZo2Xyg2SrPAw7hzQ
qtKaNvvFAgMBAAECggEAG4LHPGan5bgnFYEF3TZ1W+OzAYDFUC0eCAR67XSuBFYR
5aWk+mY8G2XgybBB4GYb3d7JjPDCbYfjFq/57+0FSm/G3PnpkLomVJwQhg8MTD9z
gGyLgQClKFRERf3LDEI8a/Sn1x07YdC3j9NJERt6hW/DF3Xo7VSuJmdmZ6LcEo5B
yu1HWLpxeA+PB1beWptNeBeeujOeJbU/zA0O8nvT7qd4uLXO1Nzu5ynmAUFuW5pb
udHq0b3KvMtZQ/ZGOvzjOkO2nr6CP8zsAE9n2t6WN1R4QySJa6RMV2Rvnz9XMl6e
+im8Bw4ZEkTz4SdnjU4ioelmHVs1BZDdhT/wgEYQMQKBgQC83wK2vGeLeDmfoAja
IrLARN1mO3GvYyTLl008RZfmm3Y3+CtPy4Gu2xWbzNCqsnjaDOJOav2delOFGwgR
VtX+qikMcZWy2NPFbmLMB0cM3Dpwn5Rt2PzNlOig7mynRWrqDRGrziHqgHNEahKZ
9ixoZRam4iX0iynIApt36Cz62QKBgQDsxH2fDZ8WgVkMO4wmw/TmVr9qcVtM9ILu
L6fGZ5jiVwH/4JceGJKZGbMVVGkSo72XZ9giBW7PWnW82jxt2VXKeTwlumVRRwjS
4I6dw1tNu0tR9phStW0A8siWZ7K+JIlisNi8fMSISNETxrHmr3aNtwvyHGxJOSi+
EHUgIZl8zQKBgAjs3Pr3skjz+H0jmed9BkdxuaiwHHI2VDHOx5aWj1QVeqOwdZOC
wXEa502Cg0XdwzpCq5sbETsU4ceDfIEdQmWTcvckkvdtqaxFyCNuIJxp99UEpYX/
YArzA38/ZSEOdbvzvCcLSa0EPu43uQNPj8+rH0PpofOJdAMApIopDZ8ZAoGAFL6K
exsIa0Jd+PJmrybQGDZVgw/3feCWcCQAwSNmg7430KFu3BYvEfbsd9vzcMyj2dYh
W6m6MbStSCSe0skN+TVyDaQtKFfe8Ar4s93f7AmS6dV/Nw/qQwECjhr70CkHWHxC
IRGVbpNiribkg1+wNW5qP4Y5/phhd3WdrXkEJ6kCgYBm41kaTDx2kvLCZjGYEtZ1
vjmZMkdFyA2IirLKOXYRFDxBoZnnz65+T3lulC78yXd+mDipg8T9Z0PMZMSgDaJv
iTlUzP9KrmnM6pX2fKHIoZ8AvwVkzTGWoAlZbXFMG59eBV+jr8fLuzGrtke8ugeL
jUdStcIcwQEfBmrMRB4mxQ==
-----END PRIVATE KEY-----
EOF
    chmod 600 /etc/openvpn/server.key

    cat << 'EOF' > /etc/openvpn/dh.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAusZpuIV/w+/YQ6xs8UwquRK5lSntUtl+rc7ELhJAC9OCwmkfhRyB
p3HyJl3er1diDYJsZXM8SlLT8NQ1dBQo2X1s8HjKj0y46hpip913LTy9hZWaW5LQ
qiwJFGxzV43guh3xEpWhq/JwZf8i8d54JcXhDI8lWvoQi+MTu0Cccd2LRAqzHuCs
7y3xhckkSPyEoKsnOcnTB8wpalt5WV75oBIbAU+AU2/gIDeyXNidDvAD+RKGPUWu
p295403GCfjpbXpeEqX79DmjbPGGjJf1eysF30XRA7n22IaEZnWm9aIym+2T+Umr
23/K8hyMcKmOnvDgb2hYKIcP60+lO/+yZwIBAg==
-----END DH PARAMETERS-----
EOF

    cat << 'EOF' > /etc/openvpn/server.conf
mode server
topology subnet 
port 1199 
proto tcp-server 
dev tun0 
ca ca.crt 
cert server.crt 
key server.key 
dh dh.pem
server 172.18.0.0 255.255.0.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 172.18.0.1"
keepalive 10 120 
max-clients 1000
status-version 1
status /etc/openvpn/openvpn-status.log 10
verb 3
log /var/log/openvpn.log
persist-key
persist-tun
reneg-sec 0
script-security 3
auth-user-pass-verify /etc/openvpn/checkpsw.sh via-env
username-as-common-name
verify-client-cert none
client-config-dir /etc/openvpn/ccd
client-to-client
mute 20
tun-mtu 1400
EOF

    cat << 'EOF' > /etc/openvpn/checkpsw.sh
#!/bin/sh
PASSFILE="/etc/openvpn/psw-file"
LOG_FILE="/etc/openvpn/openvpn-password.log"
TIME_STAMP=$(date "+%Y-%m-%d %T")

if [ ! -r "${PASSFILE}" ]; then
  echo "${TIME_STAMP}: Could not open password file \"${PASSFILE}\" for reading." >> "${LOG_FILE}"
  exit 1
fi

CORRECT_PASSWORD=$(awk '!/^;/&&!/^#/&&$1=="'${username}'"{print $2;exit}' "${PASSFILE}")
 
if [ "${CORRECT_PASSWORD}" = "" ]; then 
  echo "${TIME_STAMP}: User does not exist: username=\"${username}\"." >> "${LOG_FILE}"    
  exit 1
fi

if [ "${password}" = "${CORRECT_PASSWORD}" ]; then 
  echo "${TIME_STAMP}: Successful authentication: username=\"${username}\"." >> "${LOG_FILE}"
  exit 0
fi

echo "${TIME_STAMP}: Incorrect password: username=\"${username}\"." >> "${LOG_FILE}"
exit 1
EOF
    chmod +x /etc/openvpn/checkpsw.sh

    cat << 'EOF' > /etc/openvpn/psw-file
peter    switch-net.com
switch-net   switch-net.com
EOF

    mkdir -p /etc/openvpn/ccd
    echo "ifconfig-push 172.18.1.2 255.255.0.0" > /etc/openvpn/ccd/peter
    echo "ifconfig-push 172.18.1.3 255.255.0.0" > /etc/openvpn/ccd/switch-net

    systemctl enable openvpn@server.service
}

# ==================== 9. 启动服务与最终验证 ====================
start_services() {
    log_info "Starting Services and fetching lists..."
    systemctl start baseconfig.service

    # 更新路由和智能 DNS 列表
    bash "$SCRIPT_DIR/update-domainlist.sh" || log_warn "update-domainlist execution failed."
    bash "$SCRIPT_DIR/update-iplist.sh" || log_warn "update-iplist execution failed."

    systemctl restart openvpn@server.service
    sleep 2
    systemctl restart smartdns.service
    sleep 2

    if lsof -i:1199 >/dev/null; then
        log_info "Openvpn is running."
    else
        log_error "Openvpn startup failed."
    fi

    if lsof -i:53 | grep -q 'smartdns'; then
        log_info "Smartdns is running on port 53."
    else
        log_error "Smartdns failed to start on port 53."
    fi

    log_info "=========================================="
    log_info "      Server Init Successful! Enjoy!      "
    log_info "=========================================="
}

get_user_inputs() {
    echo -e "${COLOR_GREEN}>>> 请输入网络配置参数 (Network Configuration) <<<${COLOR_NC}"
    echo -e "（如直接回车将使用默认示例值）"
    
    read -p "请输入内网IP (INNET_IP) [默认: 121.14.71.168]: " input_inner_ip
    INNER_IP=${input_inner_ip:-121.14.71.168}
    
    read -p "请输入内网子网掩码位 (INNET_IP_MASK) [默认: 28]: " input_inner_mask
    INNER_IP_MASK=${input_inner_mask:-28}
    
    read -p "请输入内网网关 (INNET_GW) [默认: 121.14.71.161]: " input_inner_gw
    INNER_GW=${input_inner_gw:-121.14.71.161}
    
    echo ""
    read -p "请输入外网IP (OUT_IP) [默认: 149.112.116.110]: " input_out_ip
    OUT_IP=${input_out_ip:-149.112.116.110}
    
    read -p "请输入外网子网掩码位 (OUT_IP_MASK) [默认: 29]: " input_out_mask
    OUT_IP_MASK=${input_out_mask:-29}
    
    read -p "请输入外网网关 (OUT_GW) [默认: 149.112.116.105]: " input_out_gw
    OUT_GW=${input_out_gw:-149.112.116.105}
    
    echo ""
    log_info "获取到的配置如下："
    log_info "  内网(INNET): IP=${INNER_IP}, MASK=${INNER_IP_MASK}, GW=${INNER_GW}"
    log_info "  外网(OUT): IP=${OUT_IP}, MASK=${OUT_IP_MASK}, GW=${OUT_GW}"
    echo ""
}

main() {
    echo -e "${COLOR_YELLOW}================================================================${COLOR_NC}"
    echo -e "${COLOR_YELLOW}   Debian 12 Initialization Script for OpenVPN & SmartDNS   ${COLOR_NC}"
    echo -e "${COLOR_YELLOW}================================================================${COLOR_NC}"
    read -n 1 -r -p "Press 'y' to start installation, or any other key to abort: " char
    echo 
    if [[ ! "$char" =~ ^[Yy]$ ]]; then
        echo "Installation aborted."
        exit 0
    fi

    get_user_inputs
    check_env
    install_software
    setup_time
    setup_sysctl
    generate_scripts
    setup_systemd_cron
    setup_resolved
    setup_smartdns
    setup_openvpn
    start_services
}

main
