# LOG4J

## 配置文件
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- Log4j 2.x 配置文件。每30秒自动检查和应用配置文件的更新； -->
<configuration status="OFF" monitorInterval="30" strict="true">
    <Properties>
        <Property name="MODULE">${bundle:bootstrap:spring.application.name}</Property>
        <Property name="LOG_HOME">logs/${MODULE}/</Property>
        <Property name="LOG_LEVEL">DEBUG</Property>
        <property name="CHARSET">UTF-8</property>
        <property name="INCLUDE_LOCATION">true</property>
        <property name="LOG_PATTERN"
                  value="[%d{yyyy-MM-dd HH:mm:ss:SSS}] - [%-5level] - [%logger{36} %L %M] - [%t] %msg%xEx%n"/>
    </Properties>

    <appenders>
        <console name="Console" target="SYSTEM_OUT">
            <!--只接受程序中DEBUG级别的日志进行处理 -->
            <ThresholdFilter level="TRACE" onMatch="ACCEPT"
                             onMismatch="DENY"/>
            <PatternLayout pattern="${LOG_PATTERN}" charset="${CHARSET}"/>
        </console>

        <RollingRandomAccessFile name="INFO-FILE"
                                 fileName="${LOG_HOME}/info.log"
                                 filePattern="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/info/info-%d{yyyy-MM-dd-HH}-%i.log.zip">
            <!-- 添加过滤器ThresholdFilter,可以有选择的输出某个级别以上的类别  onMatch="ACCEPT" onMismatch="DENY"意思是匹配就接受,否则直接拒绝  -->
            <Filters>
                <!--只接受INFO和INFO以上的日志，其余的全部拒绝处理 -->
                <ThresholdFilter level="warn" onMatch="DENY"
                                 onMismatch="NEUTRAL"/>
                <ThresholdFilter level="info" onMatch="ACCEPT"
                                 onMismatch="DENY"/>
            </Filters>
            <PatternLayout pattern="${LOG_PATTERN}" charset="${CHARSET}"/>
            <Policies>
                <!--根据当前filePattern配置，日志文件每3分钟滚动一次-->
                <TimeBasedTriggeringPolicy/>
                <!--日志文件大于10 MB滚动一次-->
                <SizeBasedTriggeringPolicy size="20 MB"/>
            </Policies>
            <!-- DefaultRolloverStrategy属性如不设置，则默认为最多同一文件夹下7个文件，这里设置了100 -->
            <DefaultRolloverStrategy max="100">
                <Delete basePath="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/info" maxDepth="1">
                    <IfFileName glob="*.log.zip"/>
                    <!--!Note: 这里的age必须和filePattern协调, 后者是精确到dd, 这里就要写成xd, xD就不起作用
                    另外, 数字最好>2, 否则可能造成删除的时候, 最近的文件还处于被占用状态,导致删除不成功!-->
                    <!--365天-->
                    <IfLastModified age="365d"/>
                </Delete>
            </DefaultRolloverStrategy>
        </RollingRandomAccessFile>

        <!--处理DEBUG级别的日志，并把该日志放到logs/应用名称/debug.log文件中 -->
        <!--打印出DEBUG级别日志，每次大小超过size，则这size大小的日志会自动存入按年份-月份建立的文件夹下面并进行压缩，作为存档 -->
        <RollingRandomAccessFile name="DEBUG-FILE"
                                 fileName="${LOG_HOME}/debug.log"
                                 filePattern="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/debug/debug-%d{yyyy-MM-dd-HH}-%i.log.zip">
            <!-- 添加过滤器ThresholdFilter,可以有选择的输出某个级别以上的类别  onMatch="ACCEPT" onMismatch="DENY"意思是匹配就接受,否则直接拒绝  -->
            <Filters>
                <ThresholdFilter level="info" onMatch="DENY"
                                 onMismatch="NEUTRAL"/>
                <ThresholdFilter level="debug" onMatch="ACCEPT"
                                 onMismatch="DENY"/>
            </Filters>
            <PatternLayout pattern="${LOG_PATTERN}" charset="${CHARSET}"/>
            />
            <Policies>
                <!--根据当前filePattern配置，日志文件每3分钟滚动一次-->
                <TimeBasedTriggeringPolicy/>
                <!--日志文件大于10 MB滚动一次-->
                <SizeBasedTriggeringPolicy size="20 MB"/>
            </Policies>
            <!-- DefaultRolloverStrategy属性如不设置，则默认为最多同一文件夹下7个文件，这里设置了100 -->
            <DefaultRolloverStrategy max="100">
                <Delete basePath="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/debug" maxDepth="1">
                    <IfFileName glob="*.log.zip"/>
                    <!--!Note: 这里的age必须和filePattern协调, 后者是精确到dd, 这里就要写成xd, xD就不起作用
                    另外, 数字最好>2, 否则可能造成删除的时候, 最近的文件还处于被占用状态,导致删除不成功!-->
                    <!--365天-->
                    <IfLastModified age="365d"/>
                </Delete>
            </DefaultRolloverStrategy>
        </RollingRandomAccessFile>

        <!--处理WARN级别的日志，并把该日志放到logs/应用名称/warn.log文件中 -->
        <RollingRandomAccessFile name="WARN-FILE"
                                 fileName="${LOG_HOME}/warn.log"
                                 filePattern="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/warn/warn-%d{yyyy-MM-dd-HH}-%i.log.zip">
            <!-- 添加过滤器ThresholdFilter,可以有选择的输出某个级别以上的类别  onMatch="ACCEPT" onMismatch="DENY"意思是匹配就接受,否则直接拒绝  -->
            <Filters>
                <ThresholdFilter level="error" onMatch="DENY"
                                 onMismatch="NEUTRAL"/>
                <ThresholdFilter level="warn" onMatch="ACCEPT"
                                 onMismatch="DENY"/>
            </Filters>
            <PatternLayout pattern="${LOG_PATTERN}" charset="${CHARSET}"/>
            <Policies>
                <!--根据当前filePattern配置，日志文件每3分钟滚动一次-->
                <TimeBasedTriggeringPolicy/>
                <!--日志文件大于10 MB滚动一次-->
                <SizeBasedTriggeringPolicy size="20 MB"/>
            </Policies>
            <!-- DefaultRolloverStrategy属性如不设置，则默认为最多同一文件夹下7个文件，这里设置了100 -->
            <DefaultRolloverStrategy max="100">
                <Delete basePath="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/warn" maxDepth="1">
                    <IfFileName glob="*.log.zip"/>
                    <!--!Note: 这里的age必须和filePattern协调, 后者是精确到dd, 这里就要写成xd, xD就不起作用
                    另外, 数字最好>2, 否则可能造成删除的时候, 最近的文件还处于被占用状态,导致删除不成功!-->
                    <!--365天-->
                    <IfLastModified age="365d"/>
                </Delete>
            </DefaultRolloverStrategy>
        </RollingRandomAccessFile>

        <!--处理error级别的日志，并把该日志放到logs/应用名称/error.log文件中 -->
        <RollingRandomAccessFile name="ERROR-FILE"
                                 fileName="${LOG_HOME}/error.log"
                                 filePattern="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/error/error-%d{yyyy-MM-dd-HH}-%i.log.zip">
            <!-- 添加过滤器ThresholdFilter,可以有选择的输出某个级别以上的类别  onMatch="ACCEPT" onMismatch="DENY"意思是匹配就接受,否则直接拒绝  -->
            <Filters>
                <ThresholdFilter level="ERROR" onMatch="ACCEPT"
                                 onMismatch="DENY"/>
            </Filters>
            <PatternLayout pattern="${LOG_PATTERN}" charset="${CHARSET}"/>
            <Policies>
                <!--根据当前filePattern配置，日志文件每3分钟滚动一次-->
                <TimeBasedTriggeringPolicy/>
                <!--日志文件大于10 MB滚动一次-->
                <SizeBasedTriggeringPolicy size="20 MB"/>
            </Policies>
            <!-- DefaultRolloverStrategy属性如不设置，则默认为最多同一文件夹下7个文件，这里设置了100 -->
            <DefaultRolloverStrategy max="100">
                <Delete basePath="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/error" maxDepth="1">
                    <IfFileName glob="*.log.zip"/>
                    <!--!Note: 这里的age必须和filePattern协调, 后者是精确到dd, 这里就要写成xd, xD就不起作用
                    另外, 数字最好>2, 否则可能造成删除的时候, 最近的文件还处于被占用状态,导致删除不成功!-->
                    <!--365天-->
                    <IfLastModified age="365d"/>
                </Delete>
            </DefaultRolloverStrategy>
        </RollingRandomAccessFile>


        <!--处理 WebLogAspect 打印的 接口请求日志，并把该日志放到logs/应用名称/rest.log文件中 -->
        <RollingRandomAccessFile name="REST-FILE"
                                 fileName="${LOG_HOME}/rest.log"
                                 filePattern="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/rest/rest-%d{yyyy-MM-dd-HH}-%i.log.zip">
            <PatternLayout pattern="${LOG_PATTERN}" charset="${CHARSET}"/>
            <Policies>
                <!--根据当前filePattern配置，日志文件每3分钟滚动一次-->
                <TimeBasedTriggeringPolicy/>
                <!--日志文件大于10 MB滚动一次-->
                <SizeBasedTriggeringPolicy size="20 MB"/>
            </Policies>
            <!-- DefaultRolloverStrategy属性如不设置，则默认为最多同一文件夹下7个文件，这里设置了100 -->
            <DefaultRolloverStrategy max="100">
                <Delete basePath="${LOG_HOME}/$${date:yyyy-MM}/$${date:yyyy-MM-dd}/rest" maxDepth="1">
                    <IfFileName glob="*.log.zip"/>
                    <!--!Note: 这里的age必须和filePattern协调, 后者是精确到dd, 这里就要写成xd, xD就不起作用
                    另外, 数字最好>2, 否则可能造成删除的时候, 最近的文件还处于被占用状态,导致删除不成功!-->
                    <!--365天-->
                    <IfLastModified age="365d"/>
                </Delete>
            </DefaultRolloverStrategy>
        </RollingRandomAccessFile>
    </appenders>

    <!--日志记录器-->
    <Loggers>
        <!-- apache logger -->
        <Logger name="org.apache.catalina.startup.DigesterFactory" level="ERROR" additivity="false"/>
        <Logger name="org.apache.catalina.util.LifecycleBase" level="ERROR" additivity="false"/>
        <logger name="org.apache.coyote.http11.Http11NioProtocol" level="WARN" additivity="false"/>
        <Logger name="org.apache.tomcat.util.net.NioSelectorPool" level="WARN" additivity="false"/>
        <!-- http loggers -->
        <logger name="org.apache.http" level="WARN" additivity="false"/>
        <!-- Spring loggers -->
        <logger name="org.springframework" level="WARN" additivity="false"/>
        <!-- hibernate loggers -->
        <Logger name="org.hibernate.validator.internal.util.Version" level="WARN" additivity="false"/>
        <!-- mybatis loggers -->
        <logger name="org.mybatis.spring" level="ERROR" additivity="false"/>
        <logger name="org.apache.ibatis.logging.stdout.StdOutImpl" level="DEBUG" additivity="false"/>
        <!-- Hikaricp loggers -->
        <logger name="com.zaxxer.hikari.pool.PoolBase" level="ERROR" additivity="false"/>
        <logger name="com.zaxxer.hikari.pool.HikariPool" level="ERROR" additivity="false"/>
        <logger name="com.zaxxer.hikari.pool.HikariProxyConnection" level="ERROR" additivity="false"/>
        <logger name="com.zaxxer.hikari.pool.HikariProxyPreparedStatement" level="ERROR" additivity="false"/>
        <!-- mongodb loggers -->
        <logger name="org.springframework.data.mongodb.core" level="DEBUG" additivity="false"/>
        <logger name="org.mongodb.driver" level="ERROR" additivity="false"/>
        <!-- swagger loggers -->
        <logger name="io.swagger.models.parameters.AbstractSerializableParameter" level="DEBUG" additivity="false"/>
        <!-- lettuce loggers -->
        <logger name="io.lettuce.core" level="DEBUG" additivity="false"/>
        <!-- redisson loggers -->
        <logger name="org.redisson" level="DEBUG" additivity="false"/>
        <!-- netty loggers -->
        <logger name="io.netty" level="ERROR" additivity="false"/>
        <!-- quartz loggers -->
        <logger name="org.quartz" level="DEBUG" additivity="false"/>
        <!-- nacos loggers -->
        <logger name="com.alibaba.nacos" level="DEBUG" additivity="false"/>
        <!-- seata loggers -->
        <logger name="com.alibaba.cloud.seata" level="ERROR" additivity="false"/>
        <logger name="io.seata" level="ERROR" additivity="false"/>
        <!-- axis loggers -->
        <logger name="org.apache.axis" level="WARN" additivity="false"/>
        <!-- 接口请求日志 -->
        <Logger name="com.winseco.cloud.aspect.WebLogAspect" includeLocation="${INCLUDE_LOCATION}"
                additivity="false">
            <AppenderRef ref="REST-FILE"/>
        </Logger>
        <Logger name="com.winseco.cloud.filter" includeLocation="${INCLUDE_LOCATION}"
                additivity="false">
            <AppenderRef ref="REST-FILE"/>
        </Logger>
        <AsyncRoot level="${LOG_LEVEL}" includeLocation="${INCLUDE_LOCATION}" additivity="false">
            <AppenderRef ref="Console"/>
            <AppenderRef ref="INFO-FILE"/>
            <AppenderRef ref="DEBUG-FILE"/>
            <AppenderRef ref="WARN-FILE"/>
            <AppenderRef ref="ERROR-FILE"/>
        </AsyncRoot>
    </Loggers>
</configuration>
```

## 