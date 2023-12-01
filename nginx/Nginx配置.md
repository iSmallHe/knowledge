# Nginx配置

## 常用命令
```bash
Usage: nginx [-?hvVtTq] [-s signal] [-c filename] [-p prefix] [-g directives]

Options:
  -?,-h         : this help
  -v            : show version and exit
  -V            : show version and configure options then exit
  -t            : test configuration and exit
  -T            : test configuration, dump it and exit
  -q            : suppress non-error messages during configuration testing
  -s signal     : send signal to a master process: stop, quit, reopen, reload
  -p prefix     : set prefix path (default: /usr/share/nginx/)
  -c filename   : set configuration file (default: /etc/nginx/nginx.conf)
  -g directives : set global directives out of configuration file
```


## 示例配置

```nginx
# 以下是全局段配置
#user administrator administrators;  #配置用户或者组，默认为nobody nobody。
#worker_processes 2;  #设置进程数，默认为1
#pid /nginx/pid/nginx.pid; #指定nginx进程运行文件存放地址
error_log log/error.log debug;  #制定日志路径，级别：debug|info|notice|warn|error|crit|alert|emerg
# events段配置信息
events {
    accept_mutex on;   #设置网路连接序列化，防止惊群现象发生，默认为on
    multi_accept on;  #设置一个进程是否同时接受多个网络连接，默认为off
    #use epoll;      #事件驱动模型，select|poll|kqueue|epoll|resig|/dev/poll|eventport
    worker_connections  1024;    #最大连接数，默认为512
}
# http、配置请求信息
http {
    include       mime.types;   #文件扩展名与文件类型映射表
    default_type  application/octet-stream; #默认文件类型，默认为text/plain
    #access_log off; #取消服务日志    
    log_format myFormat '$remote_addr–$remote_user [$time_local] $request $status $body_bytes_sent $http_referer $http_user_agent $http_x_forwarded_for'; #自定义格式
    access_log log/access.log myFormat;  #combined为日志格式的默认值
    sendfile on;   #允许sendfile方式传输文件，默认为off，可以在http块，server块，location块。
    sendfile_max_chunk 100k;  #每个进程每次调用传输数量不能大于设定的值，默认为0，即不设上限。
    keepalive_timeout 65;  #连接超时时间，默认为75s，可以在http，server，location块。


    upstream mysvr {   
      server 127.0.0.1:7878;
      server 192.168.10.121:3333 backup;  #热备
    }
    error_page 404 https://www.baidu.com; #错误页
    # 第一个Server区块开始，表示一个独立的虚拟主机站点
    server {
        keepalive_requests 120; #单连接请求上限次数。
        listen       4545;   #监听端口
        server_name  127.0.0.1;   #监听地址       
        location  ~*^.+$ {       #请求的url过滤，正则匹配，~为区分大小写，~*为不区分大小写。
           #root path;  #根目录
           #index vv.txt;  #设置默认页
           proxy_pass  http://mysvr;  #请求转向mysvr 定义的服务器列表
           deny 127.0.0.1;  #拒绝的ip
           allow 172.18.5.54; #允许的ip           
        } 
    }
}
```

## HTTP

## Server
**参数解析**
|name|description|example|
|---|---|:---|
|listen|监听的端口，后可加 ip 地址、端口或主机名，不加端口时，默认监听 80 端口。|listen 8080;listen 127.0.0.1:8080;listen*:8080|
|server_name|server_name 用于与 http 请求 header 头部的 Host 匹配。注意：后可跟多个主机名，主机名也可使用通匹符|*.test.com|
|location|路径匹配|location /test {}|

## Location

### 匹配规则
```nginx
#语法规则：
location [ = | ~ | ~* | ^~ ] uri { ... }
```

|符号|解释|优先级|
|---|---|:---|
|=|用于标准 URI 前，要求请求字符串与其精准匹配，成功则立即处理，nginx停止搜索其他匹配。|1|
|^~|用于标准 URI 前，并要求一旦匹配到就会立即处理，不再去匹配其他正则 URI，一般用来匹配目录|2|
|~|用于正则 URI 前，表示 URI 包含正则表达式， 区分大小写|3|
|~*|用于正则 URI 前， 表示 URI 包含正则表达式， 不区分大小写|4|
|不带符号|location 后没有参数直接跟着 标准 URI，表示前缀匹配，代表跟请求中的 URI 从头开始匹配。|5|

> 优先级
>1. location =    # 精准匹配
>2. location ^~   # 带参前缀匹配
>3. location ~    # 正则匹配（区分大小写）
>4. location ~*   # 正则匹配（不区分大小写）
>5. location /a   # 普通前缀匹配，优先级低于带参数前缀匹配。
>6. location /    # 任何没有匹配成功的，都会匹配这里处理

location URI结尾带不带 /  
关于 URI 尾部的 / 有三点也需要说明一下。第一点与 location 配置有关，其他两点无关。

1. location 中的字符有没有 / 都没有影响。也就是说 /user/ 和 /user 是一样的。  
2. 如果 URI 结构是 https://domain.com/ 的形式，尾部有没有 / 都不会造成重定向。因为浏览器在发起请求的时候，默认加上了 / 。虽然很多浏览器在地址栏里也不会显示 / 。这一点，可以访问baidu验证一下。  
3. 如果 URI 的结构是 https://domain.com/some-dir/ 。尾部如果缺少 / 将导致重定向。因为根据约定，URL 尾部的 / 表示目录，没有 / 表示文件。所以访问 /some-dir/ 时，服务器会自动去该目录下找对应的默认文件。如果访问 /some-dir 的话，服务器会先去找 some-dir 文件，找不到的话会将 some-dir 当成目录，重定向到 /some-dir/ ，去该目录下找默认文件。可以去测试一下你的网站是不是这样的。  

### root/alias

两者区别：
1. `root`：是直接拼接路径：`root + location`；
2. `alias`：是用`alias`替换`location`；

alias是一个目录别名的定义，root则是最上层目录的定义。  
还有一个重要的区别是alias后面必须要用“/”结束，否则会找不到文件的。而root则可有可无。

#### root

```
location /i/ {
  root /data/w3;
}
```
当请求/i/index.html时，实际指向的路径是：/data/w3/i/index.html

#### alias

```
location /i/ {
  alias /data/w3/;
}
```
当请求/i/index.html时，实际指向的路径是：/data/w3/index.html

### autoindex
>autoindex是Nginx的一个自带模块，它用于在浏览器中展示一个目录列表。当用户访问一个Nginx web服务器下的一个目录而不是一个特定的文件时，autoindex模块会创建一个HTML页面，列出目录下的所有文件及其相关的信息，如文件大小、创建时间、文件类型等。autoindex模块还允许用户对文件进行下载、删除和重命名等操作。

#### 参数

    autoindex on;               #开启目录浏览功能；
    autoindex_exact_size off;   #关闭详细文件大小统计，让文件大小显示MB，GB单位，默认为b；
    autoindex_localtime on;     #开启以服务器本地时区显示文件修改日期！
    autoindex_format html;      #设置列表页以html形式展示，还可使用有xml,json,jsonp
    accept .mp4;                #用于限定允许下载的文件类型

#### 示例
开启autoindex只需要在Nginx配置文件中添加一行autoindex on语句即可：
```nginx
server {
  listen 80;
  server_name localhost;
  root /var/www/html;

  autoindex on;
}
```
除了on之外，还可以设置autoindex为off或exact，默认为exact。
1. 当autoindex为off时，将禁用目录列表功能，页面会返回404错误。
2. 当autoindex为exact时，Nginx将只显示与请求的URI精确匹配的目录，而不是所有子目录。  


### 反向代理

```
server {
    listen       80;
    server_name  localhost;


    location / {
         proxy_pass http://localhost:8081;
         proxy_set_header Host $host:$server_port;#为请求头添加Host字段，用于指定请求服务器的域名/IP地址和端口号。  


         # 设置用户ip地址
         proxy_set_header X-Forwarded-For $remote_addr;#为请求头添加XFF字段，值为客户端的IP地址。
         # 当请求服务器出错去寻找其他服务器
         proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    }
}

```

>1. proxy_pass ：真实服务器的地址，可以是ip也可以是域名和url地址
>2. proxy_set_header：重新定义或者添加发往后端服务器的请求头
>3. proxy_set_header X-Real-IP ：启用客户端真实地址（否则日志中显示的是代理在访问网站）
>4. proxy_set_header X-Forwarded-For：记录代理地址
>5. proxy_connect_timeout：后端服务器连接的超时时间发起三次握手等候响应超时时间
>6. proxy_send_timeout：后端服务器数据回传时间就是在规定时间之内后端服务器必须传完所有的数据
>7. proxy_read_timeout ：nginx接收upstream（上游/真实） server数据超时, 默认60s, 如果连续的60s内没有收到1个字节, 连接关闭。像长连接

## 负载均衡

### 均衡方式

1. 轮询（默认）：每个请求按时间顺序逐一分配到不同的后端服务器，如果后端服务器down掉，能自动剔除。
2. weight（权重）：指定轮询几率，weight和访问比率成正比，用于后端服务器性能不均的情况。
3. ip_hash（IP地址hash）：每个请求按访问ip的hash结果分配，这样每个访客固定访问一个后端服务器，可以解决session的问题。
4. fair（请求时间）：按后端服务器的响应时间来分配请求，响应时间短的优先分配。
4. url_hash（url hash）：按访问url的hash结果来分配请求，使每个url定向到同一个后端服务器，后端服务器为缓存时比较有效。

### 参数

1. `down`：表示单前的server暂时不参与负载
2. `weight`：默认为1.weight越大，负载的权重就越大。
3. `max_fails`：允许请求失败的次数默认为1.当超过最大次数时，返回proxy_next_upstream 模块定义的错误
4. `fail_timeout`：max_fails次失败后，暂停的时间。
5. `backup`：其它所有的非backup机器down或者忙的时候，请求backup机器。所以这台机器压力会最轻。

### 示例
定义上游服务器集群，在反向代理中 proxy_pass 使用，用于负载均衡。如：
```
upstream backend{
    ip_hash;
    server 192.168.0.1;
    server 192.168.0.2:8080;
    server 192.168.0.3 max_fails=5 fail_timeout=30s;
    server 192.168.0.4 down;
}
server {
    location /{
        proxy_pass http://backend;
    }
}
```
当希望某一请求固定到指定上游服务器上，可以在 upstream 块中加 ip_hash 关键字。注意 upstream 块内的 server 使用。server 的具体规则如下：
1. server 后可以是域名、ip 地址或加端口；

2. 当某 server 不使用时，则在后加 down 关键字；

3. 若希望某一服务器处理更多请求，则可以在后加权重 weight ，如 weight = 10，默认值为 1(不能与 ip_hash 同时使用)；

4. 配置在指定时间内失败多少次，服务器不可用，可用配置 fail_timeout(失败时间，默认为 10 秒)，max_fails(失败次数，默认为 1，若为 0，则不检查失败)。
