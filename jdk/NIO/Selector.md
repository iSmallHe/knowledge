# Selector

NIO（非阻塞IO）中的Selector是一种能够检测一到多个NIO通道，并能够知晓通道是否为诸如读写事件做好准备的组件。Selector的主要作用是完成IO的多路复用，通过通道的注册、监听、事件查询，使一个线程能够管理多个通道，从而管理多个网络连接。

具体来说，Selector能够选出（select）所监控的通道已经发生了哪些IO事件，包括读写就绪的IO操作事件。对于操作系统来说，线程之间上下文切换的开销很大，而且每个线程都要占用系统的一些资源（如内存）。因此，使用的线程越少越好。通过使用Selector，一个单线程可以处理数百、数千、数万、甚至更多的通道，从而大量地减少线程之间上下文切换的开销。

通道和选择器之间的关联，通过注册的方式完成。调用通道的Channel.register(Selector sel, int ops)方法，可以将通道实例注册到一个选择器中。注册方法有两个参数：第一个参数是选择器实例，第二个参数是选择器要监控的IO事件类型。可供选择器监控的通道IO事件类型包括可读、可写、连接和接收。如果选择器要监控通道的多种事件，可以用“按位或”运算符来实现。


>Selector选择器对象是线程安全的，但它们包含的键集合不是。通过keys()和selectKeys()返回的键的集合是Selector对象内部的私有的Set对象集合的直接引用。这些集合可能在任意时间被改变。已注册的键的集合是只读的。
如果在多个线程并发地访问一个选择器的键的集合的时候存在任何问题，可以采用同步的方式进行访问，在执行选择操作时，选择器在Selector对象上进行同步，然后是已注册的键的集合，最后是已选择的键的集合。
在并发量大的时候，使用同一个线程处理连接请求以及消息服务，可能会出现拒绝连接的情况，这是因为当该线程在处理消息服务的时候，可能会无法及时处理连接请求，从而导致超时；一个更好的策略是对所有的可选择通道使用一个选择器，并将对就绪通道的服务委托给其它线程。只需一个线程监控通道的就绪状态并使用一个协调好的的工作线程池来处理接收及发送数据

## 使用

### 创建
```java
public static Selector open() throws IOException {
    return SelectorProvider.provider().openSelector();
}
```

### 注册
```java
Selector selector = Selector.open();
// SelectableChannel: 
// 必须是非阻塞模式
channel.configureBlocking(false);
// 注册时可添加：attach 附加对象，方便在通道就绪后，拿到该对象
SelectionKey selectionKey = channel.register(selector, SelectionKey.OP_CONNECT, attach);
```

### Select

```java
// 阻塞，直到至少有一个channel在你注册的事件上就绪
select.select();
// 和select()一样，只是规定了最长会阻塞timeout毫秒(参数)。
select.select(1000);
// 非阻塞获取就绪通道，没有就绪通道直接返回0
select.selectNow();

// 获取已就绪的通道
Set<SelectionKey> keys = select.selectedKyes();

// 唤醒select阻塞的线程
select.wakeUp();
```

### 关闭

```java
public abstract void close() throws IOException;
```


## SelectionKey

|name|value|description|
|---|---|:---|
|SelectionKey.OP_READ|1 << 0|通道操作：读就绪|
|SelectionKey.OP_WRITE|1 << 2|通道操作：写就绪|
|SelectionKey.OP_CONNECT|1 << 3|通道操作：连接就绪：服务器连接成功时|
|SelectionKey.OP_ACCEPT|1 << 4|通道操作：接收就绪：客户端发起连接时|



## 示例

```java

public class NioEchoServer {
    private static final int BUF_SIZE = 256;
    private static final int TIMEOUT = 3000;

    public static void main(String args[]) throws Exception {
        // 打开服务端 Socket
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();

        // 打开 Selector
        Selector selector = Selector.open();

        // 服务端 Socket 监听8080端口, 并配置为非阻塞模式
        serverSocketChannel.socket().bind(new InetSocketAddress(8080));
        serverSocketChannel.configureBlocking(false);

        // 将 channel 注册到 selector 中.
        // 通常我们都是先注册一个 OP_ACCEPT 事件, 然后在 OP_ACCEPT 到来时, 再将这个 Channel 的 OP_READ
        // 注册到 Selector 中.
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);

        while (true) {
            // 通过调用 select 方法, 阻塞地等待 channel I/O 可操作
            if (selector.select(TIMEOUT) == 0) {
                System.out.print(".");
                continue;
            }

            // 获取 I/O 操作就绪的 SelectionKey, 通过 SelectionKey 可以知道哪些 Channel 的哪类 I/O 操作已经就绪.
            Iterator<SelectionKey> keyIterator = selector.selectedKeys().iterator();

            while (keyIterator.hasNext()) {

                SelectionKey key = keyIterator.next();

                // 当获取一个 SelectionKey 后, 就要将它删除, 表示我们已经对这个 IO 事件进行了处理.
                keyIterator.remove();

                if (key.isAcceptable()) {
                    // 当 OP_ACCEPT 事件到来时, 我们就有从 ServerSocketChannel 中获取一个 SocketChannel,
                    // 代表客户端的连接
                    // 注意, 在 OP_ACCEPT 事件中, 从 key.channel() 返回的 Channel 是 ServerSocketChannel.
                    // 而在 OP_WRITE 和 OP_READ 中, 从 key.channel() 返回的是 SocketChannel.
                    SocketChannel clientChannel = ((ServerSocketChannel) key.channel()).accept();
                    clientChannel.configureBlocking(false);
                    //在 OP_ACCEPT 到来时, 再将这个 Channel 的 OP_READ 注册到 Selector 中.
                    // 注意, 这里我们如果没有设置 OP_READ 的话, 即 interest set 仍然是 OP_CONNECT 的话, 那么 select 方法会一直直接返回.
                    clientChannel.register(key.selector(), OP_READ, ByteBuffer.allocate(BUF_SIZE));
                }

                if (key.isReadable()) {
                    SocketChannel clientChannel = (SocketChannel) key.channel();
                    ByteBuffer buf = (ByteBuffer) key.attachment();
                    long bytesRead = clientChannel.read(buf);
                    if (bytesRead == -1) {
                        clientChannel.close();
                    } else if (bytesRead > 0) {
                        key.interestOps(OP_READ | SelectionKey.OP_WRITE);
                        System.out.println("Get data length: " + bytesRead);
                    }
                }

                if (key.isValid() && key.isWritable()) {
                    ByteBuffer buf = (ByteBuffer) key.attachment();
                    buf.flip();
                    SocketChannel clientChannel = (SocketChannel) key.channel();

                    clientChannel.write(buf);

                    if (!buf.hasRemaining()) {
                        key.interestOps(OP_READ);
                    }
                    buf.compact();
                }
            }
        }
    }
}
```