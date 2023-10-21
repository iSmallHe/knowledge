# ReentrantReadWriteLock源码解析
1. AOS：AbstractOwnableSynchronizer
2. AQS：AbstractQueuedSynchronizer
3. state：在读写锁ReentrantReadWriteLock中，高16位代表的是写锁的持有数，低16位代表的是读锁的持有数。
4. nextWaiter：在AQS中，如果是读锁则存储的是SHARED（new Node()），如果是写锁，则存储的是EXCLUSIVE（null），如果是condition中，则存储的是下一个条件节点。
5. waitStatus：默认初始值0，取消（CANCELLED=1），表示后继节点待唤醒（SIGNAL=-1），条件队列节点（CONDITION = -2），共享锁传播（PROPAGATE = -3）。

## 重要属性
|name|value|description|
|---|---|:---|
|Sync|FairSync/NonfairSync|工作锁/非公平锁|
|ReadLock|ReadLock|读锁|
|WriteLock|WriteLock|写锁|

## Sync实现
    firstReader
    readHolds
    cachedHoldCounter
    state：高16位代表的是写锁的持有数，低16位代表的是读锁的持有数。


## 写锁WriteLock实现
```java
//ReentrantReadWriteLock.WriteLock中方法
public void lock() {
            sync.acquire(1);
}
//AbstractQueuedSynchronizer类中方法
public final void acquire(int arg) {
        if (!tryAcquire(arg) &&
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
            selfInterrupt();
    }
//ReentrantReadWriteLock.Sync中方法
protected final boolean tryAcquire(int acquires) {
            /*
             * Walkthrough:
             * 1. If read count nonzero or write count nonzero
             *    and owner is a different thread, fail.
             * 2. If count would saturate, fail. (This can only
             *    happen if count is already nonzero.)
             * 3. Otherwise, this thread is eligible for lock if
             *    it is either a reentrant acquire or
             *    queue policy allows it. If so, update state
             *    and set owner.
             */
            Thread current = Thread.currentThread();
            int c = getState();
            int w = exclusiveCount(c);
            if (c != 0) {
                // (Note: if c != 0 and w == 0 then shared count != 0)
                //此处c！=0，如果w为0，则表示当前有读锁；或者w ！= 0，则表示当前有写锁存在，如果当前线程不是AOS中的独占线程，此两种情况都不能获取到锁
                if (w == 0 || current != getExclusiveOwnerThread())
                    return false;
                //此处表明是重入锁，则判断当前锁的数量是否超过限制
                if (w + exclusiveCount(acquires) > MAX_COUNT)
                    throw new Error("Maximum lock count exceeded");
                // Reentrant acquire
                //重入次数未超过限制，则将状态+acquires，返回已经获取到锁
                setState(c + acquires);
                return true;
            }
            if (writerShouldBlock() ||
                !compareAndSetState(c, c + acquires))
                return false;
            //如果c=0，则表示当前属于无锁状态，可以直接将当前线程设置为独占线程
            setExclusiveOwnerThread(current);
            return true;
        }
//该方法时获取state的低16位值，即写锁的count
static int exclusiveCount(int c) { return c & EXCLUSIVE_MASK; }
//该方法时获取state的高16位值，即读锁的count
static int sharedCount(int c)    { return c >>> SHARED_SHIFT; }
//ReentrantReadWriteLock.NonfailSync类中的方法
final boolean writerShouldBlock() {
            return false; // writers can always barge
        }
//ReentrantReadWriteLock.FailSync类中的方法
final boolean writerShouldBlock() {
            return hasQueuedPredecessors();
        }
//AQS类中的方法
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
//AQS类中的方法，此方法用于添加等待获取锁的队列
private Node addWaiter(Node mode) {
        Node node = new Node(Thread.currentThread(), mode);
        // Try the fast path of enq; backup to full enq on failure
        Node pred = tail;
        if (pred != null) {
            node.prev = pred;
            if (compareAndSetTail(pred, node)) {
                pred.next = node;
                return node;
            }
        }
        //未初始化，或者compareAndSetTail失败，则进入enq
        enq(node);
        return node;
    }
//AQS类中的方法，此方法用于初始化等待队列，或者在多线程进行添加等待队列时造成的的失败即上方代码：if (compareAndSetTail(pred, node)) 
private Node enq(final Node node) {
        for (;;) {
            Node t = tail;
            if (t == null) { // Must initialize
                if (compareAndSetHead(new Node()))
                    tail = head;
            } else {
                node.prev = t;
                if (compareAndSetTail(t, node)) {
                    t.next = node;
                    return t;
                }
            }
        }
    }
//AQS类中的方法
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        //循环获取锁
        for (;;) {
        //获取node的前一个节点，如果前节点为null，会抛出异常NullPointerException
            final Node p = node.predecessor();
            //如果前置节点是head节点，则再次进行获取锁
            if (p == head && tryAcquire(arg)) {
                //获取锁成功后，将当前节点node设置为head节点
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
//AQS类中的方法
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
        int ws = pred.waitStatus;
        //表示后继节点需要park，等待后续唤醒
        if (ws == Node.SIGNAL)
            /*
             * This node has already set status asking a release
             * to signal it, so it can safely park.
             */
            return true;
        //表示节点已经cancel了，需要去除掉
        if (ws > 0) {
            /*
             * Predecessor was cancelled. Skip over predecessors and
             * indicate retry.
             */
            do {
                node.prev = pred = pred.prev;
            } while (pred.waitStatus > 0);
            pred.next = node;
        //后继节点第一次尝试获取锁，没有获取到，但是不用马上park，可以再次尝试，所以这里只是将状态转换为SIGNAL，下一次再没有获取到，则进入第一种情况。
        } else {
            /*
             * waitStatus must be 0 or PROPAGATE.  Indicate that we
             * need a signal, but don't park yet.  Caller will need to
             * retry to make sure it cannot acquire before parking.
             */
            compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
        }
        return false;
    }
//AQS类中的方法，将当前线程挂起，并检测当前线程是否中断
private final boolean parkAndCheckInterrupt() {
    LockSupport.park(this);
    //返回当前线程是否中断了，此方法会清除中断标志
    return Thread.interrupted();
}
//AQS类中的方法
private void cancelAcquire(Node node) {
        // Ignore if node doesn't exist
        if (node == null)
            return;

        node.thread = null;

        // Skip cancelled predecessors
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
        node.waitStatus = Node.CANCELLED;

        // If we are the tail, remove ourselves.
        if (node == tail && compareAndSetTail(node, pred)) {
            compareAndSetNext(pred, predNext, null);
        } else {
            // If successor needs signal, try to set pred's next-link
            // so it will get one. Otherwise wake it up to propagate.
            int ws;
            if (pred != head &&
                ((ws = pred.waitStatus) == Node.SIGNAL ||
                 (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&
                pred.thread != null) {
                Node next = node.next;
                if (next != null && next.waitStatus <= 0)
                    compareAndSetNext(pred, predNext, next);
            } else {
                unparkSuccessor(node);
            }

            node.next = node; // help GC
        }
    }
//ReentrantReadWriteLock.WriteLock中方法写锁释放
public void unlock() {
    sync.release(1);
}
//AQS类中的方法，释放锁
public final boolean release(int arg) {
        if (tryRelease(arg)) {
            Node h = head;
            if (h != null && h.waitStatus != 0)
                unparkSuccessor(h);
            return true;
        }
        return false;
    }
//ReentrantReadWriteLock.Sync类中的方法，此方法仅仅将state值减少，并判断是否完全释放
protected final boolean tryRelease(int releases) {
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    int nextc = getState() - releases;
    boolean free = exclusiveCount(nextc) == 0;
    if (free)
        setExclusiveOwnerThread(null);
    setState(nextc);
    return free;
}
```
## 读锁ReadLock原理解析
``` java
//ReentrantReadWriteLock.ReadLock类中的方法
public void lock() {
            sync.acquireShared(1);
        }
//AQS类中的方法
public final void acquireShared(int arg) {
if (tryAcquireShared(arg) < 0)
    doAcquireShared(arg);
}
//ReentrantReadWriteLock.Sync类中的方法
protected final int tryAcquireShared(int unused) {
    /*
     * Walkthrough:
     * 1. If write lock held by another thread, fail.
     * 2. Otherwise, this thread is eligible for
     *    lock wrt state, so ask if it should block
     *    because of queue policy. If not, try
     *    to grant by CASing state and updating count.
     *    Note that step does not check for reentrant
     *    acquires, which is postponed to full version
     *    to avoid having to check hold count in
     *    the more typical non-reentrant case.
     * 3. If step 2 fails either because thread
     *    apparently not eligible or CAS fails or count
     *    saturated, chain to version with full retry loop.
     */
    Thread current = Thread.currentThread();
    int c = getState();
    //判断是否有写锁存在，如果写锁存在，则判断当前线程是否是独占线程
    if (exclusiveCount(c) != 0 &&
        getExclusiveOwnerThread() != current)
        return -1;
    //此时表明当前没有写锁，或者当前线程是独占线程，可重入
    //获取当前读锁次数
    int r = sharedCount(c);
    //判断当前读是否需要挂起，以及读锁次数是否超出限制，再通过CAS修改state
    if (!readerShouldBlock() &&
        r < MAX_COUNT &&
        compareAndSetState(c, c + SHARED_UNIT)) {
        //r==0，表示当前没有读锁
        if (r == 0) {
            firstReader = current;
            firstReaderHoldCount = 1;
        //当前有读锁，判断第一个读锁线程是否是当前线程
        } else if (firstReader == current) {
            firstReaderHoldCount++;
        //当前有读锁，且第一个读锁线程不是当前线程
        } else {
            //为每一个读锁线程计算重入次数
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
            rh.count++;
        }
        return 1;
    }
    return fullTryAcquireShared(current);
}
//ReentrantReadWriteLock.FailSync类中的方法，与FailSync中的writerShouldBlock方法一致
final boolean readerShouldBlock() {
    return hasQueuedPredecessors();
}
//AQS类中的方法
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
//ReentrantReadWriteLock.NonfailSync类中的方法
final boolean readerShouldBlock() {
    /* As a heuristic to avoid indefinite writer starvation,
     * block if the thread that momentarily appears to be head
     * of queue, if one exists, is a waiting writer.  This is
     * only a probabilistic effect since a new reader will not
     * block if there is a waiting writer behind other enabled
     * readers that have not yet drained from the queue.
     */
    return apparentlyFirstQueuedIsExclusive();
}
//AQS类中的方法，主要用于判断是否共享，共享返回false
final boolean apparentlyFirstQueuedIsExclusive() {
    Node h, s;
    return (h = head) != null &&
        (s = h.next)  != null &&
        !s.isShared()         &&
        s.thread != null;
}
//ReentrantReadWriteLock.Sync类中的方法
final int fullTryAcquireShared(Thread current) {
    /*
     * This code is in part redundant with that in
     * tryAcquireShared but is simpler overall by not
     * complicating tryAcquireShared with interactions between
     * retries and lazily reading hold counts.
     */
    HoldCounter rh = null;
    //循环获取锁
    for (;;) {
        int c = getState();
        //判断当前是否有写锁存在
        if (exclusiveCount(c) != 0) {
            //如果有写锁，再判断当前线程是否是写锁的独占线程
            if (getExclusiveOwnerThread() != current)
                return -1;
            // else we hold the exclusive lock; blocking here
            // would cause deadlock.
        //再次判断当前读是否应该阻塞
        } else if (readerShouldBlock()) {
            // Make sure we're not acquiring read lock reentrantly
            if (firstReader == current) {
                // assert firstReaderHoldCount > 0;
            //此处判断当前线程不是第一个读线程
            } else {
                if (rh == null) {
                    rh = cachedHoldCounter;
                    //判断当前线程是否是缓存
                    if (rh == null || rh.tid != getThreadId(current)) {
                        //不是缓存线程，则再取一次，如果count==0，则表示是初始化的，或者已经unlock了，直接remove
                        rh = readHolds.get();
                        if (rh.count == 0)
                            readHolds.remove();
                    }
                }
                if (rh.count == 0)
                    return -1;
            }
        }
        //判断共享读锁是否是最大
        if (sharedCount(c) == MAX_COUNT)
            throw new Error("Maximum lock count exceeded");
        //没有超过限制，则通过CAS修改state
        if (compareAndSetState(c, c + SHARED_UNIT)) {
            //修改成功，则表示拿到锁了，此时再次判断是否读锁为0（此处，可能在多线程下，第一个读线程已经完成）
            if (sharedCount(c) == 0) {
                firstReader = current;
                firstReaderHoldCount = 1;
            } else if (firstReader == current) {
                firstReaderHoldCount++;
            } else {
                if (rh == null)
                    rh = cachedHoldCounter;
                if (rh == null || rh.tid != getThreadId(current))
                    rh = readHolds.get();
                else if (rh.count == 0)
                    readHolds.set(rh);
                rh.count++;
                cachedHoldCounter = rh; // cache for release
            }
            return 1;
        }
    }
}
//AQS类中的方法
private void doAcquireShared(int arg) {
    //将当前线程添加到等待队列中
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        boolean interrupted = false;
        //再循环获取锁
        for (;;) {
            final Node p = node.predecessor();
            if (p == head) {
                int r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    if (interrupted)
                        selfInterrupt();
                    failed = false;
                    return;
                }
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
//AQS类中的方法
private void setHeadAndPropagate(Node node, int propagate) {
    Node h = head; // Record old head for check below
    setHead(node);
    /*
     * Try to signal next queued node if:
     *   Propagation was indicated by caller,
     *     or was recorded (as h.waitStatus either before
     *     or after setHead) by a previous operation
     *     (note: this uses sign-check of waitStatus because
     *      PROPAGATE status may transition to SIGNAL.)
     * and
     *   The next node is waiting in shared mode,
     *     or we don't know, because it appears null
     *
     * The conservatism in both of these checks may cause
     * unnecessary wake-ups, but only when there are multiple
     * racing acquires/releases, so most need signals now or soon
     * anyway.
     */
    if (propagate > 0 || h == null || h.waitStatus < 0 ||
        (h = head) == null || h.waitStatus < 0) {
        Node s = node.next;
        if (s == null || s.isShared())
            doReleaseShared();
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
//AQS类中的方法，此方法用于唤醒node节点的后继节点
private void unparkSuccessor(Node node) {
    /*
     * If status is negative (i.e., possibly needing signal) try
     * to clear in anticipation of signalling.  It is OK if this
     * fails or if status is changed by waiting thread.
     */
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
    //判断是否存在下一个节点，如果存在但是已经取消了，则，需找到之后队列中未取消的节点 ，进行唤醒
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)
        LockSupport.unpark(s.thread);
}
//ReentrantReadWriteLock.ReadLock类中的方法
public void unlock() {
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
//ReentrantReadWriteLock.Sync类中的方法
protected final boolean tryReleaseShared(int unused) {
    Thread current = Thread.currentThread();
    //判断是否是第一个读线程
    if (firstReader == current) {
        // assert firstReaderHoldCount > 0;
        if (firstReaderHoldCount == 1)
            firstReader = null;
        else
            firstReaderHoldCount--;
    //如果不是第一个读线程，则从ThreadLocal中获取当前线程重入次数
    } else {
        HoldCounter rh = cachedHoldCounter;
        if (rh == null || rh.tid != getThreadId(current))
            rh = readHolds.get();
        int count = rh.count;
        if (count <= 1) {
            readHolds.remove();
            if (count <= 0)
                throw unmatchedUnlockException();
        }
        --rh.count;
    }
    //自旋CAS将state减少
    for (;;) {
        int c = getState();
        int nextc = c - SHARED_UNIT;
        if (compareAndSetState(c, nextc))
            // Releasing the read lock has no effect on readers,
            // but it may allow waiting writers to proceed if
            // both read and write locks are now free.
            return nextc == 0;
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
## condition条件原理解析
```java
//AQS.ConditionObject类中的方法
public final void await() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    //新增节点并添加到condition队列中
    Node node = addConditionWaiter();
    //释放当前锁占用
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    //判断 不是锁等待队列中的节点
    while (!isOnSyncQueue(node)) {
        //将线程挂起
        LockSupport.park(this);
        //判断线程是否中断，中断则将节点添加到锁等待队列中
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    //再次循环获取锁
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;
    //如果节点有后继节点，则清理后继所有节点中取消的节点
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();
    //如果当前线程处于中断状态，则作出相应的动作
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
//AQS.ConditionObject类中的方法，此方法用于添加condition等待队列
private Node addConditionWaiter() {
    Node t = lastWaiter;
    // If lastWaiter is cancelled, clean out.
    if (t != null && t.waitStatus != Node.CONDITION) {
        //如果不是condition节点，则取消
        unlinkCancelledWaiters();
        t = lastWaiter;
    }
    Node node = new Node(Thread.currentThread(), Node.CONDITION);
    if (t == null)
        firstWaiter = node;
    else
        t.nextWaiter = node;
    lastWaiter = node;
    return node;
}
//AQS.ConditionObject类中的方法，用于取消条件队列中的非condition节点
private void unlinkCancelledWaiters() {
    Node t = firstWaiter;
    Node trail = null;
    while (t != null) {
        Node next = t.nextWaiter;
        if (t.waitStatus != Node.CONDITION) {
            t.nextWaiter = null;
            if (trail == null)
                firstWaiter = next;
            else
                trail.nextWaiter = next;
            if (next == null)
                lastWaiter = trail;
        }
        else
            trail = t;
        t = next;
    }
}
//AQS类中的方法，释放锁的占有
final int fullyRelease(Node node) {
    boolean failed = true;
    try {
        int savedState = getState();
        if (release(savedState)) {
            failed = false;
            return savedState;
        } else {
            throw new IllegalMonitorStateException();
        }
    } finally {
        if (failed)
            node.waitStatus = Node.CANCELLED;
    }
}
//AQS类中的方法，判断是否是锁等待队列中的节点
final boolean isOnSyncQueue(Node node) {
    if (node.waitStatus == Node.CONDITION || node.prev == null)
        return false;
    if (node.next != null) // If has successor, it must be on queue
        return true;
    /*
     * node.prev can be non-null, but not yet on queue because
     * the CAS to place it on queue can fail. So we have to
     * traverse from tail to make sure it actually made it.  It
     * will always be near the tail in calls to this method, and
     * unless the CAS failed (which is unlikely), it will be
     * there, so we hardly ever traverse much.
     */
    return findNodeFromTail(node);
}
//AQS类中的方法，查询是否是锁等待队列中的节点
private boolean findNodeFromTail(Node node) {
    Node t = tail;
    for (;;) {
        if (t == node)
            return true;
        if (t == null)
            return false;
        t = t.prev;
    }
}
//AQS类中的方法，用于检测线程是否中断，如果中断，则将节点添加到锁等待队列中
private int checkInterruptWhileWaiting(Node node) {
    return Thread.interrupted() ?
        (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
        0;
}
//AQS类中的方法，将node节点添加到锁等待队列中去
final boolean transferAfterCancelledWait(Node node) {
    if (compareAndSetWaitStatus(node, Node.CONDITION, 0)) {
        enq(node);
        return true;
    }
    /*
     * If we lost out to a signal(), then we can't proceed
     * until it finishes its enq().  Cancelling during an
     * incomplete transfer is both rare and transient, so just
     * spin.
     */
    while (!isOnSyncQueue(node))
        Thread.yield();
    return false;
}
```