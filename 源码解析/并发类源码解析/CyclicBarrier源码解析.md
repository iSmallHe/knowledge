# CyclicBarrier源码解析

## 重要属性
|name|value|description|
|---|---|:---|
|parties|final int|总屏蔽线程数量|
|lock|ReentrantLock|锁|
|trip|lock.newCondition()|条件：用于park线程|
|barrierCommand|Runnable|屏障破开前执行的任务|
|generation|Generation|迭代|
|count|int|当前剩余屏蔽线程数量|

## 原理简析

> `CyclicBarrier`的原理就是使用`ReentrantLock`配合`Condition`，在调用`CyclicBarrier.await`时，`--count`，使用`condition.await`，`park`当前线程。等到最后一次调用`CyclicBarrier.await`达到`count == 0`的条件时，则调用`condition.signalAll`唤醒所有线程，迭代`generation = new Generation`，重置`count = parties`，以此实现可重复使用。

## 使用示例
```java
public class CyclicbarrierTest {

    private static final int THREAD_NUM = 3;

    public static void main(String[] args) {
        CyclicbarrierTest t = new CyclicbarrierTest();
        t.tttt();
    }

    public void tttt(){
        CyclicBarrier cb = new CyclicBarrier(THREAD_NUM, new Runnable() {
            public void run() {
                System.out.println("都准备好了");
                try {
                    Thread.sleep(2000);
                    return;
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        });

        ThreadPoolExecutor executor = new ThreadPoolExecutor(THREAD_NUM,THREAD_NUM,0, TimeUnit.SECONDS,new LinkedBlockingQueue());
        for (int i = 1; i <= THREAD_NUM; i++) {
            Task t = new Task(""+i,cb);
            executor.execute(t);
        }

        System.out.println("我的任务已经分派完毕...");
    }

    class Task implements Runnable{
        private CyclicBarrier cb;
        private String taskName;
        public Task(){

        }
        public Task(String taskName,CyclicBarrier cb){
            this.taskName = taskName;
            this.cb = cb;
        }

        public void run() {
            try {
                Random r = new Random();
                int slt = r.nextInt(10);
                Thread.sleep(slt*1000);
                System.out.println(taskName+"使用了"+slt+"秒，准备好了");
                cb.await();
                System.out.println(taskName+"继续执行");
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (BrokenBarrierException e) {
                e.printStackTrace();
            }
        }
    }
}
```
## 源码解析
**CyclicBarrier是借助ReentrantLock和Condition实现的**
```java
public int await() throws InterruptedException, BrokenBarrierException {
    try {
        return dowait(false, 0L);
    } catch (TimeoutException toe) {
        throw new Error(toe); // cannot happen
    }
}

public int await(long timeout, TimeUnit unit)
    throws InterruptedException,
           BrokenBarrierException,
           TimeoutException {
    return dowait(true, unit.toNanos(timeout));
}

private int dowait(boolean timed, long nanos)
    throws InterruptedException, BrokenBarrierException,
           TimeoutException {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        final Generation g = generation;
        //判断generation是否失败
        if (g.broken)
            throw new BrokenBarrierException();
        //判断当前线程是否中断
        if (Thread.interrupted()) {
            //中断时，将终结此次栅栏，唤醒所有线程
            breakBarrier();
            throw new InterruptedException();
        }
        //减少栅栏数量
        int index = --count;
        //当栅栏数量已为0，则表示所有线程都到达目的，则可唤醒所有线程
        if (index == 0) {  // tripped
            boolean ranAction = false;
            try {
                //若是构造时，采用了到达栅栏时，还会调用barrierCommand
                final Runnable command = barrierCommand;
                if (command != null)
                    command.run();
                ranAction = true;
                //重置栅栏
                nextGeneration();
                return 0;
            } finally {
                //如果barrierCommand出现异常，则终止栅栏
                if (!ranAction)
                    breakBarrier();
            }
        }

        // loop until tripped, broken, interrupted, or timed out
        //每一个线程在调用await时，--count后，将释放锁并挂起，等待最后一个到达栅栏
        for (;;) {
            try {
                if (!timed)
                    //线程挂起
                    trip.await();
                else if (nanos > 0L)
                    nanos = trip.awaitNanos(nanos);
            } catch (InterruptedException ie) {
                if (g == generation && ! g.broken) {
                    breakBarrier();
                    throw ie;
                } else {
                    // We're about to finish waiting even if we had not
                    // been interrupted, so this interrupt is deemed to
                    // "belong" to subsequent execution.
                    Thread.currentThread().interrupt();
                }
            }
            //如果栅栏被终结，则需要相应终结，抛出终结异常
            if (g.broken)
                throw new BrokenBarrierException();
            //如果generation被更替，则表示当前栅栏已经结束，返回
            if (g != generation)
                return index;
            //如果使用了超时设置，则超时后终结栅栏，并抛出异常
            if (timed && nanos <= 0L) {
                breakBarrier();
                throw new TimeoutException();
            }
        }
    } finally {
        lock.unlock();
    }
}

//终结此次栅栏，唤醒所有线程
private void breakBarrier() {
    generation.broken = true;
    count = parties;
    trip.signalAll();
}
//唤醒所有线程，重置栅栏数量，及generation对象
private void nextGeneration() {
    // signal completion of last generation
    trip.signalAll();
    // set up next generation
    count = parties;
    generation = new Generation();
}
```