# ArrayList源码解析
![title](../image/ArrayList继承树.png)
ArrayList源码是用数组构建集合的，首次创建时，是一个空数组，但是在第一次add时，会进行判断是否未初始化，进而进行扩容操作，首次初始化为长度10的数组。
源码如下：
```java
public boolean add(E e) {
//插入时，判断数组长度是否能够容纳，如若超出，则进行扩容
        ensureCapacityInternal(size + 1);  // Increments modCount!!
        elementData[size++] = e;
        return true;
    }

private void ensureCapacityInternal(int minCapacity) {
        ensureExplicitCapacity(calculateCapacity(elementData, minCapacity));
    }

//该方法是用来计算当前数组需要的最小容量，首先判断数组是否进行初始化，如果未初始化，则长度默认设置为DEFAULT_CAPACITY=10，如果minCapacity的值大于DEFAULT_CAPACITY，则取minCapacity
private static int calculateCapacity(Object[] elementData, int minCapacity) {
        if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
            return Math.max(DEFAULT_CAPACITY, minCapacity);
        }
        return minCapacity;
}
//该方法用于明确数组的长度
private void ensureExplicitCapacity(int minCapacity) {
        modCount++;

        // overflow-conscious code
        //判断如果需要的最小容量不足时，则进行扩容
        if (minCapacity - elementData.length > 0)
            grow(minCapacity);
}
//该方法用于扩容
private void grow(int minCapacity) {
        // overflow-conscious code
        int oldCapacity = elementData.length;
        //扩容时，为当前数组长度的1.5倍
        int newCapacity = oldCapacity + (oldCapacity >> 1);
        //此处用于判断新的容量大小是否 大于 最小需要容量值
        if (newCapacity - minCapacity < 0)
            newCapacity = minCapacity;
        //此处用于判断数组最大长度，进行限制扩容
        if (newCapacity - MAX_ARRAY_SIZE > 0)
            newCapacity = hugeCapacity(minCapacity);
        // minCapacity is usually close to size, so this is a win:
        elementData = Arrays.copyOf(elementData, newCapacity);
    }
//该方法用于获取最大扩容值，此处为什么要用minCapacity呢?  
//原因在于：newCapacity的值可能大于minCapacity，但是当newCapacity的值接近最大长度时，应当选择最接近的进行扩容就好，避免扩容过大。
private static int hugeCapacity(int minCapacity) {
        if (minCapacity < 0) // overflow
            throw new OutOfMemoryError();
        return (minCapacity > MAX_ARRAY_SIZE) ?
            Integer.MAX_VALUE :
            MAX_ARRAY_SIZE;
    }

//ArrayList在获取迭代器时，是直接创建内部类迭代器对象
public Iterator<E> iterator() {
        return new Itr();
    }
public ListIterator<E> listIterator() {
        return new ListItr(0);
    }
```
## ArrayList迭代器
<font color='#FFA500'>ArrayList中的迭代器的原理：</font>  
<font color='#43CD80'>创建内部类迭代器对象，使用属性cursor指向当前容器下标，当执行next()方法时，返回当前cursor下标的对象，cursor值+1，属性lastRet指向当前返回对象所在下标</font>  

### ArrayList迭代器Itr(只可往后迭代)
![title](../image/Itr继承树.png)
```java
//private class Itr implements Iterator<E>
//cursor指向下一个

 public boolean hasNext() {
            return cursor != size;
        }
//在next（）方法获取下一个对象后，指针cursor指向新的下一个对象
 public E next() {
            checkForComodification();
            int i = cursor;
            if (i >= size)
                throw new NoSuchElementException();
            Object[] elementData = ArrayList.this.elementData;
            if (i >= elementData.length)
                throw new ConcurrentModificationException();
            cursor = i + 1;
            return (E) elementData[lastRet = i];
        }
//remove时必须要要执行过next（）方法，lastRet初始化后才可进行remove
public void remove() {
            if (lastRet < 0)
                throw new IllegalStateException();
            checkForComodification();

            try {
                ArrayList.this.remove(lastRet);
                cursor = lastRet;
                lastRet = -1;
                expectedModCount = modCount;
            } catch (IndexOutOfBoundsException ex) {
                throw new ConcurrentModificationException();
            }
        }
```

### ArrayLIst迭代器ListItr(可前后迭代)
![title](../image/ListItr继承树.png)
```java
//private class ListItr extends Itr implements ListIterator<E> 
public boolean hasPrevious() {
            return cursor != 0;
        }

        public int nextIndex() {
            return cursor;
        }

        public int previousIndex() {
            return cursor - 1;
        }

        @SuppressWarnings("unchecked")
        public E previous() {
            checkForComodification();
            int i = cursor - 1;
            if (i < 0)
                throw new NoSuchElementException();
            Object[] elementData = ArrayList.this.elementData;
            if (i >= elementData.length)
                throw new ConcurrentModificationException();
            cursor = i;
            return (E) elementData[lastRet = i];
        }

        public void set(E e) {
            if (lastRet < 0)
                throw new IllegalStateException();
            checkForComodification();

            try {
                ArrayList.this.set(lastRet, e);
            } catch (IndexOutOfBoundsException ex) {
                throw new ConcurrentModificationException();
            }
        }

        public void add(E e) {
            checkForComodification();

            try {
                int i = cursor;
                ArrayList.this.add(i, e);
                cursor = i + 1;
                lastRet = -1;
                expectedModCount = modCount;
            } catch (IndexOutOfBoundsException ex) {
                throw new ConcurrentModificationException();
            }
        }
```