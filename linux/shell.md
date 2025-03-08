**Shell 编程教程**，涵盖 **变量、运算符、流程控制、函数、数组、I/O 重定向、管道、进程控制、shell 脚本调试** 等内容。

---

# **Shell 编程基础**
## **1. 什么是 Shell？**
Shell 是 Linux 和 Unix 系统的命令行解释器，同时也可以用来编写脚本，自动化处理任务。

### **常见的 Shell 类型**
- `bash`（Bourne Again Shell，默认 Shell）
- `sh`（Bourne Shell，较早期）
- `zsh`（Z Shell，功能更强大）
- `ksh`（Korn Shell）

检查当前使用的 Shell：
```sh
echo $SHELL
```

---

## **2. 变量**
### **2.1 变量定义**
```sh
name="Alice"
age=25
```
**注意：**
- `=` 号两边不能有空格
- 变量名建议使用小写

### **2.2 访问变量**
```sh
echo "My name is $name and I am $age years old."
echo "My name is ${name}."
```
- `{}` 主要用于避免歧义，如 `echo "$namefile"` 会误以为变量是 `$namefile` 而非 `$name`。

### **2.3 只读变量**
```sh
readonly pi=3.14
pi=3.1415  # 报错：readonly variable
```

### **2.4 删除变量**
```sh
unset name
echo $name  # 变量已删除，输出为空
```

---

## **3. 运算**
### **3.1 整数运算**
```sh
a=10
b=20
sum=$((a + b))      # 推荐方式
sum=`expr $a + $b`  # 另一种方式（注意 ` 符号）
echo "Sum: $sum"
```
**算术运算符：**
| 运算符 | 含义  |
|--------|-------|
| `+`   | 加法  |
| `-`   | 减法  |
| `*`   | 乘法  |
| `/`   | 除法  |
| `%`   | 取模  |

### **3.2 浮点数运算**
```sh
a=5.5
b=2.3
echo "$a + $b" | bc  # 使用 bc 计算
```

---

## **4. 条件判断**
### **4.1 基本 if 语法**
```sh
if [ 条件 ]; then
    命令
elif [ 其他条件 ]; then
    命令
else
    命令
fi
```

### **4.2 数值比较**
```sh
a=10
b=20

if [ $a -gt $b ]; then
    echo "$a 大于 $b"
else
    echo "$a 小于等于 $b"
fi
```
**数值比较运算符**
| 运算符 | 含义      |
|--------|---------|
| `-eq` | 等于     |
| `-ne` | 不等于   |
| `-gt` | 大于     |
| `-lt` | 小于     |
| `-ge` | 大于等于 |
| `-le` | 小于等于 |

### **4.3 字符串比较**
```sh
str1="hello"
str2="world"

if [ "$str1" = "$str2" ]; then
    echo "字符串相等"
else
    echo "字符串不相等"
fi
```
**字符串比较运算符**
| 运算符  | 含义        |
|---------|-----------|
| `=`     | 等于      |
| `!=`    | 不等于    |
| `-z`    | 是否为空  |
| `-n`    | 是否非空  |

---

## **5. 循环**
### **5.1 for 循环**
```sh
for i in 1 2 3 4 5; do
    echo "Number: $i"
done
```
或
```sh
for ((i=1; i<=5; i++)); do
    echo "Number: $i"
done
```

### **5.2 while 循环**
```sh
count=1
while [ $count -le 5 ]; do
    echo "Count: $count"
    ((count++))
done
```

---

## **6. 数组**
### **6.1 定义数组**
```sh
arr=("apple" "banana" "cherry")
echo ${arr[0]}  # 访问第一个元素
```

### **6.2 遍历数组**
```sh
for item in "${arr[@]}"; do
    echo "$item"
done
```

---

## **7. 函数**
```sh
function say_hello() {
    echo "Hello, $1"
}

say_hello "World"
```

---

## **8. I/O 重定向**
```sh
echo "Hello" > file.txt  # 输出到文件（覆盖）
echo "Hello again" >> file.txt  # 追加到文件
cat < file.txt  # 从文件读取
```

---

## **9. 管道（Pipeline）**
```sh
ls -l | grep "txt"
```

---

## **10. 进程管理**
```sh
ps aux         # 查看进程
kill 1234      # 杀死进程
killall nginx  # 杀死所有 nginx 进程
```

---

## **11. Shell 调试**
```sh
bash -x script.sh  # 调试模式执行
set -x             # 脚本中启用调试
set +x             # 关闭调试
```

---

## **12. Shell 脚本示例**
**示例：批量修改文件名**
```sh
#!/bin/bash

for file in *.txt; do
    mv "$file" "${file%.txt}.bak"
done
```

**示例：自动备份文件**
```sh
#!/bin/bash

backup_dir="/backup"
mkdir -p "$backup_dir"
cp *.txt "$backup_dir/"
echo "备份完成"
```

---

这份详细教程涵盖了 Shell 编程的 **核心知识点**，你可以根据需要深入学习和实践！🚀

你想深入了解哪个部分？😊