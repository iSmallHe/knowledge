# Hashtable源码解析

## UML
![title](../../image/Hashtable类层次结构.png)  


## 适用场景

    1. 由于Hashtable中的方法都使用synchronized，所以是线程安全类，支持并发访问

## 重要属性
### Hashtable
|name|value|description|
|---|---|:---|
|table|Entry<?,?>[]|实际元素存储容器|
|count|int|计数器|
|threshold|int|扩容阈值|
|loadFactor|float|负载因子，默认0.75|
|modCount|int|修改计数|
|MAX_ARRAY_SIZE|Integer.MAX_VALUE - 8|table数组最大长度|

### Entry
|name|value|description|
|---|---|:---|
|hash|int|key的hash值|
|key|K|key|
|value|V|value|
|next|Entry<?,?>[]|链表引用，指向下一个节点|


## 实现原理

>`Hashtable`中采用数组+单向链表的方式实现。且所有方法基本上都使用`synchronized`，进行加锁，所以`Hashtable`是线程安全类。`Hashtable`中所有`key`，`value`均不允许为`null`

## 新增元素

    新增元素，如果key值已存在则返回旧值，如果key不存在，返回null
    Hashtable的链表新增元素是用新元素作为根节点，并将next指向旧的根节点

```java
public synchronized V put(K key, V value) {
    // key,value都不允许为null
    if (value == null) {
        throw new NullPointerException();
    }

    Entry<?,?> tab[] = table;
    int hash = key.hashCode();
    // 由于Hashtable的容器长度不是以2的幂次方，所以这里使用普通的取余进行处理
    int index = (hash & 0x7FFFFFFF) % tab.length;
    @SuppressWarnings("unchecked")
    Entry<K,V> entry = (Entry<K,V>)tab[index];
    // 如果存在旧值，则替换旧值，直接返回
    for(; entry != null ; entry = entry.next) {
        if ((entry.hash == hash) && entry.key.equals(key)) {
            V old = entry.value;
            entry.value = value;
            return old;
        }
    }
    // 不存在旧值，则直接新增Entry节点
    addEntry(hash, key, value, index);
    return null;
}
//在确定好桶的位置，其链表是往前添加，不是像HashMap往后添加
private void addEntry(int hash, K key, V value, int index) {
    modCount++;

    Entry<?,?> tab[] = table;
    if (count >= threshold) {
        // 元素总数超过阈值时，进行扩容
        rehash();

        tab = table;
        hash = key.hashCode();
        index = (hash & 0x7FFFFFFF) % tab.length;
    }

    // Hashtable的链表新增方式，则是用新元素作为根节点，并将next指向旧的根节点
    @SuppressWarnings("unchecked")
    Entry<K,V> e = (Entry<K,V>) tab[index];
    tab[index] = new Entry<>(hash, key, value, e);
    count++;
}

```

## 扩容

    扩容后table的长度默认为原来容量的两倍并加1，并迁移数据到新数组

```java
//扩容实现，新的数组长度为原来的(oldCapacity << 1) + 1  =2*oldCapacity+1，而且扩容后的对象迁移不如HashMap实现的精致
protected void rehash() {
    int oldCapacity = table.length;
    Entry<?,?>[] oldMap = table;

    // 计算新容量
    int newCapacity = (oldCapacity << 1) + 1;
    // 判断新容量是否超过最大值
    if (newCapacity - MAX_ARRAY_SIZE > 0) {
        if (oldCapacity == MAX_ARRAY_SIZE)
            // Keep running with MAX_ARRAY_SIZE buckets
            return;
        newCapacity = MAX_ARRAY_SIZE;
    }
    Entry<?,?>[] newMap = new Entry<?,?>[newCapacity];

    modCount++;
    // 计算新阈值
    threshold = (int)Math.min(newCapacity * loadFactor, MAX_ARRAY_SIZE + 1);
    table = newMap;
    // 旧数组元素迁移到新数组
    for (int i = oldCapacity ; i-- > 0 ;) {
        for (Entry<K,V> old = (Entry<K,V>)oldMap[i] ; old != null ; ) {
            Entry<K,V> e = old;
            old = old.next;
            // 重新计算对应数组下标
            int index = (e.hash & 0x7FFFFFFF) % newCapacity;
            e.next = (Entry<K,V>)newMap[index];
            newMap[index] = e;
        }
    }
}

```

## 删除元素

    删除元素并返回value值
    
```java
public synchronized V remove(Object key) {
    Entry<?,?> tab[] = table;
    int hash = key.hashCode();
    // 计算元素在table数组下标
    int index = (hash & 0x7FFFFFFF) % tab.length;
    @SuppressWarnings("unchecked")
    Entry<K,V> e = (Entry<K,V>)tab[index];
    // 遍历链表，查找key是否存在，如果存在，则删除链表关联关系
    for(Entry<K,V> prev = null ; e != null ; prev = e, e = e.next) {
        if ((e.hash == hash) && e.key.equals(key)) {
            modCount++;
            // 删除链表关联关系
            if (prev != null) {
                prev.next = e.next;
            } else {
                tab[index] = e.next;
            }
            count--;
            V oldValue = e.value;
            e.value = null;
            return oldValue;
        }
    }
    return null;
}

```