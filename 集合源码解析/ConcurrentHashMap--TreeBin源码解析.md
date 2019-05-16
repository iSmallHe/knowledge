# ConcurrentHashMap--TreeBin源码解析
## 关于TreeBin类比较重要的属性：lockState，初始值为0，其它可能值有以下几种情况：
| 名称   | 10进制 | 2进制 | 描述                                                                                                                                  |
| :----- | :---: | ---: | :------------------------------------------------------------------------------------------------------------------------------------ |
| WRITER |   1    | 0001 | 写模式，由于在put，remove操作slot时，都会锁住首节点，所以不会出现写写竞争，主要是读写竞争                                                    |
| WAITER |   2    | 0010 | 等模式，如果当前模式处于读状态，则当前线程会被park，并且状态为READER + WAITER，直到读线程操作完成后会unpark                                  |
| READER |   4    | 0100 | 读模式，如果已经处于读模式下且无waiter的写线程lockState=n\*READER，可使用红黑树方式遍历，如果是lockState=n\*READER+WAITER，则使用链表方式遍历 |

## TreeBin(TreeNode(K,V) b)类的构造器，用于初始化红黑树
``` java
TreeBin(TreeNode<K,V> b) {
            //设置Hash值为TREEBIN，key,value,next=null。
            super(TREEBIN, null, null, null);
            //将first指向链表的首节点
            this.first = b;
            TreeNode<K,V> r = null;
            //for循环将链表转换为红黑树结构
            for (TreeNode<K,V> x = b, next; x != null; x = next) {
                next = (TreeNode<K,V>)x.next;
                x.left = x.right = null;
                if (r == null) {
                    x.parent = null;
                    x.red = false;
                    r = x;
                }
                else {
                    K k = x.key;
                    int h = x.hash;
                    Class<?> kc = null;
                    //for循环将节点放置新的红黑树中
                    for (TreeNode<K,V> p = r;;) {
                        int dir, ph;
                        K pk = p.key;
                        //判断hash值，找到当前节点应该放置的位置
                        if ((ph = p.hash) > h)
                            dir = -1;
                        else if (ph < h)
                            dir = 1;
                        //若hash值相等，则判断当前节点有没有实现Comparable接口，如果实现该接口，则通过compareTo比较
                        //如果未实现该接口或者，compareTo结果一致，则通过System.identityHashCode(a)方法比较对象的地址，判断节点存放的位置。
                        else if ((kc == null &&
                                  (kc = comparableClassFor(k)) == null) ||
                                 (dir = compareComparables(kc, k, pk)) == 0)
                            dir = tieBreakOrder(k, pk);
                            TreeNode<K,V> xp = p;
                        //通过dir判断插入p节点的左还是右，如果选择的left，或者right不为null，则继续循环直到找到叶子节点
                        if ((p = (dir <= 0) ? p.left : p.right) == null) {
                            x.parent = xp;
                            if (dir <= 0)
                                xp.left = x;
                            else
                                xp.right = x;
                            //插入红黑树中，并平衡红黑树的约束
                            r = balanceInsertion(r, x);
                            break;
                        }
                    }
                }
            }
            //最后将新的root节点赋值
            this.root = r;
            assert checkInvariants(root);
        }
```

## final Node<K,V> find(int h, Object k)源码解析，该方法主要用于查询节点
``` java
final Node<K,V> find(int h, Object k) {
            if (k != null) {
                for (Node<K,V> e = first; e != null; ) {
                    int s; K ek;
                    //WAITER|WRITER=11与当前lockState进行位操作& ：
                    //如果！=0，则表示当前有线程在进行write操作，或者写线程在wait（此时lockState=n*READER+WAITER），此时，则直接按链表模式遍历；
                    if (((s = lockState) & (WAITER|WRITER)) != 0) {
                        if (e.hash == h &&
                            ((ek = e.key) == k || (ek != null && k.equals(ek))))
                            return e;
                        e = e.next;
                    }
                    //如果==0，则表示当前无写线程，则以CAS的方式+READER，然后通过红黑树的方式遍历获取节点
                    else if (U.compareAndSwapInt(this, LOCKSTATE, s,
                                                 s + READER)) {
                        TreeNode<K,V> r, p;
                        try {
                            p = ((r = root) == null ? null :
                                 r.findTreeNode(h, k, null));
                        } finally {
                            Thread w;
                            //获取之后再以CAS的方式-READER，如果原始值为READER|WAITER并且waiter不为null，则unpark激活写线程。
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
## final TreeNode<K,V> putTreeVal(int h, K k, V v) 插入节点
``` java
final TreeNode<K,V> putTreeVal(int h, K k, V v) {
            Class<?> kc = null;
            boolean searched = false;
            //for循环遍历，找到被替换的节点，没有相同节点直接插入
            for (TreeNode<K,V> p = root;;) {
                int dir, ph; K pk;
                //如果首节点为null，则直接new一个节点存储
                if (p == null) {
                    first = root = new TreeNode<K,V>(h, k, v, null, null);
                    break;
                }
                //首节点不为null，则判断其hash值，确定红黑树待插入的方向
                else if ((ph = p.hash) > h)
                    dir = -1;
                else if (ph < h)
                    dir = 1;
                //如果找到相同节点则直接返回
                else if ((pk = p.key) == k || (pk != null && k.equals(pk)))
                    return p;
                //若hash值相等，则判断当前节点有没有实现Comparable接口，如果实现该接口，则通过compareTo比较
                //如果未实现该接口或者，compareTo结果一致，则通过System.identityHashCode(a)方法比较对象的地址，判断节点存放的位置。
                else if ((kc == null &&
                          (kc = comparableClassFor(k)) == null) ||
                         (dir = compareComparables(kc, k, pk)) == 0) {
                    //在这种情况下，可能出现相同节点的情况，所以在此进行一次遍历查看是否能够找到相同节点，找到后直接返回
                    if (!searched) {
                        TreeNode<K,V> q, ch;
                        searched = true;
                        if (((ch = p.left) != null &&
                             (q = ch.findTreeNode(h, k, kc)) != null) ||
                            ((ch = p.right) != null &&
                             (q = ch.findTreeNode(h, k, kc)) != null))
                            return q;
                    }
                    dir = tieBreakOrder(k, pk);
                }
                //找到待插入位置时，直接new节点，此时添加是往上添加，将新加入的节点置为first，并新节点的next指向原first节点
                //注意不用担心多线程同时写入该slot的问题，因为在map向该slot执行put时，会锁住首节点，在红黑树中是锁住TreeBin对象。
                TreeNode<K,V> xp = p;
                if ((p = (dir <= 0) ? p.left : p.right) == null) {
                    TreeNode<K,V> x, f = first;
                    first = x = new TreeNode<K,V>(h, k, v, f, xp);
                    if (f != null)
                        f.prev = x;
                    if (dir <= 0)
                        xp.left = x;
                    else
                        xp.right = x;
                    if (!xp.red)
                        x.red = true;
                    else {
                        //获取锁，如果有线程处于读，则park阻塞当前线程，直到之前所有的读线程都以红黑树遍历的方式读取完成后unpark
                        lockRoot();
                        try {
                            root = balanceInsertion(root, x);
                        } finally {
                            //写完成后，将lockState置0为起始值
                            unlockRoot();
                        }
                    }
                    break;
                }
            }
            assert checkInvariants(root);
            return null;
        }
```
## private final void lockRoot() 获取写
```java
private final void lockRoot() {
            //如果lockState不是起始值，则调用contendedLock获取锁
            if (!U.compareAndSwapInt(this, LOCKSTATE, 0, WRITER))
                contendedLock(); // offload to separate method
        }
```
## private final void contendedLock()获取写锁
```java
private final void contendedLock() {
            boolean waiting = false;
            //for循环直到获取锁为止
            for (int s;;) {
                //~WAITER，表示按位取反，则除了第二位，其他位都必须为0，才能满足((s = lockState) & ~WAITER) == 0
                //满足这个条件的只有lockState为0，则进入写模式
                if (((s = lockState) & ~WAITER) == 0) {
                    if (U.compareAndSwapInt(this, LOCKSTATE, s, WRITER)) {
                        if (waiting)
                            waiter = null;
                        return;
                    }
                }
                //不满足上述条件，则判断(s & WAITER) == 0，要满足该条件，则s必须要是READER状态，则lockState=n*READER+WAITER,并设置waiter等待线程为当前线程。
                else if ((s & WAITER) == 0) {
                    if (U.compareAndSwapInt(this, LOCKSTATE, s, s | WAITER)) {
                        waiting = true;
                        waiter = Thread.currentThread();
                    }
                }
                else if (waiting)
                    LockSupport.park(this);
            }
        }
```