### NioEventLoopGroup
    NioEventLoopGroup 继承自 MultithreadEventLoopGroup
```java
    // NioEventLoopGroup的默认参数，调用父类构造器
    super(nThreads, executor, SelectorProvider.provider(), DefaultSelectStrategyFactory.INSTANCE, RejectedExecutionHandlers.reject());

    protected MultithreadEventLoopGroup(int nThreads, Executor executor, Object... args) {
        // DEFAULT_EVENT_LOOP_THREADS 即 取CPU核心数的两倍
        super(nThreads == 0 ? DEFAULT_EVENT_LOOP_THREADS : nThreads, executor, args);
    }

    protected MultithreadEventExecutorGroup(int nThreads, Executor executor, Object... args) {
        this(nThreads, executor, DefaultEventExecutorChooserFactory.INSTANCE, args);
    }

    protected MultithreadEventExecutorGroup(int nThreads, Executor executor,
                                            EventExecutorChooserFactory chooserFactory, Object... args) {
        if (nThreads <= 0) {
            throw new IllegalArgumentException(String.format("nThreads: %d (expected: > 0)", nThreads));
        }
        // 如果没有执行器，则创建ThreadPerTaskExecutor，以及默认的线程池，注意默认实现会包装Runnable，实现了线程参数相关操作
        if (executor == null) {
            executor = new ThreadPerTaskExecutor(newDefaultThreadFactory());
        }
        // 初始化线程数量
        children = new EventExecutor[nThreads];

        for (int i = 0; i < nThreads; i ++) {
            boolean success = false;
            try {
                // 创建事件循环执行器NioEventLoop（继承自SingleThreadEventLoop），将NioEventLoopGroup的参数写入NioEventLoop构造器中，即统一相关执行策略
                // 当前我们先往下看
                children[i] = newChild(executor, args);
                success = true;
            } catch (Exception e) {
                // TODO: Think about if this is a good exception type
                throw new IllegalStateException("failed to create a child event loop", e);
            } finally {
                // 如果创建失败
                if (!success) {
                    for (int j = 0; j < i; j ++) {
                        // 将所有NioEventLoop关闭
                        children[j].shutdownGracefully();
                    }
                    // 终止NioEventLoop
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
        // 创建选择器
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