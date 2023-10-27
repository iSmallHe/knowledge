# ThreadLocal源码解析

## ThreadLocal运行原理
    首先我们在分析ThreadLocal源码之前，先简要分析下其运行逻辑：
ThreadLocal本身并不存储数据，所有的数据均是存储于Thread类中的ThreadLocalMap之中，ThreadLocalMap中存储的数据类型是Entry，其继承于WeakReference，其父类Reference属性referent存储ThreadLocal对象，Entry本身存储value（即我们想要缓存的线程变量）。即Entry中的key是ThreadLocal，value是缓存对象，其继承于WeakReference类，即相当于将ThreadLocal设置为弱引用，当ThreadLocal不再被强引用持有时，系统GC时将回收ThreadLocal，那么在ThreadLocalMap中操作数据时，会调用方法`expungeStaleEntries`清理这些过期数据

    1. 为什么要将ThreadLocal设置为弱引用？
>首先，java是基于垃圾自动回收的理念进行设计！
>如果ThreadLocal不是弱引用，且在整个线程的生命周期之中没有主动将ThreadLocal从ThreadLocalMap中释放的话，那么直到线程死亡之前，线程缓存数据永远都不会被清理，那么这就意味着内存泄露了。
>如果ThreadLocal是弱引用，且在整个线程的生命周期之中没有主动将ThreadLocal从ThreadLocalMap中释放的话，那么在ThreadLocal再无强引用关联的情况下，JVM在GC的时候就会回收该对象，之后再使用ThreadLocalMap时，则会自动清理过期数据。但这也建立在一个前提下：即ThreadLocal再无强引用关联

    2. 什么情况下ThreadLocal会造成内存泄漏？

## ThreadLocal源码
```java
//ThreadLocal其实是将数据存放在Thread中的ThreadLocalMap
public void set(T value) {
        Thread t = Thread.currentThread();
        ThreadLocalMap map = getMap(t);
        if (map != null)
            map.set(this, value);
        else
            createMap(t, value);
    }
ThreadLocalMap getMap(Thread t) {
        return t.threadLocals;
    }
void createMap(Thread t, T firstValue) {
        t.threadLocals = new ThreadLocalMap(this, firstValue);
    }

public T get() {
        Thread t = Thread.currentThread();
        ThreadLocalMap map = getMap(t);
        if (map != null) {
            ThreadLocalMap.Entry e = map.getEntry(this);
            if (e != null) {
                @SuppressWarnings("unchecked")
                T result = (T)e.value;
                return result;
            }
        }
        return setInitialValue();
    }
```


## ThreadLocalMap
```java
private void set(ThreadLocal<?> key, Object value) {

            // We don't use a fast path as with get() because it is at
            // least as common to use set() to create new entries as
            // it is to replace existing ones, in which case, a fast
            // path would fail more often than not.

            Entry[] tab = table;
            int len = tab.length;
            //找到ThreadLocal在table中的对应下标位置
            int i = key.threadLocalHashCode & (len-1);
            //从下标处遍历，直到找到对应Thread/Entry中ThreadLocal为空/Entry为空的时候，就放置到table中
            for (Entry e = tab[i];
                 e != null;
                 e = tab[i = nextIndex(i, len)]) {
                ThreadLocal<?> k = e.get();

                if (k == key) {
                    e.value = value;
                    return;
                }

                if (k == null) {
                    replaceStaleEntry(key, value, i);
                    return;
                }
            }

            tab[i] = new Entry(key, value);
            int sz = ++size;
            if (!cleanSomeSlots(i, sz) && sz >= threshold)
                rehash();
        }
//此方法用于替换staleEntry，但是需要判断整个Entry数组中是否存在ThreadLocal相同的Entry，有的话，就修改这个Entry，并将其所在slot替换成离hash索引的slot最近的位置，方便后续查找 ，以及做一些擦除空闲的Entry       
private void replaceStaleEntry(ThreadLocal<?> key, Object value,
                                       int staleSlot) {
            Entry[] tab = table;
            int len = tab.length;
            Entry e;

            int slotToExpunge = staleSlot;
            for (int i = prevIndex(staleSlot, len);
                 (e = tab[i]) != null;
                 i = prevIndex(i, len))
                if (e.get() == null)
                    slotToExpunge = i;

            for (int i = nextIndex(staleSlot, len);
                 (e = tab[i]) != null;
                 i = nextIndex(i, len)) {
                ThreadLocal<?> k = e.get();

                if (k == key) {
                    e.value = value;

                    tab[i] = tab[staleSlot];
                    tab[staleSlot] = e;

                    // Start expunge at preceding stale entry if it exists
                    if (slotToExpunge == staleSlot)
                        slotToExpunge = i;
                    cleanSomeSlots(expungeStaleEntry(slotToExpunge), len);
                    return;
                }

                if (k == null && slotToExpunge == staleSlot)
                    slotToExpunge = i;
            }

            // If key not found, put new entry in stale slot
            tab[staleSlot].value = null;
            tab[staleSlot] = new Entry(key, value);

            // If there are any other stale entries in run, expunge them
            if (slotToExpunge != staleSlot)
                cleanSomeSlots(expungeStaleEntry(slotToExpunge), len);
        }
//擦除staleEntry，并遍历Entry数组清除回收过的Entry，以及将未回收的Entry的位置调换至其索引slot最近的位置，方便后续查询
private int expungeStaleEntry(int staleSlot) {
            Entry[] tab = table;
            int len = tab.length;

            // expunge entry at staleSlot
            tab[staleSlot].value = null;
            tab[staleSlot] = null;
            size--;

            // Rehash until we encounter null
            Entry e;
            int i;
            for (i = nextIndex(staleSlot, len);
                 (e = tab[i]) != null;
                 i = nextIndex(i, len)) {
                ThreadLocal<?> k = e.get();
                if (k == null) {
                    //清除被回收的Entry
                    e.value = null;
                    tab[i] = null;
                    size--;
                } else {
                    //调换至其索引slot最近的位置
                    int h = k.threadLocalHashCode & (len - 1);
                    if (h != i) {
                        tab[i] = null;

                        // Unlike Knuth 6.4 Algorithm R, we must scan until
                        // null because multiple entries could have been stale.
                        while (tab[h] != null)
                            h = nextIndex(h, len);
                        tab[h] = e;
                    }
                }
            }
            //返回被清除slot的下标
            return i;
        }
//清除被回收的Entry，但不是遍历所有的，只是执行n次(当数组长度为2^n)，但是每当有被被回收的Entry发现时，执行的次数又会重置
private boolean cleanSomeSlots(int i, int n) {
            boolean removed = false;
            Entry[] tab = table;
            int len = tab.length;
            do {
                i = nextIndex(i, len);
                Entry e = tab[i];
                if (e != null && e.get() == null) {
                    n = len;
                    removed = true;
                    i = expungeStaleEntry(i);
                }
            } while ( (n >>>= 1) != 0);
            return removed;
        }
private void rehash() {
            expungeStaleEntries();

            // Use lower threshold for doubling to avoid hysteresis
            if (size >= threshold - threshold / 4)
                resize();
        }
//清理整个Entry数组中被回收的Entry
private void expungeStaleEntries() {
            Entry[] tab = table;
            int len = tab.length;
            for (int j = 0; j < len; j++) {
                Entry e = tab[j];
                if (e != null && e.get() == null)
                    expungeStaleEntry(j);
            }
        }
//扩容，迁移数据
private void resize() {
            Entry[] oldTab = table;
            int oldLen = oldTab.length;
            int newLen = oldLen * 2;
            Entry[] newTab = new Entry[newLen];
            int count = 0;

            for (int j = 0; j < oldLen; ++j) {
                Entry e = oldTab[j];
                if (e != null) {
                    ThreadLocal<?> k = e.get();
                    if (k == null) {
                        e.value = null; // Help the GC
                    } else {
                        int h = k.threadLocalHashCode & (newLen - 1);
                        while (newTab[h] != null)
                            h = nextIndex(h, newLen);
                        newTab[h] = e;
                        count++;
                    }
                }
            }

            setThreshold(newLen);
            size = count;
            table = newTab;
        }
private void setThreshold(int len) {
            threshold = len * 2 / 3;
        }
private Entry getEntry(ThreadLocal<?> key) {
            int i = key.threadLocalHashCode & (table.length - 1);
            Entry e = table[i];
            if (e != null && e.get() == key)
                return e;
            else
                return getEntryAfterMiss(key, i, e);
        }
private Entry getEntryAfterMiss(ThreadLocal<?> key, int i, Entry e) {
            Entry[] tab = table;
            int len = tab.length;

            while (e != null) {
                ThreadLocal<?> k = e.get();
                if (k == key)
                    return e;
                if (k == null)
                    expungeStaleEntry(i);
                else
                    i = nextIndex(i, len);
                e = tab[i];
            }
            return null;
        }
```

## ThreadLocalMap.Entry
```java
static class Entry extends WeakReference<ThreadLocal<?>> {
            /** The value associated with this ThreadLocal. */
            Object value;

            Entry(ThreadLocal<?> k, Object v) {
                super(k);
                value = v;
            }
        }
```