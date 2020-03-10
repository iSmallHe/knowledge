# MongoDB使用
## MongoDB概念解析
| sql术语 | mongodb术语 | 解释 |
| :---: | :---: | :---: |
| datebase | database | 数据库 |
| table | collection | 表/集合 |
| row | document | 行记录/文档 |
| column | field | 列/字段 |

## MongoDB语法
### 创建/删除数据库
```
show dbs;//查看所有数据库
use databasename;//如果数据库不存在创建数据库，若存在则直接切换到该数据库
db.dropDatabase();//删除当前数据库
```
### 创建/删除集合
```
show collections;//查看所有集合
db.createCollection(name,options);//创建集合
db.collectionName.drop();//删除集合
```
### 增删改查

```
db.collectionName.insert({});
db.collectionName.delete({});
db.collectionName.update({});
db.collection.find({});
```
### 查询语法
|操作|格式|示例|
|---|---|---|
|等于|key:value|db.col.find({key:value})|
|大于|key:{$gt:value}|db.col.find{key:{$gt:value}}|
|大于等于|key:{$gte:value}|db.col.find{key:{$gte:value}}|
|小于|key:{$lt:value}|db.col.find{key:{$lt:value}}|
|小于等于|key:{$lte:value}|db.col.find{key:{$lte:value}}|

#### AND
```
db.col.find({key1:value1, key2:value2}).pretty();
```
#### OR
```
db.col.find({$or:[{key1:value1},{key2:value2}]);
```

#### limit-skip
```
db.col.find({key:value}).skip(1).limit(10);
```

#### sort
```
db.col.find({key:value}).sort({key:1/-1});//1：表示升序;-1：表示降序
```

### 索引
![title](../image/MongoDB创建索引的参数.png)

```
db.col.createIndex({key:1/-1});//1：表示升序建索引;-1：表示降序建索引。当然还有其他参数
```

### MapReduce

### 管道
![title](../image/MongoDB管道的聚合操作.png)  

![title](../image/MongoDB的管道操作.png)
