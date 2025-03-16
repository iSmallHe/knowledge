# SpringBoot源码解析

```java
// springboot运行方法
public static ConfigurableApplicationContext run(Class<?>[] primarySources, String[] args) {
	return new SpringApplication(primarySources).run(args);
}
```

## 一、SpringApplication

```java
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
	this.resourceLoader = resourceLoader;
	Assert.notNull(primarySources, "PrimarySources must not be null");
	this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
	// 用于判断是 servlet（普通web），还是reactive（响应式），还是none（非web）
	this.webApplicationType = WebApplicationType.deduceFromClasspath();
	// 加载BootstrapRegistryInitializer
	this.bootstrapRegistryInitializers = getBootstrapRegistryInitializersFromSpringFactories();
	// 加载ApplicationContextInitializer对应的子类
	setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
	// 加载ApplicationListener对应的子类
	setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
	// 获取系统当前main方法所属类，并加载该类
	this.mainApplicationClass = deduceMainApplicationClass();
}

// 用于判断是 servlet（普通web），还是reactive（响应式），还是none（非web）
static WebApplicationType deduceFromClasspath() {
	if (ClassUtils.isPresent(WEBFLUX_INDICATOR_CLASS, null) && !ClassUtils.isPresent(WEBMVC_INDICATOR_CLASS, null)
			&& !ClassUtils.isPresent(JERSEY_INDICATOR_CLASS, null)) {
		return WebApplicationType.REACTIVE;
	}
	for (String className : SERVLET_INDICATOR_CLASSES) {
		if (!ClassUtils.isPresent(className, null)) {
			return WebApplicationType.NONE;
		}
	}
	return WebApplicationType.SERVLET;
}

// 现在没有Bootstrapper，已移除
@SuppressWarnings("deprecation")
private List<BootstrapRegistryInitializer> getBootstrapRegistryInitializersFromSpringFactories() {
	ArrayList<BootstrapRegistryInitializer> initializers = new ArrayList<>();
	getSpringFactoriesInstances(Bootstrapper.class).stream()
			.map((bootstrapper) -> ((BootstrapRegistryInitializer) bootstrapper::initialize))
			.forEach(initializers::add);
	initializers.addAll(getSpringFactoriesInstances(BootstrapRegistryInitializer.class));
	return initializers;
}

// 获取spring.factories文件，加载对应的类，并创建对应的bean
private <T> Collection<T> getSpringFactoriesInstances(Class<T> type, Class<?>[] parameterTypes, Object... args) {
	// type默认是Bootstrapper.class
	ClassLoader classLoader = getClassLoader();
	// Use names and ensure unique to protect against duplicates
	// 读取spring.factories文件，并获取对应type，需要加载的类
	Set<String> names = new LinkedHashSet<>(SpringFactoriesLoader.loadFactoryNames(type, classLoader));
	// 加载对应的类，并创建对应的bean
	List<T> instances = createSpringFactoriesInstances(type, parameterTypes, classLoader, args, names);
	AnnotationAwareOrderComparator.sort(instances);
	return instances;
}
```


## 二、run

```java
/**
 * Run the Spring application, creating and refreshing a new
 * {@link ApplicationContext}.
 * @param args the application arguments (usually passed from a Java main method)
 * @return a running {@link ApplicationContext}
 */
public ConfigurableApplicationContext run(String... args) {
	// 创建计时器
	StopWatch stopWatch = new StopWatch();
	stopWatch.start();
	// 创建
	DefaultBootstrapContext bootstrapContext = createBootstrapContext();
	ConfigurableApplicationContext context = null;
	// 配置Headless模式
	configureHeadlessProperty();
	// 获取监听器
	SpringApplicationRunListeners listeners = getRunListeners(args);
	// 执行监听器对应逻辑starting
	listeners.starting(bootstrapContext, this.mainApplicationClass);
	try {
		// 构造启动参数
		ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
		// 准备环境，即配置参数，根据配置文件的profile来决定
		ConfigurableEnvironment environment = prepareEnvironment(listeners, bootstrapContext, applicationArguments);
		// 设置系统参数spring.beaninfo.ignore默认true
		configureIgnoreBeanInfo(environment);
		// 打印banner图
		Banner printedBanner = printBanner(environment);
		// 创建ConfigurableApplicationContext
		context = createApplicationContext();
		// 设置启动监听器
		context.setApplicationStartup(this.applicationStartup);
		// 准备 ApplicationContext容器参数
		prepareContext(bootstrapContext, context, environment, listeners, applicationArguments, printedBanner);
		refreshContext(context);
		// 留给子类扩展
		afterRefresh(context, applicationArguments);
		// 计时结束
		stopWatch.stop();
		if (this.logStartupInfo) {
			new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);
		}
		// 监听器 执行 started
		listeners.started(context);
		// 启动结束后，调用runner（ApplicationRunner，CommandLineRunner）
		callRunners(context, applicationArguments);
	}
	catch (Throwable ex) {
		handleRunFailure(context, ex, listeners);
		throw new IllegalStateException(ex);
	}
	// 监听器 执行 running
	try {
		listeners.running(context);
	}
	catch (Throwable ex) {
		handleRunFailure(context, ex, null);
		throw new IllegalStateException(ex);
	}
	return context;
}
```

### 2.1 createBootstrapContext

创建`DefaultBootstrapContext`引导程序启动上下文，并使用`bootstrapRegistryInitializers`初始化`DefaultBootstrapContext`

```java
private DefaultBootstrapContext createBootstrapContext() {
	DefaultBootstrapContext bootstrapContext = new DefaultBootstrapContext();
	this.bootstrapRegistryInitializers.forEach((initializer) -> initializer.initialize(bootstrapContext));
	return bootstrapContext;
}
```

### 2.2 getRunListeners

1. 从`spring.factories`文件中获取`SpringApplicationRunListener`的具体实现类，创建`SpringApplication`运行监听器，监听启动过程中所有动作

```java
private SpringApplicationRunListeners getRunListeners(String[] args) {
	Class<?>[] types = new Class<?>[] { SpringApplication.class, String[].class };
	return new SpringApplicationRunListeners(logger,
			getSpringFactoriesInstances(SpringApplicationRunListener.class, types, this, args),
			this.applicationStartup);
}
```
2. 在`spring-boot`的`jar`包中的`META-INF`路径之下的`spring.factories`文件中，可以看到使用的是`EventPublishingRunListener`

```java
// spring.factories关于SpringApplicationRunListener部分内容
# Run Listeners
org.springframework.boot.SpringApplicationRunListener=\
org.springframework.boot.context.event.EventPublishingRunListener
```

### 2.3 DefaultApplicationArguments

创建DefaultApplicationArguments，即运行时main方法启动参数

```java
ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
```

### 2.4 prepareEnvironment
```java
private ConfigurableEnvironment prepareEnvironment(SpringApplicationRunListeners listeners,
		DefaultBootstrapContext bootstrapContext, ApplicationArguments applicationArguments) {
	// Create and configure the environment
	// 根据webApplicationType来创建不同的环境
	ConfigurableEnvironment environment = getOrCreateEnvironment();
	// 配置默认参数，以及profiles的配置文件
	configureEnvironment(environment, applicationArguments.getSourceArgs());
	// 将configurationProperties 配置置于起始
	ConfigurationPropertySources.attach(environment);
	// 发布environment parepared事件，监听器执行相关逻辑
	listeners.environmentPrepared(bootstrapContext, environment);
	// 将默认（defaultProperties）配置置于末尾
	DefaultPropertiesPropertySource.moveToEnd(environment);
	// 配置额外的profiles
	configureAdditionalProfiles(environment);
	bindToSpringApplication(environment);
	if (!this.isCustomEnvironment) {
		environment = new EnvironmentConverter(getClassLoader()).convertEnvironmentIfNecessary(environment,
				deduceEnvironmentClass());
	}
	ConfigurationPropertySources.attach(environment);
	return environment;
}
```

#### 2.4.1 getOrCreateEnvironment

创建运行环境：根据`webApplicationType`可知，我们使用的是`StandardServletEnvironment`

```java
private ConfigurableEnvironment getOrCreateEnvironment() {
	if (this.environment != null) {
		return this.environment;
	}
	switch (this.webApplicationType) {
	case SERVLET:
		return new StandardServletEnvironment();
	case REACTIVE:
		return new StandardReactiveWebEnvironment();
	default:
		return new StandardEnvironment();
	}
}
```

#### 2.4.2 configureEnvironment

1. 设置`ConversionService`，以双重检查加锁的方式获取单例`ApplicationConversionService`
2. 将`main`启动参数引入运行环境中
3. 配置`profiles`，这里是留给子类拓展，默认实现中并没有处理逻辑

```java
protected void configureEnvironment(ConfigurableEnvironment environment, String[] args) {
	if (this.addConversionService) {
		ConversionService conversionService = ApplicationConversionService.getSharedInstance();
		environment.setConversionService((ConfigurableConversionService) conversionService);
	}
	configurePropertySources(environment, args);
	configureProfiles(environment, args);
}
```

`ConversionService` 是 Spring 框架中的一个接口，它的作用是用于在不同类型之间进行转换。它通常用于将一个类型的数据转换成另一个类型，以便在应用程序中更加灵活地处理数据类型的变化。

**主要作用：**
1. **类型转换**：`ConversionService` 主要用于转换不同类型之间的对象。例如，将 `String` 转换为 `Integer`，或者将自定义的对象转换为 DTO（数据传输对象）。

2. **统一管理转换逻辑**：Spring 提供了一个统一的接口来管理不同的类型转换器（`Converter`），你可以通过实现 `Converter` 接口来定义如何将一种类型转换为另一种类型。

3. **注入支持**：Spring 自动注入 `ConversionService`，并且支持将其与注解如 `@Value` 或 `@ConfigurationProperties` 一起使用，以便自动进行类型转换。

4. **支持自定义转换器**：可以定义自定义的类型转换器，通过实现 `Converter` 接口，或者通过配置 `ConversionService` 来处理更复杂的转换需求。

**常用的实现：**
- `GenericConversionService`：Spring 提供的默认实现，支持很多常见的数据类型转换。`ApplicationConversionService`也是其子类
  
**示例：**
```java
import org.springframework.core.convert.support.GenericConversionService;
import org.springframework.core.convert.converter.Converter;

public class StringToIntegerConverter implements Converter<String, Integer> {
    @Override
    public Integer convert(String source) {
        return Integer.parseInt(source);
    }
}

public class ConversionServiceExample {
    public static void main(String[] args) {
        GenericConversionService conversionService = new GenericConversionService();
        conversionService.addConverter(new StringToIntegerConverter());

        // 使用 ConversionService 执行转换
        Integer result = conversionService.convert("123", Integer.class);
        System.out.println(result);  // 输出：123
    }
}
```

在这个例子中，`StringToIntegerConverter` 将 `String` 转换为 `Integer`，并且通过 `GenericConversionService` 来执行转换。

**总结：**
`ConversionService` 是 Spring 框架中提供的一种灵活的方式，用于在应用程序中进行类型之间的转换。它简化了类型转换操作，并允许自定义转换逻辑，适用于处理复杂的数据映射或转换需求。


#### 2.4.3 configureAdditionalProfiles

配置系统运行的额外的profile

```java
private void configureAdditionalProfiles(ConfigurableEnvironment environment) {
	if (!CollectionUtils.isEmpty(this.additionalProfiles)) {
		Set<String> profiles = new LinkedHashSet<>(Arrays.asList(environment.getActiveProfiles()));
		if (!profiles.containsAll(this.additionalProfiles)) {
			profiles.addAll(this.additionalProfiles);
			environment.setActiveProfiles(StringUtils.toStringArray(profiles));
		}
	}
}
```

### 2.5 configureIgnoreBeanInfo

给`spring.beaninfo.ignore`环境参数设置成默认`true`

```java
private void configureIgnoreBeanInfo(ConfigurableEnvironment environment) {
	if (System.getProperty(CachedIntrospectionResults.IGNORE_BEANINFO_PROPERTY_NAME) == null) {
		Boolean ignore = environment.getProperty("spring.beaninfo.ignore", Boolean.class, Boolean.TRUE);
		System.setProperty(CachedIntrospectionResults.IGNORE_BEANINFO_PROPERTY_NAME, ignore.toString());
	}
}
```

### 2.6 printBanner

打印banner图

1. 创建SpringApplicationBannerPrinter打印banner图
```java
private Banner printBanner(ConfigurableEnvironment environment) {
	if (this.bannerMode == Banner.Mode.OFF) {
		return null;
	}
	ResourceLoader resourceLoader = (this.resourceLoader != null) ? this.resourceLoader
			: new DefaultResourceLoader(null);
	SpringApplicationBannerPrinter bannerPrinter = new SpringApplicationBannerPrinter(resourceLoader, this.banner);
	if (this.bannerMode == Mode.LOG) {
		return bannerPrinter.print(environment, this.mainApplicationClass, logger);
	}
	return bannerPrinter.print(environment, this.mainApplicationClass, System.out);
}
```

2. 获取Banner类，并打印banner图，我们目前关注于`getTextBanner(environment)`
```java
// SpringApplicationBannerPrinter 方法
Banner print(Environment environment, Class<?> sourceClass, PrintStream out) {
	Banner banner = getBanner(environment);
	banner.printBanner(environment, sourceClass, out);
	return new PrintedBanner(banner, sourceClass);
}


private Banner getBanner(Environment environment) {
	Banners banners = new Banners();
	// 获取image/text的Banner，如果都没有则一般使用DEFAULT_BANNER（SpringBootBanner）打印，即我们启动时看到的springboot图
	banners.addIfNotNull(getImageBanner(environment));
	banners.addIfNotNull(getTextBanner(environment));
	if (banners.hasAtLeastOneBanner()) {
		return banners;
	}
	if (this.fallbackBanner != null) {
		return this.fallbackBanner;
	}
	return DEFAULT_BANNER;
}
// BANNER_LOCATION_PROPERTY = "spring.banner.location";
// DEFAULT_BANNER_LOCATION = "banner.txt";
private Banner getTextBanner(Environment environment) {
	// 从运行环境中获取spring.banner.location，没有的话默认banner.txt
	String location = environment.getProperty(BANNER_LOCATION_PROPERTY, DEFAULT_BANNER_LOCATION);
	// 默认加载资源banner.txt
	Resource resource = this.resourceLoader.getResource(location);
	try {
		// 存在的时候，返回ResourceBanner
		if (resource.exists() && !resource.getURL().toExternalForm().contains("liquibase-core")) {
			return new ResourceBanner(resource);
		}
	}
	catch (IOException ex) {
		// Ignore
	}
	return null;
}
```

### 2.7 createApplicationContext

我们使用的`ApplicationContext`是`AnnotationConfigServletWebServerApplicationContext`，在创建实例时会将一些重要组件类的`BeanDefinition`加入到`BeanFactory`中。`ApplicationContextFactory.DEFAULT`的实现如下：

```java
// createApplicationContext(),根据不同环境生成对应的ApplicationContext
ApplicationContextFactory DEFAULT = (webApplicationType) -> {
	try {
		switch (webApplicationType) {
		case SERVLET:
			// 我们正常使用
			return new AnnotationConfigServletWebServerApplicationContext();
		case REACTIVE:
			return new AnnotationConfigReactiveWebServerApplicationContext();
		default:
			return new AnnotationConfigApplicationContext();
		}
	}
	catch (Exception ex) {
		throw new IllegalStateException("Unable create a default ApplicationContext instance, "
				+ "you may need a custom ApplicationContextFactory", ex);
	}
};

// 此时会创建注解加载器，类路径加载器
public AnnotationConfigServletWebServerApplicationContext() {
	this.reader = new AnnotatedBeanDefinitionReader(this);
	this.scanner = new ClassPathBeanDefinitionScanner(this);
}

```

#### 2.7.1 AnnotatedBeanDefinitionReader 

创建注解`BeanDefinition`加载器`AnnotatedBeanDefinitionReader`，并加入注解加载流程重要组件类的`RootBeanDefinition`：
1. **`ConfigurationClassPostProcessor`**：是一个`BeanDefinitionRegistryPostProcessor`，用于加载标注@Configuration的配置类
2. **`AutowiredAnnotationBeanPostProcessor`**：是一个`BeanPostProcessor`，主要用于处理 @Autowired、@Value 和 @Inject 注解，自动完成依赖注入
3. **`CommonAnnotationBeanPostProcessor`**：是一个`BeanPostProcessor`，主要用于处理`JDK`标准的依赖注入注解，包括：`@PostConstruct` `@PreDestroy` `@Resource` `@WebServiceRef` `@EJB`
4. **`PersistenceAnnotationBeanPostProcessor`**：是一个`BeanPostProcessor`，主要用于处理`JPA`和`JEE`相关的持久化注解，包括：`@PersistenceContext` `@PersistenceUnit`
5. **`EventListenerMethodProcessor`**：是一个`BeanFactoryPostProcessor`，主要用于处理`@EventListener`注解的方法，并将它们注册为`Spring`事件监听器。`EventListenerMethodProcessor`负责解析这些方法，并将它们注册到`Spring`的`ApplicationEventMulticaster`进行事件分发
6. **`DefaultEventListenerFactory`**：**解析 `@EventListener` 方法**，将其转换为 `ApplicationListener`，**创建 `ApplicationListenerMethodAdapter`**，以适配 `@EventListener`


```java
public AnnotatedBeanDefinitionReader(BeanDefinitionRegistry registry) {
	this(registry, getOrCreateEnvironment(registry));
}

public AnnotatedBeanDefinitionReader(BeanDefinitionRegistry registry, Environment environment) {
	Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
	Assert.notNull(environment, "Environment must not be null");
	this.registry = registry;
	this.conditionEvaluator = new ConditionEvaluator(registry, environment, null);
	AnnotationConfigUtils.registerAnnotationConfigProcessors(this.registry);
}

public static void registerAnnotationConfigProcessors(BeanDefinitionRegistry registry) {
	registerAnnotationConfigProcessors(registry, null);
}

public static Set<BeanDefinitionHolder> registerAnnotationConfigProcessors(
		BeanDefinitionRegistry registry, @Nullable Object source) {
	// 获取BeanFactory
	DefaultListableBeanFactory beanFactory = unwrapDefaultListableBeanFactory(registry);
	if (beanFactory != null) {
		// 设置BeanFactory的DependencyComparator
		if (!(beanFactory.getDependencyComparator() instanceof AnnotationAwareOrderComparator)) {
			beanFactory.setDependencyComparator(AnnotationAwareOrderComparator.INSTANCE);
		}
		// 设置BeanFactory的AutowireCandidateResolver
		if (!(beanFactory.getAutowireCandidateResolver() instanceof ContextAnnotationAutowireCandidateResolver)) {
			beanFactory.setAutowireCandidateResolver(new ContextAnnotationAutowireCandidateResolver());
		}
	}

	Set<BeanDefinitionHolder> beanDefs = new LinkedHashSet<>(8);
	// 加入ConfigurationClassPostProcessor的RootBeanDefinition
	if (!registry.containsBeanDefinition(CONFIGURATION_ANNOTATION_PROCESSOR_BEAN_NAME)) {
		RootBeanDefinition def = new RootBeanDefinition(ConfigurationClassPostProcessor.class);
		def.setSource(source);
		beanDefs.add(registerPostProcessor(registry, def, CONFIGURATION_ANNOTATION_PROCESSOR_BEAN_NAME));
	}

	// 加入AutowiredAnnotationBeanPostProcessor的RootBeanDefinition
	if (!registry.containsBeanDefinition(AUTOWIRED_ANNOTATION_PROCESSOR_BEAN_NAME)) {
		RootBeanDefinition def = new RootBeanDefinition(AutowiredAnnotationBeanPostProcessor.class);
		def.setSource(source);
		beanDefs.add(registerPostProcessor(registry, def, AUTOWIRED_ANNOTATION_PROCESSOR_BEAN_NAME));
	}

	// 加入CommonAnnotationBeanPostProcessor的RootBeanDefinition
	// Check for JSR-250 support, and if present add the CommonAnnotationBeanPostProcessor.
	if (jsr250Present && !registry.containsBeanDefinition(COMMON_ANNOTATION_PROCESSOR_BEAN_NAME)) {
		RootBeanDefinition def = new RootBeanDefinition(CommonAnnotationBeanPostProcessor.class);
		def.setSource(source);
		beanDefs.add(registerPostProcessor(registry, def, COMMON_ANNOTATION_PROCESSOR_BEAN_NAME));
	}

	// 加入PersistenceAnnotationBeanPostProcessor的RootBeanDefinition
	// Check for JPA support, and if present add the PersistenceAnnotationBeanPostProcessor.
	if (jpaPresent && !registry.containsBeanDefinition(PERSISTENCE_ANNOTATION_PROCESSOR_BEAN_NAME)) {
		RootBeanDefinition def = new RootBeanDefinition();
		try {
			def.setBeanClass(ClassUtils.forName(PERSISTENCE_ANNOTATION_PROCESSOR_CLASS_NAME,
					AnnotationConfigUtils.class.getClassLoader()));
		}
		catch (ClassNotFoundException ex) {
			throw new IllegalStateException(
					"Cannot load optional framework class: " + PERSISTENCE_ANNOTATION_PROCESSOR_CLASS_NAME, ex);
		}
		def.setSource(source);
		beanDefs.add(registerPostProcessor(registry, def, PERSISTENCE_ANNOTATION_PROCESSOR_BEAN_NAME));
	}

	// 加入EventListenerMethodProcessor的RootBeanDefinition
	if (!registry.containsBeanDefinition(EVENT_LISTENER_PROCESSOR_BEAN_NAME)) {
		RootBeanDefinition def = new RootBeanDefinition(EventListenerMethodProcessor.class);
		def.setSource(source);
		beanDefs.add(registerPostProcessor(registry, def, EVENT_LISTENER_PROCESSOR_BEAN_NAME));
	}

	// 加入DefaultEventListenerFactory的RootBeanDefinition
	if (!registry.containsBeanDefinition(EVENT_LISTENER_FACTORY_BEAN_NAME)) {
		RootBeanDefinition def = new RootBeanDefinition(DefaultEventListenerFactory.class);
		def.setSource(source);
		beanDefs.add(registerPostProcessor(registry, def, EVENT_LISTENER_FACTORY_BEAN_NAME));
	}

	return beanDefs;
}
```

#### 2.7.2 ClassPathBeanDefinitionScanner

类路径BeanDefinition加载器

```java
public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry) {
	this(registry, true);
}
public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry, boolean useDefaultFilters) {
	this(registry, useDefaultFilters, getOrCreateEnvironment(registry));
}
public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry, boolean useDefaultFilters,
		Environment environment) {

	this(registry, useDefaultFilters, environment,
			(registry instanceof ResourceLoader ? (ResourceLoader) registry : null));
}
public ClassPathBeanDefinitionScanner(BeanDefinitionRegistry registry, boolean useDefaultFilters,
		Environment environment, @Nullable ResourceLoader resourceLoader) {

	Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
	this.registry = registry;

	if (useDefaultFilters) {
		registerDefaultFilters();
	}
	setEnvironment(environment);
	setResourceLoader(resourceLoader);
}
```

### 2.8 prepareContext

1. 配置ApplicationContext的环境
2. 后置处理`ApplicationContext`：向`ApplicationContext`中的`BeanFactory`注册`BeanNameGenerator`，`ApplicationConversionService`，并设置`ApplicationContext`的`ResourceLoader`，`ClassLoader`
3. 使用`ApplicationContextInitializer`初始化`ApplicationContext`
4. 监听器`listeners`监听流程`contextPrepared`
5. `bootstrapContext`发布`BootstrapContextClosedEvent`事件
6. 获取`ApplicationContext`中的`BeanFactory`(`DefaultListableBeanFactory`，其在顶级父类`GenericApplicationContext`的构造方法中创建)，注册`ApplicationArguments`，`Banner`；设置是否允许`BeanDefinition`覆盖，判断是否允许`lazyInitialization`，是的话，向`ApplicationContext`中加入`LazyInitializationBeanFactoryPostProcessor`
7. 获取所有`source`
8. 加载所有`source`
9. 监听器`listeners`监听流程`contextLoaded`

```java
// 准备ConfigurationApplicationContext 
private void prepareContext(DefaultBootstrapContext bootstrapContext, ConfigurableApplicationContext context,
		ConfigurableEnvironment environment, SpringApplicationRunListeners listeners,
		ApplicationArguments applicationArguments, Banner printedBanner) {
	// ApplicationContext配置环境
	context.setEnvironment(environment);
	// 配置部分参数
	postProcessApplicationContext(context);
	// 执行初始化器
	applyInitializers(context);
	// 监听器执行 context-prepared
	listeners.contextPrepared(context);
	// 发布BootstrapContextClosedEvent事件
	bootstrapContext.close(context);
	// 打印启动日志
	if (this.logStartupInfo) {
		logStartupInfo(context.getParent() == null);
		logStartupProfileInfo(context);
	}
	// Add boot specific singleton beans
	// 获取BeanFactory，默认是DefaultListableBeanFactory，其在顶级父类GenericApplicationContext的构造方法中创建
	ConfigurableListableBeanFactory beanFactory = context.getBeanFactory();
	beanFactory.registerSingleton("springApplicationArguments", applicationArguments);
	if (printedBanner != null) {
		beanFactory.registerSingleton("springBootBanner", printedBanner);
	}
	if (beanFactory instanceof DefaultListableBeanFactory) {
		((DefaultListableBeanFactory) beanFactory)
				.setAllowBeanDefinitionOverriding(this.allowBeanDefinitionOverriding);
	}
	if (this.lazyInitialization) {
		context.addBeanFactoryPostProcessor(new LazyInitializationBeanFactoryPostProcessor());
	}
	// Load the sources
	Set<Object> sources = getAllSources();
	Assert.notEmpty(sources, "Sources must not be empty");
	// 加载 BeanDefinition，在SpringBoot中，此时仅仅只是加载了启动类，所以这是我们需要关注到SpringBoot的一个注解@SpringBootApplication
	// @SpringBootApplication上还有注解@SpringBootConfiguration，@EnableAutoConfiguration，@ComponentScan
	// @ComponentScan注解会默认加载该类路径（包含子路径）上的所有bean
	load(context, sources.toArray(new Object[0]));
	// 监听 context-loaded
	listeners.contextLoaded(context);
}

```
#### 2.8.1 postProcessApplicationContext

后置处理`ApplicationContext`：向`ApplicationContext`中的`BeanFactory`注册`BeanNameGenerator`，`ApplicationConversionService`，并设置`ApplicationContext`的`ResourceLoader`，`ClassLoader`

```java
protected void postProcessApplicationContext(ConfigurableApplicationContext context) {
	if (this.beanNameGenerator != null) {
		context.getBeanFactory().registerSingleton(AnnotationConfigUtils.CONFIGURATION_BEAN_NAME_GENERATOR,
				this.beanNameGenerator);
	}
	if (this.resourceLoader != null) {
		if (context instanceof GenericApplicationContext) {
			((GenericApplicationContext) context).setResourceLoader(this.resourceLoader);
		}
		if (context instanceof DefaultResourceLoader) {
			((DefaultResourceLoader) context).setClassLoader(this.resourceLoader.getClassLoader());
		}
	}
	if (this.addConversionService) {
		context.getBeanFactory().setConversionService(ApplicationConversionService.getSharedInstance());
	}
}
```

#### 2.8.2 applyInitializers

使用`ApplicationContextInitializer`初始化`ApplicationContext`

```java
protected void applyInitializers(ConfigurableApplicationContext context) {
	for (ApplicationContextInitializer initializer : getInitializers()) {
		Class<?> requiredType = GenericTypeResolver.resolveTypeArgument(initializer.getClass(),
				ApplicationContextInitializer.class);
		Assert.isInstanceOf(requiredType, context, "Unable to call initializer.");
		initializer.initialize(context);
	}
}
```

#### 2.8.3 load

加载 `BeanDefinition`，在`SpringBoot`中，此时仅仅只是加载了启动类，所以这是我们需要关注到`SpringBoot`的一个注解`@SpringBootApplication`
`@SpringBootApplication`上还有注解`@SpringBootConfiguration`，`@EnableAutoConfiguration`，`@ComponentScan`
`@ComponentScan`注解会默认加载该类路径（包含子路径）上的所有bean

1. 创建`BeanDefinitionLoader` 用于加载类定义
2. `BeanDefinitionLoader`设置`BeanNameGenerator`
3. `BeanDefinitionLoader`设置`ResourceLoader`
4. `BeanDefinitionLoader`设置`Environment`
5. `BeanDefinitionLoader`加载类定义


```java
protected void load(ApplicationContext context, Object[] sources) {
	if (logger.isDebugEnabled()) {
		logger.debug("Loading source " + StringUtils.arrayToCommaDelimitedString(sources));
	}
	// 创建BeanDefinitionLoader 加载类定义
	BeanDefinitionLoader loader = createBeanDefinitionLoader(getBeanDefinitionRegistry(context), sources);
	if (this.beanNameGenerator != null) {
		loader.setBeanNameGenerator(this.beanNameGenerator);
	}
	if (this.resourceLoader != null) {
		loader.setResourceLoader(this.resourceLoader);
	}
	if (this.environment != null) {
		loader.setEnvironment(this.environment);
	}
	loader.load();
}
```

### 2.9 refreshContext

调用`ApplicationContext`的`refresh`方法

```java
private void refreshContext(ConfigurableApplicationContext context) {
	if (this.registerShutdownHook) {
		try {
			context.registerShutdownHook();
		}
		catch (AccessControlException ex) {
			// Not allowed in some environments.
		}
	}
	refresh((ApplicationContext) context);
}
```

#### 2.9.1 refresh

`spring`容器启动过程，注解启动的重要组件`ConfigurationClassPostProcessor`，将在这里生成`bean`相关的`BeanDefinition`，并执行方法`postProcessBeanDefinitionRegistry`

```java
// AbstractApplicationContext的模板方法refresh
public void refresh() throws BeansException, IllegalStateException {
	synchronized (this.startupShutdownMonitor) {
		StartupStep contextRefresh = this.applicationStartup.start("spring.context.refresh");

		// Prepare this context for refreshing.
		prepareRefresh();

		// Tell the subclass to refresh the internal bean factory.
		ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

		// Prepare the bean factory for use in this context.
		prepareBeanFactory(beanFactory);

		try {
			// Allows post-processing of the bean factory in context subclasses.
			postProcessBeanFactory(beanFactory);

			StartupStep beanPostProcess = this.applicationStartup.start("spring.context.beans.post-process");
			// Invoke factory processors registered as beans in the context.
			// 注解启动的重要组件ConfigurationClassPostProcessor，将在这里生成bean相关的BeanDefinition，并执行postProcessBeanDefinitionRegistry
			invokeBeanFactoryPostProcessors(beanFactory);

			// Register bean processors that intercept bean creation.
			registerBeanPostProcessors(beanFactory);
			beanPostProcess.end();

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
			contextRefresh.end();
		}
	}
}
```

### 2.10 callRunners

以`DefaultApplicationArguments`为参数，调用所有的`ApplicationRunner`，`CommandLineRunner`

```java
private void callRunners(ApplicationContext context, ApplicationArguments args) {
	List<Object> runners = new ArrayList<>();
	runners.addAll(context.getBeansOfType(ApplicationRunner.class).values());
	runners.addAll(context.getBeansOfType(CommandLineRunner.class).values());
	AnnotationAwareOrderComparator.sort(runners);
	for (Object runner : new LinkedHashSet<>(runners)) {
		if (runner instanceof ApplicationRunner) {
			callRunner((ApplicationRunner) runner, args);
		}
		if (runner instanceof CommandLineRunner) {
			callRunner((CommandLineRunner) runner, args);
		}
	}
}
```

## 三、实例化BEAN

对于实例化BEAN流程的`ApplicationContext`，我们主要分析`AnnotationConfigServletWebServerApplicationContext`

### 3.1 prepareRefresh

>Prepare this context for refreshing, setting its startup date and active flag as well as performing any initialization of property sources.
>为刷新准备此上下文，设置其启动日期和活动标志，并执行任何属性源的初始化。

```java
protected void prepareRefresh() {
	// Switch to active.
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
	// 在上下文环境中初始化任何占位符属性源。
	initPropertySources();

	// Validate that all properties marked as required are resolvable:
	// see ConfigurablePropertyResolver#setRequiredProperties
	// 验证所有标记为必需的属性是否可解析：请参阅ConfigurablePropertyResolver#setRequiredProperties
	getEnvironment().validateRequiredProperties();

	// Store pre-refresh ApplicationListeners...
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
	// 允许收集早期的ApplicationEvents，一旦事件广播器（multicaster）可用，就发布这些事件……
	this.earlyApplicationEvents = new LinkedHashSet<>();
}
```

### 3.2 obtainFreshBeanFactory

>Tell the subclass to refresh the internal bean factory.
>Returns: the fresh BeanFactory instance
>See Also: refreshBeanFactory(), getBeanFactory()
>指示子类刷新内部BeanFactory。 返回值：刷新后的BeanFactory实例。另请参阅：refreshBeanFactory(), getBeanFactory()

```java
// AbstractApplicationContext
protected ConfigurableListableBeanFactory obtainFreshBeanFactory() {
	refreshBeanFactory();
	return getBeanFactory();
}

// GenericApplicationContext
protected final void refreshBeanFactory() throws IllegalStateException {
	if (!this.refreshed.compareAndSet(false, true)) {
		throw new IllegalStateException(
				"GenericApplicationContext does not support multiple refresh attempts: just call 'refresh' once");
	}
	this.beanFactory.setSerializationId(getId());
}
// GenericApplicationContext
public final ConfigurableListableBeanFactory getBeanFactory() {
	return this.beanFactory;
}
```

### 3.3 prepareBeanFactory

>Configure the factory's standard context characteristics, such as the context's ClassLoader and post-processors.
>Params: beanFactory – the BeanFactory to configure
>配置工厂的标准上下文特性，如上下文的ClassLoader和后处理器。
>参数：beanFactory – 要配置的BeanFactory

重要的内容就是：
1. beanFactory.setBeanExpressionResolver(new StandardBeanExpressionResolver(beanFactory.getBeanClassLoader()));
2. beanFactory.addPropertyEditorRegistrar(new ResourceEditorRegistrar(this, getEnvironment()));
3. beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));
4. beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));

```java

protected void prepareBeanFactory(ConfigurableListableBeanFactory beanFactory) {
	// Tell the internal bean factory to use the context's class loader etc.
	// 设置类加载器
	beanFactory.setBeanClassLoader(getClassLoader());
	/**
	* 添加bean表达式解释器，为了能够让我们的beanFactory去解析bean表达式
	* 模板默认以前缀“#{”开头，以后缀“}”结尾
	* 可以修改默认额前缀后缀
	* 通过beanFactory.getBeanExpressionResolver()获得BeanExpressionResolver
	* 然后resolver.setExpressionPrefix("%{");resolver.setExpressionSuffix("}");
	*
	* 那么什么时候用到这个解析器？
	* 就是在Bean进行初始化后会有属性填充的一步,方法如下:
	* protected void populateBean(String beanName, RootBeanDefinition mbd, BeanWrapper bw) {
	* 	//属性填充
	* 	applyPropertyValues(beanName, mbd, bw, pvs);
	* }
	* 最终会通过AbstractBeanFactory中的evaluateBeanDefinitionString方法进行解析
	* 然后这时候就进到StandardBeanExpressionResolver中的evaluate方法中进行解析了
	*/
	beanFactory.setBeanExpressionResolver(new StandardBeanExpressionResolver(beanFactory.getBeanClassLoader()));
	/**
	 * 添加PropertyEditor属性编辑器（可以将我们的property动态设置为bean里面对应的属性类型）
	 * 比如：property赋值的是路径名(classpath/spring.xml)，而对应bean属性设置的是Resource，则有spring的ResourceEditor完成转换
	 * springframework-bean下的propertyEditors包下有很多spring自带的属性编辑器
	 * 其中刚才提到的ResourceEditor在springframework-core下的io包里面
	 *
	 * 可以自定义属性编辑器，通过实现PropertyEditorSupport接口，spring中自带的属性编辑器也是这么做的
	 * 使用ApplicationContext,只需要在配置文件中通过CustomEditorConfigurer注册即可。
	 * CustomEditorConfigurer实现了BeanFactoryPostProcessor接口，因而是一个Bean工厂后置处理器
	 * 在Spring容器中加载配置文件并生成BeanDefinition后会被执行。CustomEditorConfigurer在容器启动时有机会注册自定义的属性编辑器
	 */
	beanFactory.addPropertyEditorRegistrar(new ResourceEditorRegistrar(this, getEnvironment()));

	// Configure the bean factory with context callbacks.
	// ApplicationContextAwareProcessor 是一个BeanPostProcessor，用于配置各类Aware接口（EnvironmentAware/EmbeddedValueResolverAware/ResourceLoaderAware/ApplicationEventPublisherAware/MessageSourceAware/ApplicationContextAware）
	beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));
	// 此时暂时先忽略依赖这些Aware接口，等到执行BeanPostProccessor时，ApplicationContextAwareProcessor再将这些依赖注入进去
	beanFactory.ignoreDependencyInterface(EnvironmentAware.class);
	beanFactory.ignoreDependencyInterface(EmbeddedValueResolverAware.class);
	beanFactory.ignoreDependencyInterface(ResourceLoaderAware.class);
	beanFactory.ignoreDependencyInterface(ApplicationEventPublisherAware.class);
	beanFactory.ignoreDependencyInterface(MessageSourceAware.class);
	beanFactory.ignoreDependencyInterface(ApplicationContextAware.class);

	// BeanFactory interface not registered as resolvable type in a plain factory.
	// MessageSource registered (and found for autowiring) as a bean.
	// 在普通工厂中，BeanFactory接口没有被注册为可解析的类型。
	// MessageSource被注册为bean（并且可以被自动装配时发现）。
	beanFactory.registerResolvableDependency(BeanFactory.class, beanFactory);
	beanFactory.registerResolvableDependency(ResourceLoader.class, this);
	beanFactory.registerResolvableDependency(ApplicationEventPublisher.class, this);
	beanFactory.registerResolvableDependency(ApplicationContext.class, this);

	// Register early post-processor for detecting inner beans as ApplicationListeners.
	// 注册早期后处理器以检测作为ApplicationListeners的内部bean。即将系统中的ApplicationListener子类添加到applicationContext中
	beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));

	// Detect a LoadTimeWeaver and prepare for weaving, if found.
	// LoadTimeWeaver暂不分析
	if (beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
		beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
		// Set a temporary ClassLoader for type matching.
		beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
	}

	// Register default environment beans.
	// 注册 环境bean systemProperties systemEnvironment
	if (!beanFactory.containsLocalBean(ENVIRONMENT_BEAN_NAME)) {
		beanFactory.registerSingleton(ENVIRONMENT_BEAN_NAME, getEnvironment());
	}
	if (!beanFactory.containsLocalBean(SYSTEM_PROPERTIES_BEAN_NAME)) {
		beanFactory.registerSingleton(SYSTEM_PROPERTIES_BEAN_NAME, getEnvironment().getSystemProperties());
	}
	if (!beanFactory.containsLocalBean(SYSTEM_ENVIRONMENT_BEAN_NAME)) {
		beanFactory.registerSingleton(SYSTEM_ENVIRONMENT_BEAN_NAME, getEnvironment().getSystemEnvironment());
	}
}
```

### 3.4 postProcessBeanFactory

>Modify the application context's internal bean factory after its standard initialization. All bean definitions will have been loaded, but no beans will have been instantiated yet. This allows for registering special BeanPostProcessors etc in certain ApplicationContext implementations.
>Params: beanFactory – the bean factory used by the application context
>在应用上下文完成标准初始化之后，修改其内部的BeanFactory。此时，所有的bean定义都已经被加载，但还没有任何bean被实例化。这允许在某些ApplicationContext实现中注册特殊的BeanPostProcessors等。
>参数：beanFactory – 应用上下文所使用的BeanFactory

重要的步骤：
1. 添加`WebApplicationContextServletContextAwareProcessor`，来处理`ServletContextAware`
2. 注册与`Web`应用相关的特定作用域
3. 判断是否扫描类路径
4. 判断是否加载注解类

```java
// AnnotationConfigServletWebServerApplicationContext
protected void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
	super.postProcessBeanFactory(beanFactory);
	// 判断是否要扫描类路径
	if (this.basePackages != null && this.basePackages.length > 0) {
		this.scanner.scan(this.basePackages);
	}
	// 判断是否要加载注解类
	if (!this.annotatedClasses.isEmpty()) {
		this.reader.register(ClassUtils.toClassArray(this.annotatedClasses));
	}
}

// ServletWebServerApplicationContext
protected void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
	// 添加BeanPostProcessor处理ServletContextAware接口注入问题
	beanFactory.addBeanPostProcessor(new WebApplicationContextServletContextAwareProcessor(this));
	beanFactory.ignoreDependencyInterface(ServletContextAware.class);
	// registerWebApplicationScopes 方法在 Spring 框架中主要用于注册与 Web 应用相关的特定作用域（scopes）。这些作用域通常与 HTTP 请求、会话（session）以及整个 Web 应用上下文（application context）相关。通过注册这些作用域，Spring 容器能够管理在这些不同作用域下生命周期的 bean。
	registerWebApplicationScopes();
}
```
### 3.5 invokeBeanFactoryPostProcessors

>Instantiate and invoke all registered BeanFactoryPostProcessor beans, respecting explicit order if given.
>Must be called before singleton instantiation.
>按照给定的明确顺序（如果有的话），实例化并调用所有已注册的BeanFactoryPostProcessor bean。
>必须在单例bean实例化之前调用。

重要步骤：
1. 找出`beanFactory`中所有的`BeanDefinitionRegistryPostProcessor`，并将其实例化后执行方法`postProcessBeanDefinitionRegistry`，由于`BeanDefinitionRegistryPostProcessor`继承了`BeanFactoryPostProcessor`，所以也会执行方法`postProcessBeanFactory`，处理顺序PriorityOrdered-Ordered-普通
2. 找出`beanFactory`中所有的`BeanFactoryPostProcessor`，并将其实例化后执行方法`postProcessBeanFactory`，处理顺序PriorityOrdered-Ordered-普通

**注解启动的重要组件`ConfigurationClassPostProcessor`，将在这里生成`bean`相关的`BeanDefinition`，并执行`postProcessBeanDefinitionRegistry`**

```java
protected void invokeBeanFactoryPostProcessors(ConfigurableListableBeanFactory beanFactory) {
	PostProcessorRegistrationDelegate.invokeBeanFactoryPostProcessors(beanFactory, getBeanFactoryPostProcessors());

	// Detect a LoadTimeWeaver and prepare for weaving, if found in the meantime
	// (e.g. through an @Bean method registered by ConfigurationClassPostProcessor)
	if (beanFactory.getTempClassLoader() == null && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
		beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
		beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
	}
}

// PostProcessorRegistrationDelegate
public static void invokeBeanFactoryPostProcessors(
		ConfigurableListableBeanFactory beanFactory, List<BeanFactoryPostProcessor> beanFactoryPostProcessors) {

	// Invoke BeanDefinitionRegistryPostProcessors first, if any.
	Set<String> processedBeans = new HashSet<>();

	// 判断当前beanFactory是否是BeanDefinitionRegistry，如果是，则处理BeanDefinitionRegistryPostProcessor
	if (beanFactory instanceof BeanDefinitionRegistry) {
		BeanDefinitionRegistry registry = (BeanDefinitionRegistry) beanFactory;
		List<BeanFactoryPostProcessor> regularPostProcessors = new ArrayList<>();
		List<BeanDefinitionRegistryPostProcessor> registryProcessors = new ArrayList<>();

		// 1. 首先处理beanFactoryPostProcessors中的BeanDefinitionRegistryPostProcessor
		for (BeanFactoryPostProcessor postProcessor : beanFactoryPostProcessors) {
			if (postProcessor instanceof BeanDefinitionRegistryPostProcessor) {
				BeanDefinitionRegistryPostProcessor registryProcessor =
						(BeanDefinitionRegistryPostProcessor) postProcessor;
				// 此处执行 BeanDefinitionRegistryPostProcessor
				registryProcessor.postProcessBeanDefinitionRegistry(registry);
				registryProcessors.add(registryProcessor);
			}
			else {
				regularPostProcessors.add(postProcessor);
			}
		}

		// Do not initialize FactoryBeans here: We need to leave all regular beans
		// uninitialized to let the bean factory post-processors apply to them!
		// Separate between BeanDefinitionRegistryPostProcessors that implement
		// PriorityOrdered, Ordered, and the rest.
		List<BeanDefinitionRegistryPostProcessor> currentRegistryProcessors = new ArrayList<>();

		// First, invoke the BeanDefinitionRegistryPostProcessors that implement PriorityOrdered.
		// 2. 再处理beanFactory中未实例化的BeanDefinitionRegistryPostProcessor，将其实例化后，然后执行postProcessBeanDefinitionRegistry，处理顺序PriorityOrdered-Ordered-普通
		String[] postProcessorNames =
				beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
		for (String ppName : postProcessorNames) {
			if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
				currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
				processedBeans.add(ppName);
			}
		}
		sortPostProcessors(currentRegistryProcessors, beanFactory);
		registryProcessors.addAll(currentRegistryProcessors);
		invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
		currentRegistryProcessors.clear();

		// Next, invoke the BeanDefinitionRegistryPostProcessors that implement Ordered.
		postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
		for (String ppName : postProcessorNames) {
			if (!processedBeans.contains(ppName) && beanFactory.isTypeMatch(ppName, Ordered.class)) {
				currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
				processedBeans.add(ppName);
			}
		}
		sortPostProcessors(currentRegistryProcessors, beanFactory);
		registryProcessors.addAll(currentRegistryProcessors);
		invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
		currentRegistryProcessors.clear();

		// Finally, invoke all other BeanDefinitionRegistryPostProcessors until no further ones appear.
		// 3. 由于BeanDefinitionRegistryPostProcessor可以拓展添加BeanDefinition，所以这些自定义的BeanDefinition也可能有BeanDefinitionRegistryPostProcessor，所以这里循环找出所有的BeanDefinitionRegistryPostProcessor，然后实例化，并执行postProcessBeanDefinitionRegistry
		boolean reiterate = true;
		while (reiterate) {
			reiterate = false;
			postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
			for (String ppName : postProcessorNames) {
				if (!processedBeans.contains(ppName)) {
					currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
					processedBeans.add(ppName);
					reiterate = true;
				}
			}
			sortPostProcessors(currentRegistryProcessors, beanFactory);
			registryProcessors.addAll(currentRegistryProcessors);
			invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
			currentRegistryProcessors.clear();
		}
		
		// Now, invoke the postProcessBeanFactory callback of all processors handled so far.
		// 由于BeanDefinitionRegistryPostProcessor继承了接口BeanFactoryPostProcessor，所以这里也统一执行下BeanFactoryPostProcessor
		invokeBeanFactoryPostProcessors(registryProcessors, beanFactory);
		// 以及之前的普通BeanFactoryPostProcessor
		invokeBeanFactoryPostProcessors(regularPostProcessors, beanFactory);
	}

	else {
		// Invoke factory processors registered with the context instance.
		// 如果不是BeanDefinitionRegistry，则直接执行BeanFactoryPostProcessor
		invokeBeanFactoryPostProcessors(beanFactoryPostProcessors, beanFactory);
	}

	// Do not initialize FactoryBeans here: We need to leave all regular beans
	// uninitialized to let the bean factory post-processors apply to them!
	// 不要在这里初始化FactoryBean：我们需要将所有常规的bean保持未初始化状态，以便bean工厂后处理器可以对它们进行处理！

	// 这里就是处理beanFactory中的BeanFactoryPostProcessor，处理顺序也按照PriorityOrdered-Ordered-普通
	String[] postProcessorNames =
			beanFactory.getBeanNamesForType(BeanFactoryPostProcessor.class, true, false);

	// Separate between BeanFactoryPostProcessors that implement PriorityOrdered,
	// Ordered, and the rest.
	List<BeanFactoryPostProcessor> priorityOrderedPostProcessors = new ArrayList<>();
	List<String> orderedPostProcessorNames = new ArrayList<>();
	List<String> nonOrderedPostProcessorNames = new ArrayList<>();
	for (String ppName : postProcessorNames) {
		if (processedBeans.contains(ppName)) {
			// skip - already processed in first phase above
		}
		else if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
			priorityOrderedPostProcessors.add(beanFactory.getBean(ppName, BeanFactoryPostProcessor.class));
		}
		else if (beanFactory.isTypeMatch(ppName, Ordered.class)) {
			orderedPostProcessorNames.add(ppName);
		}
		else {
			nonOrderedPostProcessorNames.add(ppName);
		}
	}

	// First, invoke the BeanFactoryPostProcessors that implement PriorityOrdered.
	sortPostProcessors(priorityOrderedPostProcessors, beanFactory);
	invokeBeanFactoryPostProcessors(priorityOrderedPostProcessors, beanFactory);

	// Next, invoke the BeanFactoryPostProcessors that implement Ordered.
	List<BeanFactoryPostProcessor> orderedPostProcessors = new ArrayList<>(orderedPostProcessorNames.size());
	for (String postProcessorName : orderedPostProcessorNames) {
		orderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
	}
	sortPostProcessors(orderedPostProcessors, beanFactory);
	invokeBeanFactoryPostProcessors(orderedPostProcessors, beanFactory);

	// Finally, invoke all other BeanFactoryPostProcessors.
	List<BeanFactoryPostProcessor> nonOrderedPostProcessors = new ArrayList<>(nonOrderedPostProcessorNames.size());
	for (String postProcessorName : nonOrderedPostProcessorNames) {
		nonOrderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
	}
	invokeBeanFactoryPostProcessors(nonOrderedPostProcessors, beanFactory);

	// Clear cached merged bean definitions since the post-processors might have
	// modified the original metadata, e.g. replacing placeholders in values...
	beanFactory.clearMetadataCache();
}~
```

### 3.6 registerBeanPostProcessors

>Instantiate and register all BeanPostProcessor beans, respecting explicit order if given.
>Must be called before any instantiation of application beans.
>实例化并注册所有`BeanPostProcessor` `bean`，如果给定明确顺序，则按照该顺序进行。
>必须在任何应用`bean`实例化之前调用。

重要步骤：
1. 从`beanFactory`中找出所有的`BeanPostProcessor`，并按顺序(`PriorityOrdered`-`Ordered`-普通)实例化，然后放到`beanFactory`的`beanPostProcessors`中，方便后续实例化`bean`的时候执行。

```java
public static void registerBeanPostProcessors(
		ConfigurableListableBeanFactory beanFactory, AbstractApplicationContext applicationContext) {
	// 1. 从beanFactory中找出所有的BeanPostProcessor，并实例化，然后放到beanFactory的beanPostProcessors中，方便后续实例化bean的时候执行
	String[] postProcessorNames = beanFactory.getBeanNamesForType(BeanPostProcessor.class, true, false);

	// Register BeanPostProcessorChecker that logs an info message when
	// a bean is created during BeanPostProcessor instantiation, i.e. when
	// a bean is not eligible for getting processed by all BeanPostProcessors.
	int beanProcessorTargetCount = beanFactory.getBeanPostProcessorCount() + 1 + postProcessorNames.length;
	beanFactory.addBeanPostProcessor(new BeanPostProcessorChecker(beanFactory, beanProcessorTargetCount));

	// Separate between BeanPostProcessors that implement PriorityOrdered,
	// Ordered, and the rest.
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

	// First, register the BeanPostProcessors that implement PriorityOrdered.
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
	beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(applicationContext));
}
```

### 3.7 initMessageSource

>initMessageSource() 方法用于初始化消息源（MessageSource）。消息源是 Spring 框架中用于处理国际化（i18n）消息的接口，它提供了一种机制，允许开发者将应用程序中的文本消息外部化，从而使得应用程序能够轻松地支持多种语言和地区的消息显示

>Initialize the MessageSource. Use parent's if none defined in this context.
>初始化MessageSource。如果当前上下文中没有定义，则使用父级的MessageSource。
```java
protected void initMessageSource() {
	ConfigurableListableBeanFactory beanFactory = getBeanFactory();
	if (beanFactory.containsLocalBean(MESSAGE_SOURCE_BEAN_NAME)) {
		this.messageSource = beanFactory.getBean(MESSAGE_SOURCE_BEAN_NAME, MessageSource.class);
		// Make MessageSource aware of parent MessageSource.
		if (this.parent != null && this.messageSource instanceof HierarchicalMessageSource) {
			HierarchicalMessageSource hms = (HierarchicalMessageSource) this.messageSource;
			if (hms.getParentMessageSource() == null) {
				// Only set parent context as parent MessageSource if no parent MessageSource
				// registered already.
				hms.setParentMessageSource(getInternalParentMessageSource());
			}
		}
		if (logger.isTraceEnabled()) {
			logger.trace("Using MessageSource [" + this.messageSource + "]");
		}
	}
	else {
		// Use empty MessageSource to be able to accept getMessage calls.
		DelegatingMessageSource dms = new DelegatingMessageSource();
		dms.setParentMessageSource(getInternalParentMessageSource());
		this.messageSource = dms;
		beanFactory.registerSingleton(MESSAGE_SOURCE_BEAN_NAME, this.messageSource);
		if (logger.isTraceEnabled()) {
			logger.trace("No '" + MESSAGE_SOURCE_BEAN_NAME + "' bean, using [" + this.messageSource + "]");
		}
	}
}
```

### 3.8 initApplicationEventMulticaster

>Initialize the ApplicationEventMulticaster. Uses SimpleApplicationEventMulticaster if none defined in the context.
>See Also: SimpleApplicationEventMulticaster
>初始化ApplicationEventMulticaster。如果上下文中没有定义，则使用SimpleApplicationEventMulticaster。
>另请参阅：SimpleApplicationEventMulticaster

>initApplicationEventMulticaster() 方法用于初始化应用事件多播器（ApplicationEventMulticaster）。应用事件多播器是 Spring 框架中用于管理和传播应用程序事件的机制，它负责将事件广播给注册了对应监听器的组件

重要步骤：
1. 查询`beanFactory`中是否存在`bean`：`applicationEventMulticaster`，没有的话，默认创建`SimpleApplicationEventMulticaster`，并注册到`beanFactory`的`singleton`中

```java
public static final String APPLICATION_EVENT_MULTICASTER_BEAN_NAME = "applicationEventMulticaster";
protected void initApplicationEventMulticaster() {
	ConfigurableListableBeanFactory beanFactory = getBeanFactory();
	if (beanFactory.containsLocalBean(APPLICATION_EVENT_MULTICASTER_BEAN_NAME)) {
		this.applicationEventMulticaster =
				beanFactory.getBean(APPLICATION_EVENT_MULTICASTER_BEAN_NAME, ApplicationEventMulticaster.class);
		if (logger.isTraceEnabled()) {
			logger.trace("Using ApplicationEventMulticaster [" + this.applicationEventMulticaster + "]");
		}
	}
	else {
		this.applicationEventMulticaster = new SimpleApplicationEventMulticaster(beanFactory);
		beanFactory.registerSingleton(APPLICATION_EVENT_MULTICASTER_BEAN_NAME, this.applicationEventMulticaster);
		if (logger.isTraceEnabled()) {
			logger.trace("No '" + APPLICATION_EVENT_MULTICASTER_BEAN_NAME + "' bean, using " +
					"[" + this.applicationEventMulticaster.getClass().getSimpleName() + "]");
		}
	}
}
```
### 3.9 onRefresh

>Template method which can be overridden to add context-specific refresh work. Called on initialization of special beans, before instantiation of singletons.
>This implementation is empty.
>Throws: BeansException – in case of errors
>See Also: refresh()

>这是一个模板方法，可以被重写以添加特定于上下文的刷新工作。它在特殊bean的初始化过程中被调用，位于单例bean实例化之前。
>此实现为空。
>抛出异常： BeansException - 如果发生错误
>另请参阅： refresh()方法

重要步骤：
1. 创建 WebServer，后续分析

```java
// ServletWebServerApplicationContext
protected void onRefresh() {
	super.onRefresh();
	try {
		createWebServer();
	}
	catch (Throwable ex) {
		throw new ApplicationContextException("Unable to start web server", ex);
	}
}
// GenericWebApplicationContext
protected void onRefresh() {
	this.themeSource = UiApplicationContextUtils.initThemeSource(this);
}

private void createWebServer() {
	WebServer webServer = this.webServer;
	ServletContext servletContext = getServletContext();
	if (webServer == null && servletContext == null) {
		ServletWebServerFactory factory = getWebServerFactory();
		this.webServer = factory.getWebServer(getSelfInitializer());
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
```

### 3.10 registerListeners

>Add beans that implement ApplicationListener as listeners. Doesn't affect other listeners, which can be added without being beans.
>添加实现了ApplicationListener接口的bean作为监听器。这不会影响其他监听器，这些监听器可以在不成为bean的情况下被添加。

重要步骤：
1. 从`ApplicationContext`中获取所有的`ApplicationListener`，并加入到`applicationEventMulticaster`中
2. 从`beanFactory`中获取所有的`ApplicationListener`，并实例化，然后加入`applicationEventMulticaster`中
3. 执行早期启动时的事件

```java
protected void registerListeners() {
	// Register statically specified listeners first.
	// 从ApplicationContext中获取所有的ApplicationListener，并加入到applicationEventMulticaster中
	for (ApplicationListener<?> listener : getApplicationListeners()) {
		getApplicationEventMulticaster().addApplicationListener(listener);
	}

	// Do not initialize FactoryBeans here: We need to leave all regular beans
	// uninitialized to let post-processors apply to them!
	// 从beanFactory中获取所有的ApplicationListener，并实例化，然后加入applicationEventMulticaster中
	String[] listenerBeanNames = getBeanNamesForType(ApplicationListener.class, true, false);
	for (String listenerBeanName : listenerBeanNames) {
		getApplicationEventMulticaster().addApplicationListenerBean(listenerBeanName);
	}

	// Publish early application events now that we finally have a multicaster...
	// 执行早期启动时的事件
	Set<ApplicationEvent> earlyEventsToProcess = this.earlyApplicationEvents;
	this.earlyApplicationEvents = null;
	if (!CollectionUtils.isEmpty(earlyEventsToProcess)) {
		for (ApplicationEvent earlyEvent : earlyEventsToProcess) {
			getApplicationEventMulticaster().multicastEvent(earlyEvent);
		}
	}
}
```

### 3.11 finishBeanFactoryInitialization

```java
protected void finishBeanFactoryInitialization(ConfigurableListableBeanFactory beanFactory) {
	// Initialize conversion service for this context.
	// 实例化 ConversionService，并设置到beanFactory中
	if (beanFactory.containsBean(CONVERSION_SERVICE_BEAN_NAME) &&
			beanFactory.isTypeMatch(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class)) {
		beanFactory.setConversionService(
				beanFactory.getBean(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class));
	}

	// Register a default embedded value resolver if no BeanFactoryPostProcessor
	// (such as a PropertySourcesPlaceholderConfigurer bean) registered any before:
	// at this point, primarily for resolution in annotation attribute values.
	// 如果beanFatory中不包含内嵌的value解析器，则创建个默认的
	if (!beanFactory.hasEmbeddedValueResolver()) {
		beanFactory.addEmbeddedValueResolver(strVal -> getEnvironment().resolvePlaceholders(strVal));
	}

	// Initialize LoadTimeWeaverAware beans early to allow for registering their transformers early.
	// 实例化LoadTimeWeaverAware相关类
	String[] weaverAwareNames = beanFactory.getBeanNamesForType(LoadTimeWeaverAware.class, false, false);
	for (String weaverAwareName : weaverAwareNames) {
		getBean(weaverAwareName);
	}

	// Stop using the temporary ClassLoader for type matching.
	// 停止使用临时类加载器
	beanFactory.setTempClassLoader(null);

	// Allow for caching all bean definition metadata, not expecting further changes.
	// 冻结配置，不再改变
	beanFactory.freezeConfiguration();

	// Instantiate all remaining (non-lazy-init) singletons.
	// 实例化 singleton
	beanFactory.preInstantiateSingletons();
}
```
最重要的实例化步骤preInstantiateSingletons：

```java
public void preInstantiateSingletons() throws BeansException {
	if (logger.isTraceEnabled()) {
		logger.trace("Pre-instantiating singletons in " + this);
	}

	// Iterate over a copy to allow for init methods which in turn register new bean definitions.
	// While this may not be part of the regular factory bootstrap, it does otherwise work fine.
	List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

	// Trigger initialization of all non-lazy singleton beans...
	for (String beanName : beanNames) {
		RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
		if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
			if (isFactoryBean(beanName)) {
				Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
				if (bean instanceof FactoryBean) {
					FactoryBean<?> factory = (FactoryBean<?>) bean;
					boolean isEagerInit;
					if (System.getSecurityManager() != null && factory instanceof SmartFactoryBean) {
						isEagerInit = AccessController.doPrivileged(
								(PrivilegedAction<Boolean>) ((SmartFactoryBean<?>) factory)::isEagerInit,
								getAccessControlContext());
					}
					else {
						isEagerInit = (factory instanceof SmartFactoryBean &&
								((SmartFactoryBean<?>) factory).isEagerInit());
					}
					if (isEagerInit) {
						getBean(beanName);
					}
				}
			}
			else {
				getBean(beanName);
			}
		}
	}

	// Trigger post-initialization callback for all applicable beans...
	for (String beanName : beanNames) {
		Object singletonInstance = getSingleton(beanName);
		if (singletonInstance instanceof SmartInitializingSingleton) {
			SmartInitializingSingleton smartSingleton = (SmartInitializingSingleton) singletonInstance;
			if (System.getSecurityManager() != null) {
				AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
					smartSingleton.afterSingletonsInstantiated();
					return null;
				}, getAccessControlContext());
			}
			else {
				smartSingleton.afterSingletonsInstantiated();
			}
		}
	}
}

```


### 3.12 finishRefresh


## 四、创建WebServer容器
创建的时机在 创建spring容器的onRefresh()步骤；
主要是web server factory 有三个：
TomcatServletWebServerFactory
UndertowServletWebServerFactory
JettyServletWebServerFactory

```java
protected void onRefresh() {
	super.onRefresh();
	try {
		// 此时创建web server
		createWebServer();
	}
	catch (Throwable ex) {
		throw new ApplicationContextException("Unable to start web server", ex);
	}
}
// 创建web server
private void createWebServer() {
	WebServer webServer = this.webServer;
	ServletContext servletContext = getServletContext();
	if (webServer == null && servletContext == null) {
		StartupStep createWebServer = this.getApplicationStartup().start("spring.boot.webserver.create");
		// 获取web容器工厂类
		// 此时我们需要注意到SpringBoot中的自动配置类 ServletWebServerFactoryAutoConfiguration 
		// 以及spring-boot-starter-web中默认使用tomcat的jar
		ServletWebServerFactory factory = getWebServerFactory();
		createWebServer.tag("factory", factory.getClass().toString());
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

// 获取创建 tomcat服务器
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
	prepareContext(tomcat.getHost(), initializers);
	return getTomcatWebServer(tomcat);
}

// 获取tomcat web server，并启动tomcat
protected TomcatWebServer getTomcatWebServer(Tomcat tomcat) {
	return new TomcatWebServer(tomcat, getPort() >= 0, getShutdown());
}

public TomcatWebServer(Tomcat tomcat, boolean autoStart, Shutdown shutdown) {
	Assert.notNull(tomcat, "Tomcat Server must not be null");
	this.tomcat = tomcat;
	this.autoStart = autoStart;
	this.gracefulShutdown = (shutdown == Shutdown.GRACEFUL) ? new GracefulShutdown(tomcat) : null;
	initialize();
}
// tomcat 初始化
private void initialize() throws WebServerException {
	logger.info("Tomcat initialized with port(s): " + getPortsDescription(false));
	synchronized (this.monitor) {
		try {
			addInstanceIdToEngineName();

			Context context = findContext();
			context.addLifecycleListener((event) -> {
				if (context.equals(event.getSource()) && Lifecycle.START_EVENT.equals(event.getType())) {
					// Remove service connectors so that protocol binding doesn't
					// happen when the service is started.
					removeServiceConnectors();
				}
			});

			// Start the server to trigger initialization listeners
			this.tomcat.start();

			// We can re-throw failure exception directly in the main thread
			rethrowDeferredStartupExceptions();

			try {
				ContextBindings.bindClassLoader(context, context.getNamingToken(), getClass().getClassLoader());
			}
			catch (NamingException ex) {
				// Naming is not enabled. Continue
			}

			// Unlike Jetty, all Tomcat threads are daemon threads. We create a
			// blocking non-daemon to stop immediate shutdown
			startDaemonAwaitThread();
		}
		catch (Exception ex) {
			stopSilently();
			destroySilently();
			throw new WebServerException("Unable to start embedded Tomcat", ex);
		}
	}
}
```