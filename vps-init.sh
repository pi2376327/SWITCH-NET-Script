#!/bin/bash

#update system and packages
apt update && apt upgrade -y

read -n 1 -p "continue [y/n] > " char
echo
if [ "$char" = n ];then exit 0;fi

timedatectl set-timezone Asia/Shanghai
apt install -y ca-certificates openvpn wireguard wget iptables vim iperf3 dnsutils  traceroute tcpdump curl ipset ntpdate lsof bash-completion smartdns cron lrzsz telnet zabbix-agent2 fping

#Turn on ip_foward,bbr-acceleration，turn off urpf
sed -i "/net.ipv4.ip_forward=1/d" /etc/sysctl.conf
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
sed -i "/net.ipv4.conf.all.rp_filter/d" /etc/sysctl.conf
echo net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/d" /etc/sysctl.conf
echo net.ipv4.conf.default.rp_filter=0 >> /etc/sysctl.conf
sysctl -p

read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi

#clean DIR:/etc/openvpn
rm -rf /etc/openvpn/*

#Add ca.crt
cat <<EOF > /etc/openvpn/ca.crt
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
cat /etc/openvpn/ca.crt

read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi

##Add server.crt
cat <<EOF > /etc/openvpn/server.crt
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

cat /etc/openvpn/server.crt
read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi

##Add server.key
cat <<EOF > /etc/openvpn/server.key
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

cat /etc/openvpn/server.key
read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi

##Add dh.pem
cat <<EOF > /etc/openvpn/dh.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAusZpuIV/w+/YQ6xs8UwquRK5lSntUtl+rc7ELhJAC9OCwmkfhRyB
p3HyJl3er1diDYJsZXM8SlLT8NQ1dBQo2X1s8HjKj0y46hpip913LTy9hZWaW5LQ
qiwJFGxzV43guh3xEpWhq/JwZf8i8d54JcXhDI8lWvoQi+MTu0Cccd2LRAqzHuCs
7y3xhckkSPyEoKsnOcnTB8wpalt5WV75oBIbAU+AU2/gIDeyXNidDvAD+RKGPUWu
p295403GCfjpbXpeEqX79DmjbPGGjJf1eysF30XRA7n22IaEZnWm9aIym+2T+Umr
23/K8hyMcKmOnvDgb2hYKIcP60+lO/+yZwIBAg==
-----END DH PARAMETERS-----
EOF

cat /etc/openvpn/dh.pem
read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi

##Add ovpn-up.sh
cat <<'EOF' > /etc/openvpn/ovpn-up.sh
#!/bin/bash
int=$(ip route show 1/0 | cut -d' ' -f5)
iptables -t nat -C POSTROUTING -o $int -j MASQUERADE
if [ $? -eq 1 ]; then
        iptables -t nat -I POSTROUTING -o $int -j MASQUERADE
        echo "MASQUERADE rules for $int have been added"
else
        echo "MASQUERADE rules for $int exist,done"
fi

ip route show | grep 119.29.29.29 2>&1 >>/dev/null
if [ $? -eq 1 ]; then
        ip route add 119.29.29.29/32 via 172.18.1.3 dev tun0
        echo "Added the absence of route 119.29.29.29"
else
        echo "The route 119.29.29.29/32 exist,done"
fi
EOF
chmod +x /etc/openvpn/ovpn-up.sh

cat /etc/openvpn/ovpn-up.sh
read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi
   
##Add server.conf
cat <<EOF > /etc/openvpn/server.conf
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
push "dhcp-option DNS 8.8.8.8"
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
up /etc/openvpn/ovpn-up.sh
EOF


cat /etc/openvpn/server.conf


read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi


##Add checkpsw.sh
if [ ! -f /etc/openvpn/checkpsw.sh ];then
    touch /etc/openvpn/checkpsw.sh
    chmod +x /etc/openvpn/checkpsw.sh
    cat <<EOF > /etc/openvpn/checkpsw.sh
#!/bin/sh
###########################################################
# checkpsw.sh (C) 2004 Mathias Sundman 
#
# This script will authenticate OpenVPN users against
# a plain text file. The passfile should simply contain
# one row per user with the username first followed by
# one or more space(s) or tab(s) and then the password.

PASSFILE="/etc/openvpn/psw-file"
LOG_FILE="/etc/openvpn/openvpn-password.log"
TIME_STAMP=\`date "+%Y-%m-%d %T"\`

###########################################################

if [ ! -r "\${PASSFILE}" ]; then
  echo "\${TIME_STAMP}: Could not open password file \"\${PASSFILE}\" for reading." >> \${LOG_FILE}
  exit 1
fi

CORRECT_PASSWORD=\`awk '!/^;/&&!/^#/&&\$1=="'\${username}'"{print \$2;exit}' \${PASSFILE}\`
 
if [ "\${CORRECT_PASSWORD}" = "" ]; then 
  echo "\${TIME_STAMP}: User does not exist: username=\"\${username}\", password=\"\${password}\"." >> \${LOG_FILE}    
  exit 1
fi

if [ "\${password}" = "\${CORRECT_PASSWORD}" ]; then 
  echo "\${TIME_STAMP}: Successful authentication: username=\"\${username}\"." >> \${LOG_FILE}
  exit 0
fi

echo "\${TIME_STAMP}: Incorrect password: username=\"\${username}\", password=\"\${password}\"." >> \${LOG_FILE}
exit 1
EOF
fi

cat /etc/openvpn/checkpsw.sh
read -n 1 -p "continue [y/n] > " char
echo 
if [ "$char" = n ];then exit 0;fi

if [ ! -f /etc/openvpn/psw-file ];then
        touch /etc/openvpn/psw-file
        echo "peter    switch-net.com" >> /etc/openvpn/psw-file
        echo "switch-net   switch-net.com" >> /etc/openvpn/psw-file
fi

if [ ! -d /etc/openvpn/ccd ];then
        mkdir /etc/openvpn/ccd
        if [ ! -f /etc/openvpn/ccd/peter ];then
                touch /etc/openvpn/ccd/peter
                touch /etc/openvpn/ccd/switch-net
                echo ifconfig-push 172.18.1.2 255.255.0.0 >> /etc/openvpn/ccd/peter
                echo ifconfig-push 172.18.1.3 255.255.0.0 >> /etc/openvpn/ccd/switch-net
                echo iroute 119.29.29.29 255.255.255.255 >> /etc/openvpn/ccd/switch-net 
        fi
fi

##add script of update-domainlist.sh
if [ ! -d /root/script ];then
        mkdir -p /root/script
        echo $DATE Directory /root/script has been added.
fi

if [ ! -f /root/script/update-domainlist.sh ];then
        touch /root/script/update-domainlist.sh
        chmod +x /root/script/update-domainlist.sh
fi

cat <<'EOF' > /root/script/update-domainlist.sh
#!/bin/sh

DATE=`date +%Y-%m-%d-%H:%M:%S`

if [ ! -d /tmp/smartdns/ ];then
        mkdir -p /tmp/smartdns
fi

#Download the file of China-Domain-List
wget -P /tmp/smartdns/ https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf

if [ ! -f /tmp/smartdns/china.conf ];then
    echo '-----------------------------------------------------------------------------------------' >> /root/script/update.log
    echo $DATE: Domain file download failed, EXIT !   >> /root/script/update.log
    echo '-----------------------------------------------------------------------------------------' >> /root/script/update.log
    exit 1
else
    echo '-----------------------------------------------------------------------------------------' >> /root/script/update.log
    echo $DATE: Domian file download successful.  >> /root/script/update.log

    #Format conversion
    sed -e 's/server=/nameserver /g' -e 's/114.114.114.114/china/g' /tmp/smartdns/china.conf > /tmp/smartdns/address.conf
    cp -a /tmp/smartdns/address.conf /root/script/cndomainlist.conf
    mv -f /tmp/smartdns/address.conf /etc/smartdns/cndomainlist.conf
    echo $DATE: The conversion of the file to a smartDNS .conf format has been completed. >> /root/script/update.log

    # Delete the tmp files
    rm -rf /tmp/smartdns/
    
    domain_number=$(cat /etc/smartdns/cndomainlist.conf | wc -l)
    echo "$DATE: Update domain list from github/felixonmars completely" >> /root/script/update.log
    echo "$DATE: The number of newest domain list is: $domain_number"  >> /root/script/update.log
    echo "$DATE: The number of newest domain list is: $domain_number"
    echo '-----------------------------------------------------------------------------------------' >> /root/script/update.log
    systemctl restart smartdns.service

    exit 0
fi
EOF

if [ -s /root/script/update-domainlist.sh ];then
        cat /root/script/update-domainlist.sh
        echo "----------------------------------------------------------------------------"
        echo $DATE:  The script of update-domainlist has been added
        echo "----------------------------------------------------------------------------"
fi

read -n 1 -p "continue [y/n] > " char
echo
if [ "$char" = n ];then exit 0;fi 

#Create a crontab rule for smartdns
if [ ! -f /var/spool/cron/crontabs/root ];then
        touch /var/spool/cron/crontabs/root
        echo "0 2 * * sun sh /root/script/update-domainlist.sh" >> /var/spool/cron/crontabs/root
        crontab -l
else
        sed -i '/update-domainlist/d' /var/spool/cron/crontabs/root
        sed -i '/update-iplist/d' /var/spool/cron/crontabs/root
        echo "0 2 * * sun sh /root/script/update-domainlist.sh" >> /var/spool/cron/crontabs/root
        crontab -l
fi

read -n 1 -p "continue [y/n] > " char
echo
if [ "$char" = n ];then exit 0;fi

#stop listening udp port 53 by the dns app,and modify the resolve.conf
if lsof -i:53 >>/dev/null;then
        dns_name=$(lsof -i:53 | awk 'NR==2 {print $1}')
        echo port 53 in used by $dns_name,try to release it.
        if [ $dns_name = systemd-r ];then
                sed -i '/DNS=/d' /etc/systemd/resolved.conf
                echo DNS=8.8.8.8 >> /etc/systemd/resolved.conf
                sed -i '/DNSStubListener/d' /etc/systemd/resolved.conf
                echo DNSStubListener=no >> /etc/systemd/resolved.conf
                rm /etc/resolv.conf
                echo nameserver 127.0.0.1 >> /etc/resolv.conf
                echo nameserver 8.8.8.8 >> /etc/resolv.conf
                #ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
                systemctl restart systemd-resolved
                echo The port 53 was released now.
        else
                echo Plz stop $dns_name which use port 53

        fi
else
        sed -i '/DNS=/d' /etc/systemd/resolved.conf
        echo DNS=8.8.8.8 >> /etc/systemd/resolved.conf
        sed -i '/DNSStubListener/d' /etc/systemd/resolved.conf
        echo DNSStubListener=no >> /etc/systemd/resolved.conf
        rm /etc/resolv.conf
        echo nameserver 127.0.0.1 >> /etc/resolv.conf
        echo nameserver 8.8.8.8 >> /etc/resolv.conf
        systemctl start systemd-resolved.service
        echo The port 53 is free.
fi

read -n 1 -p "continue [y/n] > " char
echo
if [ "$char" = n ];then exit 0;fi

#Add smartdns.conf
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
cat /etc/smartdns/smartdns.conf

read -n 1 -p "continue [y/n] > " char
echo
if [ "$char" = n ];then exit 0;fi

#start ovpn-server
systemctl enable openvpn@server.service
systemctl start openvpn@server.service
sleep 1
if lsof -i:1199 >>/dev/null; then
        echo "Openvpn is running"
        sh /root/script/update-domainlist.sh
        systemctl start smartdns.service
        sleep 1
        dn=$(lsof -i:53 | awk 'NR==2 {print $1}')
        if [ $dn=smartdns ];then
                echo "Smartdns is running too."
        else
                echo "Smartdns starts fail"
        fi
else
        echo "Openvpn startup failures,Smartdns waiting for launch"
fi
