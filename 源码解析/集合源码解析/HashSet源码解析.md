# HashSet源码解析

## UML
![title](../../image/HashSet类层次结构.png)  

## 重要属性

|name|value|description|
|---|---|:---|
|map|HashMap<E,Object>|HashSet实际存储对象的容器|
|PRESENT|Object|map默认value|

## 实现原理
<font color='#43CD80'>HashSet中源码实现非常简单，在其中维护了一个HashMap，key当作Set中的元素存储，而value统一存放PRESENT（new Object（）对象）。所有的数据操作实际都是调用HashMap相应的方法进行处理。</font>

## 方法

```java
public boolean add(E e) {
    return map.put(e, PRESENT)==null;
}

public boolean remove(Object o) {
    return map.remove(o)==PRESENT;
}

public int size() {
    return map.size();
}

public boolean contains(Object o) {
    return map.containsKey(o);
}
```