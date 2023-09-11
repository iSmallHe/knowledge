# Mybatis源码解析

## mybatis入门

```java
public static void main(String[] args) {
    SqlSessionFactory factory = null;
    String config = "config/mybatis.xml";
    try {
        InputStream inputStream = Resources.getResourceAsStream(config);
        factory = new SqlSessionFactoryBuilder().build(inputStream);
    } catch (IOException e) {
        e.printStackTrace();
    }
    if (factory != null) {
        SqlSession session = factory.openSession();
        StudentDao mapper = session.getMapper(StudentDao.class);
        List<Student> students = mapper.selectAll();
        System.out.println(JSONUtil.toJsonStr(students));
        session.close();
    }
}
```

## 解析mybatis配置文件
    1. 创建解析类XMLConfigBuilder
    2. 解析配置文件: parser.parse()
    3. 创建默认的DefaultSqlSessionFactory
```java
    public SqlSessionFactory build(InputStream inputStream) {
        return build(inputStream, null, null);
    }

    public SqlSessionFactory build(InputStream inputStream, String environment, Properties properties) {
        try {
            XMLConfigBuilder parser = new XMLConfigBuilder(inputStream, environment, properties);
            return build(parser.parse());
        } catch (Exception e) {
            throw ExceptionFactory.wrapException("Error building SqlSession.", e);
        } finally {
            ErrorContext.instance().reset();
            try {
                if (inputStream != null) {
                    inputStream.close();
                }
            } catch (IOException e) {
                // Intentionally ignore. Prefer previous error.
            }
        }
    }

    public SqlSessionFactory build(Configuration config) {
        return new DefaultSqlSessionFactory(config);
    }
```

### XMLConfigBuilder
    XMLConfigBuilder extends BaseBuilder
    XMLConfigBuilder 使用XPathParser解析文件生成document,此时仅解析xml文件为DOM树,并未实际解析生成配置信息
```java
    public XMLConfigBuilder(InputStream inputStream, String environment, Properties props) {
        this(new XPathParser(inputStream, true, props, new XMLMapperEntityResolver()), environment, props);
    }

    private XMLConfigBuilder(XPathParser parser, String environment, Properties props) {
        // 注意这里new Configuration非常重要，mybatis的配置信息后续都在这里
        super(new Configuration());
        ErrorContext.instance().resource("SQL Mapper Configuration");
        this.configuration.setVariables(props);
        this.parsed = false;
        this.environment = environment;
        this.parser = parser;
    }

    public XPathParser(InputStream inputStream, boolean validation, Properties variables, EntityResolver entityResolver) {
        commonConstructor(validation, variables, entityResolver);
        this.document = createDocument(new InputSource(inputStream));
    }

    private void commonConstructor(boolean validation, Properties variables, EntityResolver entityResolver) {
        this.validation = validation;
        this.entityResolver = entityResolver;
        this.variables = variables;
        XPathFactory factory = XPathFactory.newInstance();
        this.xpath = factory.newXPath();
    }

    // 解析生成document
    private Document createDocument(InputSource inputSource) {
        // important: this must only be called AFTER common constructor
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setValidating(validation);

            factory.setNamespaceAware(false);
            factory.setIgnoringComments(true);
            factory.setIgnoringElementContentWhitespace(false);
            factory.setCoalescing(false);
            factory.setExpandEntityReferences(true);

            DocumentBuilder builder = factory.newDocumentBuilder();
            builder.setEntityResolver(entityResolver);
            builder.setErrorHandler(new ErrorHandler() {
                @Override
                public void error(SAXParseException exception) throws SAXException {
                    throw exception;
                }

                @Override
                public void fatalError(SAXParseException exception) throws SAXException {
                    throw exception;
                }

                @Override
                public void warning(SAXParseException exception) throws SAXException {
                    // NOP
                }
            });
            // 解析xml配置文件生成docuemnt
            return builder.parse(inputSource);
        } catch (Exception e) {
            throw new BuilderException("Error creating document instance.  Cause: " + e, e);
        }
    }
```

### 解析Document
    解析Document文件,将配置信息填充至Configuration类中
    1. 解析根节点configuration
    2. 解析根节点下的子节点
```java

    public Configuration parse() {
        if (parsed) {
            throw new BuilderException("Each XMLConfigBuilder can only be used once.");
        }
        parsed = true;
        parseConfiguration(parser.evalNode("/configuration"));
        return configuration;
    }

    // 解析子节点
    private void parseConfiguration(XNode root) {
        try {
            // issue #117 read properties first
            // 解析标签properties，获取properties文件的信息并保存到configuration中，全局可获取
            propertiesElement(root.evalNode("properties"));
            // 解析settings标签，setting标签用于给Configuration类的属性set参数
            Properties settings = settingsAsProperties(root.evalNode("settings"));
            // 给参数vfsImpl设置类Class
            loadCustomVfs(settings);
            // 给参数logImpl设置类Class
            loadCustomLogImpl(settings);
            // 自定义类型别名
            typeAliasesElement(root.evalNode("typeAliases"));
            // 解析标签plugins，其实plugin就是interceptor
            pluginElement(root.evalNode("plugins"));
            // 解析标签objectFactory，给Configuration设置参数objectFactory
            objectFactoryElement(root.evalNode("objectFactory"));
            // 解析标签objectWrapperFactory，给Configuration设置参数objectWrapperFactory
            objectWrapperFactoryElement(root.evalNode("objectWrapperFactory"));
            // 解析标签reflectorFactory，给Configuration设置参数reflectorFactory
            reflectorFactoryElement(root.evalNode("reflectorFactory"));
            // 设置Configuration类的属性，如果没有setting，则赋予默认值
            settingsElement(settings);
            // read it after objectFactory and objectWrapperFactory issue #631
            // 读取environments标签，其中包含dataSource数据源，连接数据库，
            // 以及transactionManager事务管理器 type：设置事务管理的方式 type="JDBC/MANAGED" JDBC：表示使用JDBC中原生的事务管理方式 MANAGED：被管理，例如Spring
            environmentsElement(root.evalNode("environments"));
            // databaseIdProvider和databaseId的作用简单来说就是让一个项目支持不同的数据库。（暂不了解）
            databaseIdProviderElement(root.evalNode("databaseIdProvider"));
            // 解析typeHandlers，注册typeHandler
            typeHandlerElement(root.evalNode("typeHandlers"));
            // 解析mapper
            mapperElement(root.evalNode("mappers"));
        } catch (Exception e) {
            throw new BuilderException("Error parsing SQL Mapper Configuration. Cause: " + e, e);
        }
    }
```

## SqlSession
    1. 获取数据库连接环境
    2. 根据数据库获取事务工厂类,默认创建ManagedTransactionFactory,及生成ManagedTransaction  
    3. 根据事务隔离级别 创建事务
    4. 生成SqlSession
```java
    public SqlSession openSession() {
        return openSessionFromDataSource(configuration.getDefaultExecutorType(), null, false);
    }

    private SqlSession openSessionFromDataSource(ExecutorType execType, TransactionIsolationLevel level, boolean autoCommit) {
        Transaction tx = null;
        try {
            final Environment environment = configuration.getEnvironment();
            final TransactionFactory transactionFactory = getTransactionFactoryFromEnvironment(environment);
            tx = transactionFactory.newTransaction(environment.getDataSource(), level, autoCommit);
            final Executor executor = configuration.newExecutor(tx, execType);
            return new DefaultSqlSession(configuration, executor, autoCommit);
        } catch (Exception e) {
            closeTransaction(tx); // may have fetched a connection so lets call close()
            throw ExceptionFactory.wrapException("Error opening session.  Cause: " + e, e);
        } finally {
            ErrorContext.instance().reset();
        }
    }
```

## mybatis主要结构分析

主要来看mybatis分为几个部分
1. 配置解析 BaseBuilder的子类, 主要有  
    1.1 XMLConfigBuilder: 用于解析mybatis的配置文件  
    1.2 XMLMapperBuilder: 用于解析mapper的配置文件  
    1.3 MapperBuilderAssistant: 用于协助处理mapper.xml文件,主要将解析后的信息,处理生成对应的对象(MappedStatement, ResultMap, ParameterMapping, ParameterMap, Discriminator), 并将这些信息,置入Configuration中  
    1.4 XMLStatementBuilder: 主要用于解析Mapper.xml文件的增删改查  
    1.5 XMLScriptBuilder: 用于处理sql中的特殊标签(trim,where,set,foreach,if,choose,when,otherwise,bind)  
    1.6 SqlSourceBuilder: 主要用于将sql中的参数#{}进行替换为?, 后续原生的jdbc再进行参数绑定  

    非 BaseHandler的主要类:  
    1.7 MapperAnnotationBuilder: 如果使用包名来加载mapper时，则会使用该类来解析mapper的xml文件，支持处理注解@Insert @Select @Update @Delete 等等  
    1.8 MapperProxyFactory: 使用jdk的Proxy生成mapper接口的代理类  
    1.9 MapperProxy:　MapperProxy实现了接口InvocationHandler, 动态代理类的主要逻辑  
2. SqlSessionFactory   
    默认使用DefaultSqlSessionFactory, 用于创建SqlSession
3. SqlSession  
    默认使用DefaultSqlSession
4. 动态代理  
    mapper的动态代理的工厂类:MapperProxyFactory, 存放于knownMappers
    InvocationHandler的实现类MapperProxy, 其主要代理逻辑在这里

```java
// 从knownMappers中获取对应Mapper代理工厂类, 然后实例化
public <T> T getMapper(Class<T> type, SqlSession sqlSession) {
    final MapperProxyFactory<T> mapperProxyFactory = (MapperProxyFactory<T>) knownMappers.get(type);
    if (mapperProxyFactory == null) {
        throw new BindingException("Type " + type + " is not known to the MapperRegistry.");
    }
    try {
        return mapperProxyFactory.newInstance(sqlSession);
    } catch (Exception e) {
        throw new BindingException("Error getting mapper instance. Cause: " + e, e);
    }
}

protected T newInstance(MapperProxy<T> mapperProxy) {
    return (T) Proxy.newProxyInstance(mapperInterface.getClassLoader(), new Class[] { mapperInterface }, mapperProxy);
}

// 在实例化的过程中会创建重要的MapperProxy, 其实现了InvocationHandler类, 用于代理执行所有方法
public T newInstance(SqlSession sqlSession) {
    final MapperProxy<T> mapperProxy = new MapperProxy<>(sqlSession, mapperInterface, methodCache);
    return newInstance(mapperProxy);
}

// MapperProxy类的invoke方法
// 1. 会创建并缓存执行method的实例对象PlainMethodInvoker
// 2. 执行method
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    try {
      if (Object.class.equals(method.getDeclaringClass())) {
        return method.invoke(this, args);
      } else {
        return cachedInvoker(method).invoke(proxy, method, args, sqlSession);
      }
    } catch (Throwable t) {
      throw ExceptionUtil.unwrapThrowable(t);
    }
}
// 如果方法不是默认方法,则创建PlainMethodInvoker, 此时创建MapperMethod类, 用于解析方法
private MapperMethodInvoker cachedInvoker(Method method) throws Throwable {
    try {
      return MapUtil.computeIfAbsent(methodCache, method, m -> {
        if (m.isDefault()) {
          try {
            if (privateLookupInMethod == null) {
              return new DefaultMethodInvoker(getMethodHandleJava8(method));
            } else {
              return new DefaultMethodInvoker(getMethodHandleJava9(method));
            }
          } catch (IllegalAccessException | InstantiationException | InvocationTargetException
              | NoSuchMethodException e) {
            throw new RuntimeException(e);
          }
        } else {
          return new PlainMethodInvoker(new MapperMethod(mapperInterface, method, sqlSession.getConfiguration()));
        }
      });
    } catch (RuntimeException re) {
      Throwable cause = re.getCause();
      throw cause == null ? re : cause;
    }
}

// PlainMethodInvoker的invoke方法就是调用mapperMethod执行
public Object invoke(Object proxy, Method method, Object[] args, SqlSession sqlSession) throws Throwable {
    return mapperMethod.execute(sqlSession, args);
}

// 创建MapperMethod的时候, 将之前已解析的mapper.xml文件, 与当前方法对应起来
// 解析method的参数,结果,注解等等重要信息
public MapperMethod(Class<?> mapperInterface, Method method, Configuration config) {
    this.command = new SqlCommand(config, mapperInterface, method);
    this.method = new MethodSignature(config, mapperInterface, method);
  }

// 根据方法的类型,执行, SqlSession中封装了jdbc的底层方法, 所以在进行了sql的解析后,调用SqlSession执行
public Object execute(SqlSession sqlSession, Object[] args) {
    Object result;
    switch (command.getType()) {
      case INSERT: {
        Object param = method.convertArgsToSqlCommandParam(args);
        result = rowCountResult(sqlSession.insert(command.getName(), param));
        break;
      }
      case UPDATE: {
        Object param = method.convertArgsToSqlCommandParam(args);
        result = rowCountResult(sqlSession.update(command.getName(), param));
        break;
      }
      case DELETE: {
        Object param = method.convertArgsToSqlCommandParam(args);
        result = rowCountResult(sqlSession.delete(command.getName(), param));
        break;
      }
      case SELECT:
        if (method.returnsVoid() && method.hasResultHandler()) {
          executeWithResultHandler(sqlSession, args);
          result = null;
        } else if (method.returnsMany()) {
          result = executeForMany(sqlSession, args);
        } else if (method.returnsMap()) {
          result = executeForMap(sqlSession, args);
        } else if (method.returnsCursor()) {
          result = executeForCursor(sqlSession, args);
        } else {
          Object param = method.convertArgsToSqlCommandParam(args);
          result = sqlSession.selectOne(command.getName(), param);
          if (method.returnsOptional()
              && (result == null || !method.getReturnType().equals(result.getClass()))) {
            result = Optional.ofNullable(result);
          }
        }
        break;
      case FLUSH:
        result = sqlSession.flushStatements();
        break;
      default:
        throw new BindingException("Unknown execution method for: " + command.getName());
    }
    if (result == null && method.getReturnType().isPrimitive() && !method.returnsVoid()) {
      throw new BindingException("Mapper method '" + command.getName()
          + " attempted to return null from a method with a primitive return type (" + method.getReturnType() + ").");
    }
    return result;
}
```
5. 参数绑定  
    参数绑定在mapper执行方法时的MapperProxy.invoke中, 此时会创建MapperMethod类, 生成ParamNameResolver进行解析@Param注解, 存放于SortedMap<Integer, String> names中
6. 结果映射  
    ResultSetHandler结果映射类, 默认使用DefaultResultSetHandler

```java
public List<Object> handleResultSets(Statement stmt) throws SQLException {
    ErrorContext.instance().activity("handling results").object(mappedStatement.getId());

    final List<Object> multipleResults = new ArrayList<>();

    int resultSetCount = 0;
    ResultSetWrapper rsw = getFirstResultSet(stmt);

    List<ResultMap> resultMaps = mappedStatement.getResultMaps();
    int resultMapCount = resultMaps.size();
    validateResultMapsCount(rsw, resultMapCount);
    while (rsw != null && resultMapCount > resultSetCount) {
      ResultMap resultMap = resultMaps.get(resultSetCount);
      handleResultSet(rsw, resultMap, multipleResults, null);
      rsw = getNextResultSet(stmt);
      cleanUpAfterHandlingResultSet();
      resultSetCount++;
    }

    String[] resultSets = mappedStatement.getResultSets();
    if (resultSets != null) {
      while (rsw != null && resultSetCount < resultSets.length) {
        ResultMapping parentMapping = nextResultMaps.get(resultSets[resultSetCount]);
        if (parentMapping != null) {
          String nestedResultMapId = parentMapping.getNestedResultMapId();
          ResultMap resultMap = configuration.getResultMap(nestedResultMapId);
          handleResultSet(rsw, resultMap, null, parentMapping);
        }
        rsw = getNextResultSet(stmt);
        cleanUpAfterHandlingResultSet();
        resultSetCount++;
      }
    }

    return collapseSingleResultList(multipleResults);
}
```