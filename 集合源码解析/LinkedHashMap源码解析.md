# LinkedHashMap源码解析
![title](../image/LinkedHashMap类层次结构.png)  
LinkedHashMap是继承HashMap，在HashMap中维护了一个数组，每一个桶下，维护了一条链表（红黑树）。而LinkedHashMap在HashMap的基础上增加了一条整体的双向链表。而且其排序有两种方式：
1. 插入排序：accessOrder=false，默认情况下
2. 访问排序：accessOrder=true    

LinkedHashMap中的存储对象Entry继承了HashMap的Node，Node基础上添加了before和after两个指针
```java
static class Entry<K,V> extends HashMap.Node<K,V> {
        Entry<K,V> before, after;
        Entry(int hash, K key, V value, Node<K,V> next) {
            super(hash, key, value, next);
        }
    }
```
LinkedHashMap在put时，通过覆盖部分方法实现在HashMap基础上维护一条整体的双向链表
```java
//这是HashMap中的put时的方法主体
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
                   boolean evict) {
        Node<K,V>[] tab; Node<K,V> p; int n, i;
        if ((tab = table) == null || (n = tab.length) == 0)
            n = (tab = resize()).length;
        if ((p = tab[i = (n - 1) & hash]) == null)
        //被覆盖处newNode(hash, key, value, null)
            tab[i] = newNode(hash, key, value, null);
        else {
            Node<K,V> e; K k;
            if (p.hash == hash &&
                ((k = p.key) == key || (key != null && key.equals(k))))
                e = p;
            else if (p instanceof TreeNode)
                e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
            else {
                for (int binCount = 0; ; ++binCount) {
                    if ((e = p.next) == null) {
                    //被覆盖处newNode(hash, key, value, null)
                        p.next = newNode(hash, key, value, null);
                        if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                            treeifyBin(tab, hash);
                        break;
                    }
                    if (e.hash == hash &&
                        ((k = e.key) == key || (key != null && key.equals(k))))
                        break;
                    p = e;
                }
            }
            if (e != null) { // existing mapping for key
                V oldValue = e.value;
                if (!onlyIfAbsent || oldValue == null)
                    e.value = value;
                //被覆盖处
                afterNodeAccess(e);
                return oldValue;
            }
        }
        ++modCount;
        if (++size > threshold)
            resize();
        //被覆盖处
        afterNodeInsertion(evict);
        return null;
    }
/**
*以下是LinkedHashMap中的override实现
*/
//newNode(int hash, K key, V value, Node<K,V> e) 覆盖处
//此处在new新对象时，也维护了LinkedHashMap的双向链表，在插入时，将新对象置于tail末尾
Node<K,V> newNode(int hash, K key, V value, Node<K,V> e) {
        LinkedHashMap.Entry<K,V> p =
            new LinkedHashMap.Entry<K,V>(hash, key, value, e);
        linkNodeLast(p);
        return p;
    }
private void linkNodeLast(LinkedHashMap.Entry<K,V> p) {
        LinkedHashMap.Entry<K,V> last = tail;
        tail = p;
        if (last == null)
            head = p;
        else {
            p.before = last;
            last.after = p;
        }
    }
//此处是判断如果当前LinkedHashMap处于访问排序，则将已访问对象e置于tail末尾处
void afterNodeAccess(Node<K,V> e) { // move node to last
        LinkedHashMap.Entry<K,V> last;
        if (accessOrder && (last = tail) != e) {
            LinkedHashMap.Entry<K,V> p =
                (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
            p.after = null;
            if (b == null)
                head = a;
            else
                b.after = a;
            if (a != null)
                a.before = b;
            else
                last = b;
            if (last == null)
                head = p;
            else {
                p.before = last;
                last.after = p;
            }
            tail = p;
            ++modCount;
        }
    }
//插入后，判断是否要驱逐第一个节点
void afterNodeInsertion(boolean evict) { // possibly remove eldest
        LinkedHashMap.Entry<K,V> first;
        if (evict && (first = head) != null && removeEldestEntry(first)) {
            K key = first.key;
            removeNode(hash(key), key, null, false, true);
        }
    }
protected boolean removeEldestEntry(Map.Entry<K,V> eldest) {
        return false;
    }
```