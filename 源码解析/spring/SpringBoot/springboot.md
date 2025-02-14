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

// 此时会创建注解加载器，累路径加载器
public AnnotationConfigServletWebServerApplicationContext() {
	this.reader = new AnnotatedBeanDefinitionReader(this);
	this.scanner = new ClassPathBeanDefinitionScanner(this);
}

```

#### 2.7.1 AnnotatedBeanDefinitionReader 

创建注解BeanDefinition加载器`AnnotatedBeanDefinitionReader`，并加入注解加载流程重要组件类的RootBeanDefinition：
1. ConfigurationClassPostProcessor
2. AutowiredAnnotationBeanPostProcessor
3. CommonAnnotationBeanPostProcessor
4. PersistenceAnnotationBeanPostProcessor
5. EventListenerMethodProcessor
6. DefaultEventListenerFactory

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

`spring`容器启动过程，注解启动的重要组件`ConfigurationClassPostProcessor`，将在这里生成`bean`，并执行方法`postProcessBeanDefinitionRegistry`

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
			// 注解启动的重要组件ConfigurationClassPostProcessor，将在这里生成bean，并执行postProcessBeanDefinitionRegistry
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

## 三、创建WebServer容器
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