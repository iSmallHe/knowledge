# SpringBoot中的Tomcat
    tomcat中常见的Filter，Servlet，listener，在Spring中其实也会用到，但我们是如何将这些bean注册到tomcat容器中的呢？

## tomcat的创建
    springboot中tomcat服务器的创建在AbstractApplicationContext主流程下的onRefresh()中。
```java
private void createWebServer() {
    WebServer webServer = this.webServer;
    ServletContext servletContext = getServletContext();
    // 在默认情况下，我们没有主动创建WebServer以及ServletContext
    if (webServer == null && servletContext == null) {
        // 此处只是创建一个记录仪，无需多看
        StartupStep createWebServer = this.getApplicationStartup().start("spring.boot.webserver.create");
        // 这里是获取创建WebServer的factory，由于SpringBoot的自动化配置，我们默认会加载 TomcatServletWebServerFactory
        // 此处不理解的话，需要去查看SpringBoot的自动加载配置信息
        ServletWebServerFactory factory = getWebServerFactory();
        createWebServer.tag("factory", factory.getClass().toString());
        // 向tomcat中注册Filter，Servlet，listener的重中之重在 getSelfInitializer()，但getSelfInitializer我们稍后分析，我们先追踪下ServletContextInitializer的后续走向
        this.webServer = factory.getWebServer(getSelfInitializer());
        createWebServer.end();
        getBeanFactory().registerSingleton("webServerGracefulShutdown",
                new WebServerGracefulShutdownLifecycle(this.webServer));
        getBeanFactory().registerSingleton("webServerStartStop",
                new WebServerStartStopLifecycle(this, this.webServer));
    }
    else if (servletContext != null) {
        try {
            getSelfInitializer().onStartup(servletContext);
        }
        catch (ServletException ex) {
            throw new ApplicationContextException("Cannot initialize servlet context", ex);
        }
    }
    initPropertySources();
}
// 此时我们继续追踪ServletContextInitializer
public WebServer getWebServer(ServletContextInitializer... initializers) {
    if (this.disableMBeanRegistry) {
        Registry.disableRegistry();
    }
    Tomcat tomcat = new Tomcat();
    File baseDir = (this.baseDirectory != null) ? this.baseDirectory : createTempDir("tomcat");
    tomcat.setBaseDir(baseDir.getAbsolutePath());
    Connector connector = new Connector(this.protocol);
    connector.setThrowOnFailure(true);
    tomcat.getService().addConnector(connector);
    customizeConnector(connector);
    tomcat.setConnector(connector);
    tomcat.getHost().setAutoDeploy(false);
    configureEngine(tomcat.getEngine());
    for (Connector additionalConnector : this.additionalTomcatConnectors) {
        tomcat.getService().addConnector(additionalConnector);
    }
    // 此时准备Context，会引用到ServletContextInitializer
    prepareContext(tomcat.getHost(), initializers);
    // 此时将启动tomcat
    return getTomcatWebServer(tomcat);
}
// 继续追踪ServletContextInitializer
protected void prepareContext(Host host, ServletContextInitializer[] initializers) {
    File documentRoot = getValidDocumentRoot();
    TomcatEmbeddedContext context = new TomcatEmbeddedContext();
    if (documentRoot != null) {
        context.setResources(new LoaderHidingResourceRoot(context));
    }
    context.setName(getContextPath());
    context.setDisplayName(getDisplayName());
    context.setPath(getContextPath());
    File docBase = (documentRoot != null) ? documentRoot : createTempDir("tomcat-docbase");
    context.setDocBase(docBase.getAbsolutePath());
    context.addLifecycleListener(new FixContextListener());
    context.setParentClassLoader((this.resourceLoader != null) ? this.resourceLoader.getClassLoader()
            : ClassUtils.getDefaultClassLoader());
    resetDefaultLocaleMapping(context);
    addLocaleMappings(context);
    try {
        context.setCreateUploadTargets(true);
    }
    catch (NoSuchMethodError ex) {
        // Tomcat is < 8.5.39. Continue.
    }
    configureTldPatterns(context);
    WebappLoader loader = new WebappLoader();
    loader.setLoaderClass(TomcatEmbeddedWebappClassLoader.class.getName());
    loader.setDelegate(true);
    context.setLoader(loader);
    if (isRegisterDefaultServlet()) {
        addDefaultServlet(context);
    }
    if (shouldRegisterJspServlet()) {
        addJspServlet(context);
        addJasperInitializer(context);
    }
    context.addLifecycleListener(new StaticResourceConfigurer(context));
    // ServletContextInitializer在此处进行合并
    ServletContextInitializer[] initializersToUse = mergeInitializers(initializers);
    host.addChild(context);
    // 并将合并后的ServletContextInitializer再进行配置
    configureContext(context, initializersToUse);
    postProcessContext(context);
}
// 继续追踪ServletContextInitializer
protected void configureContext(Context context, ServletContextInitializer[] initializers) {
    // TomcatStarter将在onStartup时，initializers调用onStartup
    TomcatStarter starter = new TomcatStarter(initializers);
    if (context instanceof TomcatEmbeddedContext) {
        TomcatEmbeddedContext embeddedContext = (TomcatEmbeddedContext) context;
        embeddedContext.setStarter(starter);
        embeddedContext.setFailCtxIfServletStartFails(true);
    }
    // 此时将TomcatStarter放入，此时追踪到此结束，这意味这，在tomcat启动后，对这些ServletContextInitializer执行，有兴趣可以继续观看后续的源码，但我们此时不再进行过多分析，因为后续涉及太多的tomcat源码
    context.addServletContainerInitializer(starter, NO_CLASSES);
    for (LifecycleListener lifecycleListener : this.contextLifecycleListeners) {
        context.addLifecycleListener(lifecycleListener);
    }
    for (Valve valve : this.contextValves) {
        context.getPipeline().addValve(valve);
    }
    for (ErrorPage errorPage : getErrorPages()) {
        org.apache.tomcat.util.descriptor.web.ErrorPage tomcatErrorPage = new org.apache.tomcat.util.descriptor.web.ErrorPage();
        tomcatErrorPage.setLocation(errorPage.getPath());
        tomcatErrorPage.setErrorCode(errorPage.getStatusCode());
        tomcatErrorPage.setExceptionType(errorPage.getExceptionName());
        context.addErrorPage(tomcatErrorPage);
    }
    for (MimeMappings.Mapping mapping : getMimeMappings()) {
        context.addMimeMapping(mapping.getExtension(), mapping.getMimeType());
    }
    configureSession(context);
    new DisableReferenceClearingContextCustomizer().customize(context);
    for (String webListenerClassName : getWebListenerClassNames()) {
        context.addApplicationListener(webListenerClassName);
    }
    for (TomcatContextCustomizer customizer : this.tomcatContextCustomizers) {
        customizer.customize(context);
    }
}
```
    需要查看tomcat相关源码，请看[tomcat源码](../../tomcat/tomcat9.md)

### 自加载
    getSelfInitializer()方法会创建一个函数式接口ServletContextInitializer，这个函数式接口的内容就是回调selfInitialize
```java
private org.springframework.boot.web.servlet.ServletContextInitializer getSelfInitializer() {
    return this::selfInitialize;
}
private void selfInitialize(ServletContext servletContext) throws ServletException {
    // 向ServletContext中 配置属性保存 ApplicationContext
    prepareWebApplicationContext(servletContext);
    // 将ServletContext封装的域对象ServletContextScope注册到ApplicationContext中
    // 并在ServletContext中同样保存属性ServletContextScope
    registerApplicationScope(servletContext);
    // 注册ServletContext到ApplicationContext中，并将一些其他属性注册到ApplicationContext中
    WebApplicationContextUtils.registerEnvironmentBeans(getBeanFactory(), servletContext);
    // 重中之重在此，遍历sortedList中的ServletContextInitializer
    for (ServletContextInitializer beans : getServletContextInitializerBeans()) {
        // 执行RegistrationBean的逻辑，即向tomcat中注册
        beans.onStartup(servletContext);
    }
}
```
    但是ServletContextInitializer并不能主动执行onStartup来执行，其在configureContext中借助TomcatStarter植入tomcat容器中。TomcatStarter其实现了ServletContainerInitializer。而ServletContainerInitializer将在tomcat服务器启动时调用。

    此时我们再来关注如何向tomcat中注册Servlet，Filter，Listener的

```java
protected Collection<ServletContextInitializer> getServletContextInitializerBeans() {
    return new ServletContextInitializerBeans(getBeanFactory());
}

public ServletContextInitializerBeans(ListableBeanFactory beanFactory,
        Class<? extends ServletContextInitializer>... initializerTypes) {
    this.initializers = new LinkedMultiValueMap<>();
    this.initializerTypes = (initializerTypes.length != 0) ? Arrays.asList(initializerTypes)
            : Collections.singletonList(ServletContextInitializer.class);
    // 将Spring容器中的ServletContextInitializer子类（主要是那些RegistrationBean）bean全部保存到initializers中
    addServletContextInitializerBeans(beanFactory);
    // 此处是获取spring容器中的filter，servlet，listener，然后封装成对应的RegistrationBean
    addAdaptableBeans(beanFactory);
    List<ServletContextInitializer> sortedInitializers = this.initializers.values().stream()
            .flatMap((value) -> value.stream().sorted(AnnotationAwareOrderComparator.INSTANCE))
            .collect(Collectors.toList());
    // 将Spring容器中的加载的RegistrationBean放到sortedList中，后续遍历执行onStartup
    this.sortedList = Collections.unmodifiableList(sortedInitializers);
    logMappings(this.initializers);
}

// 从spring容器中获取所有ServletContextInitializer子类bean，然后保存到initializers中，后续一起执行注册逻辑
private void addServletContextInitializerBeans(ListableBeanFactory beanFactory) {
    for (Class<? extends ServletContextInitializer> initializerType : this.initializerTypes) {
        for (Entry<String, ? extends ServletContextInitializer> initializerBean : getOrderedBeansOfType(beanFactory,
                initializerType)) {
            addServletContextInitializerBean(initializerBean.getKey(), initializerBean.getValue(), beanFactory);
        }
    }
}
// ServletRegistrationBean，FilterRegistrationBean，DelegatingFilterProxyRegistrationBean，ServletListenerRegistrationBean
private void addServletContextInitializerBean(String beanName, ServletContextInitializer initializer,
        ListableBeanFactory beanFactory) {
    if (initializer instanceof ServletRegistrationBean) {
        Servlet source = ((ServletRegistrationBean<?>) initializer).getServlet();
        addServletContextInitializerBean(Servlet.class, beanName, initializer, beanFactory, source);
    }
    else if (initializer instanceof FilterRegistrationBean) {
        Filter source = ((FilterRegistrationBean<?>) initializer).getFilter();
        addServletContextInitializerBean(Filter.class, beanName, initializer, beanFactory, source);
    }
    else if (initializer instanceof DelegatingFilterProxyRegistrationBean) {
        String source = ((DelegatingFilterProxyRegistrationBean) initializer).getTargetBeanName();
        addServletContextInitializerBean(Filter.class, beanName, initializer, beanFactory, source);
    }
    else if (initializer instanceof ServletListenerRegistrationBean) {
        EventListener source = ((ServletListenerRegistrationBean<?>) initializer).getListener();
        addServletContextInitializerBean(EventListener.class, beanName, initializer, beanFactory, source);
    }
    else {
        addServletContextInitializerBean(ServletContextInitializer.class, beanName, initializer, beanFactory,
                initializer);
    }
}

// 此处是获取spring容器中的filter，servlet，listener，然后封装成对应的RegistrationBean
protected void addAdaptableBeans(ListableBeanFactory beanFactory) {
    MultipartConfigElement multipartConfig = getMultipartConfig(beanFactory);
    addAsRegistrationBean(beanFactory, Servlet.class, new ServletRegistrationBeanAdapter(multipartConfig));
    addAsRegistrationBean(beanFactory, Filter.class, new FilterRegistrationBeanAdapter());
    for (Class<?> listenerType : ServletListenerRegistrationBean.getSupportedTypes()) {
        addAsRegistrationBean(beanFactory, EventListener.class, (Class<EventListener>) listenerType,
                new ServletListenerRegistrationBeanAdapter());
    }
}

protected <T> void addAsRegistrationBean(ListableBeanFactory beanFactory, Class<T> type,
        RegistrationBeanAdapter<T> adapter) {
    addAsRegistrationBean(beanFactory, type, type, adapter);
}

private <T, B extends T> void addAsRegistrationBean(ListableBeanFactory beanFactory, Class<T> type,
        Class<B> beanType, RegistrationBeanAdapter<T> adapter) {
    // 从spring容器中获取相应的类型（filter，servlet，listener）的bean，并且会排序
    List<Map.Entry<String, B>> entries = getOrderedBeansOfType(beanFactory, beanType, this.seen);
    for (Entry<String, B> entry : entries) {
        String beanName = entry.getKey();
        B bean = entry.getValue();
        if (this.seen.add(bean)) {
            // 将未添加的bean，封装成对应的RegistrationBean保存到initializers中
            RegistrationBean registration = adapter.createRegistrationBean(beanName, bean, entries.size());
            int order = getOrder(bean);
            registration.setOrder(order);
            this.initializers.add(type, registration);
            if (logger.isTraceEnabled()) {
                logger.trace("Created " + type.getSimpleName() + " initializer for bean '" + beanName + "'; order="
                        + order + ", resource=" + getResourceDescription(beanName, beanFactory));
            }
        }
    }
}
```


### RegistrationBean注册Filter，Servlet，Listener
    注册的主要流程如下
```java
public final void onStartup(ServletContext servletContext) throws ServletException {
    String description = getDescription();
    if (!isEnabled()) {
        logger.info(StringUtils.capitalize(description) + " was not registered (disabled)");
        return;
    }
    register(description, servletContext);
}
```

    我们关注下FilterRegistrationBean的注册流程，其他RegistrationBean都是大同小异
    FilterRegistrationBean继承于AbstractFilterRegistrationBean，其主要的注册流程都在父类中实现

```java
// 获取filter名称
protected String getDescription() {
    Filter filter = getFilter();
    Assert.notNull(filter, "Filter must not be null");
    return "filter " + getOrDeduceName(filter);
}
// 注册filter
protected final void register(String description, ServletContext servletContext) {
    // 向ServletContext注册filter
    D registration = addRegistration(description, servletContext);
    if (registration == null) {
        logger.info(StringUtils.capitalize(description) + " was not registered (possibly already registered?)");
        return;
    }
    // 配置filter的匹配路径或者匹配的Servlet
    configure(registration);
}
// 向ServletContext注册filter
protected Dynamic addRegistration(String description, ServletContext servletContext) {
    Filter filter = getFilter();
    return servletContext.addFilter(getOrDeduceName(filter), filter);
}

// 配置filter的匹配路径或者匹配的Servlet，默认匹配全路径
protected void configure(FilterRegistration.Dynamic registration) {
    super.configure(registration);
    EnumSet<DispatcherType> dispatcherTypes = this.dispatcherTypes;
    if (dispatcherTypes == null) {
        T filter = getFilter();
        if (ClassUtils.isPresent("org.springframework.web.filter.OncePerRequestFilter",
                filter.getClass().getClassLoader()) && filter instanceof OncePerRequestFilter) {
            dispatcherTypes = EnumSet.allOf(DispatcherType.class);
        }
        else {
            dispatcherTypes = EnumSet.of(DispatcherType.REQUEST);
        }
    }
    Set<String> servletNames = new LinkedHashSet<>();
    for (ServletRegistrationBean<?> servletRegistrationBean : this.servletRegistrationBeans) {
        servletNames.add(servletRegistrationBean.getServletName());
    }
    servletNames.addAll(this.servletNames);
    if (servletNames.isEmpty() && this.urlPatterns.isEmpty()) {
        // 默认匹配全路径
        registration.addMappingForUrlPatterns(dispatcherTypes, this.matchAfter, DEFAULT_URL_MAPPINGS);
    }
    else {
        // 配置映射Servlet
        if (!servletNames.isEmpty()) {
            registration.addMappingForServletNames(dispatcherTypes, this.matchAfter,
                    StringUtils.toStringArray(servletNames));
        }
        // 配置映射路径
        if (!this.urlPatterns.isEmpty()) {
            registration.addMappingForUrlPatterns(dispatcherTypes, this.matchAfter,
                    StringUtils.toStringArray(this.urlPatterns));
        }
    }
}
```

## 题外话：DispatcherType
    枚举类 DispatcherType表示的是各种请求类型：
    1. FORWARD：转发，只处理最终流程的响应
    2. INCLUDE：转发，会处理流程中的所有响应
    3. REQUEST：默认请求
    4. ASYNC：异步资源访问
    5. ERROR：失败时
```java
public enum DispatcherType {
    FORWARD,
    INCLUDE,
    REQUEST,
    ASYNC,
    ERROR
}
```