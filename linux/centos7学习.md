# centos7.8 学习过程
## 常用命令

### 查看ip
1. ifconfig -a

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

### 解压
tar -zxvf 

### tail 
tail [ -f ] [ -c Number | -n Number | -m Number | -b Number | -k Number ] [ File ]
参数解释：
-f 该参数用于监视File文件增长。
-c Number 从 Number 字节位置读取指定文件
-n Number 从 Number 行位置读取指定文件。
-m Number 从 Number 多字节字符位置读取指定文件，比方你的文件假设包括中文字，假设指定-c参数，可能导致截断，但使用-m则会避免该问题。
-b Number 从 Number 表示的512字节块位置读取指定文件。
-k Number 从 Number 表示的1KB块位置读取指定文件。
File 指定操作的目标文件名称
上述命令中，都涉及到number，假设不指定，默认显示10行。Number前面可使用正负号，表示该偏移从顶部还是从尾部開始计算。
tail可运行文件一般在/usr/bin/以下。

1、tail -f filename
说明：监视filename文件的尾部内容（默认10行，相当于增加参数 -n 10），刷新显示在屏幕上。退出，按下CTRL+C。

2、tail -n 20 filename
说明：显示filename最后20行。

3、tail -r -n 10 filename
说明：逆序显示filename最后10行。

补充：
跟tail功能相似的命令还有：
cat 从第一行開始显示档案内容。
tac 从最后一行開始显示档案内容。
more 分页显示档案内容。
less 与 more 相似，但支持向前翻页
head 仅仅显示前面几行
tail 仅仅显示后面几行
n 带行号显示档案内容
od 以二进制方式显示档案内容

### vim
* 命令模式→输入模式：
　　　　　i：在当前光标所在字符的前面，转为输入模式
　　　　　I：在当前光标所在行的行首转换为输入模式
　　　　　a：在当前光标所在字符的后面，转为输入模式
　　　　　A：在光标所在行的行尾，转换为输入模式
　　　　　o：在当前光标所在行的下方，新建一行，并转为输入模式
　　　　　O：在当前光标所在行的上方，新建一行，并转为输入模式
　　　　　s：删除光标所在字符
　　　　　r：替换光标处字符
* 输入模式→命令模式
　　　　　ESC键
* 命令模式→末行模式
　　　　　输入：即可 转为末行模式
* 复制
　　　　　在光标处按V键，按方向键选择待复制内容，选择完毕后按Y键，然后光标移向待放置处按P键
* 剪切
　　　　　在光标处按V键，按方向键选择待复制内容，选择完毕后按D键，然后光标移向待放置处按P键
### jdk
export JAVA_HOME=/usr/dev/java/jdk1.8.0_271
export PATH=$JAVA_HOME/bin:$PATH
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar

### 指令echo
> echo 'export JAVA_HOME=/usr/dev/java/jdk1.8.0_271' >> /etc/profile
> echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile
> echo 'export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar' >> /etc/profile

### 查看端口
netstat -tunlp|grep 22

### 查看内存使用
free -m



http://123.56.227.113:8848/
118.178.127.216
centos安装nginx：https://www.cnblogs.com/boonya/p/7907999.html

export PATH=$PATH:/usr/dev/rabbitmq/rabbitmq_server-3.8.9/sbin
### system
nohup java -jar -Xms256m -Xmx256m -Dspring.profiles.active=xiaohe /usr/dev/winseco/system/system-web-0.0.1-SNAPSHOT.jar >  /usr/dev/winseco/system/nohup.out 2>&1 &

tail -f 100 /usr/dev/winseco/system/nohup.out

### smartlock
nohup java -jar -Xms256m -Xmx256m -Dspring.profiles.active=xiaohe -Dserver.port=8090 /usr/dev/winseco/smart/smartlock-web-0.0.1-SNAPSHOT.jar > /usr/dev/winseco/smart/nohup.out 2>&1 &

tail -f 100 /usr/dev/winseco/smart/nohup.out

### websocket
nohup java -jar -Xms128m -Xmx128m -Dspring.profiles.active=xiaohe /usr/dev/winseco/websocket/winseco-websocket-0.0.1-SNAPSHOT.jar > /usr/dev/winseco/websocket/nohup.out 2>&1 &

tail -f 100 /usr/dev/winseco/websocket/nohup.out

### communication
nohup java -jar -Xms200m -Xmx200m -Dspring.profiles.active=xiaohe /usr/dev/winseco/communication/communication-service-0.0.1-SNAPSHOT.jar > /usr/dev/winseco/communication/nohup.out 2>&1 &

tail -f 100 /usr/dev/winseco/communication/nohup.out

### gateway
nohup java -jar -Xms128m -Xmx128m -Dspring.profiles.active=xiaohe /usr/dev/winseco/gateway/winseco-gateway-0.0.1-SNAPSHOT.jar > /usr/dev/winseco/gateway/nohup.out 2>&1 & 

tail -f 100 /usr/dev/winseco/gateway/nohup.out

### attendance
nohup java -jar -Xms128m -Xmx128m -Dspring.profiles.active=xiaohe /usr/dev/winseco/attendance/attendance-web-0.0.1-SNAPSHOT.jar > /usr/dev/winseco/attendance/nohup.out 2>&1 & 

tail -f 100 /usr/dev/winseco/attendance/nohup.out
