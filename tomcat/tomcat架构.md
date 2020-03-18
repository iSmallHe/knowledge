# tomcat架构
* Listener：监听器
* LifeCycleListener：生命周期监听器，主要用于响应生命周期的事件：初始化，启动，结束等等事件
* Server:服务器，主要包含Service服务
* Service:服务，主要包含：Connector，Container两部分
* Container:  
    * Engine:引擎，用于管理多个虚拟主机
    * Host:代表一个虚拟主机
    * Context:代表一个应用程序
    * Wrapper:代表一个Servlet
* Connector:用于接受请求，并解析参数封装到Request，Response
* Processor:处理Connector中的请求，即调用容器来处理
* Pipeline-Valve:管道-阀门
* Filter:过滤器

## tomcat启动流程

## tomcat运行流程

Connector接受到请求--Processor处理请求--Container容器进行处理--每个容器都会执行当前容器中的管道中的阀门，即--Engine管道--Engine的basic阀门--Host管道--Host的basic阀门--Context管道--Context的basic阀门--Wrapper管道--Wrapper的basic阀门--filterChain--servlet处理