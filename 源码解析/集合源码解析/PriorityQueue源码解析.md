# PriorityQueue

PriorityQueue的数据结构采用的是二叉堆，二叉堆是一种特殊的堆，二叉堆是完全二叉树或者是近似完全二叉树。二叉堆有两种：最大堆和最小堆。最大堆：父结点的键值总是大于或等于任何一个子节点的键值；最小堆：父结点的键值总是小于或等于任何一个子节点的键值。

## 二叉堆

## 源码分析

以下是针对 Java 中 `PriorityQueue` 的源码分析，涵盖核心实现逻辑和关键设计细节：

---

### 一、类结构与基本特性
- **继承关系**：继承自 `AbstractQueue`，实现了 `Serializable` 接口。
- **底层数据结构**：基于 **数组**（`Object[] queue`）实现的最小堆（默认），可通过 `Comparator` 自定义排序规则。
- **元素要求**：元素必须实现 `Comparable` 接口，或在构造时提供 `Comparator`，否则抛出 `ClassCastException`。
- **非线程安全**：多线程环境下需外部同步或使用 `PriorityBlockingQueue`。
- **不允许 null**：插入 `null` 会抛出 `NullPointerException`。

---

### 二、核心方法分析

#### 1. 入队操作：`add(E e)` / `offer(E e)`
```java
public boolean offer(E e) {
    if (e == null)
        throw new NullPointerException();
    modCount++;
    int i = size;
    if (i >= queue.length)
        grow(i + 1); // 扩容机制
    siftUp(i, e);   // 上浮调整堆
    size = i + 1;
    return true;
}
```
- **扩容逻辑**：当元素数量超过数组长度时触发（见下文 **扩容机制**）。
- **堆调整**：通过 `siftUp(k, x)` 将元素 `x` 插入到位置 `k`，并向上比较父节点，直到满足堆条件。
  - **比较逻辑**：若自定义了 `Comparator`，则使用其比较；否则使用自然顺序 (`Comparable`)。

#### 2. 出队操作：`poll()`
```java
public E poll() {
    if (size == 0)
        return null;
    int s = --size;
    modCount++;
    E result = (E) queue[0];         // 取出堆顶元素
    E x = (E) queue[s];              // 取末尾元素
    queue[s] = null;                 // 防止内存泄漏
    if (s != 0)
        siftDown(0, x);             // 下沉调整堆
    return result;
}
```
- **堆调整**：将末尾元素移到堆顶，通过 `siftDown(k, x)` 向下比较子节点，直到堆条件满足。

#### 3. 查看队首元素：`peek()`
```java
public E peek() {
    return (size == 0) ? null : (E) queue[0]; // 直接返回数组第一个元素
}
```

---

### 三、堆操作核心方法

#### 1. 上浮调整：`siftUp(int k, E x)`
```java
private void siftUp(int k, E x) {
    if (comparator != null)
        siftUpUsingComparator(k, x);
    else
        siftUpComparable(k, x);
}

private void siftUpComparable(int k, E x) {
    Comparable<? super E> key = (Comparable<? super E>) x;
    while (k > 0) {
        int parent = (k - 1) >>> 1;      // 计算父节点索引
        Object e = queue[parent];
        if (key.compareTo((E) e) >= 0)   // 当前节点 >= 父节点时停止
            break;
        queue[k] = e;                   // 父节点下沉
        k = parent;
    }
    queue[k] = key;                      // 插入正确位置
}
```

#### 2. 下沉调整：`siftDown(int k, E x)`
```java
private void siftDown(int k, E x) {
    if (comparator != null)
        siftDownUsingComparator(k, x);
    else
        siftDownComparable(k, x);
}

private void siftDownComparable(int k, E x) {
    Comparable<? super E> key = (Comparable<? super E>)x;
    int half = size >>> 1;               // 只需遍历到叶子节点的父节点
    while (k < half) {
        int child = (k << 1) + 1;        // 左子节点索引
        Object c = queue[child];
        int right = child + 1;
        if (right < size &&
            ((Comparable<? super E>) c).compareTo((E) queue[right]) > 0)
            c = queue[child = right];    // 选择较小的子节点
        if (key.compareTo((E) c) <= 0)   // 当前节点 <= 子节点时停止
            break;
        queue[k] = c;                    // 子节点上浮
        k = child;
    }
    queue[k] = key;                      // 插入正确位置
}
```

---

### 四、扩容机制
```java
private void grow(int minCapacity) {
    int oldCapacity = queue.length;
    int newCapacity = oldCapacity + ((oldCapacity < 64) ?
                                     (oldCapacity + 2) : // 小容量时快速扩容
                                     (oldCapacity >> 1)); // 大容量时扩容50%
    if (newCapacity > MAX_ARRAY_SIZE)    // 处理溢出
        newCapacity = hugeCapacity(minCapacity);
    queue = Arrays.copyOf(queue, newCapacity);
}
```
- **策略**：旧容量 < 64 时，扩容为 `2*n + 2`；否则扩容 50%。
- **最大容量**：受 `MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8` 限制。

---

### 五、时间复杂度
| 操作      | 时间复杂度  | 说明                     |
|-----------|-------------|--------------------------|
| `offer()` | O(log n)    | 堆调整最多 log n 层      |
| `poll()`  | O(log n)    | 同上                    |
| `peek()`  | O(1)        | 直接访问堆顶元素         |
| `remove()`| O(n)        | 需要线性搜索元素位置     |

---

### 六、注意事项
1. **迭代顺序**：通过 `iterator()` 获得的迭代器不保证按优先级顺序遍历。
2. **动态调整**：修改队列中元素的值可能导致堆结构破坏，需谨慎操作。
3. **初始容量**：默认大小为 11，可根据场景预分配容量以减少扩容开销。

---

通过以上分析，可以看出 `PriorityQueue` 是一个高效、简洁的优先队列实现，适合需要动态排序的场景，但需注意其非线程安全性和元素可变性带来的潜在问题。