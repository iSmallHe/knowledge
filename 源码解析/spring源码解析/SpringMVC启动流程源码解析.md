# SpringMVC启动流程源码解析
SpringMVC主要的关键类在于DispatcherServlet
## DispatcherServlet的类图
![title](../../image/DispatcherServlet类图.png)

DispatcherServlet继承于父类`FrameworkServlet`,爷爷`HttpServletBean`。而这其中重要的方法则是`init`方法。

### HttpServletBean_init

    在tomcat中初始化servlet时，会调用 init 方法。并在其中留下钩子方法 initServletBean ，由子类拓展
```java
public final void init() throws ServletException {
	// 从ServletConfig中获取需要的属性值
    PropertyValues pvs = new ServletConfigPropertyValues(getServletConfig(), this.requiredProperties);
    if (!pvs.isEmpty()) {
        try {
			// 包装器包装下，以便后续属性赋值
            BeanWrapper bw = PropertyAccessorFactory.forBeanPropertyAccess(this);
            ResourceLoader resourceLoader = new ServletContextResourceLoader(getServletContext());
            bw.registerCustomEditor(Resource.class, new ResourceEditor(resourceLoader, getEnvironment()));
            initBeanWrapper(bw);
			// 此处是初始化 DispatcherServlet的属性
            bw.setPropertyValues(pvs, true);
        }
        catch (BeansException ex) {
            if (logger.isErrorEnabled()) {
                logger.error("Failed to set bean properties on servlet '" + getServletName() + "'", ex);
            }
            throw ex;
        }
    }
    initServletBean();
}
```

### FrameworkServlet_initServletBean

    此处会进行容器的初始化动作 initWebApplicationContext，并留下 hook 方法 initFrameworkServlet，交由子类拓展

```java
protected final void initServletBean() throws ServletException {
    getServletContext().log("Initializing Spring " + getClass().getSimpleName() + " '" + getServletName() + "'");
    if (logger.isInfoEnabled()) {
        logger.info("Initializing Servlet '" + getServletName() + "'");
    }
    long startTime = System.currentTimeMillis();

    try {
        this.webApplicationContext = initWebApplicationContext();
        initFrameworkServlet();
    }
    catch (ServletException | RuntimeException ex) {
        logger.error("Context initialization failed", ex);
        throw ex;
    }

    if (logger.isDebugEnabled()) {
        String value = this.enableLoggingRequestDetails ?
                "shown which may lead to unsafe logging of potentially sensitive data" :
                "masked to prevent unsafe logging of potentially sensitive data";
        logger.debug("enableLoggingRequestDetails='" + this.enableLoggingRequestDetails +
                "': request parameters and headers will be " + value);
    }

    if (logger.isInfoEnabled()) {
        logger.info("Completed initialization in " + (System.currentTimeMillis() - startTime) + " ms");
    }
}
```

### initWebApplicationContext

    初始化WebApplicationContext，并执行DispatcherServlet的初始化动作
```java
    protected WebApplicationContext initWebApplicationContext() {
        // 从ServletContext中获取WebApplicationContext，参数名：WebApplicationContext全限定类名.ROOT
		WebApplicationContext rootContext =
				WebApplicationContextUtils.getWebApplicationContext(getServletContext());
		WebApplicationContext wac = null;
        // 判断当前是否有 WebApplicationContext
		if (this.webApplicationContext != null) {
			wac = this.webApplicationContext;
			if (wac instanceof ConfigurableWebApplicationContext) {
				ConfigurableWebApplicationContext cwac = (ConfigurableWebApplicationContext) wac;
				if (!cwac.isActive()) {
					if (cwac.getParent() == null) {
						cwac.setParent(rootContext);
					}
					configureAndRefreshWebApplicationContext(cwac);
				}
			}
		}
		if (wac == null) {
            // 如果wac为空，则通过属性 contextAttribute 去ServletContext中查找是否存在 WebApplicationContext
			wac = findWebApplicationContext();
		}
		if (wac == null) {
            // 创建默认的WebApplicationContext XmlWebApplicationContext，然后启动容器
			wac = createWebApplicationContext(rootContext);
		}

		if (!this.refreshEventReceived) {
			// 重中之重，此处方法由DispatcherServlet重写
			synchronized (this.onRefreshMonitor) {
				onRefresh(wac);
			}
		}

		if (this.publishContext) {
			// Publish the context as a servlet context attribute.
			String attrName = getServletContextAttributeName();
			getServletContext().setAttribute(attrName, wac);
		}

		return wac;
	}
```

### DispatcherServlet_onRefresh
	DispatcherServlet.properties内容，该文件用于加载MVC系统需要的解析器
```
# Default implementation classes for DispatcherServlet's strategy interfaces.
# Used as fallback when no matching beans are found in the DispatcherServlet context.
# Not meant to be customized by application developers.

org.springframework.web.servlet.LocaleResolver=org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver

org.springframework.web.servlet.ThemeResolver=org.springframework.web.servlet.theme.FixedThemeResolver

org.springframework.web.servlet.HandlerMapping=org.springframework.web.servlet.handler.BeanNameUrlHandlerMapping,\
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping,\
	org.springframework.web.servlet.function.support.RouterFunctionMapping

org.springframework.web.servlet.HandlerAdapter=org.springframework.web.servlet.mvc.HttpRequestHandlerAdapter,\
	org.springframework.web.servlet.mvc.SimpleControllerHandlerAdapter,\
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter,\
	org.springframework.web.servlet.function.support.HandlerFunctionAdapter


org.springframework.web.servlet.HandlerExceptionResolver=org.springframework.web.servlet.mvc.method.annotation.ExceptionHandlerExceptionResolver,\
	org.springframework.web.servlet.mvc.annotation.ResponseStatusExceptionResolver,\
	org.springframework.web.servlet.mvc.support.DefaultHandlerExceptionResolver

org.springframework.web.servlet.RequestToViewNameTranslator=org.springframework.web.servlet.view.DefaultRequestToViewNameTranslator

org.springframework.web.servlet.ViewResolver=org.springframework.web.servlet.view.InternalResourceViewResolver

org.springframework.web.servlet.FlashMapManager=org.springframework.web.servlet.support.SessionFlashMapManager
```

```java

    protected void onRefresh(ApplicationContext context) {
		initStrategies(context);
	}

    protected void initStrategies(ApplicationContext context) {
		// 初始化 MultipartResolver ：该类用于处理文件上传
		initMultipartResolver(context);
		// 初始化 国际化解析器 即设置MVC不同的语言
		initLocaleResolver(context);
		// 初始化 主题解析器：用于jsp文件更换主题
		initThemeResolver(context);
		// 初始化 映射处理器 
		initHandlerMappings(context);
		// 初始化 适配处理器
		initHandlerAdapters(context);
		// 初始化 异常解析器
		initHandlerExceptionResolvers(context);
		// 初始化 视图解析转换器
		initRequestToViewNameTranslator(context);
		// 初始化 视图解析器
		initViewResolvers(context);
		// FlashMap主要用于在redirect中传递参数，而FlashMapManager主要用于管理FlashMap
		initFlashMapManager(context);
	}

	// 初始化 MultipartResolver ：该类用于处理文件上传
	private void initMultipartResolver(ApplicationContext context) {
		try {
			this.multipartResolver = context.getBean(MULTIPART_RESOLVER_BEAN_NAME, MultipartResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("Detected " + this.multipartResolver);
			}
			else if (logger.isDebugEnabled()) {
				logger.debug("Detected " + this.multipartResolver.getClass().getSimpleName());
			}
		}
		catch (NoSuchBeanDefinitionException ex) {
			// Default is no multipart resolver.
			this.multipartResolver = null;
			if (logger.isTraceEnabled()) {
				logger.trace("No MultipartResolver '" + MULTIPART_RESOLVER_BEAN_NAME + "' declared");
			}
		}
	}

	// 初始化 国际化解析器 即设置MVC不同的语言
	private void initLocaleResolver(ApplicationContext context) {
		try {
			this.localeResolver = context.getBean(LOCALE_RESOLVER_BEAN_NAME, LocaleResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("Detected " + this.localeResolver);
			}
			else if (logger.isDebugEnabled()) {
				logger.debug("Detected " + this.localeResolver.getClass().getSimpleName());
			}
		}
		catch (NoSuchBeanDefinitionException ex) {
			// We need to use the default.
			this.localeResolver = getDefaultStrategy(context, LocaleResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No LocaleResolver '" + LOCALE_RESOLVER_BEAN_NAME +
						"': using default [" + this.localeResolver.getClass().getSimpleName() + "]");
			}
		}
	}

	// 初始化 主题解析器：用于jsp文件更换主题
	private void initThemeResolver(ApplicationContext context) {
		try {
			this.themeResolver = context.getBean(THEME_RESOLVER_BEAN_NAME, ThemeResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("Detected " + this.themeResolver);
			}
			else if (logger.isDebugEnabled()) {
				logger.debug("Detected " + this.themeResolver.getClass().getSimpleName());
			}
		}
		catch (NoSuchBeanDefinitionException ex) {
			// We need to use the default.
			this.themeResolver = getDefaultStrategy(context, ThemeResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No ThemeResolver '" + THEME_RESOLVER_BEAN_NAME +
						"': using default [" + this.themeResolver.getClass().getSimpleName() + "]");
			}
		}
	}

	// 初始化 映射处理器 
	private void initHandlerMappings(ApplicationContext context) {
		this.handlerMappings = null;

		if (this.detectAllHandlerMappings) {
			// Find all HandlerMappings in the ApplicationContext, including ancestor contexts.
			Map<String, HandlerMapping> matchingBeans =
					BeanFactoryUtils.beansOfTypeIncludingAncestors(context, HandlerMapping.class, true, false);
			if (!matchingBeans.isEmpty()) {
				this.handlerMappings = new ArrayList<>(matchingBeans.values());
				// We keep HandlerMappings in sorted order.
				AnnotationAwareOrderComparator.sort(this.handlerMappings);
			}
		}
		else {
			try {
				HandlerMapping hm = context.getBean(HANDLER_MAPPING_BEAN_NAME, HandlerMapping.class);
				this.handlerMappings = Collections.singletonList(hm);
			}
			catch (NoSuchBeanDefinitionException ex) {
				// Ignore, we'll add a default HandlerMapping later.
			}
		}

		// Ensure we have at least one HandlerMapping, by registering
		// a default HandlerMapping if no other mappings are found.
		if (this.handlerMappings == null) {
			this.handlerMappings = getDefaultStrategies(context, HandlerMapping.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No HandlerMappings declared for servlet '" + getServletName() +
						"': using default strategies from DispatcherServlet.properties");
			}
		}
	}

	// 初始化 适配处理器
	private void initHandlerAdapters(ApplicationContext context) {
		this.handlerAdapters = null;

		if (this.detectAllHandlerAdapters) {
			// Find all HandlerAdapters in the ApplicationContext, including ancestor contexts.
			Map<String, HandlerAdapter> matchingBeans =
					BeanFactoryUtils.beansOfTypeIncludingAncestors(context, HandlerAdapter.class, true, false);
			if (!matchingBeans.isEmpty()) {
				this.handlerAdapters = new ArrayList<>(matchingBeans.values());
				// We keep HandlerAdapters in sorted order.
				AnnotationAwareOrderComparator.sort(this.handlerAdapters);
			}
		}
		else {
			try {
				HandlerAdapter ha = context.getBean(HANDLER_ADAPTER_BEAN_NAME, HandlerAdapter.class);
				this.handlerAdapters = Collections.singletonList(ha);
			}
			catch (NoSuchBeanDefinitionException ex) {
				// Ignore, we'll add a default HandlerAdapter later.
			}
		}

		// Ensure we have at least some HandlerAdapters, by registering
		// default HandlerAdapters if no other adapters are found.
		if (this.handlerAdapters == null) {
			this.handlerAdapters = getDefaultStrategies(context, HandlerAdapter.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No HandlerAdapters declared for servlet '" + getServletName() +
						"': using default strategies from DispatcherServlet.properties");
			}
		}
	}

	// 初始化 异常解析器
	private void initHandlerExceptionResolvers(ApplicationContext context) {
		this.handlerExceptionResolvers = null;

		if (this.detectAllHandlerExceptionResolvers) {
			// Find all HandlerExceptionResolvers in the ApplicationContext, including ancestor contexts.
			Map<String, HandlerExceptionResolver> matchingBeans = BeanFactoryUtils
					.beansOfTypeIncludingAncestors(context, HandlerExceptionResolver.class, true, false);
			if (!matchingBeans.isEmpty()) {
				this.handlerExceptionResolvers = new ArrayList<>(matchingBeans.values());
				// We keep HandlerExceptionResolvers in sorted order.
				AnnotationAwareOrderComparator.sort(this.handlerExceptionResolvers);
			}
		}
		else {
			try {
				HandlerExceptionResolver her =
						context.getBean(HANDLER_EXCEPTION_RESOLVER_BEAN_NAME, HandlerExceptionResolver.class);
				this.handlerExceptionResolvers = Collections.singletonList(her);
			}
			catch (NoSuchBeanDefinitionException ex) {
				// Ignore, no HandlerExceptionResolver is fine too.
			}
		}

		// Ensure we have at least some HandlerExceptionResolvers, by registering
		// default HandlerExceptionResolvers if no other resolvers are found.
		if (this.handlerExceptionResolvers == null) {
			this.handlerExceptionResolvers = getDefaultStrategies(context, HandlerExceptionResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No HandlerExceptionResolvers declared in servlet '" + getServletName() +
						"': using default strategies from DispatcherServlet.properties");
			}
		}
	}

	// 初始化 视图解析转换器
	private void initRequestToViewNameTranslator(ApplicationContext context) {
		try {
			this.viewNameTranslator =
					context.getBean(REQUEST_TO_VIEW_NAME_TRANSLATOR_BEAN_NAME, RequestToViewNameTranslator.class);
			if (logger.isTraceEnabled()) {
				logger.trace("Detected " + this.viewNameTranslator.getClass().getSimpleName());
			}
			else if (logger.isDebugEnabled()) {
				logger.debug("Detected " + this.viewNameTranslator);
			}
		}
		catch (NoSuchBeanDefinitionException ex) {
			// We need to use the default.
			this.viewNameTranslator = getDefaultStrategy(context, RequestToViewNameTranslator.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No RequestToViewNameTranslator '" + REQUEST_TO_VIEW_NAME_TRANSLATOR_BEAN_NAME +
						"': using default [" + this.viewNameTranslator.getClass().getSimpleName() + "]");
			}
		}
	}

	// 初始化 视图解析器
	private void initViewResolvers(ApplicationContext context) {
		this.viewResolvers = null;

		if (this.detectAllViewResolvers) {
			// Find all ViewResolvers in the ApplicationContext, including ancestor contexts.
			Map<String, ViewResolver> matchingBeans =
					BeanFactoryUtils.beansOfTypeIncludingAncestors(context, ViewResolver.class, true, false);
			if (!matchingBeans.isEmpty()) {
				this.viewResolvers = new ArrayList<>(matchingBeans.values());
				// We keep ViewResolvers in sorted order.
				AnnotationAwareOrderComparator.sort(this.viewResolvers);
			}
		}
		else {
			try {
				ViewResolver vr = context.getBean(VIEW_RESOLVER_BEAN_NAME, ViewResolver.class);
				this.viewResolvers = Collections.singletonList(vr);
			}
			catch (NoSuchBeanDefinitionException ex) {
				// Ignore, we'll add a default ViewResolver later.
			}
		}

		// Ensure we have at least one ViewResolver, by registering
		// a default ViewResolver if no other resolvers are found.
		if (this.viewResolvers == null) {
			this.viewResolvers = getDefaultStrategies(context, ViewResolver.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No ViewResolvers declared for servlet '" + getServletName() +
						"': using default strategies from DispatcherServlet.properties");
			}
		}
	}
	// 初始化 
	// FlashMap主要用于在redirect中传递参数，而FlashMapManager主要用于管理FlashMap
	private void initFlashMapManager(ApplicationContext context) {
		try {
			this.flashMapManager = context.getBean(FLASH_MAP_MANAGER_BEAN_NAME, FlashMapManager.class);
			if (logger.isTraceEnabled()) {
				logger.trace("Detected " + this.flashMapManager.getClass().getSimpleName());
			}
			else if (logger.isDebugEnabled()) {
				logger.debug("Detected " + this.flashMapManager);
			}
		}
		catch (NoSuchBeanDefinitionException ex) {
			// We need to use the default.
			this.flashMapManager = getDefaultStrategy(context, FlashMapManager.class);
			if (logger.isTraceEnabled()) {
				logger.trace("No FlashMapManager '" + FLASH_MAP_MANAGER_BEAN_NAME +
						"': using default [" + this.flashMapManager.getClass().getSimpleName() + "]");
			}
		}
	}
```


### getDefaultStrategy
	获取默认的实例
```java

	// DispatcherServlet的静态代码块会自动加载DispatcherServlet.properties的内容，用于生成缺省状态下的各类解析器
	private static final Properties defaultStrategies;

	static {
		// DEFAULT_STRATEGIES_PATH = "DispatcherServlet.properties";
		try {
			ClassPathResource resource = new ClassPathResource(DEFAULT_STRATEGIES_PATH, DispatcherServlet.class);
			defaultStrategies = PropertiesLoaderUtils.loadProperties(resource);
		}
		catch (IOException ex) {
			throw new IllegalStateException("Could not load '" + DEFAULT_STRATEGIES_PATH + "': " + ex.getMessage());
		}
	}

	// 用于生成缺省状态下的各类解析器
	protected <T> T getDefaultStrategy(ApplicationContext context, Class<T> strategyInterface) {
		List<T> strategies = getDefaultStrategies(context, strategyInterface);
		if (strategies.size() != 1) {
			throw new BeanInitializationException(
					"DispatcherServlet needs exactly 1 strategy for interface [" + strategyInterface.getName() + "]");
		}
		return strategies.get(0);
	}

	protected <T> List<T> getDefaultStrategies(ApplicationContext context, Class<T> strategyInterface) {
		String key = strategyInterface.getName();
		// 从properties文件中获取对应的值
		String value = defaultStrategies.getProperty(key);
		if (value != null) {
			// 分割字符串
			String[] classNames = StringUtils.commaDelimitedListToStringArray(value);
			List<T> strategies = new ArrayList<>(classNames.length);
			for (String className : classNames) {
				try {
					Class<?> clazz = ClassUtils.forName(className, DispatcherServlet.class.getClassLoader());
					// 创建默认的解析器
					Object strategy = createDefaultStrategy(context, clazz);
					strategies.add((T) strategy);
				}
				catch (ClassNotFoundException ex) {
					throw new BeanInitializationException(
							"Could not find DispatcherServlet's default strategy class [" + className +
							"] for interface [" + key + "]", ex);
				}
				catch (LinkageError err) {
					throw new BeanInitializationException(
							"Unresolvable class definition for DispatcherServlet's default strategy class [" +
							className + "] for interface [" + key + "]", err);
				}
			}
			return strategies;
		}
		else {
			return new LinkedList<>();
		}
	}
	// 创建 解析器bean
	protected Object createDefaultStrategy(ApplicationContext context, Class<?> clazz) {
		// 即调用 BeanFactory 生成bean
		return context.getAutowireCapableBeanFactory().createBean(clazz);
	}
```
	以上分析只是DispatcherServlet的初始化过程。那么映射关系是如何产生的呢？
### 映射关系生成
	首先默认的HanderMapping有三个：
	1. BeanNameUrlHandlerMapping ：仅仅绑定url与handler的关系，存储在handlerMap中。其创建映射关系的时机在于ApplicationContextAware的setApplicationContext方法中，业务Controller 需要实现接口 Controller
	2. RequestMappingHandlerMapping ：mappingLookup中绑定mapping与handlerMethod，urlLookup中绑定url与mapping的映射，并在registry中保存完整的映射关系信息。其创建映射关系的时机在于 InitializingBean的afterPropertiesSet方法中
	3. RouterFunctionMapping：响应式编程相关，暂不进行分析

![title](../../image/handler_mapping.png)

### DispatcherServlet执行
	DispatcherServlet实际处理接口业务逻辑流程：
	1. 检测上传文件
	2. 获取拦截器链
	3. 获取相应适配器
	4. 执行拦截器链的prehandle
	5. 执行适配器中实际的接口业务逻辑
	6. 执行视图处理
	7. 执行拦截器链的postHandle
	8. 处理异常拦截以及拦截器链的afterCompletion
	9. 最终清理上传文件缓存
```java
protected void doDispatch(HttpServletRequest request, HttpServletResponse response) throws Exception {
	HttpServletRequest processedRequest = request;
	HandlerExecutionChain mappedHandler = null;
	boolean multipartRequestParsed = false;

	WebAsyncManager asyncManager = WebAsyncUtils.getAsyncManager(request);

	try {
		ModelAndView mv = null;
		Exception dispatchException = null;

		try {
			// 检测是否有文件上传
			processedRequest = checkMultipart(request);
			multipartRequestParsed = (processedRequest != request);

			// 根据映射关系获取对应的拦截器-处理器链
			mappedHandler = getHandler(processedRequest);
			if (mappedHandler == null) {
				noHandlerFound(processedRequest, response);
				return;
			}

			// 根据所属的处理器获取相应的适配器
			HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());

			// Process last-modified header, if supported by the handler.
			String method = request.getMethod();
			boolean isGet = "GET".equals(method);
			if (isGet || "HEAD".equals(method)) {
				long lastModified = ha.getLastModified(request, mappedHandler.getHandler());
				if (new ServletWebRequest(request, response).checkNotModified(lastModified) && isGet) {
					return;
				}
			}
			// 执行拦截器preHandle
			if (!mappedHandler.applyPreHandle(processedRequest, response)) {
				return;
			}

			// 使用适配器执行实际的接口业务逻辑
			mv = ha.handle(processedRequest, response, mappedHandler.getHandler());

			if (asyncManager.isConcurrentHandlingStarted()) {
				return;
			}
			// 处理视图
			applyDefaultViewName(processedRequest, mv);
			// 执行拦截器链的postHandle
			mappedHandler.applyPostHandle(processedRequest, response, mv);
		}
		catch (Exception ex) {
			dispatchException = ex;
		}
		catch (Throwable err) {
			// As of 4.3, we're processing Errors thrown from handler methods as well,
			// making them available for @ExceptionHandler methods and other scenarios.
			dispatchException = new NestedServletException("Handler dispatch failed", err);
		}
		// 处理拦截器链的afterCompletion以及处理异常拦截
		processDispatchResult(processedRequest, response, mappedHandler, mv, dispatchException);
	}
	catch (Exception ex) {
		// 处理拦截器链的afterCompletion
		triggerAfterCompletion(processedRequest, response, mappedHandler, ex);
	}
	catch (Throwable err) {
		// 处理拦截器链的afterCompletion
		triggerAfterCompletion(processedRequest, response, mappedHandler,
				new NestedServletException("Handler processing failed", err));
	}
	finally {
		if (asyncManager.isConcurrentHandlingStarted()) {
			// Instead of postHandle and afterCompletion
			if (mappedHandler != null) {
				mappedHandler.applyAfterConcurrentHandlingStarted(processedRequest, response);
			}
		}
		else {
			// 清除上传文件的缓存
			if (multipartRequestParsed) {
				cleanupMultipart(processedRequest);
			}
		}
	}
}
```

### 拦截器
	在Spring体系中的拦截器(interceptor)有两种：
	1. HandlerInterceptor：preHandle方法返回boolean
	2. WebRequestInterceptor：preHandle方法返回void
	两者差别不大，带有boolean值的preHandle方法在mvc的请求职责链中可以过滤不符合要求的请求。
	但是最终要被Spring加载还是需要代理类 MappedInterceptor ，因为我们的拦截器需要进行配置拦截哪些请求，所以Spring默认只加载MappedInterceptor，当然也可以绕过限制，直接使用interceptor，此时会拦截所有请求
	无论在xml配置时代，还是java类配置时代，默认的实现都是创建代理类 MappedInterceptor。

#### 拦截器初始化
	初始化时机:在于HandlerMapping类实现的ApplicationContextAware接口中，最终的模板方法在AbstractHandlerMapping.initApplicationContext()中。
**ApplicationObjectSupport**
```java
	public final void setApplicationContext(@Nullable ApplicationContext context) throws BeansException {
		if (context == null && !isContextRequired()) {
			// Reset internal context state.
			this.applicationContext = null;
			this.messageSourceAccessor = null;
		}
		else if (this.applicationContext == null) {
			// Initialize with passed-in context.
			if (!requiredContextClass().isInstance(context)) {
				throw new ApplicationContextException(
						"Invalid application context: needs to be of type [" + requiredContextClass().getName() + "]");
			}
			this.applicationContext = context;
			this.messageSourceAccessor = new MessageSourceAccessor(context);
			// 此处由子类拓展
			initApplicationContext(context);
		}
		else {
			// Ignore reinitialization if same context passed in.
			if (this.applicationContext != context) {
				throw new ApplicationContextException(
						"Cannot reinitialize with different application context: current one is [" +
						this.applicationContext + "], passed-in one is [" + context + "]");
			}
		}
	}
```
	子类WebApplicationObjectSupport拓展了initApplicationContext方法
**WebApplicationObjectSupport**
```java
	protected void initApplicationContext(ApplicationContext context) {
		// 主要初始化逻辑在此
		super.initApplicationContext(context);
		if (this.servletContext == null && context instanceof WebApplicationContext) {
			this.servletContext = ((WebApplicationContext) context).getServletContext();
			if (this.servletContext != null) {
				initServletContext(this.servletContext);
			}
		}
	}
```
**ApplicationObjectSupport**
```java
protected void initApplicationContext(ApplicationContext context) throws BeansException {
	initApplicationContext();
}
```
**AbstractHandlerMapping**
```java
protected void initApplicationContext() throws BeansException {
	// 暂无实现
	extendInterceptors(this.interceptors);
	// 获取spring容器中的MappedInterceptor
	detectMappedInterceptors(this.adaptedInterceptors);
	// 将其他途径创建的interceptor添加到adaptedInterceptors中
	initInterceptors();
}
```
#### 拦截器链创建
	拦截器链是在DispatcherServlet获取handle时创建
```java
protected HandlerExecutionChain getHandler(HttpServletRequest request) throws Exception {
	if (this.handlerMappings != null) {
		// 将所有的映射器查询一遍
		for (HandlerMapping mapping : this.handlerMappings) {
			HandlerExecutionChain handler = mapping.getHandler(request);
			if (handler != null) {
				return handler;
			}
		}
	}
	return null;
}
```
	AbstractHandlerMapping的模板方法getHandler
```java
public final HandlerExecutionChain getHandler(HttpServletRequest request) throws Exception {
	// 在映射器中获取相应的接口处理器，即初始化时扫描Controller时生成的
	// 此处由子类拓展，根据不同的映射器获取接口的处理方法
	Object handler = getHandlerInternal(request);
	if (handler == null) {
		handler = getDefaultHandler();
	}
	if (handler == null) {
		return null;
	}
	// 如果获取的handler是String，则可能是bean的name或alias，直接去BeanFactory中获取
	if (handler instanceof String) {
		String handlerName = (String) handler;
		handler = obtainApplicationContext().getBean(handlerName);
	}

	// Ensure presence of cached lookupPath for interceptors and others
	if (!ServletRequestPathUtils.hasCachedPath(request)) {
		initLookupPath(request);
	}
	// 创建拦截器链，并从adaptedInterceptors中获取相应的拦截器添加到拦截器链中
	HandlerExecutionChain executionChain = getHandlerExecutionChain(handler, request);

	if (logger.isTraceEnabled()) {
		logger.trace("Mapped to " + handler);
	}
	else if (logger.isDebugEnabled() && !DispatcherType.ASYNC.equals(request.getDispatcherType())) {
		logger.debug("Mapped to " + executionChain.getHandler());
	}
	// 判断是否为cors跨域配置或者是预置OPTIONS请求即PreFlight请求
	if (hasCorsConfigurationSource(handler) || CorsUtils.isPreFlightRequest(request)) {
		CorsConfiguration config = getCorsConfiguration(handler, request);
		if (getCorsConfigurationSource() != null) {
			CorsConfiguration globalConfig = getCorsConfigurationSource().getCorsConfiguration(request);
			config = (globalConfig != null ? globalConfig.combine(config) : config);
		}
		if (config != null) {
			config.validateAllowCredentials();
		}
		// 此时将跨域处理器放到请求流程中处理
		executionChain = getCorsHandlerExecutionChain(request, executionChain, config);
	}

	return executionChain;
}
```

### Handler适配器
	适配器主要用于处理不同类型的业务接口Controller，HandlerAdapter默认实现有四个：
	1. HttpRequestHandlerAdapter ：主要用于支持HttpRequestHandler接口的子类业务Controller
	2. SimpleControllerHandlerAdapter ：主要用于支持Controller接口的子类业务Controller
	3. RequestMappingHandlerAdapter ：用于处理寻常的Controller的方法(HandlerMethod)
	4. HandlerFunctionAdapter ：主要用于处理响应式接口
	这里主要介绍下 RequestMappingHandlerAdapter ，该适配器是我们最常使用的，包含了@InitBinder，@ModelAttribute，@ControllerAdvice，入参解析，异步执行。等等逻辑。

#### 适配器初始化
![title](../../image/RequestMappingHandlerAdapter.png)
	如上图所示， RequestMappingHandlerAdapter 实现接口 InitializingBean ：afterPropertiesSet方法会初始化ControllerAdvice，参数解析器，initBinder解析器，返回值处理器，等等非常重要的步骤
```java
public void afterPropertiesSet() {
	// Do this first, it may add ResponseBody advice beans
	// @ControllerAdvice：表示全局(当然可配置注解参数)处理：此时会初始化全局 @InitBinder，@ModelAttribute处理
	initControllerAdviceCache();
	// 设置参数解析器
	if (this.argumentResolvers == null) {
		List<HandlerMethodArgumentResolver> resolvers = getDefaultArgumentResolvers();
		this.argumentResolvers = new HandlerMethodArgumentResolverComposite().addResolvers(resolvers);
	}
	// 设置@InitBinder解析器
	if (this.initBinderArgumentResolvers == null) {
		List<HandlerMethodArgumentResolver> resolvers = getDefaultInitBinderArgumentResolvers();
		this.initBinderArgumentResolvers = new HandlerMethodArgumentResolverComposite().addResolvers(resolvers);
	}
	// 设置返回值处理器
	if (this.returnValueHandlers == null) {
		List<HandlerMethodReturnValueHandler> handlers = getDefaultReturnValueHandlers();
		this.returnValueHandlers = new HandlerMethodReturnValueHandlerComposite().addHandlers(handlers);
	}
}
```
#### 适配器执行
	RequestMappingHandlerAdapter 在执行业务Controller的HandlerMehtod
```java
protected ModelAndView invokeHandlerMethod(HttpServletRequest request,
		HttpServletResponse response, HandlerMethod handlerMethod) throws Exception {
	// 包装request，response
	ServletWebRequest webRequest = new ServletWebRequest(request, response);
	try {
		// 获取@ControllerAdvice的全局@InitBinder处理
		WebDataBinderFactory binderFactory = getDataBinderFactory(handlerMethod);
		// 获取@ControllerAdvice的全局@ModelAttribute处理
		ModelFactory modelFactory = getModelFactory(handlerMethod, binderFactory);
		// 创建代理类 ServletInvocableHandlerMethod
		ServletInvocableHandlerMethod invocableMethod = createInvocableHandlerMethod(handlerMethod);
		// 设置参数解析器，即在RequestMappingHandlerAdapter.afterPropertiesSet时添加的
		if (this.argumentResolvers != null) {
			invocableMethod.setHandlerMethodArgumentResolvers(this.argumentResolvers);
		}
		// 设置返回值处理器，即在RequestMappingHandlerAdapter.afterPropertiesSet时添加的
		if (this.returnValueHandlers != null) {
			invocableMethod.setHandlerMethodReturnValueHandlers(this.returnValueHandlers);
		}
		invocableMethod.setDataBinderFactory(binderFactory);
		// 设置查询参数名称工具类
		invocableMethod.setParameterNameDiscoverer(this.parameterNameDiscoverer);
		// 创建视图容器
		ModelAndViewContainer mavContainer = new ModelAndViewContainer();
		mavContainer.addAllAttributes(RequestContextUtils.getInputFlashMap(request));
		// 执行@ModelAttribute处理
		modelFactory.initModel(webRequest, mavContainer, invocableMethod);
		mavContainer.setIgnoreDefaultModelOnRedirect(this.ignoreDefaultModelOnRedirect);
		// 异步执行
		AsyncWebRequest asyncWebRequest = WebAsyncUtils.createAsyncWebRequest(request, response);
		asyncWebRequest.setTimeout(this.asyncRequestTimeout);

		WebAsyncManager asyncManager = WebAsyncUtils.getAsyncManager(request);
		asyncManager.setTaskExecutor(this.taskExecutor);
		asyncManager.setAsyncWebRequest(asyncWebRequest);
		asyncManager.registerCallableInterceptors(this.callableInterceptors);
		asyncManager.registerDeferredResultInterceptors(this.deferredResultInterceptors);
		// 判断异步执行结果
		if (asyncManager.hasConcurrentResult()) {
			Object result = asyncManager.getConcurrentResult();
			mavContainer = (ModelAndViewContainer) asyncManager.getConcurrentResultContext()[0];
			asyncManager.clearConcurrentResult();
			LogFormatUtils.traceDebug(logger, traceOn -> {
				String formatted = LogFormatUtils.formatValue(result, !traceOn);
				return "Resume with async result [" + formatted + "]";
			});
			invocableMethod = invocableMethod.wrapConcurrentResult(result);
		}
		// 执行具体业务方法
		// ps一个小知识：BridgeMethod是用来处理泛型方法
		invocableMethod.invokeAndHandle(webRequest, mavContainer);
		if (asyncManager.isConcurrentHandlingStarted()) {
			return null;
		}
		// 获取最终的视图
		return getModelAndView(mavContainer, modelFactory, webRequest);
	}
	finally {
		// 执行所有请求销毁回调，并更新请求处理过程中访问的会话属性。
		webRequest.requestCompleted();
	}
}

```

### 异常拦截器
	ExceptionHandlerExceptionResolver的初始化方法在实现的接口InitializingBean.afterPropertiesSet

```java
public void afterPropertiesSet() {
	// Do this first, it may add ResponseBodyAdvice beans
	initExceptionHandlerAdviceCache();

	if (this.argumentResolvers == null) {
		List<HandlerMethodArgumentResolver> resolvers = getDefaultArgumentResolvers();
		this.argumentResolvers = new HandlerMethodArgumentResolverComposite().addResolvers(resolvers);
	}
	if (this.returnValueHandlers == null) {
		List<HandlerMethodReturnValueHandler> handlers = getDefaultReturnValueHandlers();
		this.returnValueHandlers = new HandlerMethodReturnValueHandlerComposite().addHandlers(handlers);
	}
}

private void initExceptionHandlerAdviceCache() {
	if (getApplicationContext() == null) {
		return;
	}

	List<ControllerAdviceBean> adviceBeans = ControllerAdviceBean.findAnnotatedBeans(getApplicationContext());
	for (ControllerAdviceBean adviceBean : adviceBeans) {
		Class<?> beanType = adviceBean.getBeanType();
		if (beanType == null) {
			throw new IllegalStateException("Unresolvable type for ControllerAdviceBean: " + adviceBean);
		}
		ExceptionHandlerMethodResolver resolver = new ExceptionHandlerMethodResolver(beanType);
		if (resolver.hasExceptionMappings()) {
			this.exceptionHandlerAdviceCache.put(adviceBean, resolver);
		}
		if (ResponseBodyAdvice.class.isAssignableFrom(beanType)) {
			this.responseBodyAdvice.add(adviceBean);
		}
	}

	if (logger.isDebugEnabled()) {
		int handlerSize = this.exceptionHandlerAdviceCache.size();
		int adviceSize = this.responseBodyAdvice.size();
		if (handlerSize == 0 && adviceSize == 0) {
			logger.debug("ControllerAdvice beans: none");
		}
		else {
			logger.debug("ControllerAdvice beans: " +
					handlerSize + " @ExceptionHandler, " + adviceSize + " ResponseBodyAdvice");
		}
	}
}
```