# nacos

## 1.官方文档
[nacos官方文档](https://nacos.io/zh-cn/)

## 2.nacos地图
![nacos地图](../../../image/nacosMap.jpg)

## 3.Nacos Spring Cloud
nacos主要功能分为两大块：Nacos Config(动态配置)，Nacos Discovery(服务注册与发现)
* 通过Nacos Server 和 spring-cloud-starter-alibaba-nacos-config 实现配置的动态变更
* 通过Nacos Server 和 spring-cloud-starter-alibaba-nacos-discovery 实现服务的注册与发现

### 3.1 Nacos Config

#### 3.1.1 依赖
```
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
    <version>${latest.version}</version>
</dependency>
```
> 版本 2.1.x.RELEASE 对应的是 Spring Boot 2.1.x 版本。  
> 版本 2.0.x.RELEASE 对应的是 Spring Boot 2.0.x 版本。 
> 版本 1.5.x.RELEASE 对应的是 Spring Boot 1.5.x 版本。 

#### 3.1.2 参数配置
```
spring.cloud.nacos.config.server-addr=127.0.0.1:8848
spring.application.name=example
```
> `spring.application.name` 是构成nacos配置管理`dataId`字段的一部分  
> `dataId` 的完整格式：`${prefix}-${spring.profile.active}.${file-extension}`

* `prefix` 默认为 `spring.application.name` ，也可通过配置 `spring.cloud.nacos.config.prefix` 来另行设置。
* `spring.profile.active` 即为当前的环境对应的profile，当 `spring.profile.active` 为空时，则连接符 `-` 也不存在。`dataId` 的拼接格式变成 `${prefix}.${file-extension}` 。
* `file-extension` 即为配置文件的数据格式，可通过配置项 `spring.cloud.nacos.config.file-extension` 来配置。目前仅支持`yaml` 和 `properties` 两种格式。

<font color='#43CD80'>配置参数可通过原生注解 `@RefreshScope` 来实现自动更新</font>

#### 3.1.3  使用
1. 启动nacos server，并增加配置文件，如下：
```
Data ID:    nacos-config.properties

Group  :    DEFAULT_GROUP

配置格式:    Properties

配置内容：   user.name=nacos-config-properties
            user.age=90
```
2. 客户端添加依赖，参数配置  
<font color='#43CD80'>主要的配置参数必须使用 `bootstrap.properties` 配置文件</font>
```
spring.application.name=nacos-config
spring.cloud.nacos.config.server-addr=127.0.0.1:8848
```
> 当使用域名配置Nacos Server的时候，必须要加上端口号，配置方式：`域名:port`  
> 你可以通过配置 `spring.cloud.nacos.config.refresh.enabled=false` 来关闭动态刷新  
> `${spring.profiles.active}` 当通过配置文件来指定时必须放在 `bootstrap.properties` 文件中。 

#### 3.1.4 namespace
> 1. 不同的命名空间下，可以存在相同的group和dataId的配置。namespace的常用场景之一是不同环境的区分隔离，例如开发测试环境和生产环境的资源隔离等  
> 2. 命名空间的配置使用 `spring.cloud.nacos.config.namespace` 来控制，默认的情况下使用的是Nacos的Public这个命名空间。  
> 3. 该配置必须放在 bootstrap.properties

#### 3.1.5 group
> 在没有明确指定group的情况下，默认是DEFAULT_GROUP。也可通过配置 `spring.cloud.nacos.config.group` 来控制  
> 该配置必须放置在bootstrap.properties

#### 3.1.6 扩展
<font color='#43CD80'>nacos支持自定义扩展的DataId配置</font>
```properties
spring.application.name=opensource-service-provider
spring.cloud.nacos.config.server-addr=127.0.0.1:8848

# config external configuration
# 1、Data Id 在默认的组 DEFAULT_GROUP,不支持配置的动态刷新
spring.cloud.nacos.config.extension-configs[0].data-id=ext-config-common01.properties

# 2、Data Id 不在默认的组，不支持动态刷新
spring.cloud.nacos.config.extension-configs[1].data-id=ext-config-common02.properties
spring.cloud.nacos.config.extension-configs[1].group=GLOBALE_GROUP

# 3、Data Id 既不在默认的组，也支持动态刷新
spring.cloud.nacos.config.extension-configs[2].data-id=ext-config-common03.properties
spring.cloud.nacos.config.extension-configs[2].group=REFRESH_GROUP
spring.cloud.nacos.config.extension-configs[2].refresh=true
```  

> 多个 Data Id 同时配置时，他的优先级关系是 spring.cloud.nacos.config.extension-configs[n].data-id 其中 n 的值越大，优先级越高。   
> `spring.cloud.nacos.config.extension-configs[n].data-id` 的值必须带文件扩展名，文件扩展名支持 properties/yaml/yml。  
> `spring.cloud.nacos.config.file-extension` 的配置对自定义扩展配置的 Data Id 文件扩展名没有影响  

<font color='#43CD80'>为了更加清晰的在多个应用间配置共享的 Data Id ，你可以通过以下的方式来配置</font>  

```properties
# 配置支持共享的 Data Id
spring.cloud.nacos.config.shared-configs[0].data-id=common.yaml

# 配置 Data Id 所在分组，缺省默认 DEFAULT_GROUP
spring.cloud.nacos.config.shared-configs[0].group=GROUP_APP1

# 配置Data Id 在配置变更时，是否动态刷新，缺省默认 false
spring.cloud.nacos.config.shared-configs[0].refresh=true
```

#### 3.1.7 配置优先级
<font color='#43CD80'>spring cloud alibaba nacos config目前提供了三种配置能力从nacos拉取配置</font>
1. 通过 `spring.cloud.nacos.config.shared-configs[n].data-id` 支持多个共享DataId的配置
2. 通过 `spring.cloud.nacos.config.extension-configs[n].data-id` 的方式支持多个扩展DataId的配置
3. 通过内部相关规则(应用名，应用名+Profile)自动生成相关的DataId配置
<font color='#43CD80'>三种配置的优先级关系: `1<2<3` </font>

#### 3.1.8 关闭
<font color='#43CD80'>通过设置 `spring.cloud.nacos.config.enabled = false` 来完全关闭 Spring Cloud Nacos Config</font>


### 3.2 Nacos Discovery

#### 3.2.1 依赖
```
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    <version>${latest.version}</version>
</dependency>
```
> 版本 2.1.x.RELEASE 对应的是 Spring Boot 2.1.x 版本。  
> 版本 2.0.x.RELEASE 对应的是 Spring Boot 2.0.x 版本。  
> 版本 1.5.x.RELEASE 对应的是 Spring Boot 1.5.x 版本。  

#### 3.2.2 参数配置
1. 配置nacos server地址：`spring.cloud.nacos.discovery.server-addr=127.0.0.1:8848`
2. 在启动类上添加注解 `@EnableDiscoveryClient` ，开启服务注册与发现