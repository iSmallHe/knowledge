# mysql-存储过程-触发器-函数
**创建这三类程序时，需要重新定义分隔符，即使用 DELIMITER。**
## 存储过程
![mysql存储过程创建](../image/mysql存储过程创建.png)
## 触发器
```
CREATE <触发器名> < BEFORE | AFTER >
<INSERT | UPDATE | DELETE >
ON <表名> FOR EACH ROW<触发器主体>
```
![mysql触发器创建](../image/创建mysql触发器.png)
## 函数
![mysql函数创建](../image/mysql函数创建.png)