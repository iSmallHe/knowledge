# SpringBoot源码解析
```java
    // springboot运行方法
    public static ConfigurableApplicationContext run(Class<?>[] primarySources, String[] args) {
		return new SpringApplication(primarySources).run(args);
	}

    // SpringApplication构造方法
    public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
		this.resourceLoader = resourceLoader;
		Assert.notNull(primarySources, "PrimarySources must not be null");
		this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
		// 从类路劲下查询当前WebApplication的类型：reactive，servlet，none
		this.webApplicationType = WebApplicationType.deduceFromClasspath();
		this.bootstrapRegistryInitializers = getBootstrapRegistryInitializersFromSpringFactories();
		setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
		setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
		this.mainApplicationClass = deduceMainApplicationClass();
	}

    // 构造完成SpringApplication后，执行run方法
    public ConfigurableApplicationContext run(String... args) {
		StopWatch stopWatch = new StopWatch();
		stopWatch.start();
		DefaultBootstrapContext bootstrapContext = createBootstrapContext();
		ConfigurableApplicationContext context = null;
		configureHeadlessProperty();
		SpringApplicationRunListeners listeners = getRunListeners(args);
		listeners.starting(bootstrapContext, this.mainApplicationClass);
		try {
			ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
			ConfigurableEnvironment environment = prepareEnvironment(listeners, bootstrapContext, applicationArguments);
			configureIgnoreBeanInfo(environment);
			Banner printedBanner = printBanner(environment);
			context = createApplicationContext();
			context.setApplicationStartup(this.applicationStartup);
			prepareContext(bootstrapContext, context, environment, listeners, applicationArguments, printedBanner);
			refreshContext(context);
			afterRefresh(context, applicationArguments);
			stopWatch.stop();
			if (this.logStartupInfo) {
				new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);
			}
			listeners.started(context);
			callRunners(context, applicationArguments);
		}
		catch (Throwable ex) {
			handleRunFailure(context, ex, listeners);
			throw new IllegalStateException(ex);
		}

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

## SpringApplication构造方法
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


## run方法

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

### prepareEnvironment
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

	// 根据webApplicationType来创建不同的环境
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

	// 配置参数
	protected void configureEnvironment(ConfigurableEnvironment environment, String[] args) {
		if (this.addConversionService) {
			ConversionService conversionService = ApplicationConversionService.getSharedInstance();
			environment.setConversionService((ConfigurableConversionService) conversionService);
		}
		// 配置默认参数以及启动命令行参数
		configurePropertySources(environment, args);
		// 配置profiles，默认空方法
		configureProfiles(environment, args);
	}

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


	// 准备ConfigurationApplicationContext 
	private void prepareContext(DefaultBootstrapContext bootstrapContext, ConfigurableApplicationContext context,
			ConfigurableEnvironment environment, SpringApplicationRunListeners listeners,
			ApplicationArguments applicationArguments, Banner printedBanner) {
		// 配置环境
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

## springboot创建web server
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