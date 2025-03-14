# 1. ConcurrentHashMap源码解析
>HashMap主要用于单线程或者无竞争下使用，ConcurrentHashMap主要用于多线程下，属于线程安全类。  
## ConcurrentHashMap类层次结构
![title](../../image/ConcurrentHashMap类层次结构.png)  

## ConcurrentHashMap属性
|name|value|description|
|---|---|---|
|MOVED|-1|用于判断当前是否处于迁移状态|
|TREEBIN|-2|表示该节点为红黑树节点|
|RESERVED|-3||
|HASH_BITS|0x7fffffff||
|TREEIFY_THRESHOLD|8|用于判断链表转换红黑树|
|sizeCtl|-1/init/迁移标志/other|-1：表示正在初始化table；  init：构造器初始化table的长度，暂存在sizeCtl中；  ‘迁移标志’：此时的sizeCtl由高16位1<<15+数组长度n的最高位之前的0的个数值,和低16位1+1(启动迁移线程)+协助线程数组成；  other：表示初始化的table长度值|
|transferIndex|[0,table.length]|transferIndex表示table下的[0,transferIndex-1]处的slot还未迁移|
|baseCount||表示map的长度，但不是准确值，准确值应当是baseCount加上所有CounterCell中的value值，才表示当前时刻ConcurrentHashMap的size大小|

## 插入节点分析putVal
``` java
final V putVal(K key, V value, boolean onlyIfAbsent) {
    //key，value值都不允许为null
    if (key == null || value == null) throw new NullPointerException();
    //以特定的算法重新计算hash值
    int hash = spread(key.hashCode());
    int binCount = 0;
    //自旋处理节点添加
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        //如果tab为null，或者tab长度=0，则表示未初始化
        if (tab == null || (n = tab.length) == 0)
            //初始化
            tab = initTable();
        //tab已初始化，判断当前待插入节点的slot下是否没有节点
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            //如果没有节点，则以CAS的方式将该节点放置在数组的i下标下，如果不成功，说明有其他节点已经放置进去了，此时重新回到for循环处，执行插入动作
            if (casTabAt(tab, i, null,
                         new Node<K,V>(hash, key, value, null)))
                break;                   // no lock when adding to empty bin
        }
        //判断当前slot是否处于迁移状态（即扩容后，节点需要迁移）
        else if ((fh = f.hash) == MOVED)
            //如果当前节点处于迁移状态，则当前线程应当辅助整个迁移过程，待迁移完成后，重新回到for循环处，执行插入动作
            tab = helpTransfer(tab, f);
        //当前slot下有节点且未处于迁移状态，则直接查看当前slot下是否有相同key，如果有相同key，则处理替换，没有，则直接插入
        else {
            V oldVal = null;
            //此时应当锁住第一个节点，防止其他线程同时修改当前slot下的节点
            synchronized (f) {
                //再次判断当前首节点是否是我们之前的首节点，不是的话，则表示其他线程修改过，需重新进入for循环中，执行插入动作
                if (tabAt(tab, i) == f) {
                    //首先判断首节点的hash值，如果当前slot下已经转换为红黑树结构，则该slot下存储的会是TreeBin对象，该对象hash值TREEBIN   = -2;hash值大于等于0，则表示该slot下还是链表结构，则进行相应的操作
                    if (fh >= 0) {
                        binCount = 1;
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            //判断当前节点是否与待插入节点hash值，key值相等
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                //相等则替换 
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            //将e指向下一个节点，如果下一个节点为null，则表示未找到，直接插入新节点
                            Node<K,V> pred = e;
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key,
                                                          value, null);
                                break;
                            }
                        }
                    }
                    //如果f是TreeBin对象，则表示，该slot下节点已经转换为红黑树了
                    else if (f instanceof TreeBin) {
                        Node<K,V> p;
                        binCount = 2;
                        //则调用红黑树的方法插入新节点或者替换
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key,
                                                       value)) != null) {
                            oldVal = p.val;
                        if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                }
            }
            //如果binCount值不为0，则表示节点已经插入成功，需要判断是否将链表结构转换为红黑树结构
            if (binCount != 0) {
                //如果binCount超过TREEIFY_THRESHOLD = 8，即表示链表长度超过8，应将该slot下节点进行转换为红黑树结构
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                //如果oldVal !=null 则表示有相同key节点，长度不变，无需进行后面的addCount动作。
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    //增加统计数量
    addCount(1L, binCount);
    return null;
}
```
## 初始化tab-initTable
```java
private final Node<K,V>[] initTable() {
        Node<K,V>[] tab; int sc;
        //循环处理，判断tab是否未初始化
        while ((tab = table) == null || tab.length == 0) {
            //如果sizeCrl小于0，则表示其他线程正在初始化，线程让步，等待其他线程处理完成
            if ((sc = sizeCtl) < 0)
                Thread.yield(); // lost initialization race; just spin
            //如果没有其他线程处理初始化，则CAS替换SIZECTL=-1
            else if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
                try {
                    //成功后再次判断是否未初始化
                    if ((tab = table) == null || tab.length == 0) {
                        //如果在构造ConcurrentHashMap时设置了初始化大小，则SIZECTL中会存储其值，此时判断是否有初始值
                        int n = (sc > 0) ? sc : DEFAULT_CAPACITY;
                        @SuppressWarnings("unchecked")
                        //构造tab
                        Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                        table = tab = nt;
                        sc = n - (n >>> 2);
                    }
                } finally {
                    //设置阈值，超出即需扩容
                    sizeCtl = sc;
                }
                break;
            }
        }
        return tab;
    }
```
## 统计数量addCount
```java
private final void addCount(long x, int check) {
    //此处是增加统计数量
    CounterCell[] as; long b, s;
    //counterCells不为空，且baseCount并发修改失败时
    if ((as = counterCells) != null ||
        !U.compareAndSwapLong(this, BASECOUNT, b = baseCount, s = b + x)) {
        CounterCell a; long v; int m;
        boolean uncontended = true;
        if (as == null || (m = as.length - 1) < 0 ||
            (a = as[ThreadLocalRandom.getProbe() & m]) == null ||
            !(uncontended =
              U.compareAndSwapLong(a, CELLVALUE, v = a.value, v + x))) {
            //counterCells未初始化/当前线程没有对应的CouterCell时/当前线程对应的的CounterCell并发修改失败的情况下，执行后续的逻辑
            fullAddCount(x, uncontended);
            return;
        }
        //表示当前属于链表阶段的初始阶段（即该插入的节点，在slot下的链表长度最大为2），无需进行扩容迁移
        if (check <= 1)
            return;
        //获取总数量
        s = sumCount();
    }
    if (check >= 0) {
        Node<K,V>[] tab, nt; int n, sc;
        //此处用于自旋处理迁移工作
        while (s >= (long)(sc = sizeCtl) && (tab = table) != null &&
               (n = tab.length) < MAXIMUM_CAPACITY) {
            //1<<15+n中最高位1前不为0的个数
            int rs = resizeStamp(n);
            //sc(SIZECTL)小于0，则表示在初始化(由于上面判断了table!=null，则表示不是初始化阶段)或者扩容
            if (sc < 0) {
                //code3
                //(sc >>> RESIZE_STAMP_SHIFT) != rs  : 此处表示已经不再是迁移阶段了，故此无需进行后续的迁移操作
                //sc == rs + 1 ：此处表示所有线程都已完成迁移工作。迁移的起点sc==rs+2，当每个线程加入处理时sc+1，线程迁移完成后，sc-1，所以当最后的线程处理完后，sc==rs+1，此时无需再进行迁移操作了
                //sc == rs + MAX_RESIZERS ：此处表示一起处理迁移的线程数量超过最大限制，后续线程无需再协助迁移
                //(nt = nextTable) == null ：此处时由于当迁移工作完成后，nextTable会重置null，所以，此时也无需进行迁移工作
                //transferIndex <= 0 ：此处表示待迁移的slot都已分配完成，所以也无需去协助迁移工作
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                    sc == rs + MAX_RESIZERS || (nt = nextTable) == null ||
                    transferIndex <= 0)
                    break;
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                    transfer(tab, nt);
            }
            //>=0则表示未进行初始化，或者扩容，则以CAS方式设置SIZECTL，高十六位为扩容标志位，低16位表示参与扩容线程数+1
            else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                         (rs << RESIZE_STAMP_SHIFT) + 2))
                //进行扩容
                transfer(tab, null);
            //获取总数量
            s = sumCount();
        }
    }
}
```

## 并发计数CounterCell
```java
// See LongAdder version for explanation
    private final void fullAddCount(long x, boolean wasUncontended) {
        int h;
        if ((h = ThreadLocalRandom.getProbe()) == 0) {
            //初始化当前线程的Seed，probe
            ThreadLocalRandom.localInit();      // force initialization
            h = ThreadLocalRandom.getProbe();
            wasUncontended = true;
        }
        boolean collide = false;                // True if last slot nonempty
        for (;;) {
            CounterCell[] as; CounterCell a; int n; long v;
            //并发计数器 数组已经初始化
            if ((as = counterCells) != null && (n = as.length) > 0) {
                //由于并发计数器数组的长度仍然是2^n，所以采用这种方式查找下标
                //当前下标处没有计数器
                if ((a = as[(n - 1) & h]) == null) {
                    //再判断当前是否未处于并发期
                    if (cellsBusy == 0) {            // Try to attach new Cell
                        //此时已表明位处于并发起，直接创建计数器CounterCell
                        CounterCell r = new CounterCell(x); // Optimistic create
                        //设定标志位，防止并发修改
                        if (cellsBusy == 0 &&
                            U.compareAndSwapInt(this, CELLSBUSY, 0, 1)) {
                            boolean created = false;
                            try {               // Recheck under lock
                                CounterCell[] rs; int m, j;
                                //此时二次判断是否可以插入计数器
                                if ((rs = counterCells) != null &&
                                    (m = rs.length) > 0 &&
                                    rs[j = (m - 1) & h] == null) {
                                    rs[j] = r;
                                    created = true;
                                }
                            } finally {
                                cellsBusy = 0;
                            }
                            //创建成功后，跳出for
                            if (created)
                                break;
                            continue;           // Slot is now non-empty
                        }
                    }
                    collide = false;
                }
                //数组在当前下标下有计数器，且有其他线程竞争修改，则会执行到code2处，重新生成probe
                else if (!wasUncontended)       // CAS already known to fail
                    wasUncontended = true;      // Continue after rehash
                //数组在当前下标处有计数器，但是没有竞争（此时只是基于之前的判断），则以CAS方式修改，修改成功，则结束
                else if (U.compareAndSwapLong(a, CELLVALUE, v = a.value, v + x))
                    break;
                //数组在当前下标处有计数器，但是CAS修改失败，此处判断计数器数组是否已替换了或者数组长度大于cpu个数
                else if (counterCells != as || n >= NCPU)
                    collide = false;            // At max size or stale
                else if (!collide)
                    collide = true;
                //修改并发标志位
                else if (cellsBusy == 0 &&
                         U.compareAndSwapInt(this, CELLSBUSY, 0, 1)) {
                    try {
                        //由于前面修改失败，计数器数组扩容
                        if (counterCells == as) {// Expand table unless stale
                            CounterCell[] rs = new CounterCell[n << 1];
                            for (int i = 0; i < n; ++i)
                                rs[i] = as[i];
                            counterCells = rs;
                        }
                    } finally {
                        cellsBusy = 0;
                    }
                    collide = false;
                    //扩容后重新执行计数
                    continue;                   // Retry with expanded table
                }
                //code2
                h = ThreadLocalRandom.advanceProbe(h);
            }
            //表示计数器数组未初始化，设定标志位，防止并发修改
            else if (cellsBusy == 0 && counterCells == as &&
                     U.compareAndSwapInt(this, CELLSBUSY, 0, 1)) {
                boolean init = false;
                try {                           // Initialize table
                    if (counterCells == as) {
                        //初始化的同时，直接生成计数器并设置数量
                        CounterCell[] rs = new CounterCell[2];
                        rs[h & 1] = new CounterCell(x);
                        counterCells = rs;
                        init = true;
                    }
                } finally {
                    cellsBusy = 0;
                }
                if (init)
                    break;
            }
            //此时，表明计数器未初始化，但是有其他线程并发进行初始化动作，所以以CAS执行修改baseCount，成功后退出，若不成功，则再继续之前的逻辑
            else if (U.compareAndSwapLong(this, BASECOUNT, v = baseCount, v + x))
                break;                          // Fall back on using base
        }
    }
```

## 协助扩容

```java
final Node<K,V>[] helpTransfer(Node<K,V>[] tab, Node<K,V> f) {
        Node<K,V>[] nextTab; int sc;
        //判断当前tab处于迁移状态，主要条件f instanceof ForwardingNode
        if (tab != null && (f instanceof ForwardingNode) &&
            (nextTab = ((ForwardingNode<K,V>)f).nextTable) != null) {
            int rs = resizeStamp(tab.length);
            //自旋判断是否进入协助扩容
            while (nextTab == nextTable && table == tab &&
                   (sc = sizeCtl) < 0) {
                //此处用于判断是否结束迁移工作了
                //详细解释：code3
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs || sc == rs + 1 ||
                    sc == rs + MAX_RESIZERS || transferIndex <= 0)
                    break;
                //并发修改sizeCtl，+1,表示协助修改线程数量+1
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1)) {
                    transfer(tab, nextTab);
                    //修改完成后退出
                    break;
                }
            }
            return nextTab;
        }
        return table;
    }
```

## 扩容+数据迁移transfer
```java
private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
    int n = tab.length, stride;
    //确定每个线程最小处理迁移slot的数量
    if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
        stride = MIN_TRANSFER_STRIDE; // subdivide range
    //如果nextTab是null，则初始化
    if (nextTab == null) {            // initiating
        try {
            @SuppressWarnings("unchecked")
            Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1];
            nextTab = nt;
        } catch (Throwable ex) {      // try to cope with OOME
            sizeCtl = Integer.MAX_VALUE;
            return;
        }
        nextTable = nextTab;
        //transferIndex表明待迁移数量
        transferIndex = n;
    }
    //新数组的长度
    int nextn = nextTab.length;
    //用于替代slot下的首节点，表明当前正在迁移
    ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);
    boolean advance = true;
    boolean finishing = false; // to ensure sweep before committing nextTab
    for (int i = 0, bound = 0;;) {
        Node<K,V> f; int fh;
        while (advance) {
            int nextIndex, nextBound;
            //每完成一次slot迁移，i自减，并判断当前是否迁移完成或者是否全部迁移完成
            if (--i >= bound || finishing)
                advance = false;
            //待迁移slot全部分配完成，当前线程已不用进行辅助迁移
            else if ((nextIndex = transferIndex) <= 0) {
                //用于判断-code1-处，查看是否全部迁移完成
                i = -1;
                advance = false;
            }
            //此时待迁移slot未分配完，划定当前线程应当迁移的slot数组边界
            else if (U.compareAndSwapInt
                     (this, TRANSFERINDEX, nextIndex,
                      nextBound = (nextIndex > stride ?
                                   nextIndex - stride : 0))) {
                //确定待迁移slot在数组的下标范围[bound,i]
                bound = nextBound;
                i = nextIndex - 1;
                advance = false;
            }
        }
        //判断是否当前迁移完成
        //code1
        if (i < 0 || i >= n || i + n >= nextn) {
            int sc;
            //如果完成全部迁移
            if (finishing) {
                //更新table和nextTable属性值
                nextTable = null;
                table = nextTab;
                //sizeCtl重新设置为门槛值，即设置为旧table的长度1.5倍，即新table长度的0.75倍
                sizeCtl = (n << 1) - (n >>> 1);
                //返回
                return;
            }
            //完成当前线程完成迁移且待迁移slot都已分配完，此时，将sizeCtl的低16位表示的线程数-1
            if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
                //判断是否还有其他线程在帮忙处理迁移工作，如果不相等，则表示还有其他线程在迁移，则直接退出，将结尾工作交付给最后执行迁移的工作线程；如果相等，则表示当前线程需要处理结尾工作，判断是否全部迁移完成。
                if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                    //当前线程完成迁移，直接返回
                    return;
                //全部线程完成迁移
                finishing = advance = true;
                //此处用于重新检测table中所有的slot，查看是否全部节点都是fwd，如果还有未迁移节点，继续迁移
                i = n; // recheck before commit
            }
        }
        //迁移未完成，判断当前slot是否有节点，没有节点则需要fwd以cas的方式放入table中，防止其他线程在当前线程迁移的过程中插入新节点
        else if ((f = tabAt(tab, i)) == null)
            advance = casTabAt(tab, i, null, fwd);
        //如果有节点，再判断是否正在迁移
        else if ((fh = f.hash) == MOVED)
            advance = true; // already processed
        //当前有节点，而且未处于迁移状态，则开始当前slot的迁移工作
        else {
            //迁移时，需要锁住当前slot下的首节点，防止其他线程干扰
            synchronized (f) {
                //再此判断当前slot下的首节点是否被改变了，如果没改变，再进行迁移
                if (tabAt(tab, i) == f) {
                    Node<K,V> ln, hn;
                    //再判断是链表结构
                    if (fh >= 0) {
                        //此时，由于扩容后，长度是原先的两倍，但是我们只需要判断n的1所在位置的值，因为该slot下所有节点，n的1所在位置之后的值都是一致的
                        int runBit = fh & n;
                        Node<K,V> lastRun = f;
                        for (Node<K,V> p = f.next; p != null; p = p.next) {
                            int b = p.hash & n;
                            //此处是找到链表中最后一串完全相同的节点
                            if (b != runBit) {
                                runBit = b;
                                lastRun = p;
                            }
                        }
                        //判断最后一串相同位置的节点，放置的位置
                        if (runBit == 0) {
                            ln = lastRun;
                            hn = null;
                        }
                        else {
                            hn = lastRun;
                            ln = null;
                        }
                        //遍历之前的节点，直到上一步骤中的最后一串节点的首节点
                        for (Node<K,V> p = f; p != lastRun; p = p.next) {
                            int ph = p.hash; K pk = p.key; V pv = p.val;
                            if ((ph & n) == 0)
                                ln = new Node<K,V>(ph, pk, pv, ln);
                            else
                                hn = new Node<K,V>(ph, pk, pv, hn);
                        }
                        //设置新数组的slot下的节点
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        //设置旧数组slot下节点为ForwardingNode
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                    //判断是否为红黑树结构
                    else if (f instanceof TreeBin) {
                        TreeBin<K,V> t = (TreeBin<K,V>)f;
                        TreeNode<K,V> lo = null, loTail = null;
                        TreeNode<K,V> hi = null, hiTail = null;
                        int lc = 0, hc = 0;
                        //遍历树节点，将hash值取余不同的分成两队
                        for (Node<K,V> e = t.first; e != null; e = e.next) {
                            int h = e.hash;
                            TreeNode<K,V> p = new TreeNode<K,V>
                                (h, e.key, e.val, null, null);
                            //取余=0
                            if ((h & n) == 0) {
                                if ((p.prev = loTail) == null)
                                    lo = p;
                                else
                                    loTail.next = p;
                                loTail = p;
                                ++lc;
                            }
                            //取余=1
                            else {
                                if ((p.prev = hiTail) == null)
                                    hi = p;
                                else
                                    hiTail.next = p;
                                hiTail = p;
                                ++hc;
                            }
                        }
                        //如果节点数量少于6，则进行转换为链表结构，超过6，则继续维持红黑树
                        ln = (lc <= UNTREEIFY_THRESHOLD) ? untreeify(lo) :
                            (hc != 0) ? new TreeBin<K,V>(lo) : t;
                        hn = (hc <= UNTREEIFY_THRESHOLD) ? untreeify(hi) :
                            (lc != 0) ? new TreeBin<K,V>(hi) : t;
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                }
            }
        }
    }
}
```
## 获取节点值get
```java
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;
    int h = spread(key.hashCode());
    //判断table是否未初始化
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (e = tabAt(tab, (n - 1) & h)) != null) {
        //判断是不是首节点
        if ((eh = e.hash) == h) {
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                return e.val;
        }
        //不是首节点，则判断hash值，小于0则可能是ForwardingNode或者TreeBin
        //由于table是将该slot下的所有节点迁移到nextTable后才会将首节点设置为ForwardingNode，而ForwardingNode持有nextTable，所以可以调用查找
        else if (eh < 0)
            return (p = e.find(h, key)) != null ? p.val : null;
        //普通链表节点，则直接遍历
        while ((e = e.next) != null) {
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))
                return e.val;
        }
    }
    return null;
}
```
### 获取节点值ForwardingNode
```java
Node<K,V> find(int h, Object k) {
    // loop to avoid arbitrarily deep recursion on forwarding nodes
    //由于此时处于扩容后数据迁移过程，所以要去nextTable中获取数据
    outer: for (Node<K,V>[] tab = nextTable;;) {
        Node<K,V> e; int n;
        //判断k是否符合。此时节点已经是迁移节点，说明原数组中该slot位置下数据已经迁移至新数组nextTable中了，如果此处还是没有找到，则表明不存在
        if (k == null || tab == null || (n = tab.length) == 0 ||
            (e = tabAt(tab, (n - 1) & h)) == null)
            return null;
        //此时表示找到slot了
        for (;;) {
            int eh; K ek;
            //判断hash值，key值是否相等
            if ((eh = e.hash) == h &&
                ((ek = e.key) == k || (ek != null && k.equals(ek))))
                return e;
            //如果hash值小于0，则需判断是否是ForwardingNode还是TreeBin或者其他Node
            if (eh < 0) {
                //如果是ForwardingNode
                if (e instanceof ForwardingNode) {
                    //则可能处于上一次迁移时，我们正在查询，而新一次扩容又开始了，所以我们需要重新获取nextTable，然后重新执行查询动作
                    tab = ((ForwardingNode<K,V>)e).nextTable;
                    continue outer;
                }
                //不是ForwardingNode，则调用相应类型的find方法(多态)
                else
                    return e.find(h, k);
            }
            //递归到后继节点，如果找到最后仍然没有找到，则返回null
            if ((e = e.next) == null)
                return null;
        }
    }
}
```
### 获取节点值TreeBin
```java
final Node<K,V> find(int h, Object k) {
    if (k != null) {
        for (Node<K,V> e = first; e != null; ) {
            int s; K ek;
            if (((s = lockState) & (WAITER|WRITER)) != 0) {
                if (e.hash == h &&
                    ((ek = e.key) == k || (ek != null && k.equals(ek))))
                    return e;
                e = e.next;
            }
            else if (U.compareAndSwapInt(this, LOCKSTATE, s,
                                         s + READER)) {
                TreeNode<K,V> r, p;
                try {
                    p = ((r = root) == null ? null :
                         r.findTreeNode(h, k, null));
                } finally {
                    Thread w;
                    if (U.getAndAddInt(this, LOCKSTATE, -READER) ==
                        (READER|WAITER) && (w = waiter) != null)
                        LockSupport.unpark(w);
                }
                return p;
            }
        }
    }
    return null;
}
```
