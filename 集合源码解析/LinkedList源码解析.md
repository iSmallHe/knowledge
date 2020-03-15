# LinkedList源码解析
![title](../image/LinkedList继承树.png)  
<font color='#FFA500'>LinkedList属性：</font>  
* size：LinkedList长度  
* first：LinkedList中的首节点
* last：LinkedList中的尾节点  
<font color='#43CD80'>LinkedList采用的是双向链表结构，其存储对象为Node，每一个Node对象都会包含一个next，prev的属性</font>  

### 几个方法的作用区分：
1. poll方法是：获取第一个元素，并移除，如果当前没有元素，则返回null
2. peek方法是：仅仅获取第一个元素，不做移除
3. offer方法是：仅仅向队列最后添加一个元素
4. pop方法是：移除一个元素并返回，如果当前没有元素，则抛出异常NoSuchElementException
5. push方法是：在队列最前面添加元素