# ApplicationContext
基于xml配置文件：ClassPathXmlApplicationContext
基于注解：AnnotationConfigApplicationContext
## AbstractApplicationContext
### method:refresh()  

该方法用于启动spring  

```java
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

### method:prepareRefresh()  

该方法用于设置启动标志位。并初始化属性源，校验必须的属性
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
		initPropertySources();

		// Validate that all properties marked as required are resolvable:
		// see ConfigurablePropertyResolver#setRequiredProperties
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
		this.earlyApplicationEvents = new LinkedHashSet<>();
	}
```

### method:obtainFreshBeanFactory()
该方法用于创建BeanFactory，且分为两部分
1. refreshBeanFactory()，
AbstractRefreshableApplicationContext的该方法方式：判断是否存在BeanFactory，若存在则删除并关闭
2. getBeanFactory()


### finishBeanFactoryInitialization解析
1. 判断是否存在ConversionService类，如果存在，则进行实例化。该类主要用于解析转换数据，用于getBean后的类型转换，用于MVC中的controller解析绑定参数
2. 判断是否建立嵌入式参数解析器（例如：PropertyPlaceholderConfigurer）
3. 初始化LoadTimeWeaverAware，一般用于织入第三方的类，在 class 文件载入 JVM 的时候动态织入（暂未理解）
4. freezeConfiguration：用于暂停bean的解析，加载，注册操作
5. 进入single bean的创建流程
``` java
protected void finishBeanFactoryInitialization(ConfigurableListableBeanFactory beanFactory) {
	// Initialize conversion service for this context.
	// 判断是否存在ConversionService类，如果存在，则进行实例化。该类主要用于解析转换数据，用于getBean后的类型转换。用于MVC中的controller解析绑定参数（暂未确定）
	if (beanFactory.containsBean(CONVERSION_SERVICE_BEAN_NAME) &&
			beanFactory.isTypeMatch(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class)) {
		beanFactory.setConversionService(
				beanFactory.getBean(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class));
	}

	// Register a default embedded value resolver if no bean post-processor
	// (such as a PropertyPlaceholderConfigurer bean) registered any before:
	// at this point, primarily for resolution in annotation attribute values.
	// 判断是否建立嵌入式参数解析器（例如：PropertyPlaceholderConfigurer）
	if (!beanFactory.hasEmbeddedValueResolver()) {
		beanFactory.addEmbeddedValueResolver(strVal -> getEnvironment().resolvePlaceholders(strVal));
	}
	// 初始化LoadTimeWeaverAware，一般用于织入第三方的类，在 class 文件载入 JVM 的时候动态织入（暂未理解）
	// Initialize LoadTimeWeaverAware beans early to allow for registering their transformers early.
	String[] weaverAwareNames = beanFactory.getBeanNamesForType(LoadTimeWeaverAware.class, false, false);
	for (String weaverAwareName : weaverAwareNames) {
		getBean(weaverAwareName);
	}

	// Stop using the temporary ClassLoader for type matching.
	beanFactory.setTempClassLoader(null);

	// freezeConfiguration：用于暂停bean的解析，加载，注册操作
	// Allow for caching all bean definition metadata, not expecting further changes.
	beanFactory.freezeConfiguration();
	// 进入single bean的创建流程
	// Instantiate all remaining (non-lazy-init) singletons.
	beanFactory.preInstantiateSingletons();
}
``` 
### preInstantiateSingletons解析  
**finishBeanFactoryInitialization-preInstantiateSingletons解析**
注：abstract属性表示该bean不需要进行实例化  
注：FactoryBean表示该bean实例化是由开发者自己实现
1. getMergedLocalBeanDefinition(); 此处代码适用于合并BeanDefinition，由于spring有继承机制，该继承只表示继承属性值，不代表java语义中的继承。xml配置中可设置parent属性，此时子bean可获取parent bean的属性配置值，所以这里是进行合并BeanDefinition，将父bean中的属性配置复制到子bean，并封装到RootBeanDefinition中。
2. 判断该bean是否非抽象，并且是单例，不需要延时加载，此时进行bean的初始化。
3. 判断该bean是否为FactoryBean（FactoryBean则意味着实际需要的bean需要由该FactoryBean进行创建，即其接口方法getObject），如果为FactoryBean则需要getBean两次，第一次获取FactoryBean，第二次获取beanName对应实际的bean。如果不是FactoryBean，则直接获取bean。
4. 如果该bean实现了接口SmartInitializingSingleton，则执行初始化后的用户实现方法afterSingletafonsInstantiated。

``` java
public void preInstantiateSingletons() throws BeansException {
	if (logger.isTraceEnabled()) {
		logger.trace("Pre-instantiating singletons in " + this);
	}

	// Iterate over a copy to allow for init methods which in turn register new bean definitions.
	// While this may not be part of the regular factory bootstrap, it does otherwise work fine.
	List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

	// Trigger initialization of all non-lazy singleton beans...
	for (String beanName : beanNames) {
		// 此处代码适用于合并BeanDefinition，由于spring有继承机制，该继承只表示继承属性值，不代表java语义中的继承。xml配置中可设置parent属性，此时子bean可获取parent bean的属性配置值，所以这里是进行合并BeanDefinition，将父bean中的属性配置复制到子bean，并封装到RootBeanDefinition中。
		RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
		// 判断该bean是否非抽象，并且是单例，不需要延时加载，此时进行bean的初始化。
		if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
			// 判断该bean是否为FactoryBean（FactoryBean则意味着实际需要的bean需要由该FactoryBean进行创建，即其接口方法getObject），如果为FactoryBean则需要getBean两次，第一次获取FactoryBean，第二次获取beanName对应实际的bean。如果不是FactoryBean，则直接获取bean。
			if (isFactoryBean(beanName)) {
				// 第一次获取的是FactoryBean实例，FACTORY_BEAN_PREFIX="&"
				Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
				if (bean instanceof FactoryBean) {
					final FactoryBean<?> factory = (FactoryBean<?>) bean;
					boolean isEagerInit;
					if (System.getSecurityManager() != null && factory instanceof SmartFactoryBean) {
						isEagerInit = AccessController.doPrivileged((PrivilegedAction<Boolean>)
										((SmartFactoryBean<?>) factory)::isEagerInit,
								getAccessControlContext());
					}
					else {
						isEagerInit = (factory instanceof SmartFactoryBean &&
								((SmartFactoryBean<?>) factory).isEagerInit());
					}
					if (isEagerInit) {
						// 此时才是获取的实际需要的bean
						getBean(beanName);
					}
				}
			}
			else {
				// 如果是普通bean，直接获取
				getBean(beanName);
			}
		}
	}
	// 如果该bean实现了接口SmartInitializingSingleton，则执行初始化后的用户实现方法afterSingletafonsInstantiated。
	// Trigger post-initialization callback for all applicable beans...
	for (String beanName : beanNames) {
		Object singletonInstance = getSingleton(beanName);
		if (singletonInstance instanceof SmartInitializingSingleton) {
			final SmartInitializingSingleton smartSingleton = (SmartInitializingSingleton) singletonInstance;
			if (System.getSecurityManager() != null) {
				AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
					smartSingleton.afterSingletonsInstantiated();
					return null;
				}, getAccessControlContext());
			}
			else {
				smartSingleton.afterSingletafonsInstantiated();
			}
		}
	}
}
```

### getBean解析
**finishBeanFactoryInitialization-preInstantiateSingletons-getBean解析**

***prototypesCurrentlyInCreation：***

1. transformedBeanName解析factoryBean的&，并找到beanName的唯一标识名称
2. getSingleton获取已初始化的bean，如果sharedInstance不为空，而args参数为空，则标识获取
3. 如果未初始化，则进行初始化流程。
4. 如果当前BeanFactory中未找到BeanDefinition，且存在父级BeanFactory，则取父级中取bean
5. 如果不是只检测类型，markBeanAsCreated标识bean正在被创建，alreadyCreated中添加该beanName
6. 获取RootBeanDefinition，并进行判断是否要初始化。
7. 获取该bean依赖的对象集合，逐一判断是否存在循环依赖的问题，如果不存在循环依赖，则初始化依赖对象。
8. 根据不同的scope创建bean。当前只关注singleton对象。在getSingleton后获取，再调用getObjectForBeanInstance，是为了判断是否是FactoryBean需要生成的对象。
9. 判断是否要进行类型转换，如果要，则会使用之前配置的ConversionService来进行类型转换。
```java
public Object getBean(String name) throws BeansException {
	return doGetBean(name, null, null, false);
}

protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
		@Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {
	// transformedBeanName解析factoryBean的&，并找到beanName的唯一标识名称
	final String beanName = transformedBeanName(name);
	Object bean;
	// getSingleton获取已初始化的bean，如果sharedInstance不为空，而args参数为空，则标志着已经创建完成
	// Eagerly check singleton cache for manually registered singletons.
	Object sharedInstance = getSingleton(beanName);
	if (sharedInstance != null && args == null) {
		if (logger.isTraceEnabled()) {
			if (isSingletonCurrentlyInCreation(beanName)) {
				logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
						"' that is not fully initialized yet - a consequence of a circular reference");
			}
			else {
				logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
			}
		}
		bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
	}

	else {
		// 判断是否正在创建，如果正在创建，则抛出异常
		// Fail if we're already creating this bean instance:
		// We're assumably within a circular reference.
		if (isPrototypeCurrentlyInCreation(beanName)) {
			throw new BeanCurrentlyInCreationException(beanName);
		}
		// 如果当前BeanFactory不包含该Bean的定义，则交由父级BeanFactory实例化
		// Check if bean definition exists in this factory.
		BeanFactory parentBeanFactory = getParentBeanFactory();
		if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
			// Not found -> check parent.
			String nameToLookup = originalBeanName(name);
			if (parentBeanFactory instanceof AbstractBeanFactory) {
				return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
						nameToLookup, requiredType, args, typeCheckOnly);
			}
			else if (args != null) {
				// Delegation to parent with explicit args.
				return (T) parentBeanFactory.getBean(nameToLookup, args);
			}
			else if (requiredType != null) {
				// No args -> delegate to standard getBean method.
				return parentBeanFactory.getBean(nameToLookup, requiredType);
			}
			else {
				return (T) parentBeanFactory.getBean(nameToLookup);
			}
		}
		// 如果不是只检测类型，则需要标志该Bean已经创建，在alreadyCreated中add
		if (!typeCheckOnly) {
			markBeanAsCreated(beanName);
		}

		try {
			// 获取已合并的BeanDefinition
			final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
			// 再次检测bean是否可实例化，即判断abstract属性
			checkMergedBeanDefinition(mbd, beanName, args);
			// 检测循环依赖问题
			// Guarantee initialization of beans that the current bean depends on.
			String[] dependsOn = mbd.getDependsOn();
			if (dependsOn != null) {
				for (String dep : dependsOn) {
					// 判断是否构成循环依赖，如果是则抛出异常
					if (isDependent(beanName, dep)) {
						throw new BeanCreationException(mbd.getResourceDescription(), beanName,
								"Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
					}
					// 如果不构成，则添加到dependentBeanMap中，以便后续判断是否存在循环依赖
					registerDependentBean(dep, beanName);
					try {
						// 初始化依赖的bean
						getBean(dep);
					}
					catch (NoSuchBeanDefinitionException ex) {
						throw new BeanCreationException(mbd.getResourceDescription(), beanName,
								"'" + beanName + "' depends on missing bean '" + dep + "'", ex);
					}
				}
			}
			// 此时，代表依赖项已全部加载，可执行bean的后续流程
			// Create bean instance.
			if (mbd.isSingleton()) {
				// sigleton创建
				sharedInstance = getSingleton(beanName, () -> {
					try {
						// 主要的创建过程
						return createBean(beanName, mbd, args);
					}
					catch (BeansException ex) {
						// Explicitly remove instance from singleton cache: It might have been put there
						// eagerly by the creation process, to allow for circular reference resolution.
						// Also remove any beans that received a temporary reference to the bean.
						destroySingleton(beanName);
						throw ex;
					}
				});
				bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
			}

			else if (mbd.isPrototype()) {
				// prototype实例创建，prototype是每次获取时都重新创建
				// It's a prototype -> create a new instance.
				Object prototypeInstance = null;
				try {
					beforePrototypeCreation(beanName);
					prototypeInstance = createBean(beanName, mbd, args);
				}
				finally {
					afterPrototypeCreation(beanName);
				}
				bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
			}

			else {
				// 如果是非singleton，prototype的作用域，则交由对应的Scope，在需要的时候执行创建过程
				// Session，Request
				String scopeName = mbd.getScope();
				final Scope scope = this.scopes.get(scopeName);
				if (scope == null) {
					throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
				}
				try {
					Object scopedInstance = scope.get(beanName, () -> {
						beforePrototypeCreation(beanName);
						try {
							return createBean(beanName, mbd, args);
						}
						finally {
							afterPrototypeCreation(beanName);
						}
					});
					bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
				}
				catch (IllegalStateException ex) {
					throw new BeanCreationException(beanName,
							"Scope '" + scopeName + "' is not active for the current thread; consider " +
							"defining a scoped proxy for this bean if you intend to refer to it from a singleton",
							ex);
				}
			}
		}
		catch (BeansException ex) {
			cleanupAfterBeanCreationFailure(beanName);
			throw ex;
		}
	}
	// 如果创建的bean的类型与参数requiredType不一致，则需要进行类型转换，此时用的是ConversionService，即之前说的转换器
	// Check if required type matches the type of the actual bean instance.
	if (requiredType != null && !requiredType.isInstance(bean)) {
		try {
			T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
			if (convertedBean == null) {
				throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
			}
			return convertedBean;
		}
		catch (TypeMismatchException ex) {
			if (logger.isTraceEnabled()) {
				logger.trace("Failed to convert bean '" + name + "' to required type '" +
						ClassUtils.getQualifiedName(requiredType) + "'", ex);
			}
			throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
		}
	}
	return (T) bean;
}
```

### getSingleton解析
***singletonObjects：单例bean注册到map中beanName作为key***
***singletonFactories***
***earlySingletonObjects***
***registeredSingletons***
***inCreationCheckExclusions***
***singletonsCurrentlyInCreation***
1. 锁住singletonObjects，然后再设置标志位beforeSingletonCreation
2. 调用singletonFactory创建bean
3. afterSingletonCreation最后解除标志位
4. 如果是新创建的单例bean，则需要添加到singletonObjects，registeredSingletons中
```java
	public Object getSingleton(String beanName, ObjectFactory<?> singletonFactory) {
		Assert.notNull(beanName, "Bean name must not be null");
		// 锁住singletonObjects，然后再设置标志位beforeSingletonCreation，防止并发导致异常
		synchronized (this.singletonObjects) {
			Object singletonObject = this.singletonObjects.get(beanName);
			if (singletonObject == null) {
				if (this.singletonsCurrentlyInDestruction) {
					throw new BeanCreationNotAllowedException(beanName,
							"Singleton bean creation not allowed while singletons of this factory are in destruction " +
							"(Do not request a bean from a BeanFactory in a destroy method implementation!)");
				}
				if (logger.isDebugEnabled()) {
					logger.debug("Creating shared instance of singleton bean '" + beanName + "'");
				}
				// 判断是否在inCreationCheckExclusions中存在，添加到singletonsCurrentlyInCreation中，防止过滤的bean创建 或者 重复创建
				beforeSingletonCreation(beanName);
				boolean newSingleton = false;
				boolean recordSuppressedExceptions = (this.suppressedExceptions == null);
				if (recordSuppressedExceptions) {
					this.suppressedExceptions = new LinkedHashSet<>();
				}
				try {
					// 调用singletonFactory创建bean，即上面代码中的createBean方法
					singletonObject = singletonFactory.getObject();
					newSingleton = true;
				}
				catch (IllegalStateException ex) {
					// Has the singleton object implicitly appeared in the meantime ->
					// if yes, proceed with it since the exception indicates that state.
					singletonObject = this.singletonObjects.get(beanName);
					if (singletonObject == null) {
						throw ex;
					}
				}
				catch (BeanCreationException ex) {
					if (recordSuppressedExceptions) {
						for (Exception suppressedException : this.suppressedExceptions) {
							ex.addRelatedCause(suppressedException);
						}
					}
					throw ex;
				}
				finally {
					if (recordSuppressedExceptions) {
						this.suppressedExceptions = null;
					}
					// 再次判断inCreationCheckExclusions，从singletonsCurrentlyInCreation中移除，如果不满足，则表示可能存在重复创建单例
					afterSingletonCreation(beanName);
				}
				if (newSingleton) {
					// 创建完成后添加到singletonObjects,registeredSingletons缓存中，并从二三级缓存中移除
					addSingleton(beanName, singletonObject);
				}
			}
			return singletonObject;
		}
	}

```

### getObjectForBeanInstance解析
这个方法分两层，主要应对的就是FactoryBean。
1. 判断name是否为FactoryBean的引用，是的话直接返回对象。
2. 如果name不是FactoryBean，而beanInstance是FactoryBean，则表示要用beanInstance获取对应的bean
```java
	protected Object getObjectForBeanInstance(
			Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd) {
		// 由name判断是否是FactoryBean
		// Don't let calling code try to dereference the factory if the bean isn't a factory.
		if (BeanFactoryUtils.isFactoryDereference(name)) {
			if (beanInstance instanceof NullBean) {
				return beanInstance;
			}
			if (!(beanInstance instanceof FactoryBean)) {
				throw new BeanIsNotAFactoryException(beanName, beanInstance.getClass());
			}
			if (mbd != null) {
				mbd.isFactoryBean = true;
			}
			// 如果是FactoryBean，则直接返回，等待第二次getBean的时候再执行后续的流程获取实际的实例
			return beanInstance;
		}
		// 此时表示为普通bean，则直接返回
		// Now we have the bean instance, which may be a normal bean or a FactoryBean.
		// If it's a FactoryBean, we use it to create a bean instance, unless the
		// caller actually wants a reference to the factory.
		if (!(beanInstance instanceof FactoryBean)) {
			return beanInstance;
		}
		// 如果不是FactoryBean的引用，但是beanInstance又继承于FactoryBean，则表示是第二次getBean获取实际实例
		Object object = null;
		if (mbd != null) {
			mbd.isFactoryBean = true;
		}
		else {
			object = getCachedObjectForFactoryBean(beanName);
		}
		if (object == null) {
			// Return bean instance from factory.
			FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
			// Caches object obtained from FactoryBean if it is a singleton.
			if (mbd == null && containsBeanDefinition(beanName)) {
				mbd = getMergedLocalBeanDefinition(beanName);
			}
			// 此处可能兼容了其他逻辑，暂时未涉及，所以不作过多讨论
			boolean synthetic = (mbd != null && mbd.isSynthetic());
			// 从之前创建的FactoryBean中获取实际bean
			object = getObjectFromFactoryBean(factory, beanName, !synthetic);
		}
		return object;
	}
```