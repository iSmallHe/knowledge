# Channel

1. FileChannel：主要是用于文件的读写
2. DatagramChannel：主要用于UDP读写网络中的数据。
3. SocketChannel：通过TCP读写网络中的数据。
4. ServerSocketChannel：主要用于服务端，可以监听新进来的TCP连接，像Web服务器那样。对每一个新进来的连接都会创建一个SocketChannel。


## FileChannel

## DatagramChannel

```java
DatagramChannel datagramChannel = DatagramChannel.open();
datagramChannel.socket().bind(new InetSocketAddress(10086));

ByteBuffer buffer = ByteBuffer.allocate(8096);
while (true) {
    buffer.clear();
    // 接收数据
    SocketAddress address = datagramChannel.receive(buffer);
    buffer.flip();
    System.out.println(address.toString());
    System.out.println(StandardCharsets.UTF_8.decode(buffer));
    buffer.clear();
    String message = "hello world";
    buffer.put(message.getBytes(StandardCharsets.UTF_8));
    // 发送数据
    datagramChannel.send(buffer, new InetSocketAddress(10087));
}

```

## SocketChannel

## ServerSocketChannel