# CountDownLatch源码解析

## 原理简述

> 使用`AQS`的子类`Sync`以共享锁的方式实现栅栏：在`Sync`的构造方法中使用`setState(count)`，在`await`方法中实际调用的是`tryAcquireShared`方法：`(getState() == 0) ? 1 : -1`，`countDown`方法：`sync.releaseShared(1)`。如果`state==0`时，才视为获取锁成功，这意味着调用`await`方法的线程都将被`park`，必须等待调用`countDown`的次数达到`count`时，才会以共享锁的方式链式唤醒所有线程

## 使用示例
```java
public class Test {

    public static void main(String[] args) {
       CountDownLatch begin = new CountDownLatch(1);
       CountDownLatch end = new CountDownLatch(2);

       for(int i=0; i<2; i++){
           Thread thread = new Thread(new Player(begin,end));
           thread.start();
       }

       try{
           System.out.println("the race begin");
           begin.countDown();
           end.await();
           System.out.println("the race end");
       }catch(Exception e){
            e.printStackTrace();
       }

    }
}


/**
 * 选手
 */
class Player implements Runnable{

    private CountDownLatch begin;

    private CountDownLatch end;

    Player(CountDownLatch begin,CountDownLatch end){
        this.begin = begin;
        this.end = end;
    }

    public void run() {
        try {
            begin.await();
            System.out.println(Thread.currentThread().getName() + " arrived !");
            end.countDown();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

    }
}

```
## 源码解析
CountDownLatch是借助AQS实现栅栏的，但是不可复用。
### 内部类Sync
```java
//CountDownLatch内部类
    private static final class Sync extends AbstractQueuedSynchronizer {
        private static final long serialVersionUID = 4982264981922014374L;

        Sync(int count) {
            setState(count);
        }

        int getCount() {
            return getState();
        }
        //判断state==0，如果是0，则表示已经达到要求，可以获取锁，不为0，则表示需要等待
        protected int tryAcquireShared(int acquires) {
            return (getState() == 0) ? 1 : -1;
        }
        //释放锁，将state以CAS方式减1
        protected boolean tryReleaseShared(int releases) {
            // Decrement count; signal when transition to zero
            for (;;) {
                int c = getState();
                if (c == 0)
                    return false;
                int nextc = c-1;
                if (compareAndSetState(c, nextc))
                    return nextc == 0;
            }
        }
    }

```
### await解析
**await方法：其主要目的是将添加一个节点放置锁等待队列中，然后阻塞线程，直到countDown方法将state减少至0时，唤醒被阻塞线程**
```java
//CountDownLatch类中方法。等待
public void await() throws InterruptedException {
        sync.acquireSharedInterruptibly(1);
    }
//AQS类中方法，判断是否可以获取到锁
public final void acquireSharedInterruptibly(int arg)
            throws InterruptedException {
    //判断线程是否中断
    if (Thread.interrupted())
        throw new InterruptedException();
    //尝试获取锁，如果没有获取到锁，则添加到等待队列中，自旋获取锁
    if (tryAcquireShared(arg) < 0)
        doAcquireSharedInterruptibly(arg);
}
//AQS类中方法，自旋获取锁
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
```
### countDown解析
**countDown方法：其主要目的是减少state，当state减少至0时，唤醒等待线程**
```java
//释放锁
public void countDown() {
    sync.releaseShared(1);
}
//释放锁
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
//唤醒等待中的后继节点
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