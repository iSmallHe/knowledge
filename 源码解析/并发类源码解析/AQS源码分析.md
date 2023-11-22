# AQS源码分析

## UML
![uml](../../image/uml_AbstractQueuedSynchronizer.png)

## 适用场景

    使用于多线程下，资源竞争时

## 重要属性

### AbstractQueuedSynchronizer

|name|value|description|
|---|---|:---|
|head|transient volatile Node|头节点|
|tail|transient volatile Node|尾节点|
|state|volatile int|状态|
|unsafe|Unsafe unsafe = Unsafe.getUnsafe()|用于直接处理类的属性值|

### Node

|name|value|description|
|---|---|:---|
|SHARED|Node|共享模式|
|EXCLUSIVE|null|独占模式|
|CANCELLED|1|节点取消|
|SIGNAL|-1|信号：表示可唤醒下一个节点|
|CONDITION|-2|条件：表示当前节点是condition等待队列的节点|
|PROPAGATE|-3|传播：共享模式下传播唤醒|
|waitStatus|volatile int|CANCELLED/SIGNAL//CONDITION/PROPAGATE：当前节点等待状态|
|prev|volatile Node|前节点|
|next|volatile Node|后节点|
|thread|volatile Thread|节点所表示的线程|
|nextWaiter|Node|SHARED/EXCLUSIVE，表示当前节点模式|

## 原理简析


## 源码分析

### acquire
>当前获取独占锁使用的通用的模板方法：
>1. 直接尝试获取锁
>2. 获取锁失败后，将当前线程添加到等待队列中，等待时机唤醒，循环获取锁
>3. 判断是否中断
```java
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}

static void selfInterrupt() {
    Thread.currentThread().interrupt();
}
```

### tryAcquire
    尝试获取锁，用于子类拓展；可分为 公平/非公平获取锁
```java
protected boolean tryAcquire(int arg) {
    throw new UnsupportedOperationException();
}
```

### addWaiter
    将当前线程添加到等待队列中
```java
private Node addWaiter(Node mode) {
    // 将当前线程以及模式构建节点对象
    Node node = new Node(Thread.currentThread(), mode);
    // Try the fast path of enq; backup to full enq on failure
    // 尝试直接向尾节点后追加节点
    Node pred = tail;
    if (pred != null) {
        node.prev = pred;
        // cas方式设置尾节点
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    // 如果尾节点为空（表示队列未初始化）或者cas设置尾节点失败，那么死循环入队
    enq(node);
    return node;
}
```

### enq
    节点循环入队
```java
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        // 初始化
        if (t == null) { // Must initialize
            // 未初始化时，设置虚拟的头节点
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            // 初始化完成后，再追加新的尾节点
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```

### acquireQueued
    判断当前节点是否能获取锁，如果无法获取锁，则park当前线程，等待被唤醒后，重试获取锁
```java
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            // 获取node节点的前节点
            final Node p = node.predecessor();
            if (p == head && tryAcquire(arg)) {
                // 如果前节点是头节点，且获取锁成功，将当前节点置为头节点
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            // 获取锁失败后，判断是否需要暂停当前线程，并检查当前线程是否出现中断
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

### shouldParkAfterFailedAcquire

```java

private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    int ws = pred.waitStatus;
    if (ws == Node.SIGNAL)
        /*
            * This node has already set status asking a release
            * to signal it, so it can safely park.
            */
        return true;
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
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}
```


### parkAndCheckInterrupt
```java
private final boolean parkAndCheckInterrupt() {
    LockSupport.park(this);
    return Thread.interrupted();
}
```