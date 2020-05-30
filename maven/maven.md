# maven
 
## maven的jar包冲突
jar包依赖冲突：
> A->B->C->D1(version1)
> a->b->D2(version2)

此时引用jar包D的不同版本，可能会导致一些问题NoSuchMethodError，ClassNotFoundEexception，NoClassDefFoundException，LinkageError

## maven选择jar版本原理

* 最短路径优先
> maven在面对jar包不同版本时，会优先选择jar包依赖路径最短的jar包，即如上示例，则会选择D2版本
* 最先声明优先
> 如果路径一致，则会优先选择声明在前的jar包。
>> a->b->C1
>> A->B->C2
>> 此时会选择 C1

## 处理jar包冲突方式

* 手动移除jar包
```
 <dependency>
   <groupId>groupId</groupId>
   <artifactId>artifactId</artifactId>
   <version>version</version>
   <exclusions>
       <exclusion>
           <groupId>groupId</groupId>
           <artifactId>artifactId</artifactId>        
       </exclusion>
   </exclusions>
 </dependency>
```
* 冲突jar包，声明版本
最好将所有的jar包版本在父pom中声明jar包及版本，子pom在需要的时候，引入jar包
```
<dependencyManagement>
   <groupId>groupId</groupId>
   <artifactId>artifactId</artifactId>
   <version>version</version>
</dependencyManagement>
```