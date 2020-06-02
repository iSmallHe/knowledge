# centos7.8 学习过程
## 常用命令

### 连接wifi
1. 连接wifi命令：wpa_supplicant -B -i wlp2s0 -c <(wpa_passphrase "WiFi账号" "WiFi密码")
2. 查看ip ： ip addr
3. 设置ip地址：dhclient wlp2s0(本地网卡)

### 防火墙
1. 防火墙配置文件地址：/etc/sysconfig/iptables
2. 重启防火墙命令：service iptables restart

### 启动web
1. 启动java项目：nohup java -jar filename > logfile &

### 解决问题-中文乱码问题
1. 首先解决字体安装
2. yum groupinstall "fonts"
3. vim /etc/locale.conf
4. LANG="zh_CN.UTF-8"