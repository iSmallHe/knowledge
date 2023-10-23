# Mybatis源码解析

## 简单使用

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

## 解析配置文件
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

### 解析DOM
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

## 结构分析

    主要来看mybatis分为几个部分

### Configuration
    该类保存了整个mybatis所有的配置信息

### 配置解析

    BaseBuilder的子类, 主要有  
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

### SqlSessionFactory   
    默认使用DefaultSqlSessionFactory, 用于创建SqlSession
### SqlSession  
    默认使用DefaultSqlSession
### 动态代理  
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
### 参数绑定  
    参数绑定在mapper执行方法时的MapperProxy.invoke中, 此时会创建MapperMethod类, 生成ParamNameResolver进行解析@Param注解, 存放于SortedMap<Integer, String> names中

#### 参数名称解析器
    1. 首先是创建MapperMethod，这其中会创建MethodSignature类
    2. 在MethodSignature类的构造方法中会生成参数名称解析器ParamNameResolver，用于处理注解@Param，如果没有则默认使用参数名称

``` java

    public MapperMethod(Class<?> mapperInterface, Method method, Configuration config) {
        this.command = new SqlCommand(config, mapperInterface, method);
        this.method = new MethodSignature(config, mapperInterface, method);
    }

    public MethodSignature(Configuration configuration, Class<?> mapperInterface, Method method) {
        Type resolvedReturnType = TypeParameterResolver.resolveReturnType(method, mapperInterface);
        if (resolvedReturnType instanceof Class<?>) {
            this.returnType = (Class<?>) resolvedReturnType;
        } else if (resolvedReturnType instanceof ParameterizedType) {
            this.returnType = (Class<?>) ((ParameterizedType) resolvedReturnType).getRawType();
        } else {
            this.returnType = method.getReturnType();
        }
        this.returnsVoid = void.class.equals(this.returnType);
        this.returnsMany = configuration.getObjectFactory().isCollection(this.returnType) || this.returnType.isArray();
        this.returnsCursor = Cursor.class.equals(this.returnType);
        this.returnsOptional = Optional.class.equals(this.returnType);
        this.mapKey = getMapKey(method);
        this.returnsMap = this.mapKey != null;
        this.rowBoundsIndex = getUniqueParamIndex(method, RowBounds.class);
        this.resultHandlerIndex = getUniqueParamIndex(method, ResultHandler.class);
        this.paramNameResolver = new ParamNameResolver(configuration, method);
    }

    public ParamNameResolver(Configuration config, Method method) {
        this.useActualParamName = config.isUseActualParamName();
        final Class<?>[] paramTypes = method.getParameterTypes();
        final Annotation[][] paramAnnotations = method.getParameterAnnotations();
        final SortedMap<Integer, String> map = new TreeMap<>();
        int paramCount = paramAnnotations.length;
        // get names from @Param annotations
        for (int paramIndex = 0; paramIndex < paramCount; paramIndex++) {
            if (isSpecialParameter(paramTypes[paramIndex])) {
                // skip special parameters
                continue;
            }
            String name = null;
            for (Annotation annotation : paramAnnotations[paramIndex]) {
                if (annotation instanceof Param) {
                    hasParamAnnotation = true;
                    name = ((Param) annotation).value();
                    break;
                }
            }
            if (name == null) {
                // @Param was not specified.
                if (useActualParamName) {
                    name = getActualParamName(method, paramIndex);
                }
                if (name == null) {
                    // use the parameter index as the name ("0", "1", ...)
                    // gcode issue #71
                    name = String.valueOf(map.size());
                }
            }
            map.put(paramIndex, name);
        }
        names = Collections.unmodifiableSortedMap(map);
    }

```
#### 参数转换
    Object param = method.convertArgsToSqlCommandParam(args);
    在mybatis内部对原生jdbc的参数绑定，需要用到map存储数据，这里是将参数转储到ParamMap中

``` java
    
    public Object convertArgsToSqlCommandParam(Object[] args) {
        return paramNameResolver.getNamedParams(args);
    }

    public Object getNamedParams(Object[] args) {
        final int paramCount = names.size();
        if (args == null || paramCount == 0) {
            return null;
        }
        if (!hasParamAnnotation && paramCount == 1) {
            Object value = args[names.firstKey()];
            return wrapToMapIfCollection(value, useActualParamName ? names.get(names.firstKey()) : null);
        } else {
            final Map<String, Object> param = new ParamMap<>();
            int i = 0;
            for (Map.Entry<Integer, String> entry : names.entrySet()) {
                param.put(entry.getValue(), args[entry.getKey()]);
                // add generic param names (param1, param2, ...)
                final String genericParamName = GENERIC_NAME_PREFIX + (i + 1);
                // ensure not to overwrite parameter named with @Param
                if (!names.containsValue(genericParamName)) {
                    param.put(genericParamName, args[entry.getKey()]);
                }
                i++;
            }
            return param;
        }
    }
```
#### 参数绑定
    1. 在生成StatementHandler的时候，会创建DefaultParameterHandler
    2. 参数绑定的时机在 prepareStatement(handler, ms.getStatementLog())，此时会调用DefaultParameterHandler的setParameters，进行参数绑定
```java
    // mybatis内部使用的三个StatementHandler都继承了BaseStatementHandler
    protected BaseStatementHandler(Executor executor, MappedStatement mappedStatement, Object parameterObject,
                                   RowBounds rowBounds, ResultHandler resultHandler, BoundSql boundSql) {
        this.configuration = mappedStatement.getConfiguration();
        this.executor = executor;
        this.mappedStatement = mappedStatement;
        this.rowBounds = rowBounds;

        this.typeHandlerRegistry = configuration.getTypeHandlerRegistry();
        this.objectFactory = configuration.getObjectFactory();

        if (boundSql == null) { // issue #435, get the key before calculating the statement
            generateKeys(parameterObject);
            boundSql = mappedStatement.getBoundSql(parameterObject);
        }

        this.boundSql = boundSql;
        // 此处创建了参数处理器
        this.parameterHandler = configuration.newParameterHandler(mappedStatement, parameterObject, boundSql);
        // 此处创建了结果处理器 用于将数据库中返回的数据转换为我们对应的结果
        this.resultSetHandler = configuration.newResultSetHandler(executor, mappedStatement, rowBounds, parameterHandler,
                resultHandler, boundSql);
    }

    public ParameterHandler newParameterHandler(MappedStatement mappedStatement, Object parameterObject,
                                                BoundSql boundSql) {
        ParameterHandler parameterHandler = mappedStatement.getLang().createParameterHandler(mappedStatement,
                parameterObject, boundSql);
        return (ParameterHandler) interceptorChain.pluginAll(parameterHandler);
    }

    // XMLLanguageDriver类的实现
    public ParameterHandler createParameterHandler(MappedStatement mappedStatement, Object parameterObject,
                                                   BoundSql boundSql) {
        return new DefaultParameterHandler(mappedStatement, parameterObject, boundSql);
    }

    // DefaultParameterHandler 处理参数绑定
    public void setParameters(PreparedStatement ps) {
        ErrorContext.instance().activity("setting parameters").object(mappedStatement.getParameterMap().getId());
        List<ParameterMapping> parameterMappings = boundSql.getParameterMappings();
        if (parameterMappings != null) {
            for (int i = 0; i < parameterMappings.size(); i++) {
                ParameterMapping parameterMapping = parameterMappings.get(i);
                if (parameterMapping.getMode() != ParameterMode.OUT) {
                    Object value;
                    String propertyName = parameterMapping.getProperty();
                    if (boundSql.hasAdditionalParameter(propertyName)) { // issue #448 ask first for additional params
                        value = boundSql.getAdditionalParameter(propertyName);
                    } else if (parameterObject == null) {
                        value = null;
                    } else if (typeHandlerRegistry.hasTypeHandler(parameterObject.getClass())) {
                        value = parameterObject;
                    } else {
                        MetaObject metaObject = configuration.newMetaObject(parameterObject);
                        value = metaObject.getValue(propertyName);
                    }
                    TypeHandler typeHandler = parameterMapping.getTypeHandler();
                    JdbcType jdbcType = parameterMapping.getJdbcType();
                    if (value == null && jdbcType == null) {
                        jdbcType = configuration.getJdbcTypeForNull();
                    }
                    try {
                        typeHandler.setParameter(ps, i + 1, value, jdbcType);
                    } catch (TypeException | SQLException e) {
                        throw new TypeException("Could not set parameters for mapping: " + parameterMapping + ". Cause: " + e, e);
                    }
                }
            }
        }
    }
```


### 结果映射  
    ResultSetHandler结果映射类, 默认使用 DefaultResultSetHandler 进行处理
    结果映射中比较复杂的就是嵌套ResultMap的使用了。这部分逻辑主要在于需要判断行数据是否相同，使用ResultMap中的Id列标识，如果没有，则用该ResultMap中的所有列进行判断
```java
    public List<Object> handleResultSets(Statement stmt) throws SQLException {
        ErrorContext.instance().activity("handling results").object(mappedStatement.getId());

        final List<Object> multipleResults = new ArrayList<>();

        int resultSetCount = 0;
        ResultSetWrapper rsw = getFirstResultSet(stmt);

        List<ResultMap> resultMaps = mappedStatement.getResultMaps();
        int resultMapCount = resultMaps.size();
        validateResultMapsCount(rsw, resultMapCount);
        // 处理ResultMap，顺便说一下如果mapper的增删改查使用的是resultType，其实在解析的时候还是会转换为ResultMap，只不过ResultMapping是空的，应该是利用AutoMapping来处理数据，即后面的 applyAutomaticMappings 方法
        while (rsw != null && resultMapCount > resultSetCount) {
            ResultMap resultMap = resultMaps.get(resultSetCount);
            handleResultSet(rsw, resultMap, multipleResults, null);
            rsw = getNextResultSet(stmt);
            cleanUpAfterHandlingResultSet();
            resultSetCount++;
        }

        // 处理ResultSets 该方式过于偏门，有兴趣可以了解
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

    // 处理数据库返回的数据，转换为mapper的返回值
    private void handleResultSet(ResultSetWrapper rsw, ResultMap resultMap, List<Object> multipleResults,
                                 ResultMapping parentMapping) throws SQLException {
        try {
            if (parentMapping != null) {
                handleRowValues(rsw, resultMap, null, RowBounds.DEFAULT, parentMapping);
            } else if (resultHandler == null) {
                DefaultResultHandler defaultResultHandler = new DefaultResultHandler(objectFactory);
                handleRowValues(rsw, resultMap, defaultResultHandler, rowBounds, null);
                multipleResults.add(defaultResultHandler.getResultList());
            } else {
                handleRowValues(rsw, resultMap, resultHandler, rowBounds, null);
            }
        } finally {
            // issue #228 (close resultsets)
            closeResultSet(rsw.getResultSet());
        }
    }

    // 处理每行数据，此处我们着重看下内部嵌套ResultMap的数据处理
    public void handleRowValues(ResultSetWrapper rsw, ResultMap resultMap, ResultHandler<?> resultHandler,
                                RowBounds rowBounds, ResultMapping parentMapping) throws SQLException {
        if (resultMap.hasNestedResultMaps()) {
            ensureNoRowBounds();
            checkResultHandler();
            handleRowValuesForNestedResultMap(rsw, resultMap, resultHandler, rowBounds, parentMapping);
        } else {
            handleRowValuesForSimpleResultMap(rsw, resultMap, resultHandler, rowBounds, parentMapping);
        }
    }

    private void handleRowValuesForNestedResultMap(ResultSetWrapper rsw, ResultMap resultMap,
                                                   ResultHandler<?> resultHandler, RowBounds rowBounds, ResultMapping parentMapping) throws SQLException {
        final DefaultResultContext<Object> resultContext = new DefaultResultContext<>();
        ResultSet resultSet = rsw.getResultSet();
        skipRows(resultSet, rowBounds);
        Object rowValue = previousRowValue;
        // 遍历每行数据
        while (shouldProcessMoreRows(resultContext, rowBounds) && !resultSet.isClosed() && resultSet.next()) {
            // 用于处理 mybatis 的 Discriminator
            final ResultMap discriminatedResultMap = resolveDiscriminatedResultMap(resultSet, resultMap, null);
            // 创建每行的key，此处要关联ResultMap的ResultId
            final CacheKey rowKey = createRowKey(discriminatedResultMap, rsw, null);
            // 获取之前处理过的缓存数据
            Object partialObject = nestedResultObjects.get(rowKey);
            // issue #577 && #542
            if (mappedStatement.isResultOrdered()) {
                if (partialObject == null && rowValue != null) {
                    nestedResultObjects.clear();
                    storeObject(resultHandler, resultContext, rowValue, parentMapping, resultSet);
                }
                rowValue = getRowValue(rsw, discriminatedResultMap, rowKey, null, partialObject);
            } else {
                // 关键处理
                rowValue = getRowValue(rsw, discriminatedResultMap, rowKey, null, partialObject);
                if (partialObject == null) {
                    // 填充结果
                    storeObject(resultHandler, resultContext, rowValue, parentMapping, resultSet);
                }
            }
        }
        if (rowValue != null && mappedStatement.isResultOrdered() && shouldProcessMoreRows(resultContext, rowBounds)) {
            storeObject(resultHandler, resultContext, rowValue, parentMapping, resultSet);
            previousRowValue = null;
        } else if (rowValue != null) {
            previousRowValue = rowValue;
        }
    }

    private Object getRowValue(ResultSetWrapper rsw, ResultMap resultMap, CacheKey combinedKey, String columnPrefix,
                               Object partialObject) throws SQLException {
        // partialObject用于代表是否之前处理过ResultMap中ID相同的数据
        final String resultMapId = resultMap.getId();
        Object rowValue = partialObject;
        if (rowValue != null) {
            // 存在于ID列相同的数据，则表示该数据应该合并为一条，同层级的列无需处理，直接处理内部嵌套的ResultMap
            final MetaObject metaObject = configuration.newMetaObject(rowValue);
            putAncestor(rowValue, resultMapId);
            // 处理嵌套ResultMap
            applyNestedResultMappings(rsw, resultMap, metaObject, columnPrefix, combinedKey, false);
            ancestorObjects.remove(resultMapId);
        } else {
            // 此时表示该行数据未处理，则需要将每列数据进行处理
            final ResultLoaderMap lazyLoader = new ResultLoaderMap();
            // 创建结果对象
            rowValue = createResultObject(rsw, resultMap, lazyLoader, columnPrefix);
            if (rowValue != null && !hasTypeHandlerForResultObject(rsw, resultMap.getType())) {
                // 封装对象
                final MetaObject metaObject = configuration.newMetaObject(rowValue);
                boolean foundValues = this.useConstructorMappings;
                if (shouldApplyAutomaticMappings(resultMap, true)) {
                    // 处理未配置映射，需自动映射列 有关AutoMapping的内容，在此不再赘述
                    foundValues = applyAutomaticMappings(rsw, resultMap, metaObject, columnPrefix) || foundValues;
                }
                // 处理ResultMap中映射的列
                foundValues = applyPropertyMappings(rsw, resultMap, metaObject, lazyLoader, columnPrefix) || foundValues;
                // 添加缓存，用于后续处理循环引用的问题
                putAncestor(rowValue, resultMapId);
                // 嵌套处理ResultMap中包含其他ResultMap的数据（collection，association，这些标签也会视为ResultMap）
                foundValues = applyNestedResultMappings(rsw, resultMap, metaObject, columnPrefix, combinedKey, true)
                        || foundValues;
                // 处理完嵌套数据后，删除缓存
                ancestorObjects.remove(resultMapId);
                foundValues = lazyLoader.size() > 0 || foundValues;
                rowValue = foundValues || configuration.isReturnInstanceForEmptyRow() ? rowValue : null;
            }
            if (combinedKey != CacheKey.NULL_CACHE_KEY) {
                nestedResultObjects.put(combinedKey, rowValue);
            }
        }
        return rowValue;
    }

    // 处理ResultMapping映射的列
    private boolean applyPropertyMappings(ResultSetWrapper rsw, ResultMap resultMap, MetaObject metaObject,
                                          ResultLoaderMap lazyLoader, String columnPrefix) throws SQLException {
        final List<String> mappedColumnNames = rsw.getMappedColumnNames(resultMap, columnPrefix);
        boolean foundValues = false;
        final List<ResultMapping> propertyMappings = resultMap.getPropertyResultMappings();
        for (ResultMapping propertyMapping : propertyMappings) {
            String column = prependPrefix(propertyMapping.getColumn(), columnPrefix);
            if (propertyMapping.getNestedResultMapId() != null) {
                // the user added a column attribute to a nested result map, ignore it
                column = null;
            }
            if (propertyMapping.isCompositeResult()
                    || column != null && mappedColumnNames.contains(column.toUpperCase(Locale.ENGLISH))
                    || propertyMapping.getResultSet() != null) {
                // 获取该列的数据
                Object value = getPropertyMappingValue(rsw.getResultSet(), metaObject, propertyMapping, lazyLoader,
                        columnPrefix);
                // issue #541 make property optional
                final String property = propertyMapping.getProperty();
                if (property == null) {
                    continue;
                }
                if (value == DEFERRED) {
                    foundValues = true;
                    continue;
                }
                if (value != null) {
                    foundValues = true;
                }
                if (value != null
                        || configuration.isCallSettersOnNulls() && !metaObject.getSetterType(property).isPrimitive()) {
                    // gcode issue #377, call setter on nulls (value is not 'found')
                    // 数据填充
                    metaObject.setValue(property, value);
                }
            }
        }
        return foundValues;
    }

    // 处理ResultMap嵌套数据
    private boolean applyNestedResultMappings(ResultSetWrapper rsw, ResultMap resultMap, MetaObject metaObject,
                                              String parentPrefix, CacheKey parentRowKey, boolean newObject) {
        boolean foundValues = false;
        for (ResultMapping resultMapping : resultMap.getPropertyResultMappings()) {
            // 获取ResultMap中的嵌套ResultMap
            final String nestedResultMapId = resultMapping.getNestedResultMapId();
            if (nestedResultMapId != null && resultMapping.getResultSet() == null) {
                try {
                    final String columnPrefix = getColumnPrefix(parentPrefix, resultMapping);
                    final ResultMap nestedResultMap = getNestedResultMap(rsw.getResultSet(), nestedResultMapId, columnPrefix);
                    if (resultMapping.getColumnPrefix() == null) {
                        // 用于处理循环引用的问题
                        // try to fill circular reference only when columnPrefix
                        // is not specified for the nested result map (issue #215)
                        Object ancestorObject = ancestorObjects.get(nestedResultMapId);
                        if (ancestorObject != null) {
                            if (newObject) {
                                linkObjects(metaObject, resultMapping, ancestorObject); // issue #385
                            }
                            continue;
                        }
                    }
                    // 创建嵌套的RowKey
                    final CacheKey rowKey = createRowKey(nestedResultMap, rsw, columnPrefix);
                    final CacheKey combinedKey = combineKeys(rowKey, parentRowKey);
                    Object rowValue = nestedResultObjects.get(combinedKey);
                    boolean knownValue = rowValue != null;
                    // 如果列是Collection，则先实例化
                    instantiateCollectionPropertyIfAppropriate(resultMapping, metaObject); // mandatory
                    if (anyNotNullColumnHasValue(resultMapping, columnPrefix, rsw)) {
                        // 调用getRowValue处理行数据
                        rowValue = getRowValue(rsw, nestedResultMap, combinedKey, columnPrefix, rowValue);
                        if (rowValue != null && !knownValue) {
                            linkObjects(metaObject, resultMapping, rowValue);
                            foundValues = true;
                        }
                    }
                } catch (SQLException e) {
                    throw new ExecutorException(
                            "Error getting nested result map values for '" + resultMapping.getProperty() + "'.  Cause: " + e, e);
                }
            }
        }
        return foundValues;
    }
```