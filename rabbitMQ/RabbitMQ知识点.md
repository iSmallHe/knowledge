# RabbitMQ知识点
消费者 -消费- 队列 -绑定键- 路由器  
生产者 -路由键- 路由器
## 路由器类型
* <font color="#FFA500">direct：</font><font color="#43CD80">只有路由键与绑定键完全匹配，才能接受到消息</font>  
* <font color="#FFA500">fanout：</font><font color="#43CD80">忽视绑定键，每个消息都会接受到消息</font>
* <font color="#FFA500">topic：</font><font color="#43CD80">可以设置多个关键词作为路由键，在绑定键中可以使用*和#来匹配</font>
* <font color="#FFA500">headers：</font><font color="#43CD80">可忽略</font>  

## 主要方法
### 声明队列
  生产者和消费者都可以声明队列，因为队列的创建是幂等的
```java
channel.queueDeclare(String queue, //队列的名字
                       boolean durable, //该队列是否持久化（即是否保存到磁盘中）
                       boolean exclusive,//该队列是否为该通道独占的，即其他通道是否可以消费该队列
                       boolean autoDelete,//该队列不再使用的时候，是否让RabbitMQ服务器自动删除掉
                       Map<String, Object> arguments)//其他参数
```
### 声明路由器
生产者和消费者都要声明路由器--如果声明了队列，可以不声明路由器
```java
channel.exchangeDeclare(String exchange,//路由器的名字
                          String type,//路由器的类型：topic、direct、fanout、header
                          boolean durable,//是否持久化该路由器
                          boolean autoDelete,//是否自动删除该路由器
                          boolean internal,//是否是内部使用的，true的话客户端不能使用该路由器
                          Map<String, Object> arguments) //其他参数
```
### 发布消息
生产者才能发布消息
```java
channel.basicPublish(String exchange, //路由器的名字，即将消息发到哪个路由器
                       String routingKey, //路由键，即发布消息时，该消息的路由键是什么
                       BasicProperties props, //指定消息的基本属性
                       byte[] body)//消息体，也就是消息的内容，是字节数组
//BasicProperties props：指定消息的基本属性，如deliveryMode为2时表示消息持久，2以外的值表示不持久化消息
//BasicProperties介绍
String corrId = "";
String replyQueueName = "";
Integer deliveryMode = 2;
String contentType = "application/json";
AMQP.BasicProperties props = new AMQP.BasicProperties
           .Builder()
           .correlationId(corrId)
           .replyTo(replyQueueName)
           .deliveryMode(deliveryMode)
           .contentType(contentType)
           .build();
```
### 接受消息
消费者才能接受
```java
channel.basicConsume(String queue, //队列名字，即要从哪个队列中接收消息
                      boolean autoAck, //是否自动确认，默认true
                      Consumer callback)//消费者，即谁接收消息

Consumer consumer = new DefaultConsumer(channel) {
          @Override
          public void handleDelivery(String consumerTag, //该消费者的标签
                                     Envelope envelope,//字面意思为信封：packaging data for the message
                                     AMQP.BasicProperties properties, //message content header data
                                     byte[] body) //message body
                                     throws IOException {
                  //获取消息示例
                  String message = new String(body, "UTF-8");
                  //接下来就可以根据消息处理一些事情
          }
      };
```
