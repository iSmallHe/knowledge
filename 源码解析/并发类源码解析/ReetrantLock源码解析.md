# ReetrantLock源码解析
## ReentrantLock,Sync类层次结构

![title](../image/ReentrantLock.png)
![title](../image/Sync类层次结构.png)


>* ReenTrantLock属于可重入锁，默认非公平模式。  
>* ReentrantLock是借助Sync子类实现锁的功能，FailSync实现公平锁，NonFairSync实现非公平锁。

## 重要属性

|waitStatus|value|description|
|---|---|---|
|DEFAULT|0|默认值|
|CANCELLED|1|节点取消|
|SIGNAL|-1|信号，表示后继节点park，等待唤醒|
|CONDITION|-2|表示条件等待|
|PROPAGATE|-3|表示等待传播|

Node 节点包含两种：
1. lock同步等待队列：包含的状态值有 CANCELLED SIGNAL PROPAGATE 0
2. condition等待队列：包含的状态值有 CANCELLED CONDITION 0

## Sync
    
```java
    //释放锁
    protected final boolean tryRelease(int releases) {
        int c = getState() - releases;
        // 判断当前线程是否为锁持有者线程
        if (Thread.currentThread() != getExclusiveOwnerThread())
            throw new IllegalMonitorStateException();
        boolean free = false;
        if (c == 0) {
            free = true;
            setExclusiveOwnerThread(null);
        }
        setState(c);
        return free;
    }
```

### FairSync
    公平方式获取锁
```java
    protected final boolean tryAcquire(int acquires) {
        final Thread current = Thread.currentThread();
        int c = getState();
        if (c == 0) {
            // c == 0 表示为当前锁无持有者
            // 判断是否有前置节点，没有的情况下直接获取锁
            if (!hasQueuedPredecessors() &&
                compareAndSetState(0, acquires)) {
                setExclusiveOwnerThread(current);
                return true;
            }
        }
        else if (current == getExclusiveOwnerThread()) {
            // c != 0 的情况下：当前线程是否为锁持有者，是的话，直接将state+1
            // c!=0：表示当前有线程获取了锁，则继续判断是否是同一线程，因为ReentrantLock的实现是可重入的
            int nextc = c + acquires;
            if (nextc < 0)
                throw new Error("Maximum lock count exceeded");
            setState(nextc);
            return true;
        }
        // 两者情况都不是的话，则直接返回false，后续入队等待
        return false;
    }
```
    我们可以看到公平与非公平的在tryAcquire的区别在于hasQueuedPredecessors（是否存在前置节点）
    在分析这个方法的时候，不要局限在某一个分支逻辑里。应当分析该方法的代码逻辑。
    这个方法非常有意思，其中很多情形需要分析，以及为什么要先读tail，再读head

1. `head = tail = null` : 初始阶段head，tail都为空，此时 `h == t`，即返回false，无前置节点✅
2. `head = X, tail = null` : enq方法在节点入队时，是非原子操作，则可能出现head已设置节点，但是tail=null的情况。此时`h != t` 为 true。这时肯定有另一个线程正在进行初始化，然后执行入队操作。
    1. `s == null` 的情况：即执行入队操作未完成，但仍可表明有前置节点，所以返回true，有前置节点✅
    2. `s != null` 的情况：此时还在初始化的过程中，肯定还未入队，入队操作在初始化完成之后，所以不会出现这种情况❌
3. `head = tail = X` : 此时表明刚初始化完成，与2有相似之处，似乎有违公平之说。此时是会返回false，无前置节点✅
4. `head = X, tail = Y` : 此时表明有多个线程在竞争锁
    1. `s == null` 的情况：入队操作的prev与next属性的写是非原子操作的，所以也有可能出现该情况，当前这种情况微乎其微。返回true，有前置节点✅
    2. `s != null` 的情况：为何会有`s.thread == Thread.currentThread()`的情况？还记得我们第一次获取锁的时候，会初始化head节点，`head.next`就是当前节点，其实这种情况下s才算真正的头节点，所以这里要判断`s.thread != Thread.currentThread()`，表明同步等待队列中没有有效的前置节点✅
5. `head = null, tail = Y` : 这是不会出现的情况，这就是反序先读tail的优势。因为在enq中的初始化先以CAS的方式写了head，然后再写tail的。如果先读head，则有可能出现head读取的时候为null，然后线程被切换，等再运行时，读取tail的时候，已经完成初始化了，tail不为null。❌
```java
    public final boolean hasQueuedPredecessors() {
        // The correctness of this depends on head being initialized
        // before tail and on head.next being accurate if the current
        // thread is first in queue.
        Node t = tail; // Read fields in reverse initialization order
        Node h = head;
        Node s;
        return h != t &&
            ((s = h.next) == null || s.thread != Thread.currentThread());
    }
```

### NonFairSync

>非公平锁的原理，即在开始获取锁时，直接判断能否获取锁，这样实现能获得更好的性能，减少上下文的切换。

```java
final void lock() {
    //直接尝试获取锁
    if (compareAndSetState(0, 1))
        //获取成功后，设置当前线程作为锁的拥有者
        setExclusiveOwnerThread(Thread.currentThread());
    else
        //失败后，再按照AQS的逻辑继续获取锁
        acquire(1);
}

protected final boolean tryAcquire(int acquires) {
    //直接调用父类Sync的非公平获取锁方法
    return nonfairTryAcquire(acquires);
}

//Sync类的非公平获取锁方法
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    //c==0:表示当前没有线程获取锁
    if (c == 0) {
        //以CAS方式修改state属性，标志获取锁
        if (compareAndSetState(0, acquires)) {
            //设置锁的拥有者为当前线程
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    //c!=0：表示当前有线程获取了锁，则继续判断是否是同一线程，因为ReentrantLock的实现是可重入的
    else if (current == getExclusiveOwnerThread()) {
        //同一线程的情况下，可直接获取锁，修改state+1，表示获取锁的线程总数
        int nextc = c + acquires;
        // 如果nextc小于0，则表示值溢出了，此时最高位的符号位为1，变成了负数
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    // 两者情况都不是的话，则直接返回false，后续入队等待
    return false;
}
```

## AbstractQueuedSynchronizer
### Node重要属性
|name|value|volatile|description|
|---|---|---|---|
|waitStatus|0/1/-1/-2/-3|是|等待标志位，0为初始值|
|next|Node|是|后节点|
|prev|Node|是|前节点|
|thread|Thread|是|当前节点的线程|
|nextWaiter|Node|否|SHARED/EXCLUSIVE 共享模式/独占模式|

### AQS.acquire
```java
public final void acquire(int arg) {
        // tryAcquire：尝试获取锁，如果尝试获取锁失败，
        // addWaiter添加到同步等待队列中，添加到队列之后，
        // acquireQueued再次尝试获取锁，如果无法获取，则将pred节点的waitStatus状态置为SIGNAL，即在pred节点代表的线程在释放锁的时候，需要unpark后继节点
        if (!tryAcquire(arg) &&
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
            //acquireQueued 如果返回true，表示当前线程应当中断，设定中断标志位，等待响应中断
            selfInterrupt();
    }
```

### AQS.addWaiter
    AQS:private Node addWaiter(Node mode) 插入同步等待队列中
```java
private Node addWaiter(Node mode) {
    //创建节点，并放置队列尾端
    Node node = new Node(Thread.currentThread(), mode);
    // Try the fast path of enq; backup to full enq on failure
    Node pred = tail;
    //pred != null ：表示已经初始化，则直接设置尾节点
    if (pred != null) {
        node.prev = pred;
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    //若队列未初始化，或者插入尾节点失败，则调用enq自旋执行初始化/插入尾节点动作
    enq(node);
    return node;
}
//初始化队列/设置尾节点
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        //尾节点为空，表示刚开始放入同步等待队列中，进行初始化
        if (t == null) { // Must initialize
            //CAS的方式给头节点设置new Node
            // 此处解释下为何要新增节点：进入当前代码块，则意味着有其他线程已获取锁，当前线程需要等待锁持有者释放。那当前线程在无法获取到锁的情况下，当然要暂停线程，让出时间片，这意味着需要锁持有者在释放锁的时候，唤醒当前线程。所以我们可以在后面的shouldParkAfterFailedAcquire方法中看到，在线程park前会将前节点的waitStatus置为SIGNAL，用于标识唤醒；我们在release方法中，可以看到有逻辑判断waitStatus != 0，就会unpark后节点。所以在没有head的情况下，我们需要新增一个节点，将它记作当前锁持有者所在的线程
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            // 入队：设置尾节点
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```
### AQS.acquireQueued
    AQS:final boolean acquireQueued(final Node node, int arg) 入队节点尝试获取锁，如果无法获取锁，则尝试将前置节点waitStatus状态置为SIGNAL，标记后续节点等待唤醒，park当前线程
```java
    //返回是否中断
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        // 自旋获取锁
        for (;;) {
            //获取当前节点的前节点
            final Node p = node.predecessor();
            //如果前节点为头节点，则尝试获取锁
            if (p == head && tryAcquire(arg)) {
                //获取成功后，设置当前节点为头节点，并去掉关联关系
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            //如果不是头节点或者获取锁失败，则将未取消的前节点的waitStatus置为SIGNAL，然后park当前线程，等待锁持有者unpark
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                // 判断在获取锁的过程中，是否出现中断标志
                interrupted = true;
        }
    } finally {
        // 获取锁失败后，取消当前节点
        if (failed)
            cancelAcquire(node);
    }
}
```
**问题一：finally是在什么时候触发呢？tryAcquire 方法在获取到锁后，如果超出int的最大值，会抛出异常throw new Error("Maximum lock count exceeded")**
### AQS.shouldParkAfterFailedAcquire
    AQS:private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) 
```java
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    int ws = pred.waitStatus;
    // 表示当前节点需要park，等待前置节点release后unpark当前节点
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
**解释1:其实就是让head的后继节点有两次检测获取锁的机会**
**解释2:此时的compareAndSetWaitStatus，可能出现在pred节点解锁的时候，如果不让当前节点再次尝试获取锁，则有可能不会被唤醒。保证pred节点的waitStatus在置为SIGNAL之后，必须让当前节点再次尝试获取锁**

### AQS.cancelAcquire
    取消获取锁：该方法常用于自旋获取锁失败后的finally代码块中，取消当前节点
    这个方法我们需要考虑并发情况下出现的同时取消节点的问题：并发CANCEL的时候，哪怕在修改`node.waitStatus = Node.CANCELLED`后的CAS操作失败，也不会有问题，因为在自旋获取锁的过程中会一直过滤cancel的节点，最重要的是保证等待队列能被unpark唤醒，主动获取到锁。当然这并不意味着这里的CAS操作不重要。
```java
    private void cancelAcquire(Node node) {
        // Ignore if node doesn't exist
        if (node == null)
            return;

        node.thread = null;

        // Skip cancelled predecessors
        // 找到未取消的前置节点
        Node pred = node.prev;
        while (pred.waitStatus > 0)
            node.prev = pred = pred.prev;

        // predNext is the apparent node to unsplice. CASes below will
        // fail if not, in which case, we lost race vs another cancel
        // or signal, so no further action is necessary.
        Node predNext = pred.next;

        // Can use unconditional write instead of CAS here.
        // After this atomic step, other Nodes can skip past us.
        // Before, we are free of interference from other threads.
        // 将当前节点置为取消状态
        node.waitStatus = Node.CANCELLED;

        // If we are the tail, remove ourselves.
        // 如果当前节点处于队列的尾节点，则直接将pred有效节点设置为尾节点，并将pred的后节点置空
        if (node == tail && compareAndSetTail(node, pred)) {
            compareAndSetNext(pred, predNext, null);
        } else {
            // If successor needs signal, try to set pred's next-link
            // so it will get one. Otherwise wake it up to propagate.
            int ws;
            // 如果当前节点不在尾节点
            if (pred != head &&
                ((ws = pred.waitStatus) == Node.SIGNAL ||
                    (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&
                pred.thread != null) {
                // 如果不是else情况：则将pred节点的next属性以CAS的方式修改为当前节点的后继节点
                Node next = node.next;
                if (next != null && next.waitStatus <= 0)
                    compareAndSetNext(pred, predNext, next);
            } else {
                // 如果pred 是 头节点
                // 或者pred节点也是cancel，或者pred节点CAS修改0为SIGNAL失败
                // 或者pred.thread是空
                // 此时唤醒后继节点，重新获取锁，当然这并不意味着后继节点获取锁，所以这里最重要的是保证等待队列能获取到锁
                unparkSuccessor(node);
            }

            node.next = node; // help GC
        }
    }
```

### AQS.release
    锁释放，在此我们需要注意到一个细节：锁释放的时候，不会将head节点标记为下一个节点，而是等待下一个线程获取到锁后，设置当前节点为head。这里可以看到逻辑的一致性，即在acquireQueued的时候，会判断如果前一个节点为head时，会尝试获取锁。
```java
    public final boolean release(int arg) {
        
        if (tryRelease(arg)) {
            Node h = head;
            //如果头节点不为空，且状态值不为0：如果当前waitStatus=0，表示不用唤醒后继节点了
            //释放锁后，如果head节点waitStatus 不为0，则需要unpark后继节点线程
            //此处说明：由于lock在获取到锁后，会将head赋值为当前节点，所以release的时候，直接unpark首节点的next
            if (h != null && h.waitStatus != 0)
                unparkSuccessor(h);
            return true;
        }
        return false;
    }
```

### AQS.unparkSuccessor
    AQS:  private void unparkSuccessor(Node node) 唤醒后继节点
```java

    private void unparkSuccessor(Node node) {
        /*
         * If status is negative (i.e., possibly needing signal) try
         * to clear in anticipation of signalling.  It is OK if this
         * fails or if status is changed by waiting thread.
         */
        int ws = node.waitStatus;
        if (ws < 0)
            //此时将waitStatus标志位重置为0，即标志不用唤醒后继节点了，如果失败了，意味着状态值已经被等待的线程重置了，所以无需判断是否已经修改
            compareAndSetWaitStatus(node, ws, 0);

        /*
         * Thread to unpark is held in successor, which is normally
         * just the next node.  But if cancelled or apparently null,
         * traverse backwards from tail to find the actual
         * non-cancelled successor.
         */
        Node s = node.next;
        //此时选择接近当前节点的未取消节点
        if (s == null || s.waitStatus > 0) {
            s = null;
            //此时从后往前遍历寻找可用的后继节点进行唤醒
            //为什么要从后往前呢？
            //答案可能是： cancelAcquire 方法在取消节点的时候，只修改了前驱节点的关联关系
            for (Node t = tail; t != null && t != node; t = t.prev)
                if (t.waitStatus <= 0)
                    s = t;
        }
        //若存在后继可用节点，则进行唤醒
        if (s != null)
            LockSupport.unpark(s.thread);
    }
```
**为什么要从后往前呢？**  
**这是因为入队操作是非原子操作，节点之前的prev，next关联关系的建立是可能出现偏差的，但是如果入队成功，那么prev是一定能马上看到的，但是next属性不一定**


### AQS.doAcquireNanos
    该方法用于在限定时间内获取锁
```java
    // static final long spinForTimeoutThreshold = 1000L; 静态参数
     private boolean doAcquireNanos(int arg, long nanosTimeout)
            throws InterruptedException {
        if (nanosTimeout <= 0L)
            return false;
        // 计算死亡时间
        final long deadline = System.nanoTime() + nanosTimeout;
        // 入队等待：这是因为在doAcquireNanos之前会直接获取锁，失败后才到这里。所以这里会入队列
        final Node node = addWaiter(Node.EXCLUSIVE);
        boolean failed = true;
        try {
            // 自旋获取锁
            for (;;) {
                // 这是之前的常规操作，与acquireQueued差不多
                final Node p = node.predecessor();
                if (p == head && tryAcquire(arg)) {
                    setHead(node);
                    p.next = null; // help GC
                    failed = false;
                    return true;
                }
                // 存活时间
                nanosTimeout = deadline - System.nanoTime();
                if (nanosTimeout <= 0L)
                    return false;
                // 在获取锁失败后判断是否需要park，如果剩余等待时间小于1000纳秒，则不再进行park
                if (shouldParkAfterFailedAcquire(p, node) &&
                    nanosTimeout > spinForTimeoutThreshold)
                    LockSupport.parkNanos(this, nanosTimeout);
                // 判断线程是否中断，并清除中断标志
                if (Thread.interrupted())
                    throw new InterruptedException();
            }
        } finally {
            // 获取锁失败，则需要从队列中移除
            if (failed)
                cancelAcquire(node);
        }
    }
```