# sentinel

## 1 简单使用
### 1.1 依赖
```xml
<dependency>
    <groupId>com.alibaba.csp</groupId>
    <artifactId>sentinel-core</artifactId>
    <version>1.7.2</version>
</dependency>
```

### 1.2 定义资源
* 方式一：通过代码块定义资源
```java
public static void main(String[] args) {
    // 配置规则.
    initFlowRules();

    while (true) {
        // 1.5.0 版本开始可以直接利用 try-with-resources 特性
        try (Entry entry = SphU.entry("HelloWorld")) {
            // 被保护的资源逻辑
            System.out.println("hello world");
        } catch (BlockException ex) {
                // 处理被流控的逻辑
            System.out.println("blocked!");
        }
    }
}
```
* 方式二：通过注解定义资源
```java
@SentinelResource("HelloWorld")
public void helloWorld() {
    // 资源中的逻辑
    System.out.println("hello world");
}
```

### 1.3 定义规则
```java
//通过流控规则来限制资源的请求
private static void initFlowRules(){
    List<FlowRule> rules = new ArrayList<>();
    FlowRule rule = new FlowRule();
    //定义资源helloword的规则
    rule.setResource("HelloWorld");
    //每秒最多只能通过 20 个请求
    rule.setGrade(RuleConstant.FLOW_GRADE_QPS);
    // Set limit QPS to 20.
    rule.setCount(20);
    rules.add(rule);
    FlowRuleManager.loadRules(rules);
}
```

### 1.4 LOG日志
运行过程中，LOG日志的记录格式：
```log
|--timestamp-|------date time----|--resource-|p |block|s |e|rt
1529998904000|2018-06-26 15:41:44|hello world|20|0    |20|0|0
1529998905000|2018-06-26 15:41:45|hello world|20|5579 |20|0|728
1529998906000|2018-06-26 15:41:46|hello world|20|15698|20|0|0
1529998907000|2018-06-26 15:41:47|hello world|20|19262|20|0|0
1529998908000|2018-06-26 15:41:48|hello world|20|19502|20|0|0
1529998909000|2018-06-26 15:41:49|hello world|20|18386|20|0|0
```
* p：表示pass(通过)的请求数量
* block：表示拦截的请求数量
* s：表示执行完成的请求数量
* e：表示用户自定义的异常
* rt：表示平均响应时间

## 2 详细教程

### 2.1 资源与规则

#### 2.1.1 定义资源

1. **方式一：主流框架的默认适配**
    暂不描述

2. **方式二：抛出异常的方式定义资源**
当资源发生限流时会抛出异常BlockException
```java
// 1.5.0 版本开始可以利用 try-with-resources 特性
// 资源名可使用任意有业务语义的字符串，比如方法名、接口名或其它可唯一标识的字符串。
try (Entry entry = SphU.entry("resourceName")) {
  // 被保护的业务逻辑
  // do something here...
} catch (BlockException ex) {
  // 资源访问阻止，被限流或被降级
  // 在此处进行相应的处理操作
}

//1.5.0 之前的版本的示例
Entry entry = null;
// 务必保证finally会被执行
try {
  // 资源名可使用任意有业务语义的字符串
  entry = SphU.entry("自定义资源名");
  // 被保护的业务逻辑
  // do something...
} catch (BlockException e1) {
  // 资源访问阻止，被限流或被降级
  // 进行相应的处理操作
} finally {
  if (entry != null) {
    entry.exit();
  }
}
```

3. **方式三：返回布尔值方式定义资源**

```java
  // 资源名可使用任意有业务语义的字符串
  if (SphO.entry("自定义资源名")) {
    // 务必保证finally会被执行
    try {
      /**
      * 被保护的业务逻辑
      */
    } finally {
      SphO.exit();
    }
  } else {
    // 资源访问阻止，被限流或被降级
    // 进行相应的处理操作
  }
```

4. **方式四：注解方式定义资源**
```java
// 原本的业务方法.
@SentinelResource(blockHandler = "blockHandlerForGetUser")
public User getUserById(String id) {
    throw new RuntimeException("getUserById command failed");
}

// blockHandler 函数，原方法调用被限流/降级/系统保护的时候调用
public User blockHandlerForGetUser(String id, BlockException ex) {
    return new User("admin");
}
```
> `bloackHandler` 所指向的方法会在资源被限流/降级/系统保护的情况下调用，而`fallback`指向的方法会针对所有类型的异常。  
> [Sentinel注解支持文档](https://sentinelguard.io/zh-cn/docs/annotation-support.html)  

5. **方式五：异步调用支持**
Sentinel支持异步调用链路统计
```java
try {
    AsyncEntry entry = SphU.asyncEntry(resourceName);

    // 异步调用.
    doAsync(userId, result -> {
        try {
            // 在此处处理异步调用的结果.
        } finally {
            // 在回调结束后 exit.
            entry.exit();
        }
    });
} catch (BlockException ex) {
    // Request blocked.
    // Handle the exception (e.g. retry or fallback).
}
```

#### 2.1.2 规则
Sentinel所有的规则可以动态修改，并且实时生效。  
<font color='#43CD80'>同一个资源可以同时有多个限流规则</font>  

**Sentinel的规则：**

##### 2.1.2.1 流量控制规则(FlowRule)

***重要属性：***

|Field|说明|默认值|
|:---:|:---|:---|
|resource|资源名，资源名是限流规则的作用对象||
|count|限流阈值||
|grade|限流阈值类型：QPS 或线程数模式|QPS|
|limitApp|流控针对的调用来源|`default`表示不区分来源|
|strategy|调用关系限流策略：直接、链路、关联|根据资源本身（直接）|
|controlBehavior|流控效果（直接拒绝 / 排队等待 / 慢启动模式），不支持按调用关系限流|直接拒绝|


```java
private static void initFlowQpsRule() {
    List<FlowRule> rules = new ArrayList<>();
    FlowRule rule1 = new FlowRule();
    rule1.setResource(resource);
    // Set max qps to 20
    rule1.setCount(20);
    rule1.setGrade(RuleConstant.FLOW_GRADE_QPS);
    rule1.setLimitApp("default");
    rules.add(rule1);
    FlowRuleManager.loadRules(rules);
}
```

[更多流量控制规则](https://sentinelguard.io/zh-cn/docs/flow-control.html)

##### 2.1.2.2 熔断降级规则(DegradeRule)

***重要属性：***

|Field|说明|默认值|
|:---:|:---|:---|
|resource|资源名，即限流规则的作用对象||
|count|阈值||
|grade|熔断策略，支持秒级 RT/秒级异常比例/分钟级异常数|秒级平均 RT|
|timeWindow|降级的时间，单位为 s||

```java
 private static void initDegradeRule() {
        List<DegradeRule> rules = new ArrayList<>();
        DegradeRule rule = new DegradeRule();
        rule.setResource(KEY);
        // set threshold rt, 10 ms
        rule.setCount(10);
        rule.setGrade(RuleConstant.DEGRADE_GRADE_RT);
        rule.setTimeWindow(10);
        rules.add(rule);
        DegradeRuleManager.loadRules(rules);
    }
```

[更多熔断降级规则](https://sentinelguard.io/zh-cn/docs/circuit-breaking.html)

##### 2.1.2.3 系统保护规则(SystemRule)

***重要属性：***

|Field|说明|默认值|
|:---:|:---|:---|
|highestSystemLoad|`load1`阈值，参考值|-1 (不生效)|
|avgRt|所有入口流量的平均响应时间|-1 (不生效)|
|maxThread|入口流量的最大并发数|-1 (不生效)|
|qps|所有入口资源的 QPS|-1 (不生效)|
|highestCpuUsage|当前系统的 CPU 使用率（0.0-1.0）|-1 (不生效)|

```java
private void initSystemProtectionRule() {
  List<SystemRule> rules = new ArrayList<>();
  SystemRule rule = new SystemRule();
  rule.setHighestSystemLoad(10);
  rules.add(rule);
  SystemRuleManager.loadRules(rules);
}
```

[系统自适应保护](https://sentinelguard.io/zh-cn/docs/system-adaptive-protection.html)

##### 2.1.2.4 来源访问控制规则(AuthorityRule)
很多时候我们需要根据调用方来限制资源是否通过，这时候可以使用Sentinel的访问控制(黑白名单)的功能。黑白名单根据资源的请求来源(origin)限制资源是否通过，若配置白名单则只有请求来源位于白名单中才可访问；若配置黑名单，则请求来源位于黑名单中，不可访问。  
***配置项：***
1. `resource`：资源名，即限流规则的作用对象
2. `limitApp`：对应的黑/白名单，不同origin之间用`,`分隔
3. `strategy`：限制模式：`AUTHORITY_WHITE` 白名单，`AUTHORITY_BLACK` 黑名单。默认为白名单模式

[更多来源访问控制](https://sentinelguard.io/zh-cn/docs/origin-authority-control.html)


##### 2.1.2.5 热点参数规则(ParamFlowRule)
[热点参数限流规则](https://sentinelguard.io/zh-cn/docs/parameter-flow-control.html)

#### 2.1.3 其他

* **判断限流降级异常**
`BlockException.isBlockException(Throwable t)`

* **Block事件**
> Sentinel 提供以下扩展接口，可以通过 StatisticSlotCallbackRegistry 向 StatisticSlot 注册回调函数：
> 1. ProcessorSlotEntryCallback：passed / blocked 
> 2. ProcessorSlotExitCallback：completed 

* **业务异常统计Tracer**

* **上下文工具类ContextUtil**
1. 标识进入调用链入口（上下文）：  
`public static Context enter(String contextName)`  
`public static Context enter(String contextName, String origin)`
2. 退出调用链（清空上下文）：  
`public static void exit()`
3. 获取当前线程的调用链上下文： 
`public static Context getContext()`
4. 在某个调用链上下文中执行代码：  
`public static void runOnContext(Context context, Runnable f)`

* **sentinel-dashboard**
1. 运行sentinel-dashboard的jar包：  
`java -Dserver.port=9090 -Dcsp.sentinel.dashboard.server=localhost:9090 -Dproject.name=sentinel-dashboard -jar sentinel-dashboard-1.7.2.jar`
2. 客户端需要在配置文件中添加配置连接dashboard：  
`spring.cloud.sentinel.transport.port=8719`  
`spring.cloud.sentinel.transport.dashboard=localhost:9090`  
3. 由于sentinel-dashboard是懒加载模式，只有客户端接口被请求时，才会加载到控制台中