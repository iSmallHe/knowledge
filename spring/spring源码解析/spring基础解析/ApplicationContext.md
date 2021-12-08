# ApplicationContext基础解析

![ApplicationContext继承图](../../../image/ApplicationContext.png)

**ApplicationContext主要的实现类有**
1. **FileSystemXmlApplicationContext: 基于xml配置文件的spring容器启动类**
2. **ClassPathXmlApplicationContext：基于类路径下的xml配置文件的spring容器启动类**
3. **AnnotationConfigApplicationContext：基于注解的spring容器启动类**

## 类层次结构分析
由继承图可见：ApplicationContext的主要实现类 都继承或者实现了顶级类/接口
1. **BeanFactory：BeanFactory的主要是保存bean的实例，并向外提供接口访问bean信息**
2. **ResourceLoader：资源加载器，主要用于获取类加载器，以及配置文件获取**
3. **ApplicationEventPublisher：事件发布传播的顶级类**
4. **MessageResource：主要用于国际化下，不同语言的适配**
5. **EnvironmentCapable：该接口主要用于获取配置环境**
5. **ResourcePatternResolver：主要用于解析资源地址**

当然还有部分顶级类不再在此赘述

## AbstractApplicationContext

***三者主要的启动流程都继承自 AbstractApplicationContext 的 refresh 方法中***

> AbstractApplicationContext类在refresh方法中定义了Spring启动流程  
> 上述三类ApplicationContext都是基于此流程开展spring的启动  
> 所以在此解析的是通用的流程，个性化的流程将在其他文档中详细描述
```java
@Override
public void refresh() throws BeansException, IllegalStateException {
    synchronized (this.startupShutdownMonitor) {
        // Prepare this context for refreshing.
        prepareRefresh();

        // Tell the subclass to refresh the internal bean factory.
        ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

        // Prepare the bean factory for use in this context.
        prepareBeanFactory(beanFactory);

        try {
            // Allows post-processing of the bean factory in context subclasses.
            postProcessBeanFactory(beanFactory);

            // Invoke factory processors registered as beans in the context.
            invokeBeanFactoryPostProcessors(beanFactory);

            // Register bean processors that intercept bean creation.
            registerBeanPostProcessors(beanFactory);

            // Initialize message source for this context.
            initMessageSource();

            // Initialize event multicaster for this context.
            initApplicationEventMulticaster();

            // Initialize other special beans in specific context subclasses.
            onRefresh();

            // Check for listener beans and register them.
            registerListeners();

            // Instantiate all remaining (non-lazy-init) singletons.
            finishBeanFactoryInitialization(beanFactory);

            // Last step: publish corresponding event.
            finishRefresh();
        }

        catch (BeansException ex) {
            if (logger.isWarnEnabled()) {
                logger.warn("Exception encountered during context initialization - " +
                        "cancelling refresh attempt: " + ex);
            }

            // Destroy already created singletons to avoid dangling resources.
            destroyBeans();

            // Reset 'active' flag.
            cancelRefresh(ex);

            // Propagate exception to caller.
            throw ex;
        }

        finally {
            // Reset common introspection caches in Spring's core, since we
            // might not ever need metadata for singleton beans anymore...
            resetCommonCaches();
        }
    }
}
```

### 重要的拓展类
1. BeanPostProcessor  
    `BeanPostProcessor`主要用于拓展bean的初始化前后    
    注册时机：`AbstractApplicationContext.registerBeanPostProcessors`中    
    执行时机：`AbstractAutowireCapableBeanFactory.initializeBean`中  
    ```java
    public interface BeanPostProcessor {
        @Nullable
        default Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
            return bean;
        }

        @Nullable
        default Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
            return bean;
        }

    }
    ```
2. BeanFactoryPostProcessor  
    `BeanFactoryPostProcessor`主要用于拓展处理`BeanFactory`，此时`BeanFactory`已经经过标准的初始化，且已加载所有的`BeanDefinition`，但没有Bean被初始化。  
    执行时机：`AbstractApplicationContext.invokeBeanFactoryPostProcessors`中
    ```java
    public interface BeanFactoryPostProcessor {

	    void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException;

    }
    ```
3. BeanDefinitionRegistryPostProcessor  
    `BeanDefinitionRegistryPostProcessor`主要用于拓展处理`BeanDefinitionRegistry`中的`BeanDefinition`，接口继承于`BeanFactoryPostProcessor`  
    执行时机：`AbstractApplicationContext.invokeBeanFactoryPostProcessors`中  
    ```java
    public interface BeanDefinitionRegistryPostProcessor extends BeanFactoryPostProcessor {

	    void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) throws BeansException;

    }
    ```
4. InstantiationAwareBeanPostProcessor  
    `InstantiationAwareBeanPostProcessor`主要用于拓展处理Bean的实例化前后，属性配置后，接口继承于`BeanPostProcessor`  
    执行时机：      
    1. `postProcessBeforeInstantiation`实例化前：`AbstractAutowireCapableBeanFactory.createBean.resolveBeforeInstantiation`
    2. `postProcessAfterInstantiation`实例化后：`AbstractAutowireCapableBeanFactory.doCreateBean.populateBean`
    3. `postProcessPropertyValues`属性配置后：`AbstractAutowireCapableBeanFactory.doCreateBean.populateBean`
    ```java
    public interface InstantiationAwareBeanPostProcessor extends BeanPostProcessor {

        @Nullable
        default Object postProcessBeforeInstantiation(Class<?> beanClass, String beanName) throws BeansException {
            return null;
        }

        default boolean postProcessAfterInstantiation(Object bean, String beanName) throws BeansException {
            return true;
        }

        @Nullable
        default PropertyValues postProcessProperties(PropertyValues pvs, Object bean, String beanName)
                throws BeansException {
            return null;
        }

        @Deprecated
        @Nullable
        default PropertyValues postProcessPropertyValues(
                PropertyValues pvs, PropertyDescriptor[] pds, Object bean, String beanName) throws BeansException {
            return pvs;
        }

    }
    ```
5. InitializingBean  
    `InitializingBean`主要用于拓展Bean实例化已完成且属性已配置的节点  
    执行时机：`AbstractAutowireCapableBeanFactory.initializeBean.invokeInitMethods`  
    ```java
    public interface InitializingBean {

        void afterPropertiesSet() throws Exception;

    }
    ```

6. MergedBeanDefinitionPostProcessor  
    `MergedBeanDefinitionPostProcessor`主要用于拓展修改合并的BeanDefinition，接口继承于`BeanPostProcessor`    
    执行时机：`AbstractAutowireCapableBeanFactory.doCreateBean.applyMergedBeanDefinitionPostProcessors`
    ```java
    public interface MergedBeanDefinitionPostProcessor extends BeanPostProcessor {

        void postProcessMergedBeanDefinition(RootBeanDefinition beanDefinition, Class<?> beanType, String beanName);

        default void resetBeanDefinition(String beanName) {
        }

    }
    ```
7. SmartInitializingSingleton
    `SmartInitializingSingleton`主要用于拓展单例bean在创建完成后的相关逻辑
    执行时机：`DefaultListableBeanFactory.preInstantiateSingletons`
    ```java
        public interface SmartInitializingSingleton {
            void afterSingletonsInstantiated();
        }
    ```

8. Aware类型接口
    Aware类型接口属于感知类的接口，用于拓展满足用户需求。
    1. BeanNameAware
    2. BeanClassLoaderAware
    3. BeanFactoryAware
### prepareRefresh
**此方法主要用于spring启动的准备动作**
```java
protected void prepareRefresh() {
    // Switch to active.
    // 1. 设置启动时间，以及启动标志位
    this.startupDate = System.currentTimeMillis();
    this.closed.set(false);
    this.active.set(true);

    if (logger.isDebugEnabled()) {
        if (logger.isTraceEnabled()) {
            logger.trace("Refreshing " + this);
        }
        else {
            logger.debug("Refreshing " + getDisplayName());
        }
    }

    // Initialize any placeholder property sources in the context environment.
    // 用于初始化占位符 属性资源
    initPropertySources();

    // Validate that all properties marked as required are resolvable:
    // see ConfigurablePropertyResolver#setRequiredProperties
    // 验证所有标记为必需的属性都是可解析的
    getEnvironment().validateRequiredProperties();

    // Store pre-refresh ApplicationListeners...
    // 创建早期时间监听器容集合，保存早期监听器，也就是在之前已经初始化的监听器。
    if (this.earlyApplicationListeners == null) {
        this.earlyApplicationListeners = new LinkedHashSet<>(this.applicationListeners);
    }
    else {
        // Reset local application listeners to pre-refresh state.
        this.applicationListeners.clear();
        this.applicationListeners.addAll(this.earlyApplicationListeners);
    }

    // Allow for the collection of early ApplicationEvents,
    // to be published once the multicaster is available...
    this.earlyApplicationEvents = new LinkedHashSet<>();
}
```

### obtainFreshBeanFactory
**该方法用于获取BeanFactory，在AbstractApplicationContext中并未实现，交由子类进行扩展**
1. 基于xml配置文件的实现：是AbstractApplicationContext 的子类 AbstractRefreshableApplicationContext 实现的，此方法中会进行BeanFactory的重置，并创建新的BeanFactory，再进行加载xml配置中的BeanDefinition
2. 基于注解的实现：是 AbstractApplicationContext 的子类 GenericApplicationContext 实现的，此方法中仅设置了BeanFactory的serializationId。因为BeanFactory在之前AnnotationConfigApplicationContext初始化时已经创建完成，并加载了BeanDefinition
```java
protected ConfigurableListableBeanFactory obtainFreshBeanFactory() {
    refreshBeanFactory();
    return getBeanFactory();
}
```

### prepareBeanFactory
**prepareBeanFactory方法主要用于 准备BeanFactory，即给BeanFactory设置基础配置**
```java 
protected void prepareBeanFactory(ConfigurableListableBeanFactory beanFactory) {
    // 设置BeanFactory的类加载器，用于后续类的加载
    beanFactory.setBeanClassLoader(getClassLoader());
    // 设置EL表达式解析器，该解析器将在bean的属性填充中使用（populateBean方法中的applyPropertyValues）
    beanFactory.setBeanExpressionResolver(new StandardBeanExpressionResolver(beanFactory.getBeanClassLoader()));
    // 设置属性编辑器
    beanFactory.addPropertyEditorRegistrar(new ResourceEditorRegistrar(this, getEnvironment()));

    // 添加BeanPostProcessor：ApplicationContextAwareProcessor，该类主要用于给bean赋予某个Aware接口对应注入的对象（EnvironmentAware，ResourceLoaderAware，EmbeddedValueResolverAware，ApplicationEventPublisherAware，MessageSourceAware，ApplicationContextAware）
    beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));

    // 设置忽略依赖，如果有部分bean需要依赖这些类的时候，在属性注入时，会自动忽略这些类的注入（populateBean.filterPropertyDescriptorsForDependencyCheck）
    beanFactory.ignoreDependencyInterface(EnvironmentAware.class);
    beanFactory.ignoreDependencyInterface(EmbeddedValueResolverAware.class);
    beanFactory.ignoreDependencyInterface(ResourceLoaderAware.class);
    beanFactory.ignoreDependencyInterface(ApplicationEventPublisherAware.class);
    beanFactory.ignoreDependencyInterface(MessageSourceAware.class);
    beanFactory.ignoreDependencyInterface(ApplicationContextAware.class);

    // 设置 默认类型的实例bean（populateBean.autowireByType.resolveDependency）
    beanFactory.registerResolvableDependency(BeanFactory.class, beanFactory);
    beanFactory.registerResolvableDependency(ResourceLoader.class, this);
    beanFactory.registerResolvableDependency(ApplicationEventPublisher.class, this);
    beanFactory.registerResolvableDependency(ApplicationContext.class, this);

    // 添加BeanPostProcessor ApplicationListenerDetector ，该类用于探测用户自定义的监听器（ApplicationListener），然后添加到spring的监听器管理中
    beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));

    // 如果BeanFactory中包含loadTimeWeaver，则添加LoadTimeWeaverAwareProcessor，该类主要的作用在于处理LoadTimeWeaverAware接口实现类，注入LoadTimeWeaver
    // 添加一个临时的类加载器
    // LoadTimeWeaver类主要用于 类加载器织入。具体细节，暂不深入分析
    if (beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
        beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
        // Set a temporary ClassLoader for type matching.
        beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
    }

    // 向BeanFactory中注册 默认的 environment
    if (!beanFactory.containsLocalBean(ENVIRONMENT_BEAN_NAME)) {
        beanFactory.registerSingleton(ENVIRONMENT_BEAN_NAME, getEnvironment());
    }
    // 向BeanFactory中注册 默认的 systemProperties
    if (!beanFactory.containsLocalBean(SYSTEM_PROPERTIES_BEAN_NAME)) {
        beanFactory.registerSingleton(SYSTEM_PROPERTIES_BEAN_NAME, getEnvironment().getSystemProperties());
    }
    // 向BeanFactory中注册 默认的 systemEnvironment
    if (!beanFactory.containsLocalBean(SYSTEM_ENVIRONMENT_BEAN_NAME)) {
        beanFactory.registerSingleton(SYSTEM_ENVIRONMENT_BEAN_NAME, getEnvironment().getSystemEnvironment());
    }
}
```

### postProcessBeanFactory
**默认实现为空，交由子类扩展，在xml/注解下，均无实现**

### invokeBeanFactoryPostProcessors
**执行 BeanFactoryPostProcessor 以及 BeanDefinitionRegistryPostProcessor**
```java
protected void invokeBeanFactoryPostProcessors(ConfigurableListableBeanFactory beanFactory) {
    // 执行 BeanFactoryPostProcessor 相关方法，具体内容是执行 BeanFactoryPostProcessor 以及 BeanDefinitionRegistryPostProcessor
    // 排序 按接口 PriorityOrdered Ordered 普通 
    PostProcessorRegistrationDelegate.invokeBeanFactoryPostProcessors(beanFactory, getBeanFactoryPostProcessors());

    // loadTimeWeaver的检测，进行 织入相关 的准备工作
    // Detect a LoadTimeWeaver and prepare for weaving, if found in the meantime
    // (e.g. through an @Bean method registered by ConfigurationClassPostProcessor)
    if (beanFactory.getTempClassLoader() == null && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
        beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
        beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
    }
}
```


### registerBeanPostProcessors
**注册BeanPostProcessor（按照实现的接口 PriorityOrdered Ordered进行排序），默认增加BeanPostProcessorChecker，ApplicationListenerDetector**
```java
// 注册BeanPostProcessor
protected void registerBeanPostProcessors(ConfigurableListableBeanFactory beanFactory) {
    PostProcessorRegistrationDelegate.registerBeanPostProcessors(beanFactory, this);
}

public static void registerBeanPostProcessors(
        ConfigurableListableBeanFactory beanFactory, AbstractApplicationContext applicationContext) {
    // 从BeanFactory中获取已读取的BeanDefinition中的name
    String[] postProcessorNames = beanFactory.getBeanNamesForType(BeanPostProcessor.class, true, false);
    
    int beanProcessorTargetCount = beanFactory.getBeanPostProcessorCount() + 1 + postProcessorNames.length;
    // 添加 BeanPostProcessorChecker 
    // BeanPostProcessorChecker 从目前我的角度看代码：其中的含义是：如果一个非BeanPostProcessor，非基础类的bean，在Initialization后，会去判断是否经过所有的BeanPostProcessor处理，这个判断是直接判断 注册的 BeanPostProcessor 的数量 与 解析出来的BeanDefinition中的 BeanPostProcessor 的初始数量进行比对。如果未经过所有的处理器处理，则会打印INFO日志提示
    beanFactory.addBeanPostProcessor(new BeanPostProcessorChecker(beanFactory, beanProcessorTargetCount));

    // 按照 接口 PriorityOrdered Ordered 普通的进行排序
    // 此时会额外的关注到 MergedBeanDefinitionPostProcessor （此接口也是继承接口 BeanPostProcessor ）
    List<BeanPostProcessor> priorityOrderedPostProcessors = new ArrayList<>();
    List<BeanPostProcessor> internalPostProcessors = new ArrayList<>();
    List<String> orderedPostProcessorNames = new ArrayList<>();
    List<String> nonOrderedPostProcessorNames = new ArrayList<>();
    for (String ppName : postProcessorNames) {
        if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
            BeanPostProcessor pp = beanFactory.getBean(ppName, BeanPostProcessor.class);
            priorityOrderedPostProcessors.add(pp);
            if (pp instanceof MergedBeanDefinitionPostProcessor) {
                internalPostProcessors.add(pp);
            }
        }
        else if (beanFactory.isTypeMatch(ppName, Ordered.class)) {
            orderedPostProcessorNames.add(ppName);
        }
        else {
            nonOrderedPostProcessorNames.add(ppName);
        }
    }

    // 首先注册 BeanPostProcessors 实现了 implement PriorityOrdered.
    sortPostProcessors(priorityOrderedPostProcessors, beanFactory);
    registerBeanPostProcessors(beanFactory, priorityOrderedPostProcessors);

    // Next, register the BeanPostProcessors that implement Ordered.
    List<BeanPostProcessor> orderedPostProcessors = new ArrayList<>(orderedPostProcessorNames.size());
    for (String ppName : orderedPostProcessorNames) {
        BeanPostProcessor pp = beanFactory.getBean(ppName, BeanPostProcessor.class);
        orderedPostProcessors.add(pp);
        if (pp instanceof MergedBeanDefinitionPostProcessor) {
            internalPostProcessors.add(pp);
        }
    }
    sortPostProcessors(orderedPostProcessors, beanFactory);
    registerBeanPostProcessors(beanFactory, orderedPostProcessors);

    // Now, register all regular BeanPostProcessors.
    List<BeanPostProcessor> nonOrderedPostProcessors = new ArrayList<>(nonOrderedPostProcessorNames.size());
    for (String ppName : nonOrderedPostProcessorNames) {
        BeanPostProcessor pp = beanFactory.getBean(ppName, BeanPostProcessor.class);
        nonOrderedPostProcessors.add(pp);
        if (pp instanceof MergedBeanDefinitionPostProcessor) {
            internalPostProcessors.add(pp);
        }
    }
    registerBeanPostProcessors(beanFactory, nonOrderedPostProcessors);

    // Finally, re-register all internal BeanPostProcessors.
    sortPostProcessors(internalPostProcessors, beanFactory);
    registerBeanPostProcessors(beanFactory, internalPostProcessors);

    // Re-register post-processor for detecting inner beans as ApplicationListeners,
    // moving it to the end of the processor chain (for picking up proxies etc).
    // 注册一个 ApplicationListener 的探测器，主要目的用于检测 单例(singleton) 的 ApplicationListener，然后注册到ApplicationContext中
    beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(applicationContext));
}
```

### initMessageSource
国际化处理，暂不解读

### initApplicationEventMulticaster
**初始化事件广播器 ApplicationEventMulticaster （默认创建SimpleApplicationEventMulticaster）**
```java
protected void initApplicationEventMulticaster() {
    ConfigurableListableBeanFactory beanFactory = getBeanFactory();
    // APPLICATION_EVENT_MULTICASTER_BEAN_NAME = "applicationEventMulticaster";
    // 首先判断是否存在bean=applicationEventMulticaster
    if (beanFactory.containsLocalBean(APPLICATION_EVENT_MULTICASTER_BEAN_NAME)) {
        this.applicationEventMulticaster =
                beanFactory.getBean(APPLICATION_EVENT_MULTICASTER_BEAN_NAME, ApplicationEventMulticaster.class);
        if (logger.isTraceEnabled()) {
            logger.trace("Using ApplicationEventMulticaster [" + this.applicationEventMulticaster + "]");
        }
    }
    else {
        // 不存在的话，创建默认SimpleApplicationEventMulticaster，并注册到BeanFactory中
        this.applicationEventMulticaster = new SimpleApplicationEventMulticaster(beanFactory);
        beanFactory.registerSingleton(APPLICATION_EVENT_MULTICASTER_BEAN_NAME, this.applicationEventMulticaster);
        if (logger.isTraceEnabled()) {
            logger.trace("No '" + APPLICATION_EVENT_MULTICASTER_BEAN_NAME + "' bean, using " +
                    "[" + this.applicationEventMulticaster.getClass().getSimpleName() + "]");
        }
    }
}
```

### onRefresh
hook方法，由子类继承拓展

### registerListeners
**向 ApplicationEventMulticaster 中注册监听器，并发布系统初始事件**
```java

protected void registerListeners() {
    // 先注册系统初始的监听器
    for (ApplicationListener<?> listener : getApplicationListeners()) {
        getApplicationEventMulticaster().addApplicationListener(listener);
    }

    // Do not initialize FactoryBeans here: We need to leave all regular beans
    // uninitialized to let post-processors apply to them!
    // 然后保存 用户创建的 监听器，由于此时尚未初始化，所以，在此绑定beanName。
    String[] listenerBeanNames = getBeanNamesForType(ApplicationListener.class, true, false);
    for (String listenerBeanName : listenerBeanNames) {
        getApplicationEventMulticaster().addApplicationListenerBean(listenerBeanName);
    }

    // Publish early application events now that we finally have a multicaster...
    // 先发布系统的初始事件
    Set<ApplicationEvent> earlyEventsToProcess = this.earlyApplicationEvents;
    this.earlyApplicationEvents = null;
    if (earlyEventsToProcess != null) {
        for (ApplicationEvent earlyEvent : earlyEventsToProcess) {
            getApplicationEventMulticaster().multicastEvent(earlyEvent);
        }
    }
}

```

### finishBeanFactoryInitialization


### finishRefresh

```java
protected void finishRefresh() {
    // Clear context-level resource caches (such as ASM metadata from scanning).
    // 清除资源缓存
    clearResourceCaches();

    // Initialize lifecycle processor for this context.
    // 初始化生命周期处理器，默认创建 DefaultLifecycleProcessor
    initLifecycleProcessor();

    // Propagate refresh to lifecycle processor first.
    // 获取继承 Lifecycle 的 bean，执行start方法
    // 其主要逻辑，就是将同一阶段(phase)的bean放置于同一个LifecycleGroup中执行start方法
    getLifecycleProcessor().onRefresh();

    // Publish the final event.
    // 发布 ContextRefreshedEvent 事件
    publishEvent(new ContextRefreshedEvent(this));

    // Participate in LiveBeansView MBean, if active.
    // 和MBeanServer和MBean有关的。相当于把当前容器上下文，注册到MBeanServer里面去。
    // 这样子，MBeanServer持久了容器的引用，就可以拿到容器的所有内容了，也就让Spring支持到了MBean的相关功能
    LiveBeansView.registerApplicationContext(this);
}
```
