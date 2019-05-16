# Semaphore源码解析
## Semaphore使用
```java
public static void main(String[] args) {
        ExecutorService executorService = Executors.newCachedThreadPool();
        Semaphore semaphore = new Semaphore(3);//资源最多可被3个线程并发访问
        for(int i = 0;i < 20;i++){
            final int threadnum = i;
            executorService.execute(new Runnable() {
                @Override
                public void run() {
                    try {
                        System.out.println("current thread"+Thread.currentThread().getName());
                        semaphore.acquire(1);//获取许可
                        test(threadnum);
                        semaphore.release(1);//释放许可
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            });
        }
        executorService.shutdown();//如果不shutdown工程不会结束
    }

    private static void test(int threadNum) throws Exception {
        SimpleDateFormat simpleDateFormat = new SimpleDateFormat("HH:mm:ss");
        System.out.println(simpleDateFormat.format(new Date())+"  method run "+Thread.currentThread().getName());
        Thread.sleep(1000);
    }
```
## Semaphore源码解析
### Semaphore获取许可acquire
```java
public void acquire() throws InterruptedException {
        sync.acquireSharedInterruptibly(1);
    }
//
public final void acquireSharedInterruptibly(int arg)
            throws InterruptedException {
        if (Thread.interrupted())
            throw new InterruptedException();
        if (tryAcquireShared(arg) < 0)
            doAcquireSharedInterruptibly(arg);
    }
//
private void doAcquireSharedInterruptibly(int arg)
        throws InterruptedException {
        final Node node = addWaiter(Node.SHARED);
        boolean failed = true;
        try {
            for (;;) {
                final Node p = node.predecessor();
                if (p == head) {
                    int r = tryAcquireShared(arg);
                    if (r >= 0) {
                        setHeadAndPropagate(node, r);
                        p.next = null; // help GC
                        failed = false;
                        return;
                    }
                }
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    throw new InterruptedException();
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
//Semaphore.FailSync类中方法
//公平模式
protected int tryAcquireShared(int acquires) {
    for (;;) {
        //判断是否等待队列中是否有其他线程节点在等待
        if (hasQueuedPredecessors())
            return -1;
        //没有等待节点，则以CAS方式减少state
        int available = getState();
        int remaining = available - acquires;
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
//Semaphore.NonfailSync类中方法
protected int tryAcquireShared(int acquires) {
    return nonfairTryAcquireShared(acquires);
}
//Semaphore.Sync类中方法
final int nonfairTryAcquireShared(int acquires) {
    for (;;) {
        //以CAS方式减少state
        int available = getState();
        int remaining = available - acquires;
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
```
### Semaphore释放许可release
```java
//Semaphore类中的方法
public void release() {
        sync.releaseShared(1);
    }
//AQS类中的方法
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}

//Semaphore.Sync类中的方法
protected final boolean tryReleaseShared(int releases) {
    for (;;) {
        int current = getState();
        int next = current + releases;
        if (next < current) // overflow
            throw new Error("Maximum permit count exceeded");
        if (compareAndSetState(current, next))
            return true;
    }
}
//AQS类中的方法
private void doReleaseShared() {
    /*
     * Ensure that a release propagates, even if there are other
     * in-progress acquires/releases.  This proceeds in the usual
     * way of trying to unparkSuccessor of head if it needs
     * signal. But if it does not, status is set to PROPAGATE to
     * ensure that upon release, propagation continues.
     * Additionally, we must loop in case a new node is added
     * while we are doing this. Also, unlike other uses of
     * unparkSuccessor, we need to know if CAS to reset status
     * fails, if so rechecking.
     */
    for (;;) {
        Node h = head;
        if (h != null && h != tail) {
            int ws = h.waitStatus;
            if (ws == Node.SIGNAL) {
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    continue;            // loop to recheck cases
                unparkSuccessor(h);
            }
            else if (ws == 0 &&
                     !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                continue;                // loop on failed CAS
        }
        if (h == head)                   // loop if head changed
            break;
    }
}
```