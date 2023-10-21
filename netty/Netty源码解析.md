## Netty源码解析

### demo
```java
public final class HttpHelloWorldServer {

    static final boolean SSL = System.getProperty("ssl") != null;
    static final int PORT = Integer.parseInt(System.getProperty("port", SSL? "8443" : "8080"));

    public static void main(String[] args) throws Exception {
        // Configure SSL.
        final SslContext sslCtx;
        if (SSL) {
            SelfSignedCertificate ssc = new SelfSignedCertificate();
            sslCtx = SslContextBuilder.forServer(ssc.certificate(), ssc.privateKey()).build();
        } else {
            sslCtx = null;
        }

        // Configure the server.
        // 创建服务器端的接受套接字accept请求，此时只要一个线程处理任务分发
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        // 创建服务器端的处理套接字读写
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            ServerBootstrap b = new ServerBootstrap();
            // 配置option
            b.option(ChannelOption.SO_BACKLOG, 1024);
            // 配置服务端的两个处理请求的GROUP
            b.group(bossGroup, workerGroup)
             // 设置channel类
             .channel(NioServerSocketChannel.class)
             // bossGroup中的处理器
             .handler(new LoggingHandler(LogLevel.INFO))
             // workerGroup中的处理器
             .childHandler(new HttpHelloWorldServerInitializer(sslCtx));

            Channel ch = b.bind(PORT).sync().channel();

            System.err.println("Open your web browser and navigate to " +
                    (SSL? "https" : "http") + "://127.0.0.1:" + PORT + '/');

            ch.closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}
```
### NioEventLoopGroup
    创建NioEventLoopGroup，nThreads默认是根据CPU核心数的2倍
    服务端会同时创建两个NioEventLoopGroup,一个是处理客户端连接，另一个用于处理客户端数据
```java
    public NioEventLoopGroup(int nThreads) {
        this(nThreads, (Executor) null);
    }
    public NioEventLoopGroup(int nThreads, Executor executor) {
        this(nThreads, executor, SelectorProvider.provider());
    }
    public NioEventLoopGroup(
            int nThreads, Executor executor, final SelectorProvider selectorProvider) {
        this(nThreads, executor, selectorProvider, DefaultSelectStrategyFactory.INSTANCE);
    }
    public NioEventLoopGroup(int nThreads, Executor executor, final SelectorProvider selectorProvider,
                             final SelectStrategyFactory selectStrategyFactory) {
        super(nThreads, executor, selectorProvider, selectStrategyFactory, RejectedExecutionHandlers.reject());
    }
    // DEFAULT_EVENT_LOOP_THREADS 默认是2*CPU核心数
    protected MultithreadEventLoopGroup(int nThreads, Executor executor, Object... args) {
        super(nThreads == 0 ? DEFAULT_EVENT_LOOP_THREADS : nThreads, executor, args);
    }
    protected MultithreadEventExecutorGroup(int nThreads, Executor executor, Object... args) {
        this(nThreads, executor, DefaultEventExecutorChooserFactory.INSTANCE, args);
    }

    protected MultithreadEventExecutorGroup(int nThreads, Executor executor,
                                            EventExecutorChooserFactory chooserFactory, Object... args) {
        checkPositive(nThreads, "nThreads");

        if (executor == null) {
            // 此时会创建 执行器 + 线程池
            executor = new ThreadPerTaskExecutor(newDefaultThreadFactory());
        }

        children = new EventExecutor[nThreads];

        for (int i = 0; i < nThreads; i ++) {
            boolean success = false;
            try {
                // 此处将由子类实现
                children[i] = newChild(executor, args);
                success = true;
            } catch (Exception e) {
                // TODO: Think about if this is a good exception type
                throw new IllegalStateException("failed to create a child event loop", e);
            } finally {
                if (!success) {
                    for (int j = 0; j < i; j ++) {
                        children[j].shutdownGracefully();
                    }

                    for (int j = 0; j < i; j ++) {
                        EventExecutor e = children[j];
                        try {
                            while (!e.isTerminated()) {
                                e.awaitTermination(Integer.MAX_VALUE, TimeUnit.SECONDS);
                            }
                        } catch (InterruptedException interrupted) {
                            // Let the caller handle the interruption.
                            Thread.currentThread().interrupt();
                            break;
                        }
                    }
                }
            }
        }

        chooser = chooserFactory.newChooser(children);

        final FutureListener<Object> terminationListener = new FutureListener<Object>() {
            @Override
            public void operationComplete(Future<Object> future) throws Exception {
                if (terminatedChildren.incrementAndGet() == children.length) {
                    terminationFuture.setSuccess(null);
                }
            }
        };

        for (EventExecutor e: children) {
            e.terminationFuture().addListener(terminationListener);
        }

        Set<EventExecutor> childrenSet = new LinkedHashSet<EventExecutor>(children.length);
        Collections.addAll(childrenSet, children);
        readonlyChildren = Collections.unmodifiableSet(childrenSet);
    }
```

### NioEventLoop
    taskQueue
    tailTasks
```java
    // 类 NioEventLoopGroup 创建 NioEventLoop
    protected EventLoop newChild(Executor executor, Object... args) throws Exception {
        SelectorProvider selectorProvider = (SelectorProvider) args[0];
        SelectStrategyFactory selectStrategyFactory = (SelectStrategyFactory) args[1];
        RejectedExecutionHandler rejectedExecutionHandler = (RejectedExecutionHandler) args[2];
        EventLoopTaskQueueFactory taskQueueFactory = null;
        EventLoopTaskQueueFactory tailTaskQueueFactory = null;

        int argsLength = args.length;
        if (argsLength > 3) {
            taskQueueFactory = (EventLoopTaskQueueFactory) args[3];
        }
        if (argsLength > 4) {
            tailTaskQueueFactory = (EventLoopTaskQueueFactory) args[4];
        }
        return new NioEventLoop(this, executor, selectorProvider,
                selectStrategyFactory.newSelectStrategy(),
                rejectedExecutionHandler, taskQueueFactory, tailTaskQueueFactory);
    }
```

### channel
    创建默认的 Channel工厂，实际上就是通过反射调用类的默认构造器来创建对象。
```java
    public B channel(Class<? extends C> channelClass) {
        return channelFactory(new ReflectiveChannelFactory<C>(
                ObjectUtil.checkNotNull(channelClass, "channelClass")
        ));
    }

    public class ReflectiveChannelFactory<T extends Channel> implements ChannelFactory<T> {

        private final Constructor<? extends T> constructor;

        public ReflectiveChannelFactory(Class<? extends T> clazz) {
            ObjectUtil.checkNotNull(clazz, "clazz");
            try {
                this.constructor = clazz.getConstructor();
            } catch (NoSuchMethodException e) {
                throw new IllegalArgumentException("Class " + StringUtil.simpleClassName(clazz) +
                        " does not have a public non-arg constructor", e);
            }
        }

        @Override
        public T newChannel() {
            try {
                return constructor.newInstance();
            } catch (Throwable t) {
                throw new ChannelException("Unable to create Channel from class " + constructor.getDeclaringClass(), t);
            }
        }

        @Override
        public String toString() {
            return StringUtil.simpleClassName(ReflectiveChannelFactory.class) +
                    '(' + StringUtil.simpleClassName(constructor.getDeclaringClass()) + ".class)";
        }
    }   
```

### Handler
handler按处理分组：
1. `handler(new LoggingHandler(LogLevel.INFO))`用于处理bossGroup，即处理主线程的连接事件OP_ACCEPT
2. `childHandler(new HttpHelloWorldServerInitializer(sslCtx))`用于处理workGroup，即处理读写OP_READ,OP_WIRTE

handler按处理出入站则分为：
1. ChannelInboundHandler：主要处理入站事件：
    channelRead，
    channelReadComplete，
    channelRegistered，
    channelUnregistered，
    channelActive，
    channelInactive，
    userEventTriggered，
    channelWritabilityChanged，
    exceptionCaught
2. ChannelOutboundHandler：主要处理出站事件：
    bind，
    connect，
    disconnect，
    close，
    deregister，
    read，
    write，
    flush

### bind
    绑定端口地址
```java
    public ChannelFuture bind(SocketAddress localAddress) {
        validate();
        return doBind(ObjectUtil.checkNotNull(localAddress, "localAddress"));
    }

    private ChannelFuture doBind(final SocketAddress localAddress) {
        // 初始化channel，并将channel注册到selector
        final ChannelFuture regFuture = initAndRegister();
        final Channel channel = regFuture.channel();
        if (regFuture.cause() != null) {
            return regFuture;
        }

        if (regFuture.isDone()) {
            // At this point we know that the registration was complete and successful.
            ChannelPromise promise = channel.newPromise();
            // 实际绑定port，host
            doBind0(regFuture, channel, localAddress, promise);
            return promise;
        } else {
            // Registration future is almost always fulfilled already, but just in case it's not.
            final PendingRegistrationPromise promise = new PendingRegistrationPromise(channel);
            regFuture.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    Throwable cause = future.cause();
                    if (cause != null) {
                        // Registration on the EventLoop failed so fail the ChannelPromise directly to not cause an
                        // IllegalStateException once we try to access the EventLoop of the Channel.
                        promise.setFailure(cause);
                    } else {
                        // Registration was successful, so set the correct executor to use.
                        // See https://github.com/netty/netty/issues/2586
                        promise.registered();

                        doBind0(regFuture, channel, localAddress, promise);
                    }
                }
            });
            return promise;
        }
    }

    final ChannelFuture initAndRegister() {
        Channel channel = null;
        try {
            // channel工厂生成channel，此时会设置一些重要的属性
            // interestOps：该值后续用于绑定socket事件
            // id ：生成id表示channel
            // pipeline：创建默认的通道用于处理后续连接请求。pipeline会默认创建HeadContext,TailContext
            // config：创建默认的channel config，该对象持有 channel及socketChannel引用
            channel = channelFactory.newChannel();
            // channel创建完成后初始化channel，设置一些 option，attribute
            init(channel);
        } catch (Throwable t) {
            if (channel != null) {
                // channel can be null if newChannel crashed (eg SocketException("too many open files"))
                channel.unsafe().closeForcibly();
                // as the Channel is not registered yet we need to force the usage of the GlobalEventExecutor
                return new DefaultChannelPromise(channel, GlobalEventExecutor.INSTANCE).setFailure(t);
            }
            // as the Channel is not registered yet we need to force the usage of the GlobalEventExecutor
            return new DefaultChannelPromise(new FailedChannel(), GlobalEventExecutor.INSTANCE).setFailure(t);
        }
        // 获取ServerBootstrapConfig,再获取bossGroup(NioEventLoopGroup),然后将channel注册到group中(其本质是channel注册selector中)
        ChannelFuture regFuture = config().group().register(channel);
        if (regFuture.cause() != null) {
            if (channel.isRegistered()) {
                channel.close();
            } else {
                channel.unsafe().closeForcibly();
            }
        }

        // If we are here and the promise is not failed, it's one of the following cases:
        // 1) If we attempted registration from the event loop, the registration has been completed at this point.
        //    i.e. It's safe to attempt bind() or connect() now because the channel has been registered.
        // 2) If we attempted registration from the other thread, the registration request has been successfully
        //    added to the event loop's task queue for later execution.
        //    i.e. It's safe to attempt bind() or connect() now:
        //         because bind() or connect() will be executed *after* the scheduled registration task is executed
        //         because register(), bind(), and connect() are all bound to the same thread.

        return regFuture;
    }

```

#### newChannel
1. 创建NioServerSocketChannel的方式是用工厂类ReflectiveChannelFactory,通过反射,调用构造器的newInstance创建.
2. 创建的时候会首先调用SelectorProvider生成ServerSocketChannel
3. NioMessageUnsafe
```java
    // NioServerSocketChannel 的静态属性
    private static final SelectorProvider DEFAULT_SELECTOR_PROVIDER = SelectorProvider.provider();

    public NioServerSocketChannel() {
        this(newSocket(DEFAULT_SELECTOR_PROVIDER));
    }
    // 创建java的ServerSocketChannel
    private static ServerSocketChannel newSocket(SelectorProvider provider) {
        try {
            /**
             *  Use the {@link SelectorProvider} to open {@link SocketChannel} and so remove condition in
             *  {@link SelectorProvider#provider()} which is called by each ServerSocketChannel.open() otherwise.
             *
             *  See <a href="https://github.com/netty/netty/issues/2308">#2308</a>.
             */
            return provider.openServerSocketChannel();
        } catch (IOException e) {
            throw new ChannelException(
                    "Failed to open a server socket.", e);
        }
    }

    // newSocket方法创建java nio中的ServerSocketChannel
    public NioServerSocketChannel(ServerSocketChannel channel) {
        // 设置该channel默认的事件，但是该值在register时，并未直接绑定OP_ACCEPT
        super(null, channel, SelectionKey.OP_ACCEPT);
        // 创建channel config
        config = new NioServerSocketChannelConfig(this, javaChannel().socket());
    }
    protected AbstractNioMessageChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent, ch, readInterestOp);
    }
    protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent);
        this.ch = ch;
        this.readInterestOp = readInterestOp;
        try {
            // 设置非阻塞
            ch.configureBlocking(false);
        } catch (IOException e) {
            try {
                ch.close();
            } catch (IOException e2) {
                logger.warn(
                            "Failed to close a partially initialized socket.", e2);
            }

            throw new ChannelException("Failed to enter non-blocking mode.", e);
        }
    }
    protected AbstractChannel(Channel parent) {
        this.parent = parent;
        id = newId();
        unsafe = newUnsafe();
        // 创建默认的pipeline通道
        pipeline = newChannelPipeline();
    }
    protected DefaultChannelPipeline newChannelPipeline() {
        return new DefaultChannelPipeline(this);
    }

    // 创建ChannelPipeline时会创建链表,用于处理数据
    protected DefaultChannelPipeline(Channel channel) {
        this.channel = ObjectUtil.checkNotNull(channel, "channel");
        succeededFuture = new SucceededChannelFuture(channel, null);
        voidPromise =  new VoidChannelPromise(channel, true);

        tail = new TailContext(this);
        head = new HeadContext(this);

        head.next = tail;
        tail.prev = head;
    }
```

#### init
```java
    // 初始化channel
    void init(Channel channel) {
        setChannelOptions(channel, newOptionsArray(), logger);
        setAttributes(channel, newAttributesArray());

        ChannelPipeline p = channel.pipeline();

        final EventLoopGroup currentChildGroup = childGroup;
        final ChannelHandler currentChildHandler = childHandler;
        final Entry<ChannelOption<?>, Object>[] currentChildOptions = newOptionsArray(childOptions);
        final Entry<AttributeKey<?>, Object>[] currentChildAttrs = newAttributesArray(childAttrs);
        // 添加处理器 bossGroup中的处理器，以及ServerBootstrapAcceptor, 
        // 在未register的情况下,ChannelHandler会设置handlerState = ADD_PENDING, 然后pipeline会创建任务,延迟执行(pendingHandlerCallbackHead)
        p.addLast(new ChannelInitializer<Channel>() {
            @Override
            public void initChannel(final Channel ch) {
                final ChannelPipeline pipeline = ch.pipeline();
                ChannelHandler handler = config.handler();
                if (handler != null) {
                    pipeline.addLast(handler);
                }
                // 添加重要的处理器 ServerBootstrapAcceptor ，该处理器会处理 channelRead 事件，并创建 SocketChannel ，然后注册到 selector 上
                ch.eventLoop().execute(new Runnable() {
                    @Override
                    public void run() {
                        pipeline.addLast(new ServerBootstrapAcceptor(
                                ch, currentChildGroup, currentChildHandler, currentChildOptions, currentChildAttrs));
                    }
                });
            }
        });
    }
```
#### register
    注册主要流程包含三步：
    1. channel关联eventLoop； 
    2. channel绑定selector
    3. 重置channel 绑定 Selector 的事件
```java
    public final void register(EventLoop eventLoop, final ChannelPromise promise) {
        ObjectUtil.checkNotNull(eventLoop, "eventLoop");
        if (isRegistered()) {
            promise.setFailure(new IllegalStateException("registered to an event loop already"));
            return;
        }
        // 检测是否兼容
        if (!isCompatible(eventLoop)) {
            promise.setFailure(
                    new IllegalStateException("incompatible event loop type: " + eventLoop.getClass().getName()));
            return;
        }
        // 此时是关联 NioServerSocketChannel 和 NioEventLoop
        AbstractChannel.this.eventLoop = eventLoop;
        // 判断当前线程是否在NioEventLoop同一线程里
        if (eventLoop.inEventLoop()) {
            // 注册channel
            register0(promise);
        } else {
            // 不是的话，则通过 NioEventLoop 中的执行器运行注册流程
            // 此时会间接让 NioEventLoop 启动
            try {
                eventLoop.execute(new Runnable() {
                    @Override
                    public void run() {
                        // 注册channel
                        register0(promise);
                    }
                });
            } catch (Throwable t) {
                logger.warn(
                        "Force-closing a channel whose registration task was not accepted by an event loop: {}",
                        AbstractChannel.this, t);
                closeForcibly();
                closeFuture.setClosed();
                safeSetFailure(promise, t);
            }
        }
    }

    private void register0(ChannelPromise promise) {
        try {
            // check if the channel is still open as it could be closed in the mean time when the register
            // call was outside of the eventLoop
            if (!promise.setUncancellable() || !ensureOpen(promise)) {
                return;
            }
            boolean firstRegistration = neverRegistered;
            // 真正执行注册步骤，由子类实现
            doRegister();
            // 设置 注册标志位
            neverRegistered = false;
            registered = true;

            // Ensure we call handlerAdded(...) before we actually notify the promise. This is needed as the
            // user may already fire events through the pipeline in the ChannelFutureListener.
            // pipeline在添加处理器时，会自动注册任务 PendingHandlerAddedTask/PendingHandlerRemovedTask ，hook方法用于子类拓展
            // 执行管道中的 处理器 added 事件，如果有 ChannelInitializer 会执行其 initChannel 方法
            pipeline.invokeHandlerAddedIfNeeded();
            // 修改promise中的标志位为 成功
            safeSetSuccess(promise);
            // pipeline执行channel注册事件
            pipeline.fireChannelRegistered();
            // Only fire a channelActive if the channel has never been registered. This prevents firing
            // multiple channel actives if the channel is deregistered and re-registered.
            if (isActive()) {
                if (firstRegistration) {
                    // pipeline执行channel激活事件，此时会重置 绑定的interestOps，用于后续处理selector分发的任务
                    // 具体实现看 HeadContext 中 channelActive 方法中调用 readIfIsAutoRead()
                    pipeline.fireChannelActive();
                } else if (config().isAutoRead()) {
                    // This channel was registered before and autoRead() is set. This means we need to begin read
                    // again so that we process inbound data.
                    //
                    // See https://github.com/netty/netty/issues/4805
                    // 如果不是第一次注册，则开启读取，此时将会interestOps重置为我们需要绑定的事件
                    beginRead();
                }
            }
        } catch (Throwable t) {
            // Close the channel directly to avoid FD leak.
            closeForcibly();
            closeFuture.setClosed();
            safeSetFailure(promise, t);
        }
    }

    protected void doRegister() throws Exception {
        boolean selected = false;
        // 死循环注册
        for (;;) {
            try {
                // 获取 ServerSocketChannel 注册到 selector 中，此时 interestOps = 0，后续在修改绑定事件，用于Selector分发请求
                selectionKey = javaChannel().register(eventLoop().unwrappedSelector(), 0, this);
                return;
            } catch (CancelledKeyException e) {
                if (!selected) {
                    // Force the Selector to select now as the "canceled" SelectionKey may still be
                    // cached and not removed because no Select.select(..) operation was called yet.
                    eventLoop().selectNow();
                    selected = true;
                } else {
                    // We forced a select operation on the selector before but the SelectionKey is still cached
                    // for whatever reason. JDK bug ?
                    throw e;
                }
            }
        }
    }
```


### NioEventLoop启动
```java
    private void execute(Runnable task, boolean immediate) {
        boolean inEventLoop = inEventLoop();
        addTask(task);
        if (!inEventLoop) {
            // 启动NioEventLoop核心功能
            startThread();
            if (isShutdown()) {
                boolean reject = false;
                try {
                    if (removeTask(task)) {
                        reject = true;
                    }
                } catch (UnsupportedOperationException e) {
                    // The task queue does not support removal so the best thing we can do is to just move on and
                    // hope we will be able to pick-up the task before its completely terminated.
                    // In worst case we will log on termination.
                }
                if (reject) {
                    reject();
                }
            }
        }
        
        if (!addTaskWakesUp && immediate) {
            // 唤醒selector
            wakeup(inEventLoop);
        }
    }

    private void startThread() {
        if (state == ST_NOT_STARTED) {
            // 设置 启动标志位
            if (STATE_UPDATER.compareAndSet(this, ST_NOT_STARTED, ST_STARTED)) {
                boolean success = false;
                try {
                    // 启动
                    doStartThread();
                    success = true;
                } finally {
                    if (!success) {
                        STATE_UPDATER.compareAndSet(this, ST_STARTED, ST_NOT_STARTED);
                    }
                }
            }
        }
    }

     private void doStartThread() {
        assert thread == null;
        executor.execute(new Runnable() {
            @Override
            public void run() {
                // 设置当前启动线程
                thread = Thread.currentThread();
                if (interrupted) {
                    thread.interrupt();
                }

                boolean success = false;
                updateLastExecutionTime();
                try {
                    // 此时进入 NioEventLoop 的 run 方法
                    SingleThreadEventExecutor.this.run();
                    success = true;
                } catch (Throwable t) {
                    logger.warn("Unexpected exception from an event executor: ", t);
                } finally {
                    // 此处是 关闭 流程，暂不讨论
                    for (;;) {
                        int oldState = state;
                        if (oldState >= ST_SHUTTING_DOWN || STATE_UPDATER.compareAndSet(
                                SingleThreadEventExecutor.this, oldState, ST_SHUTTING_DOWN)) {
                            break;
                        }
                    }

                    // Check if confirmShutdown() was called at the end of the loop.
                    if (success && gracefulShutdownStartTime == 0) {
                        if (logger.isErrorEnabled()) {
                            logger.error("Buggy " + EventExecutor.class.getSimpleName() + " implementation; " +
                                    SingleThreadEventExecutor.class.getSimpleName() + ".confirmShutdown() must " +
                                    "be called before run() implementation terminates.");
                        }
                    }

                    try {
                        // Run all remaining tasks and shutdown hooks. At this point the event loop
                        // is in ST_SHUTTING_DOWN state still accepting tasks which is needed for
                        // graceful shutdown with quietPeriod.
                        for (;;) {
                            if (confirmShutdown()) {
                                break;
                            }
                        }

                        // Now we want to make sure no more tasks can be added from this point. This is
                        // achieved by switching the state. Any new tasks beyond this point will be rejected.
                        for (;;) {
                            int oldState = state;
                            if (oldState >= ST_SHUTDOWN || STATE_UPDATER.compareAndSet(
                                    SingleThreadEventExecutor.this, oldState, ST_SHUTDOWN)) {
                                break;
                            }
                        }

                        // We have the final set of tasks in the queue now, no more can be added, run all remaining.
                        // No need to loop here, this is the final pass.
                        confirmShutdown();
                    } finally {
                        try {
                            cleanup();
                        } finally {
                            // Lets remove all FastThreadLocals for the Thread as we are about to terminate and notify
                            // the future. The user may block on the future and once it unblocks the JVM may terminate
                            // and start unloading classes.
                            // See https://github.com/netty/netty/issues/6596.
                            FastThreadLocal.removeAll();

                            STATE_UPDATER.set(SingleThreadEventExecutor.this, ST_TERMINATED);
                            threadLock.countDown();
                            int numUserTasks = drainTasks();
                            if (numUserTasks > 0 && logger.isWarnEnabled()) {
                                logger.warn("An event executor terminated with " +
                                        "non-empty task queue (" + numUserTasks + ')');
                            }
                            terminationFuture.setSuccess(null);
                        }
                    }
                }
            }
        });
    }

    // NioEventLoop 实现的 Runnable 方法
    protected void run() {
        int selectCnt = 0;
        for (;;) {
            try {
                int strategy;
                try {
                    // 判断当前是否有 任务，没有任务，则直接调用 selectNow 
                    // 当前有任务的情况下，判断下次定时任务启动时间，保证定时任务执行时机
                    // strategy > 0时表示 selector 有接收到事件
                    strategy = selectStrategy.calculateStrategy(selectNowSupplier, hasTasks());
                    switch (strategy) {
                    case SelectStrategy.CONTINUE:
                        continue;

                    case SelectStrategy.BUSY_WAIT:
                        // fall-through to SELECT since the busy-wait is not supported with NIO

                    case SelectStrategy.SELECT:
                        long curDeadlineNanos = nextScheduledTaskDeadlineNanos();
                        if (curDeadlineNanos == -1L) {
                            curDeadlineNanos = NONE; // nothing on the calendar
                        }
                        nextWakeupNanos.set(curDeadlineNanos);
                        try {
                            if (!hasTasks()) {
                                strategy = select(curDeadlineNanos);
                            }
                        } finally {
                            // This update is just to help block unnecessary selector wakeups
                            // so use of lazySet is ok (no race condition)
                            nextWakeupNanos.lazySet(AWAKE);
                        }
                        // fall through
                    default:
                    }
                } catch (IOException e) {
                    // If we receive an IOException here its because the Selector is messed up. Let's rebuild
                    // the selector and retry. https://github.com/netty/netty/issues/8566
                    rebuildSelector0();
                    selectCnt = 0;
                    handleLoopException(e);
                    continue;
                }

                selectCnt++;
                cancelledKeys = 0;
                needsToSelectAgain = false;
                // ioRatio 是 select/runTask 的时间比例，默认是50
                final int ioRatio = this.ioRatio;
                boolean ranTasks;
                if (ioRatio == 100) {
                    try {
                        if (strategy > 0) {
                            processSelectedKeys();
                        }
                    } finally {
                        // Ensure we always run tasks.
                        ranTasks = runAllTasks();
                    }
                } else if (strategy > 0) {
                    final long ioStartTime = System.nanoTime();
                    try {
                        processSelectedKeys();
                    } finally {
                        // Ensure we always run tasks.
                        final long ioTime = System.nanoTime() - ioStartTime;
                        // 计算 selector 耗时，通过ioRatio计算runTask的时间
                        ranTasks = runAllTasks(ioTime * (100 - ioRatio) / ioRatio);
                    }
                } else {
                    // 表示只执行一个任务
                    ranTasks = runAllTasks(0); // This will run the minimum number of tasks
                }

                if (ranTasks || strategy > 0) {
                    if (selectCnt > MIN_PREMATURE_SELECTOR_RETURNS && logger.isDebugEnabled()) {
                        logger.debug("Selector.select() returned prematurely {} times in a row for Selector {}.",
                                selectCnt - 1, selector);
                    }
                    selectCnt = 0;
                    // 此处是解决臭名昭著的 空轮询bug ，解决方式就是重新生成 selector 绑定旧selector上的channel及事件，并关闭旧的selector
                } else if (unexpectedSelectorWakeup(selectCnt)) { // Unexpected wakeup (unusual case)
                    selectCnt = 0;
                }
            } catch (CancelledKeyException e) {
                // Harmless exception - log anyway
                if (logger.isDebugEnabled()) {
                    logger.debug(CancelledKeyException.class.getSimpleName() + " raised by a Selector {} - JDK bug?",
                            selector, e);
                }
            } catch (Error e) {
                throw (Error) e;
            } catch (Throwable t) {
                handleLoopException(t);
            } finally {
                // Always handle shutdown even if the loop processing threw an exception.
                try {
                    if (isShuttingDown()) {
                        closeAll();
                        if (confirmShutdown()) {
                            return;
                        }
                    }
                } catch (Error e) {
                    throw (Error) e;
                } catch (Throwable t) {
                    handleLoopException(t);
                }
            }
        }
    }
```


### 模型解释
    netty使用的是reactor模式，一个NioEventLoopGroup（仅包含一个NioEventLoop）用于处理AP_ACCEPT事件，接收客户端的连接请求（主要实现在ServerBootstrapAcceptor逻辑中）。
    另一个NioEventLoopGroup（NioEventLoop池，容量默认是CPU两倍）用于处理读写相关逻辑。其中 childHandler 用于处理出站入站数据。

### 源码疑问
1. 为什么每次有 OP_CONNECT 连接过来时，都要重置 interestOps？
2. 为什么每个provider可以生成多个selector都可以同时接受？未看到源码。


