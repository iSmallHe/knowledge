# HashMap源码解析
HashMap实现是采用数组+链表（双向链表+红黑树）实现的
``` java
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
### 解析
        1. 这个算法的精巧之处，在于：由于hashmap中所有的capacity都必须是2的n次方，当我们预设的capacity不符合规定时，  
        他帮我们自动调整为正确的capacity，首先-1的原因是为了把所有位都置1后加1的操作，其主要目的还是为了防止预设值为正常时，  
        实际初始化大小却为预设值的2倍。  
        2. >>>：是逻辑右移，高位置0。>>：是算数右移，高位在正数时置0，负数时置1。  
        3. 操作过程：初始，在第一个高位为1的位置右移一位，再或运算，则高两位都置1；再高两位右移两位后进行或预算，则高四位为1，  
        以此到右移16为，则将int的32位中以高位为1的后面位全部置1，然后再加1，将capacity变成2的n次方。  

```java
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    if (oldCap > 0) {
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    else {               // zero initial threshold signifies using defaults
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    if (newThr == 0) {
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
        Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) {
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                if (e.next == null)
                //待解析处代码1
                    newTab[e.hash & (newCap - 1)] = e;
                else if (e instanceof TreeNode)
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                else { // preserve order
                    Node<K,V> loHead = null, loTail = null;
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        next = e.next;
                        //待解析处代码2
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
### 解析
``e.hash & (newCap - 1)``
此处代码是根据 hash值来获取table中对应下标位置存放处，其原理：因为HashMap中维护的table数组的长度为2的n次方，所以取余操作，可以通过数组长度-1之后相与，可得到余数，原理表格如下:
假设table数组长度为16，则值为0b10000，某个带储存对象hash值为：0b10110111
|     |     |     |     |     |     |     |     |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
|  1   |   0  |   1  |  1   |  0   |  1   |  1   |   1  |
|     |     |     |   1  |  0   |  0   |   0  |   0  |
若要对此进行求余，可将table长度-1（即后面位全为1），相与，则可获得当前值的余数0b0111
|     |     |     |     |     |     |     |     |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
|  1   |   0  |   1  |  1   |  0   |  1   |  1   |   1  |
|     |     |     |   0  |  1   |  1   |   1  |   1  |
|     |     |     |     |  0   |  1   |   1  |   1  |
``(e.hash & oldCap) == 0``此处代码逻辑是因为在扩容后，新数组是原数组的2倍，所以取余时的相与位数要多一位，但是由于之前取余时，已经判断当时余数是一致的，所以现在我们只需要判断扩容前的最高位对应的hash值是0还是1，则可判断出，扩容后，元素存放的位置（假设下标为x，数组长度为n），为0时，则依然放置原处x，为1时，则表示应放置在下标为x+n处。其逻辑还是一样重新计算对象存储在table中的位置。