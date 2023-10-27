# centos7.8 学习过程

## 查看ip

```bash
ifconfig -a
```

## 连接wifi

    1. 连接wifi命令：wpa_supplicant -B -i wlp2s0 -c <(wpa_passphrase "WiFi账号" "WiFi密码")
    2. 查看ip ： ip addr
    3. 设置ip地址：dhclient wlp2s0(本地网卡)

## 防火墙

    1. 防火墙配置文件地址：/etc/sysconfig/iptables
    2. 重启防火墙命令：service iptables restart

## 启动web

    1. 启动java项目：nohup java -jar filename > logfile &

## 中文乱码

    1. 首先解决字体安装
    2. yum groupinstall "fonts"
    3. vim /etc/locale.conf
    4. LANG="zh_CN.UTF-8"

## 解压

```bash
tar -zxvf 
```

## jdk
```bash
export JAVA_HOME=/usr/dev/java/jdk1.8.0_271
export PATH=$JAVA_HOME/bin:$PATH
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
```

## 指令echo
```bash
echo 'export JAVA_HOME=/usr/dev/java/jdk1.8.0_271' >> /etc/profile
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile
echo 'export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar' >> /etc/profile
```

## 查看端口

```bash
netstat -tunlp|grep 22
```


## tail 
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

## vim
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


## 内存使用

```bash
free -m
```
    free [-bkmotV][-s <间隔秒数>]

        -b 　以Byte为单位显示内存使用情况。
        -k 　以KB为单位显示内存使用情况。
        -m 　以MB为单位显示内存使用情况。
        -h 　以合适的单位显示内存使用情况，最大为三位数，自动计算对应的单位值
        -o 　不显示缓冲区调节列。
        -s   <间隔秒数>持续观察内存使用状况。
        -t 　显示内存总和列。
        -V 　显示版本信息。


## 下载文件

```bash
wget url
```

## 文件权限
    chmod [-cfvR] [--help] [--version] mode file...
    -c:若该文件权限已经更改，才显示更改动作
    -f:若文件权限无法更改也不要显示错误讯息
    -v:显示权限变更的详细信息
    -R:递归授权
    mode = [ugoa...][[+-=][rwxX]...][,...]
    u:文件所有者
    g:文件所有者所在组
    o:other其他用户
    a:all所有用户

    +:增加授权
    -:去除授权
    =:重置后再授权

    r:读
    w:写
    x:执行
    X:特殊执行权限。只有当文件为目录文件，或者其他类型的用户有可执行权限时，才将文件权限设置可执行

    eg:chmod u+r,g+w,o+x filename
    eg:chmod 711 filename = chmod u+rwx,go+r filename

## 使用空间
    du [-abcDhHklmsSx][-L <符号连接>][-X <文件>][--block-size][--exclude=<目录或文件>][--max-depth=<目录层数>][--help][--version][目录或文件]

## 系统进程
    top [-] [d delay] [q] [c] [S] [s] [i] [n] [b]

        d : 改变显示的更新速度，或是在交谈式指令列( interactive command)按 s
        q : 没有任何延迟的显示速度，如果使用者是有 superuser 的权限，则 top 将会以最高的优先序执行
        c : 切换显示模式，共有两种模式，一是只显示执行档的名称，另一种是显示完整的路径与名称
        S : 累积模式，会将己完成或消失的子行程 ( dead child process ) 的 CPU time 累积起来
        s : 安全模式，将交谈式指令取消, 避免潜在的危机
        i : 不显示任何闲置 (idle) 或无用 (zombie) 的行程
        n : 更新的次数，完成后将会退出 top
        b : 批次档模式，搭配 "n" 参数一起使用，可以用来将 top 的结果输出到档案内


## touch
    修改文件的时间属性（存取时间），若文件不存在则新建文件。  

    touch [-acfm][-d<日期时间>][-r<参考文件或目录>] [-t<日期时间>][--help][--version][文件或目录…]

        a 改变档案的读取时间记录。
        m 改变档案的修改时间记录。
        c 假如目的档案不存在，不会建立新的档案。与 --no-create 的效果一样。
        f 不使用，是为了与其他 unix 系统的相容性而保留。
        r 使用参考档的时间记录，与 --file 的效果一样。
        d 设定时间与日期，可以使用各种不同的格式。
        t 设定档案的时间记录，格式与 date 指令相同。
        --no-create 不会建立新档案。
        --help 列出指令格式。
        --version 列出版本讯息。

## 启动

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
