# ReetrantLock源码解析
ReenTrantLock属于可重入锁，默认非公平模式。
## 首先说下nonFailSync下获取锁：lock()
```java
final void lock() {
    //非公平锁在lock时，会直接获取锁
    if (compareAndSetState(0, 1))
        //设置当前线程作为锁的拥有者
        setExclusiveOwnerThread(Thread.currentThread());
    else
        //
        acquire(1);
}
```
### AQS:public final void acquire(int arg) 获取请求锁，或插入双向链表队列
```java
public final void acquire(int arg) {
    //尝试获取锁，如果没有获取到，则添加到等待队列中,park当前线程，并判断中断标志位
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```
#### Sync:final boolean nonfairTryAcquire(int acquires) 非公平尝试获取锁
```java
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        //如果当前没有竞争，则直接获取锁
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    //如果当前锁已被获取，则判断是否是同一线程，如果是，则将锁标志位state加1，ReenTrantLock是可重入锁
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```
#### AQS:private Node addWaiter(Node mode) 插入等待队列中
```java
private Node addWaiter(Node mode) {
    Node node = new Node(Thread.currentThread(), mode);
    // Try the fast path of enq; backup to full enq on failure
    //将新的节点添加至最后
    Node pred = tail;
    if (pred != null) {
        node.prev = pred;
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    //将节点添加至queue中，如果queue没有初始化，则初始化queue
    enq(node);
    return node;
}
```
#### AQS:final boolean acquireQueued(final Node node, int arg)检测是否到node节点执行，如果不是则park节点所属线程，并检测中断
```java
final boolean acquireQueued(final Node node, int arg) {
        boolean failed = true;
        try {
            boolean interrupted = false;
            for (;;) {
                //获取前置节点
                final Node p = node.predecessor();
                //如果当前节点的前置节点是头节点，则表示当前线程可以获取锁了
                if (p == head && tryAcquire(arg)) {
                    setHead(node);
                    p.next = null; // help GC
                    failed = false;
                    return interrupted;
                }
                //如果前置节点不是首节点，或者尝试获取锁失败，则应当LockSupport.park当前线程
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    interrupted = true;
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
```
**问题一：finally是在什么时候触发呢？就我目前而看，只有未实现tryAcquire方法时会抛出异常，然后failed=true进入cancelAcquire方法，补充还有predecessor方法如果没有前置节点，也会抛出NullPointerException**
##### AQS:private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) 
```java
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    int ws = pred.waitStatus;
    //表示当前节点需要park，等待前置节点release后unpark当前节点
    if (ws == Node.SIGNAL)
        /*
         * This node has already set status asking a release
         * to signal it, so it can safely park.
         */
        return true;
    //表明前置节点已取消，则将当前节点循环放到上一个未取消的节点
    if (ws > 0) {
        /*
         * Predecessor was cancelled. Skip over predecessors and
         * indicate retry.
         */
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    } else {
        /*
         * waitStatus must be 0 or PROPAGATE.  Indicate that we
         * need a signal, but don't park yet.  Caller will need to
         * retry to make sure it cannot acquire before parking.
         */
        //疑问：为什么不返回true，直接让他park，而是等待下一次判断？
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}
```
**问题二：为什么不返回true，直接让他park，而是等待下一次判断？**<br/>
**解释:其实就是让head的后继节点有两次检测获取锁的机会**
## AQS:public final boolean release(int arg)释放锁
```java
public final boolean release(int arg) {
    //释放锁
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            //释放锁后，如果head节点waitStatus 不为0，则需要unpark后继节点线程
            //此处说明：由于lock在获取到锁后，会将head赋值为当前节点，所以release的时候，直接unpark首节点的next
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```

### AQS:  private void unparkSuccessor(Node node) 唤醒后继节点
```java
private void unparkSuccessor(Node node) {
        /*
         * If status is negative (i.e., possibly needing signal) try
         * to clear in anticipation of signalling.  It is OK if this
         * fails or if status is changed by waiting thread.
         */
        //waitStatus小于0，将其置0
        int ws = node.waitStatus;
        if (ws < 0)
            compareAndSetWaitStatus(node, ws, 0);

        /*
         * Thread to unpark is held in successor, which is normally
         * just the next node.  But if cancelled or apparently null,
         * traverse backwards from tail to find the actual
         * non-cancelled successor.
         */
        Node s = node.next;
        if (s == null || s.waitStatus > 0) {
            s = null;
            for (Node t = tail; t != null && t != node; t = t.prev)
                if (t.waitStatus <= 0)
                    s = t;
        }
        if (s != null)
            LockSupport.unpark(s.thread);
    }
```