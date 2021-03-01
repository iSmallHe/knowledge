# communication模块
> communication主要启动两个服务器：SocketTask和KssFaceSocketTask  
> SocketTask：主要用于于网关/非人脸设备通信  
> KssFaceSocketTask：主要用于人脸设备通信  

## SocketTask服务
> 该模块主要是处理与网关通信，所有设备通过与网关连接，接受/发送消息  
> 主要的处理类：
> 1. BaseHandler：用于编码/解码信息message
> 2. GatewayLockHandler：BaseHandler子类，用于处理message的相关业务
> 3. DialDeviceHandler：用于处理拨码设备信息
> 4. DialDeviceNormalHandler：用于处理拨码设备信息
> 5. SecretDeviceHandler：用于处理国密设备信息
> 6. GatewayDeviceHandler：用于处理网关连接
> 7. GatewayAtHandler：用于处理网关信息  

### 接收设备推送消息
接收消息流程：  
```flow
st=>start: 开始
op=>operation: GatewayLockHandler根据message获取相应Handler
cond=>condition: Handler不为空
op1=>operation: messageParse解析消息
op2=>operation: execute执行主要的业务
cond1=>condition: 判断是否需要断开连接
op3=>operation: 1.Tio断开连接;2.cache缓存移除
e=>end: 结束

st->op->cond
cond(yes)->op1->op2->cond1
cond(no)->e
cond1(yes)->op3->e
cond1(no)->e
```
> 其中主要的逻辑处理：
> 1. 获取handler;
> 2. 解析消息;
> 3. 执行业务流程;
> 4. 断开连接，清除缓存。sleep的作用是让网关延迟重连，防止连接过快，网关重连时不发送首次连接指令。
#### 获取handler
根据message获取相应handler  
1. `message[0] == 0xFFFFFFEA && message.length == 0x49 && message[message.length - 1] == 0x59`，返回拨码设备处理器(DialDeviceHandler)
2. `message[0] == 0xFFFFFFEA && message.length == 0x15 && message[message.length - 1] == 0x59`，返回普通拨码设备处理器(DialDeviceNormalHandler)
3. `message[0] == 0xFFFFFFA5 && message[(0 + message[1]) - 1] == 0x5A`，返回国密设备处理器(SecretDeviceHandler)
4. `message.length == 0x0E` ，并且前6个字节=(FA071302FA02)，后2个字节=(FAFF)，返回网关连接处理器(GatewayDeviceHandler)。注：中间6个字节属于网关编码
5. `message.length >= 0x49`，此处是未加密信息处理，返回拨码设备处理器(DialDeviceHandler)
6. 如果字节信息message中包含0x2B----0x0D0A，返回网关信息处理器(GatewayAtHandler)
7. 返回null

#### 解析消息
* DialDeviceHandler  
消息解析为对象DialPacket，判断网关是否绑定  
已绑定：将设备信息放入redis中。获取网关redis缓存，如果缓存心跳不存在或超时，则设置网关心跳为当前时间，mq推送异步消息(A)  
未绑定：GatewayUtil的cache中缓存当前channel的hashcode及当前时间，如果已缓存，则设置删除标志位为true  
* DialDeviceNormalHandler  
判断message[3] != 0xFF，将消息解析为DialNormalPacket/DialPushPacket，判断网关是否绑定    
已绑定：将设备信息放入redis中。获取网关redis缓存，如果缓存心跳不存在或超时，则设置网关心跳为当前时间，mq推送异步消息(A)  
未绑定：GatewayUtil的cache中缓存当前channel的hashcode及当前时间，如果已缓存，则设置删除标志位为true  
* SecretDeviceHandler  
将message解析为SecretPacket，判断网关是否绑定    
已绑定：将设备信息放入redis中。获取网关redis缓存，如果缓存心跳不存在或超时，则设置网关心跳为当前时间，mq推送异步消息(A)  
未绑定：GatewayUtil的cache中缓存当前channel的hashcode及当前时间，如果已缓存，则设置删除标志位为true  
* GatewayDeviceHandler  
解析message获取gatewayCode，如果网关编码不为空，则将网关信息缓存至redis中。  
Tio绑定网关gatewayCode-channelContext
* GatewayAtHandler  
记录网关信息至redis缓存  
#### 业务处理
* DialDeviceHandler  
判断当前message指令类型，进行对应指令的逻辑处理。指令：远程开门；修改rootSecretKey；同步时钟；获取信息...等等  
* DialDeviceNormalHandler  
判断消息类型  
非推送消息：即服务器主动向设备发送指令，设备响应结果信息。此时设备返回的是拨码锁的开关信息，锁舌状态，磁锁状态  
推送消息：设备主动推送消息。判断设备推送消息类型，查询设备信息，mq推送统计在线机器。告警Map中存储的是需要记录的告警类型，判断该消息是否为告警信息且需要记录警告，需要则记录告警信息到数据库，并推送消息给拥有设备权限的用户。如非告警信息，判断消息如果是远程开门，则记录开门记录   
* SecretDeviceHandler  
判断当前message指令类型，进行对应指令的逻辑处理。  
* GatewayDeviceHandler  
mq推送网关信息  
* GatewayAtHandler  
解析网关指令信息，根据不同类型信息进行相应处理。指令类型：告警，查询，设置告警电压，校正，设置上传周期应答，电压定时上报  

### 其他
#### (A)mq推送异步消息 
> GatewayConfig.EXCHANGE  
> 此处主要处理的是
> 1. 判断网关是否为断线的网关，是的话直接推送未连接网关信息
> 2. 当前网关非断线，网关ip是否需要重置，收集所有的新注册网关的未超时的设备，向所有连接的websocket客户端推送新注册网关及网关下设备编码信息  

## KssFaceSocketTask服务
> 该服务主要用于人脸设备通信，主要通信解析流程已由com.facesdk.jar封装完成，仅需判断返回信息类型，进行相应业务处理。
> 主要的处理类：
> 1. BaseHandler：用于编码/解码信息message
> 2. Handler：BaseHandler子类，用于处理message的相关业务
> 3. KssFaceUtil：主要用于处理 设备注册，心跳，开门记录，人脸授权等业务
> 4. MqUtil：信息推送至websocket模块进行处理

### 人脸设备接受消息
1. 更新redis中设备缓存信息
2. 分析指令类型，根据类型，进行相应的业务处理  
    2.1. 设备注册：将设备信息缓存至redis，Tio绑定channel，并响应设备信息  
    2.2. 心跳：接受心跳，并响应设备信息  
    2.3. 开门记录回调：判断开门成功/失败，失败的具体原因，填充开门信息然后保存  
    2.4. 人脸授权回调：  
    2.5. 设置人脸参数回调：  
