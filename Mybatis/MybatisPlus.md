# MyBatisPlus
    首先分析mybatis-plus需要先理解mybatis的结构
    1. mybatis的全局配置类Configuration
    2. 解析mybatis配置xml 
    3. 解析mapper的xml文件
    4. JDK动态代理Proxy来生成统一的数据库操作逻辑
    5. 参数绑定
    6. 结果映射
    
    mybatis-plus在增强mybatis有几个方面需要了解：
    1. 数据库表与实体类的映射
    2. DAO层单表操作的增删改查
    3. 分页查询的封装
    4. service层的封装
    5. 以及一些插件

    当然我们还需要关注下spring与mybatis的融合mybatis-spring这个jar包的相关代码，这里开启mapper的扫描注册

## mybatis-spring
### ClassPathMapperScanner
    该类用于扫描类路径下的mapper

### MapperFactoryBean
    该类用于注册mapper

## mybatis-plus
    使用mybatis-plus时，其中很多配置类，配置解析类都继承自mybatis，对mybatis再封装，增强
    
### MybatisConfiguration
    MybatisConfiguration 继承 Configuration

### MybatisMapperRegistry
    MybatisMapperRegistry 继承 MapperRegistry

### MybatisMapperAnnotationBuilder
    MybatisMapperAnnotationBuilder 继承 MapperAnnotationBuilder

### AbstractSqlInjector
    mybaits-plus的sql注入器，用于生成BaseMapper的方法
### AbstractMethod

### SelectList

