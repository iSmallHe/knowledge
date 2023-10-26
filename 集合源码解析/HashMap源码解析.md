# HashMap源码解析

## 1 UML
![title](../image/HashMap类层次结构.png)  

## 2 重要属性

### 2.1 HashMap
|name|value|description|
|---|---|:---|
|DEFAULT_INITIAL_CAPACITY|1 << 4 == 16|默认初始容量|
|MAXIMUM_CAPACITY|1 << 30 == 1073741824|最大容量|
|DEFAULT_LOAD_FACTOR|0.75f|默认负载因子|
|TREEIFY_THRESHOLD|8|红黑树阈值|
|UNTREEIFY_THRESHOLD|6|反红黑树阈值|
|MIN_TREEIFY_CAPACITY|64|可以对链表进行树化的最小表容量|
|table|Node<K,V>[]|节点数组|
|entrySet|Set<Map.Entry<K,V>>|缓存EntrySet|
|size|int|元素总个数|
|modCount|int|修改计数|
|threshold|int|扩容阈值|
|loadFactor|int|扩容阈值负载因子|

### 2.2 Node
    普通节点类，主要用于处理链表
|name|value|description|
|---|---|:---|
|hash|int|节点hash值|
|key|k|节点的key|
|value|v|节点的value|
|next|Node|下一个节点|


### 2.3 TreeNode
    红黑树节点类
|name|value|description|
|---|---|:---|
|parent|TreeNode|父节点|
|left|TreeNode|子左节点|
|right|TreeNode|子右节点|
|prev|TreeNode|用于链表关联的前节点|

## 3 原理简析
>`HashMap`实现是采用数组+链表（单向链表+红黑树）实现的。
>`HashMap`根据`node`的`hash`值确定存储`table`数组的下标，即`(n - 1) & hash`，`table`存储链表/红黑树的根节点，如果已经存在根节点，则在根节点后以链表的方式关联，当链表存储过长时，则将链表转换为红黑树结构
>扩容：当`HashMap`中的节点总数`size`超过阈值`threshold`时，则会触发扩容


## 4 构造器

```java
public HashMap() {
    this.loadFactor = DEFAULT_LOAD_FACTOR; // all other fields defaulted
}
public HashMap(int initialCapacity) {
    this(initialCapacity, DEFAULT_LOAD_FACTOR);
}
public HashMap(int initialCapacity, float loadFactor) {
    //判断初始化容量
    if (initialCapacity < 0)
        throw new IllegalArgumentException("Illegal initial capacity: " +
                                            initialCapacity);
    //限制最大容量为1<<30                        
    if (initialCapacity > MAXIMUM_CAPACITY)
        initialCapacity = MAXIMUM_CAPACITY;
    if (loadFactor <= 0 || Float.isNaN(loadFactor))
        throw new IllegalArgumentException("Illegal load factor: " +
                                            loadFactor);
    this.loadFactor = loadFactor;
    //由于HashMap的容量值必须为2^n，所以此方法用于获取最接近的2^n
    //此时虽然已经获取了容量值，但是并没有直接进行初始化容器，而是赋值给了threshold，以便后续真正使用HashMap时，设置容器大小
    this.threshold = tableSizeFor(initialCapacity);
}
```

## 5 巧妙算法
### 5.1 tableSizeFor
``` java
//由于HashMap的容量值必须为2^n，所以此方法用于获取最接近的2^n
static final int tableSizeFor(int cap) {
    int n = cap - 1;
    n |= n >>> 1;
    n |= n >>> 2;
    n |= n >>> 4;
    n |= n >>> 8;
    n |= n >>> 16;
    return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACITY : n + 1;
}
```
**我们以二进制示例演示其过程**
|init|value|operate|value|description|
|---|---|---|---|---|
|初始值|01xx xxxx xxxx xxxx xxxx xxxx|左移1位|001x xxxx xxxx xxxx xxxx xxxx|此时相或，最高位1的2位都置为1|
|左移值相或|011x xxxx xxxx xxxx xxxx xxxx|左移2位|0001 1xxx xxxx xxxx xxxx xxxx|此时相或，最高位1的4位都置为1|
|左移值相或|0111 1xxx xxxx xxxx xxxx xxxx|左移4位|0000 0111 1xxx xxxx xxxx xxxx|此时相或，最高位1的8位都置为1|
|左移值相或|0111 1111 1xxx xxxx xxxx xxxx|左移8位|0000 0000 0111 1111 1xxx xxxx|此时相或，最高位1的16位都置为1|
|左移值相或|0111 1111 1111 1111 1xxx xxxx|左移16位|0000 0000 0000 0000 0111 1111|此时相或，最高位1的32位都置为1|
|左移值相或|0111 1111 1111 1111 1111 1111|n += 1|1000 0000 0000 0000 0000 0000|此时最高位1的后位都已经是1，此时+1，则变成2的幂次方|

>1. `>>>`：是逻辑右移，高位置0。`>>`：是算数右移，高位在正数时置0，负数时置1。  
>2. 这个算法的精巧之处，在于：由于`Hashmap`中所有的`capacity`都必须是2的n次方，当我们预设的`capacity`不符合规定时，他帮我们自动调整为正确的`capacity`，首先`capacity - 1`的原因是为了为了防止预设值为正常时，实际初始化大小却为预设值的2倍，因为该算法的核心点在于将1所在的最高位之后的所有位都置为1，然后最后再加1，将数据回正。  
>3. 操作过程：初始，在第一个高位为1的位置右移一位，再或运算，则高两位都置1；再高两位右移两位后进行或预算，则高四位为1，以此到右移16为，则将int的32位中以高位为1的后面位全部置1，然后再加1，将`capacity`变成2的n次方。  

### 5.2 取余
**hash计算数组下标**
`e.hash & (newCap - 1)` 
>此处代码是根据 hash值来获取table中对应下标位置存放处，其原理：因为HashMap中维护的table数组的长度为2的n次方，所以取余操作，可以通过数组长度-1之后相与，可得到余数。假设table数组长度为128，则值为0b10000000，某个带储存对象hash值为：0bxxxxxxxx10110111，原理表格如下:

|name|binary|value|description|
|---|---|---|:---|
|newCap|0000 0000 1000 0000|128|table数组长度|
|hash|xxxx xxxx 1011 0111|n|存储对象hash值|
|newCap - 1|0000 0000 0111 1111|127|table数组长度 - 1|
|e.hash & (newCap - 1)|0000 0000 0011 0111|55|数组下标|


**扩容2倍后，重新计算数组下标**
`(e.hash & oldCap) == 0`  

|name|binary|value|description|
|---|---|---|:---|
|newCap|0000 0001 0000 0000|256|新table数组长度|
|hash|xxxx xxxx 1011 0111|n|存储对象hash值|
|oldCap|0000 0001 0000 0000|128|旧数组长度|
|e.hash & oldCap|0000 000x 0000 0000|0/>0|该值则=0或者>0|


>此处代码逻辑是因为在扩容后，新数组是原数组的2倍，所以取余时的相与位数要多一位，但是由于之前取余时，已经判断当时余数是一致的，所以现在我们只需要判断扩容前的最高位对应的`hash`值是0还是1，则可判断出，扩容后，元素存放的位置（假设下标为`x`，数组长度为`n`），为0时，则依然放置原处`x`，为1时，则表示应放置在下标为`x+n`处。其逻辑还是一样重新计算对象存储在`table`中的位置。


## 6 put

```java
public V put(K key, V value) {
        return putVal(hash(key), key, value, false, true);
    }
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
                boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    //首先判断HashMap的容器是否初始化
    if ((tab = table) == null || (n = tab.length) == 0)
        //未初始化，则调用扩容方法进行初始化大小
        n = (tab = resize()).length;
    //此处用于获取当前需要新增的Node节点在tab数组的下标位置，当tab数组在该下标的位置为空时，则表示HashMap中没有与之相同的key，可以直接插入到tab中。
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    else {
        //此时，则表示当前下标存在Node节点，则需要进一步判断是否存在相同key
        Node<K,V> e; K k;
        //判断tab下的首节点p是否与待插入节点的key相同
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        //此时，首节点p与待插入节点key不相同
        //再判断p是否是红黑树节点
        else if (p instanceof TreeNode)
            //是红黑树节点，则调用红黑树的插入逻辑
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        //此时，表示首节点p不是红黑树，且不与待插入节点key相同
        else {
            //遍历tab下的链表，寻找插入的位置
            for (int binCount = 0; ; ++binCount) {
                //若后续节点为空，则表示整个HashMap中没有相同key，可以直接插入新节点
                if ((e = p.next) == null) {
                    //插入新节点
                    p.next = newNode(hash, key, value, null);
                    //此处用于判断是否 将链表转换为红黑树结构
                    //满足的条件：链表长度超过8
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                //若后续节点不为空，则判断是否与新节点key相同
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        //如果e不为空，则表示存在节点e的key与待插入节点的key相同
        //此时需要判断，是否需要替换value
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;
    //判断容器大小是否超过扩容门槛值,超过则进行容器扩容
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

## 7 扩容
```java
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    //oldCap>0，则表示已经初始化
    if (oldCap > 0) {
        //如果table已经处于最大容量，则不再进行扩容操作
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        //如果table新的长度大于等于默认值，小于最大容量值，则将新的扩容门槛值调整为之前的两倍
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    //此时table未初始化，且创建HashMap对象时，已经设了置初始化table大小
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    //此时table未初始化，且创建HashMap时，未设置table大小，进行初始化设置
    else {               // zero initial threshold signifies using defaults
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    //newThr==0，表示之前table未初始化，且创建HashMap对象时，已经设了置初始化table大小
    if (newThr == 0) {
        //此时重置扩容门槛值
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
        Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    //如果oldTab==null，则表示当前属于初始化，无需将进行数据迁移到新数组中
    //oldTab!=null，则表示需要进行数据迁移
    if (oldTab != null) {
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            //不为空，则表示table在改下标中有数据需要迁移
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                //e.next == null，表示只有一个节点，则直接将该节点迁移到新容器中
                if (e.next == null)
                    //计算数组下标
                    newTab[e.hash & (newCap - 1)] = e;
                //如果是红黑树节点，则调用红黑树的处理方式
                else if (e instanceof TreeNode)
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                //此时表示，当前下标下不止一个节点，且不属于红黑树结构
                else { // preserve order
                    Node<K,V> loHead = null, loTail = null;
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        next = e.next;
                        //待解析处代码2
                        //此处用于判断扩容后，该节点是否需要迁移到另一个下标位置
                        //0：表示该节点仍在当前下标位置
                        //1：表示该节点应该迁移到j+oldCap位置处
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead;
                    }
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

## 删除
    删除节点，如果matchValue == true，则还需要判断value是否相等，才能删除
```java
final Node<K,V> removeNode(int hash, Object key, Object value,
                               boolean matchValue, boolean movable) {
        Node<K,V>[] tab; Node<K,V> p; int n, index;
        // 判断数组是否存在，且hash对应数组下标是否有根节点
        if ((tab = table) != null && (n = tab.length) > 0 &&
            (p = tab[index = (n - 1) & hash]) != null) {
            Node<K,V> node = null, e; K k; V v;
            // 存在根节点后，判断是否是根节点
            if (p.hash == hash &&
                ((k = p.key) == key || (key != null && key.equals(k))))
                node = p;
            else if ((e = p.next) != null) {
                // 非根节点则判断，当前是链表还是红黑树
                if (p instanceof TreeNode)
                    // 通过红黑树方式获取该节点
                    node = ((TreeNode<K,V>)p).getTreeNode(hash, key);
                else {
                    // 通过链表方式获取该节点
                    do {
                        if (e.hash == hash &&
                            ((k = e.key) == key ||
                             (key != null && key.equals(k)))) {
                            node = e;
                            break;
                        }
                        p = e;
                    } while ((e = e.next) != null);
                }
            }
            // 找到该节点后，如果需要按value删除，则判断value是否相等
            if (node != null && (!matchValue || (v = node.value) == value ||
                                 (value != null && value.equals(v)))) {
                if (node instanceof TreeNode)
                    // 红黑树删除节点
                    ((TreeNode<K,V>)node).removeTreeNode(this, tab, movable);
                else if (node == p)
                    // 表明是根节点
                    tab[index] = node.next;
                else
                    // 表明不是链表的根节点，此时p表示node的前节点，所以此时将node从链表中移除
                    p.next = node.next;
                ++modCount;
                --size;
                afterNodeRemoval(node);
                return node;
            }
        }
        return null;
    }

```

## 数据结构转换

### 转红黑树
    链表转红黑树
```java
final void treeifyBin(Node<K,V>[] tab, int hash) {
    int n, index; Node<K,V> e;
    if (tab == null || (n = tab.length) < MIN_TREEIFY_CAPACITY)
        resize();
    else if ((e = tab[index = (n - 1) & hash]) != null) {
        TreeNode<K,V> hd = null, tl = null;
        do {
            TreeNode<K,V> p = replacementTreeNode(e, null);
            if (tl == null)
                hd = p;
            else {
                p.prev = tl;
                tl.next = p;
            }
            tl = p;
        } while ((e = e.next) != null);
        if ((tab[index] = hd) != null)
            hd.treeify(tab);
    }
}
```

### 转链表
    红黑树转链表
```java
final Node<K,V> untreeify(HashMap<K,V> map) {
    Node<K,V> hd = null, tl = null;
    for (Node<K,V> q = this; q != null; q = q.next) {
        Node<K,V> p = map.replacementNode(q, null);
        if (tl == null)
            hd = p;
        else
            tl.next = p;
        tl = p;
    }
    return hd;
}
```

## 红黑树


