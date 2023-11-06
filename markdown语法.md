# markdown语法

## 部分语法
<font color='#43CD80'>markdown语法中换行使用两个空格</font>

## 1 标题
<font color=green>标题语法：使用`#`来控制标题大小，`#`的个数表示标题字体的大小，个数越少，字体越大</font>
>
> `#` 一号标题：
>
> > # 一号标题
>
> `######` 六号标题：
>
> > ###### 六号标题
>

## 2 区块引用
<font color=green>区块引用语法：使用`>`来作为区块的前缀</font>
区块中还支持嵌套区块
>> 我使用了`>>`来嵌套

区块中还可以使用一些基础语法，标题，列表，字体等等
字体

> `*字体*` -- *字体*  
> `**字体**` -- **字体**  
> `***字体***` -- ***字体***  
> `~~字体~~` -- ~~字体~~  
> `_字体_` -- _字体_  

列表

> 1. 我在区块中的列表1
> 2. 我在区块中的列表2

## 3 列表

### 3.1 有序列表
<font color='#43CD80'>有序列表语法：使用数字加英文句号以及空格</font>
> `1. 有序列表1`
> `2. 有序列表2`
> `3. 有序列表3`

1. 有序列表1
2. 有序列表2
3. 有序列表3

### 3.2 无序列表
<font color='#43CD80'>无序列表语法：使用`*+-`加空格作为无序列表前缀</font>
> `* 无序列表第一行`
> `* 无序列表第二行`
> `* 无序列表第三行`

* 无序列表第一行
* 无序列表第二行
* 无序列表第三行

## 4 分割线
<font color='#43CD80'>分割线语法：使用三个以上的星号、减号、底线来表示</font>
> `***`


***

## 5 链接
<font color='#43CD80'>链接语法：`[链接名称](超链接地址 "超链接title")`</font>
`[百度](www.baidu.com "百度")`
[百度](www.baidu.com "百度")

## 6 图片
<font color='#43CD80'>图片语法：`![图片alt](图片地址 "图片title")`</font>

`![我是一张图片](http://1.116.114.158/home.jpg "图片title")`

![我是一张图片](http://1.116.114.158/home.jpg "图片title")


## 7 代码块
<font color='#43CD80'>单行代码块语法：使用两个\`将代码包裹起来</font>
<font color='#43CD80'>多行代码块语法：使用两个\```将代码包裹起来，可以在第一个\```的旁边标注语言类型</font>

## 8 流程图
```flow
flowchat
st=>start: 开始框
op=>operation: 处理框
cond=>condition: 判断框(是或否?)
sub1=>subroutine: 子流程
io=>inputoutput: 输入输出框
e=>end: 结束框
st->op->cond
cond(yes)->io->e
cond(no)->sub1(right)->op
```

```flow
flowchat
st=>start: 开始
op=>operation: GatewayLockHandler根据message获取相应Handler
cond=>condition: Handler不为空
op1=>operation: messageParse解析消息
op2=>operation: execute执行主要的业务
cond1=>condition: 判断是否需要断开连接
op3=>operation: 1.Tio断开连接;2.cache缓存移除
e=>end: 结束
st->op->cond
cond(yes)->op1->op2->cond1
cond(no)->e
cond1(yes)->op3->e
cond1(no)->e
```


## 9 表格
<font color='#43CD80'>表格语法：</font>
```
表头|表头|表头
---|:--:|---:
内容|内容|内容
内容|内容|内容

第二行分割表头和内容。
- 有一个就行，为了对齐，多加了几个
文字默认居左
-两边加：表示文字居中
-右边加：表示文字居右
注：原生的语法两边都要用 | 包起来。此处省略
```
|表头|表头|表头|
|---|:--:|---:|
|内容|内容|内容|
|内容|内容|内容|


## 10 自动链接

```
<http://www.google.com>
```

<http://www.google.com>

