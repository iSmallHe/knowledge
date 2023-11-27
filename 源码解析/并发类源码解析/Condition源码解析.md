# Condition 源码解析
```java
// ReentrantLock类的方法
final ConditionObject newCondition() {
    return new ConditionObject();
}
```
    主要看类ConditionObject，其操作逻辑与Object.wait()/Object.notify()一致，均要获取锁后才能执行
    Object.wait() -- await：释放锁，并等待signal唤醒
    Object.notify() -- signal：唤醒firstWaiter所在线程，并让其重新进行锁的等待队列中，等待获取锁

    
## 重要属性
|name|value|description|
|---|---|:---|
|firstWaiter|Node|队列头节点|
|lastWaiter|Node|队列尾节点|

    与AQS同步等待队列的双向链表不同，Condition中的队列使用的是单向链表，以Node属性nextWaiter连接而成。
    但我们仍要注意Node类中的属性nextWaiter是非volatile字段，这是因为Condition需要在获取锁成功后使用，加/解锁动作保证了可见性

## Conditon.await
    该方法必须在获取锁的情况下执行。添加到condition等待队列，并释放锁，然后park当前线程，等待被signal后，重新进入AQS的同步等待队列重新获取锁
```java
    public final void await() throws InterruptedException {
        if (Thread.interrupted())
            throw new InterruptedException();
        // 向condition队列添加节点并返回
        Node node = addConditionWaiter();
        // 释放锁
        int savedState = fullyRelease(node);
        int interruptMode = 0;
        // 判断当前节点不是同步队列节点，则进入循环体
        while (!isOnSyncQueue(node)) {
            // park当前线程，等待signal唤醒
            LockSupport.park(this);
            if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
                break;
        }
        if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
            interruptMode = REINTERRUPT;
        if (node.nextWaiter != null) // clean up if cancelled
            unlinkCancelledWaiters();
        if (interruptMode != 0)
            reportInterruptAfterWait(interruptMode);
    }
    
```

## Conditon.addConditionWaiter
    向condition队列添加当前节点并返回
```java
    private Node addConditionWaiter() {
        Node t = lastWaiter;
        // If lastWaiter is cancelled, clean out.
        // 如果节点已取消则重新整理队列
        if (t != null && t.waitStatus != Node.CONDITION) {
            unlinkCancelledWaiters();
            t = lastWaiter;
        }
        // 增加节点
        Node node = new Node(Thread.currentThread(), Node.CONDITION);
        if (t == null)
            firstWaiter = node;
        else
            t.nextWaiter = node;
        lastWaiter = node;
        return node;
    }
```

## Conditon.unlinkCancelledWaiters
    拆分取消的节点
```java
    // 拆分取消的节点。
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
```

## AQS.fullyRelease
    释放全部（重入）锁，如果失败则取消当前节点
```java
    // 释放锁
    final int fullyRelease(Node node) {
        boolean failed = true;
        try {
            int savedState = getState();
            // 锁释放
            if (release(savedState)) {
                failed = false;
                return savedState;
            } else {
                throw new IllegalMonitorStateException();
            }
        } finally {
            // 失败则取消当前节点
            if (failed)
                node.waitStatus = Node.CANCELLED;
        }
    }

    // AQS的释放锁方法
    public final boolean release(int arg) {
        if (tryRelease(arg)) {
            // 释放锁后，判断是否需要唤醒后节点
            Node h = head;
            if (h != null && h.waitStatus != 0)
                // 唤醒后节点
                unparkSuccessor(h);
            return true;
        }
        return false;
    }

    // ReentrantLock.Sync类的方法，释放锁
    protected final boolean tryRelease(int releases) {
        int c = getState() - releases;
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

## AQS.isOnSyncQueue
    判断该节点是否在同步等待队列中
```java
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
    // 从后向前遍历同步等待队列
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
```

## Condition.checkInterruptWhileWaiting
    检查在循环等待唤醒期间是否有中断？
        没有中断则返回0
        存在中断，则取消当前节点

```java
    private int checkInterruptWhileWaiting(Node node) {
        return Thread.interrupted() ?
            (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
            0;
    }
```

## AQS.transferAfterCancelledWait
    取消等待后，
    如果CAS成功：迁移节点到同步等待队列中。
    如果CAS失败：自旋判断是否接入同步等待队列中
```java
    
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

## signal
    该方法必须在获取锁的情况下执行。condition队列的节点迁移至同步等待队列，然后修改前置节点waitStatus状态为SIGNAL，如果修改失败，则直接唤醒当前线程，线程会在await的acquireQueued中自旋等待锁
```java
    public final void signal() {
        // 判断锁持有者线程是否为当前线程
        if (!isHeldExclusively())
            throw new IllegalMonitorStateException();
        Node first = firstWaiter;
        if (first != null)
            doSignal(first);
    }

    private void doSignal(Node first) {
        do {
            if ( (firstWaiter = first.nextWaiter) == null)
                lastWaiter = null;
            first.nextWaiter = null;
        } while (!transferForSignal(first) &&
                    (first = firstWaiter) != null);
    }
    // 将Condition队列节点迁移至同步等待队列，并unpark节点所属线程
    final boolean transferForSignal(Node node) {
        /*
         * If cannot change waitStatus, the node has been cancelled.
         */
        if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
            return false;

        /*
         * Splice onto queue and try to set waitStatus of predecessor to
         * indicate that thread is (probably) waiting. If cancelled or
         * attempt to set waitStatus fails, wake up to resync (in which
         * case the waitStatus can be transiently and harmlessly wrong).
         */
        // 接入同步等待队列
        Node p = enq(node);
        int ws = p.waitStatus;
        // 修改前置节点waitStatus状态为SIGNAL，如果修改失败，则直接唤醒当前线程，线程会在await的acquireQueued中自旋等待锁
        if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
            LockSupport.unpark(node.thread);
        return true;
    }
```