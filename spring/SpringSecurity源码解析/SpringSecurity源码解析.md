# SpringSecurity源码解析

在解析Spring-Security时，我们需要注意其结构设计，但在此时，我还处于管中窥豹，暂不分析。
在引入Spring容器中，最重要的是一个注解 `@EnableWebSecurity` 这个注解承载了Spring-Security的加载配置流程。

## @EnableWebSecurity注解分析
    @EnableWebSecurity import了部分配置类，
    1. WebSecurityConfiguration：配置关键类，在其属性注入时，会获取Spring中加载的WebSecurityConfigurer配置类，并添加到WebSecurity中，后续进行Spring-Security的加载流程
    2. SpringWebMvcImportSelector：判断是否存在DispatcherServlet，如果存在则会加载WebMvcSecurityConfiguration配置类，添加CsrfRequestDataValueProcessor，以及几个参数解析器
    3. OAuth2ImportSelector：增加OAuth2相关配置，暂不讨论
    4. HttpSecurityConfiguration：具体作用暂不清楚，后续再分析
	5. EnableGlobalAuthentication：增加鉴权关键bean，以及加入配置ObjectPostProcessorConfiguration，生成ObjectPostProcessor,该类用于将new出来的实例注入spring容器中
```java
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@Documented
@Import({ WebSecurityConfiguration.class, SpringWebMvcImportSelector.class, OAuth2ImportSelector.class,
		HttpSecurityConfiguration.class })
@EnableGlobalAuthentication
@Configuration
public @interface EnableWebSecurity {

	/**
	 * Controls debugging support for Spring Security. Default is false.
	 * @return if true, enables debug support with Spring Security
	 */
	boolean debug() default false;
}
```

### WebSecurityConfiguration分析
    源码如下，这其中我们需要关注的方法：
    1. autowiredWebSecurityConfigurersIgnoreParents：创建AutowiredWebSecurityConfigurersIgnoreParents类，其方法getWebSecurityConfigurers会从Spring容器中获取WebSecurityConfigurer类型相关bean，这些配置类，在setFilterChainProxySecurityConfigurer中大有所为。
    2. setFilterChainProxySecurityConfigurer：将Spring容器中的配置类SecurityConfigurer，加载到webSecurity中
    3. springSecurityFilterChain：构建WebSecurity，初始化Security配置流程

springSecurityFilterChain创建的过滤器，将在springboot中的tomcat中加载，详情请看[SpringBootTomcat](../SpringBoot/SpringBootTomcat.md)
```java
@Configuration(proxyBeanMethods = false)
public class WebSecurityConfiguration implements ImportAware, BeanClassLoaderAware {

	private WebSecurity webSecurity;

	private Boolean debugEnabled;

	private List<SecurityConfigurer<Filter, WebSecurity>> webSecurityConfigurers;

	private List<SecurityFilterChain> securityFilterChains = Collections.emptyList();

	private List<WebSecurityCustomizer> webSecurityCustomizers = Collections.emptyList();

	private ClassLoader beanClassLoader;

	@Autowired(required = false)
	private ObjectPostProcessor<Object> objectObjectPostProcessor;

	@Bean
	public static DelegatingApplicationListener delegatingApplicationListener() {
		return new DelegatingApplicationListener();
	}

	@Bean
	@DependsOn(AbstractSecurityWebApplicationInitializer.DEFAULT_FILTER_NAME)
	public SecurityExpressionHandler<FilterInvocation> webSecurityExpressionHandler() {
		return this.webSecurity.getExpressionHandler();
	}

	// Spring-Security的重点在此
	@Bean(name = AbstractSecurityWebApplicationInitializer.DEFAULT_FILTER_NAME)
	public Filter springSecurityFilterChain() throws Exception {
		// 判断是否存在配置类，如果没有的话，则会创建默认配置WebSecurityConfigurerAdapter
		boolean hasConfigurers = this.webSecurityConfigurers != null && !this.webSecurityConfigurers.isEmpty();
		boolean hasFilterChain = !this.securityFilterChains.isEmpty();
		Assert.state(!(hasConfigurers && hasFilterChain),
				"Found WebSecurityConfigurerAdapter as well as SecurityFilterChain. Please select just one.");
		if (!hasConfigurers && !hasFilterChain) {
			WebSecurityConfigurerAdapter adapter = this.objectObjectPostProcessor
					.postProcess(new WebSecurityConfigurerAdapter() {
					});
			this.webSecurity.apply(adapter);
		}
		// 将注入的SecurityFilterChain添加到WebSecurity中
		for (SecurityFilterChain securityFilterChain : this.securityFilterChains) {
			this.webSecurity.addSecurityFilterChainBuilder(() -> securityFilterChain);
			for (Filter filter : securityFilterChain.getFilters()) {
				if (filter instanceof FilterSecurityInterceptor) {
					this.webSecurity.securityInterceptor((FilterSecurityInterceptor) filter);
					break;
				}
			}
		}
		// 执行客制化需求，此时可以对WebSecurity进行修改
		for (WebSecurityCustomizer customizer : this.webSecurityCustomizers) {
			customizer.customize(this.webSecurity);
		}
		// 此处正是开启Spring-Security的构建之旅
		return this.webSecurity.build();
	}

	@Bean
	@DependsOn(AbstractSecurityWebApplicationInitializer.DEFAULT_FILTER_NAME)
	public WebInvocationPrivilegeEvaluator privilegeEvaluator() {
		return this.webSecurity.getPrivilegeEvaluator();
	}

	// 此处是创建WebSecurity的开端，并在此处借助autowiredWebSecurityConfigurersIgnoreParents获取Spring容器中的WebSecurityConfigurer。我们继承的WebSecurityConfigurerAdapter的子类，正是在这里被加载到Spring-Security中。
	@Autowired(required = false)
	public void setFilterChainProxySecurityConfigurer(ObjectPostProcessor<Object> objectPostProcessor,
			@Value("#{@autowiredWebSecurityConfigurersIgnoreParents.getWebSecurityConfigurers()}") List<SecurityConfigurer<Filter, WebSecurity>> webSecurityConfigurers)
			throws Exception {
		// 创建WebSecurity
		this.webSecurity = objectPostProcessor.postProcess(new WebSecurity(objectPostProcessor));
		if (this.debugEnabled != null) {
			this.webSecurity.debug(this.debugEnabled);
		}
		// 根据配置类实现的接口Ordered或者注解@Order进行排序
		webSecurityConfigurers.sort(AnnotationAwareOrderComparator.INSTANCE);
		Integer previousOrder = null;
		Object previousConfig = null;
		// 遍历判断是否有重复的order，这是不允许的
		for (SecurityConfigurer<Filter, WebSecurity> config : webSecurityConfigurers) {
			Integer order = AnnotationAwareOrderComparator.lookupOrder(config);
			if (previousOrder != null && previousOrder.equals(order)) {
				throw new IllegalStateException("@Order on WebSecurityConfigurers must be unique. Order of " + order
						+ " was already used on " + previousConfig + ", so it cannot be used on " + config + " too.");
			}
			previousOrder = order;
			previousConfig = config;
		}
		// 将关于spring-security的配置类加载到WebSecurity中
		for (SecurityConfigurer<Filter, WebSecurity> webSecurityConfigurer : webSecurityConfigurers) {
			this.webSecurity.apply(webSecurityConfigurer);
		}
		this.webSecurityConfigurers = webSecurityConfigurers;
	}

	@Autowired(required = false)
	void setFilterChains(List<SecurityFilterChain> securityFilterChains) {
		this.securityFilterChains = securityFilterChains;
	}

	@Autowired(required = false)
	void setWebSecurityCustomizers(List<WebSecurityCustomizer> webSecurityCustomizers) {
		this.webSecurityCustomizers = webSecurityCustomizers;
	}

	@Bean
	public static BeanFactoryPostProcessor conversionServicePostProcessor() {
		return new RsaKeyConversionServicePostProcessor();
	}

	// 我们这里要注意到该方法是static方法，所以在setFilterChainProxySecurityConfigurer时，保证该bean已被创建
	// 该Bean主要是获取Spring容器中的WebSecurityConfigurer
	@Bean
	public static AutowiredWebSecurityConfigurersIgnoreParents autowiredWebSecurityConfigurersIgnoreParents(
			ConfigurableListableBeanFactory beanFactory) {
		return new AutowiredWebSecurityConfigurersIgnoreParents(beanFactory);
	}

	@Override
	public void setImportMetadata(AnnotationMetadata importMetadata) {
		Map<String, Object> enableWebSecurityAttrMap = importMetadata
				.getAnnotationAttributes(EnableWebSecurity.class.getName());
		AnnotationAttributes enableWebSecurityAttrs = AnnotationAttributes.fromMap(enableWebSecurityAttrMap);
		this.debugEnabled = enableWebSecurityAttrs.getBoolean("debug");
		if (this.webSecurity != null) {
			this.webSecurity.debug(this.debugEnabled);
		}
	}

	@Override
	public void setBeanClassLoader(ClassLoader classLoader) {
		this.beanClassLoader = classLoader;
	}

	private static class AnnotationAwareOrderComparator extends OrderComparator {

		private static final AnnotationAwareOrderComparator INSTANCE = new AnnotationAwareOrderComparator();

		@Override
		protected int getOrder(Object obj) {
			return lookupOrder(obj);
		}

		private static int lookupOrder(Object obj) {
			if (obj instanceof Ordered) {
				return ((Ordered) obj).getOrder();
			}
			if (obj != null) {
				Class<?> clazz = ((obj instanceof Class) ? (Class<?>) obj : obj.getClass());
				Order order = AnnotationUtils.findAnnotation(clazz, Order.class);
				if (order != null) {
					return order.value();
				}
			}
			return Ordered.LOWEST_PRECEDENCE;
		}

	}

}
```

### WebSecurity
	首先我们要关注下WebSecurity的类结构，实现了顶级类SecurityBuilder
![WebSecurity类结构](../../image/WebSecurity类结构.png)

#### build
	构建流程的模板方法在AbstractConfiguredSecurityBuilder.doBuild方法中，制定了整个加载流程。
	构建流程分为三段：
	init：初始化阶段
	configure：配置阶段
	performBuild：构建阶段，主要由子类进行拓展。存在三个子类分支：
		WebSecurity：用于主导整个Spring-Security的构建
		HttpSecurity：用于主导关于Http请求配置的构建
		AuthenticationManagerBuilder：用于主导授权鉴权相关配置的构建
```java
// AbstractSecurityBuilder
public final O build() throws Exception {
	if (this.building.compareAndSet(false, true)) {
		this.object = doBuild();
		return this.object;
	}
	throw new AlreadyBuiltException("This object has already been built");
}
// AbstractConfiguredSecurityBuilder
// 构建流程的模板方法
protected final O doBuild() throws Exception {
	synchronized (this.configurers) {
		this.buildState = BuildState.INITIALIZING;
		beforeInit();
		init();
		this.buildState = BuildState.CONFIGURING;
		beforeConfigure();
		configure();
		this.buildState = BuildState.BUILDING;
		// performBuild构建交由子类进行拓展
		O result = performBuild();
		this.buildState = BuildState.BUILT;
		return result;
	}
}
// AbstractConfiguredSecurityBuilder
private void init() throws Exception {
	Collection<SecurityConfigurer<O, B>> configurers = getConfigurers();
	for (SecurityConfigurer<O, B> configurer : configurers) {
		configurer.init((B) this);
	}
	// 此处为何要进行第二次的初始化，原因在于：
	// configurer.init之时，可能会添加新的SecurityConfigurer类，所以在此处对初始化中新添加的配置类进行初始化
	for (SecurityConfigurer<O, B> configurer : this.configurersAddedInInitializing) {
		configurer.init((B) this);
	}
}
// AbstractConfiguredSecurityBuilder
private void configure() throws Exception {
	Collection<SecurityConfigurer<O, B>> configurers = getConfigurers();
	for (SecurityConfigurer<O, B> configurer : configurers) {
		configurer.configure((B) this);
	}
}

// WebSecurity
protected Filter performBuild() throws Exception {
	Assert.state(!this.securityFilterChainBuilders.isEmpty(),
			() -> "At least one SecurityBuilder<? extends SecurityFilterChain> needs to be specified. "
					+ "Typically this is done by exposing a SecurityFilterChain bean "
					+ "or by adding a @Configuration that extends WebSecurityConfigurerAdapter. "
					+ "More advanced users can invoke " + WebSecurity.class.getSimpleName()
					+ ".addSecurityFilterChainBuilder directly");
	int chainSize = this.ignoredRequests.size() + this.securityFilterChainBuilders.size();
	List<SecurityFilterChain> securityFilterChains = new ArrayList<>(chainSize);
	// 创建ignoredRequest过滤器链
	for (RequestMatcher ignoredRequest : this.ignoredRequests) {
		securityFilterChains.add(new DefaultSecurityFilterChain(ignoredRequest));
	}
	// 添加配置类构建的过滤器链，这个链路创建在init阶段，我们后续在WebSecurityConfiguration中会分析
	for (SecurityBuilder<? extends SecurityFilterChain> securityFilterChainBuilder : this.securityFilterChainBuilders) {
		securityFilterChains.add(securityFilterChainBuilder.build());
	}
	// 构建过滤器，用于代理整个Security的过滤器执行链路
	FilterChainProxy filterChainProxy = new FilterChainProxy(securityFilterChains);
	if (this.httpFirewall != null) {
		filterChainProxy.setFirewall(this.httpFirewall);
	}
	if (this.requestRejectedHandler != null) {
		filterChainProxy.setRequestRejectedHandler(this.requestRejectedHandler);
	}
	filterChainProxy.afterPropertiesSet();

	Filter result = filterChainProxy;
	if (this.debugEnabled) {
		this.logger.warn("\n\n" + "********************************************************************\n"
				+ "**********        Security debugging is enabled.       *************\n"
				+ "**********    This may include sensitive information.  *************\n"
				+ "**********      Do not use in a production system!     *************\n"
				+ "********************************************************************\n\n");
		result = new DebugFilter(filterChainProxy);
	}
	// 执行构建完成后的动作
	this.postBuildAction.run();
	return result;
}
```

### WebSecurityConfigurerAdapter
	我们实现对Spring-Security的配置主要通过继承WebSecurityConfigurerAdapter来实现
![WebSecurityConfigurerAdapter类结构](../../image/WebSecurityConfigurerAdapter类结构.png)  

	实现的配置方法有：
	configure(WebSecurity web)：对WebSecurity进行配置，执行时机在WebSecurity.configure阶段
	configure(AuthenticationManagerBuilder auth)：对权限管理进行配置，执行时机在WebSecurity.init阶段
	configure(HttpSecurity http)：对Http请求配置，执行时机在WebSecurity.init阶段
```java
// WebSecurityConfigurerAdapter
// WebSecurityConfigurerAdapter及其子类在init阶段
public void init(WebSecurity web) throws Exception {
	// 创建HttpSecurity
	HttpSecurity http = getHttp();
	// 添加到SecurityFilterChainBuilder中，后续启动HttpSecurity相关配置构建(即WebSecurity.performBuild中的securityFilterChainBuilder.build())
	web.addSecurityFilterChainBuilder(http).postBuildAction(() -> {
		FilterSecurityInterceptor securityInterceptor = http.getSharedObject(FilterSecurityInterceptor.class);
		web.securityInterceptor(securityInterceptor);
	});
}

// WebSecurityConfigurerAdapter
// 创建HttpSecurity
protected final HttpSecurity getHttp() throws Exception {
	if (this.http != null) {
		return this.http;
	}
	// 获取授权事件发布器
	AuthenticationEventPublisher eventPublisher = getAuthenticationEventPublisher();
	this.localConfigureAuthenticationBldr.authenticationEventPublisher(eventPublisher);
	// 获取权限管理器，此时也将执行configure(AuthenticationManagerBuilder auth)
	AuthenticationManager authenticationManager = authenticationManager();
	// 设置父级鉴权管理器
	this.authenticationBuilder.parentAuthenticationManager(authenticationManager);
	Map<Class<?>, Object> sharedObjects = createSharedObjects();
	// 创建HttpSecurity
	this.http = new HttpSecurity(this.objectPostProcessor, this.authenticationBuilder, sharedObjects);
	if (!this.disableDefaults) {
		// 添加默认的HttpSecurity配置
		applyDefaultConfiguration(this.http);
		ClassLoader classLoader = this.context.getClassLoader();
		// 获取spring容器中的AbstractHttpConfigurer配置类
		List<AbstractHttpConfigurer> defaultHttpConfigurers = SpringFactoriesLoader
				.loadFactories(AbstractHttpConfigurer.class, classLoader);
		for (AbstractHttpConfigurer configurer : defaultHttpConfigurers) {
			this.http.apply(configurer);
		}
	}
	// 执行configure(HttpSecurity http)
	configure(this.http);
	return this.http;
}

// WebSecurityConfigurerAdapter
protected AuthenticationManager authenticationManager() throws Exception {
	if (!this.authenticationManagerInitialized) {
		// 执行configure(AuthenticationManagerBuilder auth)
		// localConfigureAuthenticationBldr 初始化在  setApplicationContext方法中
		configure(this.localConfigureAuthenticationBldr);
		if (this.disableLocalConfigureAuthenticationBldr) {
			this.authenticationManager = this.authenticationConfiguration.getAuthenticationManager();
		}
		else {
			// 此处开启AuthenticationManagerBuilder的构建
			this.authenticationManager = this.localConfigureAuthenticationBldr.build();
		}
		this.authenticationManagerInitialized = true;
	}
	return this.authenticationManager;
}
// WebSecurityConfigurerAdapter
public void setApplicationContext(ApplicationContext context) {
	this.context = context;
	ObjectPostProcessor<Object> objectPostProcessor = context.getBean(ObjectPostProcessor.class);
	LazyPasswordEncoder passwordEncoder = new LazyPasswordEncoder(context);
	this.authenticationBuilder = new DefaultPasswordEncoderAuthenticationManagerBuilder(objectPostProcessor,
			passwordEncoder);
	this.localConfigureAuthenticationBldr = new DefaultPasswordEncoderAuthenticationManagerBuilder(
			objectPostProcessor, passwordEncoder) {

		@Override
		public AuthenticationManagerBuilder eraseCredentials(boolean eraseCredentials) {
			WebSecurityConfigurerAdapter.this.authenticationBuilder.eraseCredentials(eraseCredentials);
			return super.eraseCredentials(eraseCredentials);
		}

		@Override
		public AuthenticationManagerBuilder authenticationEventPublisher(
				AuthenticationEventPublisher eventPublisher) {
			WebSecurityConfigurerAdapter.this.authenticationBuilder.authenticationEventPublisher(eventPublisher);
			return super.authenticationEventPublisher(eventPublisher);
		}

	};
}

// 添加默认的HttpSecurity配置
private void applyDefaultConfiguration(HttpSecurity http) throws Exception {
	// 添加CsrfConfigurer，configure阶段添加CsrfFilter
	http.csrf();
	// 添加过滤器WebAsyncManagerIntegrationFilter(该过滤器用于处理异步请求，暂不清楚)
	http.addFilter(new WebAsyncManagerIntegrationFilter());
	// 添加ExceptionHandlingConfigurer，configure阶段添加ExceptionTranslationFilter(该过滤器用于处理异常)
	http.exceptionHandling();
	// 添加HeadersConfigurer，configure阶段添加HeaderWriterFilter(该过滤器用于给请求/响应添加头)
	http.headers();
	// 添加SessionManagementConfigurer，init阶段处理SecurityContextRepository，configure阶段添加SessionManagementFilter(保持用户会话的身份验证，暂不清晰)
	http.sessionManagement();
	// 添加SecurityContextConfigurer，configure阶段处理SecurityContextRepository，并添加SecurityContextPersistenceFilter(该过滤器用于保存SecurityContext)
	http.securityContext();
	// 添加RequestCacheConfigurer，configure阶段添加RequestCacheAwareFilter(该过滤器用于处理用户登录成功后，恢复因登录而被打断的请求)
	http.requestCache();
	// 添加AnonymousConfigurer，init阶段创建鉴权相关类，configure阶段添加AnonymousAuthenticationFilter(用于处理匿名用户权限)
	http.anonymous();
	// 添加ServletApiConfigurer，configure阶段添加SecurityContextHolderAwareRequestFilter(该过滤器主要使用Servlet3SecurityContextHolderAwareRequestWrapper装饰器封装了Request，用于兼容servlet api的接口方法)
	http.servletApi();
	// 添加DefaultLoginPageConfigurer，init阶段处理隐藏输入，configure阶段判断是否添加DefaultLoginPageGeneratingFilter，DefaultLogoutPageGeneratingFilter
	http.apply(new DefaultLoginPageConfigurer<>());
	// 添加LogoutConfigurer，init阶段设置退出成功地址，configure阶段添加LogoutFilter(该过滤器用于处理用户退出登录相关逻辑)
	http.logout();
}
```

	HttpSecurity的performBuild构建，此时将所有的过滤器按既定的顺序进行统一排序，并创建执行器链
```java
protected DefaultSecurityFilterChain performBuild() {
	// 此处交由比较器进行排序
	// private FilterComparator comparator = new FilterComparator();
	this.filters.sort(this.comparator);
	return new DefaultSecurityFilterChain(this.requestMatcher, this.filters);
}
```



### AuthenticationManager
	客户端的鉴权配置是置于父级鉴权器中
	首先我们需要了解Spring-Security的鉴权策略在于父子管理器通用鉴权，子鉴权管理器若弃权，则会上浮到父级鉴权管理器处理
	鉴权管理器被放置ShareObject的时机在HttpSecurity.beforeConfigure，后续UsernamePasswordAuthenticationFilter在configure阶段将会获取
	鉴权时机在UsernamePasswordAuthenticationFilter.attemptAuthentication

	Spring-Security提供的权限方案有三种：
	1. 内存方式：inMemoryAuthentication，此时将使用配置类InMemoryUserDetailsManagerConfigurer
	2. 自定义：userDetailsService，此时将使用配置类DaoAuthenticationConfigurer
	3. jdbc：jdbcAuthentication，此时将使用配置类JdbcUserDetailsManagerConfigurer

	自定义方式使用范围最广，也最实用，所以在此只分析自定义模式
	
#### DaoAuthenticationConfigurer
![DaoAuthenticationConfigurer类结构](../../image/DaoAuthenticationConfigurer类结构.png)

	父类(AbstractDaoAuthenticationConfigurer)会默认创建DaoAuthenticationProvider
	其configure阶段会向AuthenticationManagerBuilder添加DaoAuthenticationProvider
```java
public void configure(B builder) throws Exception {
	this.provider = postProcess(this.provider);
	builder.authenticationProvider(this.provider);
}
```

#### AuthenticationManagerBuilder
	AuthenticationManagerBuilder的构建
```java
protected ProviderManager performBuild() throws Exception {
	if (!isConfigured()) {
		this.logger.debug("No authenticationProviders and no parentAuthenticationManager defined. Returning null.");
		return null;
	}
	// 创建鉴权管理器，提取配置类中提供的AuthenticationProvider
	ProviderManager providerManager = new ProviderManager(this.authenticationProviders,
			this.parentAuthenticationManager);
	if (this.eraseCredentials != null) {
		providerManager.setEraseCredentialsAfterAuthentication(this.eraseCredentials);
	}
	// ProviderManager添加事件分发器
	if (this.eventPublisher != null) {
		providerManager.setAuthenticationEventPublisher(this.eventPublisher);
	}
	// 将ProviderManager注入spring容器
	providerManager = postProcess(providerManager);
	return providerManager;
}
```

### UsernamePasswordAuthenticationFilter
	在设置鉴权配置时需要使用到配置类FormLoginConfigurer，UsernamePasswordAuthenticationFilter会在FormLoginConfigurer的实话过程中创建

	init阶段
```java
// FormLoginConfigurer
public void init(H http) throws Exception {
	super.init(http);
	initDefaultLoginFilter(http);
}

// AbstractAuthenticationFilterConfigurer
public void init(B http) throws Exception {
	// 配置登录URL，登录失败URL，退出成功URL
	updateAuthenticationDefaults();
	// 设置登录/退出URL为全权限
	updateAccessDefaults(http);
	// 注册默认的登录入口
	registerDefaultAuthenticationEntryPoint(http);
}

// FormLoginConfigurer
private void initDefaultLoginFilter(H http) {
	DefaultLoginPageGeneratingFilter loginPageGeneratingFilter = http
			.getSharedObject(DefaultLoginPageGeneratingFilter.class);
	// 此处进行判断是否使用客户端的登录页
	if (loginPageGeneratingFilter != null && !isCustomLoginPage()) {
		loginPageGeneratingFilter.setFormLoginEnabled(true);
		loginPageGeneratingFilter.setUsernameParameter(getUsernameParameter());
		loginPageGeneratingFilter.setPasswordParameter(getPasswordParameter());
		loginPageGeneratingFilter.setLoginPageUrl(getLoginPage());
		loginPageGeneratingFilter.setFailureUrl(getFailureUrl());
		loginPageGeneratingFilter.setAuthenticationUrl(getLoginProcessingUrl());
	}
}
```
	configure阶段，此时会配置鉴权管理器
```java
public void configure(B http) throws Exception {
	PortMapper portMapper = http.getSharedObject(PortMapper.class);
	if (portMapper != null) {
		this.authenticationEntryPoint.setPortMapper(portMapper);
	}
	RequestCache requestCache = http.getSharedObject(RequestCache.class);
	if (requestCache != null) {
		this.defaultSuccessHandler.setRequestCache(requestCache);
	}
	// 配置鉴权管理器
	this.authFilter.setAuthenticationManager(http.getSharedObject(AuthenticationManager.class));
	this.authFilter.setAuthenticationSuccessHandler(this.successHandler);
	this.authFilter.setAuthenticationFailureHandler(this.failureHandler);
	if (this.authenticationDetailsSource != null) {
		this.authFilter.setAuthenticationDetailsSource(this.authenticationDetailsSource);
	}
	SessionAuthenticationStrategy sessionAuthenticationStrategy = http
			.getSharedObject(SessionAuthenticationStrategy.class);
	if (sessionAuthenticationStrategy != null) {
		this.authFilter.setSessionAuthenticationStrategy(sessionAuthenticationStrategy);
	}
	RememberMeServices rememberMeServices = http.getSharedObject(RememberMeServices.class);
	if (rememberMeServices != null) {
		this.authFilter.setRememberMeServices(rememberMeServices);
	}
	F filter = postProcess(this.authFilter);
	http.addFilter(filter);
}
```
#### attemptAuthentication
	进行鉴权
```java
public Authentication attemptAuthentication(HttpServletRequest request, HttpServletResponse response)
		throws AuthenticationException {
	if (this.postOnly && !request.getMethod().equals("POST")) {
		throw new AuthenticationServiceException("Authentication method not supported: " + request.getMethod());
	}
	String username = obtainUsername(request);
	username = (username != null) ? username : "";
	username = username.trim();
	String password = obtainPassword(request);
	password = (password != null) ? password : "";
	UsernamePasswordAuthenticationToken authRequest = new UsernamePasswordAuthenticationToken(username, password);
	// Allow subclasses to set the "details" property
	setDetails(request, authRequest);
	// 获取权限管理器进行鉴权
	return this.getAuthenticationManager().authenticate(authRequest);
}
```
	AuthenticationManager进行鉴权，实例是ProviderManager，在使用自定义的权限控制的Provider是DaoAuthenticationProvider
```java
// ProviderManager
public Authentication authenticate(Authentication authentication) throws AuthenticationException {
	Class<? extends Authentication> toTest = authentication.getClass();
	AuthenticationException lastException = null;
	AuthenticationException parentException = null;
	Authentication result = null;
	Authentication parentResult = null;
	int currentPosition = 0;
	int size = this.providers.size();
	for (AuthenticationProvider provider : getProviders()) {
		// 判断是否支持
		if (!provider.supports(toTest)) {
			continue;
		}
		if (logger.isTraceEnabled()) {
			logger.trace(LogMessage.format("Authenticating request with %s (%d/%d)",
					provider.getClass().getSimpleName(), ++currentPosition, size));
		}
		try {
			// 进行鉴权
			result = provider.authenticate(authentication);
			if (result != null) {
				copyDetails(authentication, result);
				break;
			}
		}
		catch (AccountStatusException | InternalAuthenticationServiceException ex) {
			prepareException(ex, authentication);
			// SEC-546: Avoid polling additional providers if auth failure is due to
			// invalid account status
			throw ex;
		}
		catch (AuthenticationException ex) {
			lastException = ex;
		}
	}
	// 如果此时没有处理，则交由父级权限管理器进行鉴权
	if (result == null && this.parent != null) {
		// Allow the parent to try.
		try {
			parentResult = this.parent.authenticate(authentication);
			result = parentResult;
		}
		catch (ProviderNotFoundException ex) {
			// 如果没有鉴权器处理，则在后续会抛出该异常，这里无需处理，此处理解要建立在多级嵌套父子管理器的思维下
		}
		catch (AuthenticationException ex) {
			parentException = ex;
			lastException = ex;
		}
	}
	if (result != null) {
		// 鉴权结束后，删除私密数据
		if (this.eraseCredentialsAfterAuthentication && (result instanceof CredentialsContainer)) {
			((CredentialsContainer) result).eraseCredentials();
		}
		// 父级结果为null，则表明是当前管理器进行鉴权的，则发布鉴权结果事件
		if (parentResult == null) {
			this.eventPublisher.publishAuthenticationSuccess(result);
		}

		return result;
	}
	// 此时表明已有的所有权限鉴定器都弃权了，找不到响应的鉴权器
	if (lastException == null) {
		lastException = new ProviderNotFoundException(this.messages.getMessage("ProviderManager.providerNotFound",
				new Object[] { toTest.getName() }, "No AuthenticationProvider found for {0}"));
	}
	// If the parent AuthenticationManager was attempted and failed then it will
	// publish an AbstractAuthenticationFailureEvent
	// This check prevents a duplicate AbstractAuthenticationFailureEvent if the
	// parent AuthenticationManager already published it
	// 此处的含义与发布事件的原因一致
	if (parentException == null) {
		prepareException(lastException, authentication);
	}
	throw lastException;
}
```
	AbstractUserDetailsAuthenticationProvider进行鉴权
```java
// AbstractUserDetailsAuthenticationProvider
public Authentication authenticate(Authentication authentication) throws AuthenticationException {
	Assert.isInstanceOf(UsernamePasswordAuthenticationToken.class, authentication,
			() -> this.messages.getMessage("AbstractUserDetailsAuthenticationProvider.onlySupports",
					"Only UsernamePasswordAuthenticationToken is supported"));
	String username = determineUsername(authentication);
	boolean cacheWasUsed = true;
	UserDetails user = this.userCache.getUserFromCache(username);
	if (user == null) {
		cacheWasUsed = false;
		try {
			user = retrieveUser(username, (UsernamePasswordAuthenticationToken) authentication);
		}
		catch (UsernameNotFoundException ex) {
			this.logger.debug("Failed to find user '" + username + "'");
			if (!this.hideUserNotFoundExceptions) {
				throw ex;
			}
			throw new BadCredentialsException(this.messages
					.getMessage("AbstractUserDetailsAuthenticationProvider.badCredentials", "Bad credentials"));
		}
		Assert.notNull(user, "retrieveUser returned null - a violation of the interface contract");
	}
	try {
		// 校验账号的有效性
		this.preAuthenticationChecks.check(user);
		// 校验密码
		additionalAuthenticationChecks(user, (UsernamePasswordAuthenticationToken) authentication);
	}
	catch (AuthenticationException ex) {
		if (!cacheWasUsed) {
			throw ex;
		}
		// There was a problem, so try again after checking
		// we're using latest data (i.e. not from the cache)
		cacheWasUsed = false;
		user = retrieveUser(username, (UsernamePasswordAuthenticationToken) authentication);
		this.preAuthenticationChecks.check(user);
		additionalAuthenticationChecks(user, (UsernamePasswordAuthenticationToken) authentication);
	}
	// 校验凭证是否过期
	this.postAuthenticationChecks.check(user);
	// 缓存用户
	if (!cacheWasUsed) {
		this.userCache.putUserInCache(user);
	}
	Object principalToReturn = user;
	if (this.forcePrincipalAsString) {
		principalToReturn = user.getUsername();
	}
	// 创建鉴权成功凭证
	return createSuccessAuthentication(principalToReturn, authentication, user);
}
// DaoAuthenticationProvider
protected Authentication createSuccessAuthentication(Object principal, Authentication authentication,
		UserDetails user) {
	// 判断是否需要升级编码
	boolean upgradeEncoding = this.userDetailsPasswordService != null
			&& this.passwordEncoder.upgradeEncoding(user.getPassword());
	if (upgradeEncoding) {
		// 升级之后更改用户密码
		String presentedPassword = authentication.getCredentials().toString();
		String newPassword = this.passwordEncoder.encode(presentedPassword);
		user = this.userDetailsPasswordService.updatePassword(user, newPassword);
	}
	// 创建凭证
	return super.createSuccessAuthentication(principal, authentication, user);
}
// AbstractUserDetailsAuthenticationProvider
protected Authentication createSuccessAuthentication(Object principal, Authentication authentication,
		UserDetails user) {
	// Ensure we return the original credentials the user supplied,
	// so subsequent attempts are successful even with encoded passwords.
	// Also ensure we return the original getDetails(), so that future
	// authentication events after cache expiry contain the details
	// 创建凭证
	UsernamePasswordAuthenticationToken result = new UsernamePasswordAuthenticationToken(principal,
			authentication.getCredentials(), this.authoritiesMapper.mapAuthorities(user.getAuthorities()));
	result.setDetails(authentication.getDetails());
	this.logger.debug("Authenticated user");
	return result;
}
```

### ObjectPostProcessor
	在此我们有必要具体分析下ObjectPostProcessor的作用

