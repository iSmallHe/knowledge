# HashSet源码解析
![title](../../image/HashSet类层次结构.png)  
<font color='#43CD80'>HashSet中源码实现非常简单，在其中维护了一个HashMap，key当作Set中的元素存储，而value统一存放PRESENT（new Object（）对象）</font>