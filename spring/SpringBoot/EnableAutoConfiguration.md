# EnableAutoConfiguration

`@EnableAutoConfiguration` 是 Spring Boot 中一个非常重要的注解，它主要用于自动配置 Spring 应用上下文。这个注解通过启用 Spring Boot 的自动配置功能，帮助开发者在项目启动时自动配置所需的 Spring Bean。理解 `@EnableAutoConfiguration` 的源码对于更深入地理解 Spring Boot 自动配置机制非常有帮助。

- `@EnableAutoConfiguration` 注解的核心作用是启用 Spring Boot 的自动配置机制，它通过 `@Import` 引入 `AutoConfigurationImportSelector` 类。
- `AutoConfigurationImportSelector` 类负责根据一定的条件从 `spring.factories` 文件中选择自动配置类。
- Spring Boot 的自动配置类使用了大量的条件注解（如 `@ConditionalOnClass`、`@ConditionalOnMissingBean` 等），使得配置是动态和条件化的，能够根据具体的环境和类路径自动配置应用程序。
- 这种自动配置机制极大地简化了开发人员的配置工作，使得 Spring Boot 应用程序能够在很少的手动配置下运行。

## 一、注解定义

`@EnableAutoConfiguration`相当于`import`了类`AutoConfigurationImportSelector`，并通过注解`@AutoConfigurationPackage`，`import`了类`AutoConfigurationPackages.Registrar`

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class)
public @interface EnableAutoConfiguration {

	/**
	 * Environment property that can be used to override when auto-configuration is
	 * enabled.
	 */
	String ENABLED_OVERRIDE_PROPERTY = "spring.boot.enableautoconfiguration";

	/**
	 * Exclude specific auto-configuration classes such that they will never be applied.
	 * @return the classes to exclude
	 */
	Class<?>[] exclude() default {};

	/**
	 * Exclude specific auto-configuration class names such that they will never be
	 * applied.
	 * @return the class names to exclude
	 * @since 1.3.0
	 */
	String[] excludeName() default {};

}

@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@Import(AutoConfigurationPackages.Registrar.class)
public @interface AutoConfigurationPackage {

	/**
	 * Base packages that should be registered with {@link AutoConfigurationPackages}.
	 * <p>
	 * Use {@link #basePackageClasses} for a type-safe alternative to String-based package
	 * names.
	 * @return the back package names
	 * @since 2.3.0
	 */
	String[] basePackages() default {};

	/**
	 * Type-safe alternative to {@link #basePackages} for specifying the packages to be
	 * registered with {@link AutoConfigurationPackages}.
	 * <p>
	 * Consider creating a special no-op marker class or interface in each package that
	 * serves no purpose other than being referenced by this attribute.
	 * @return the base package classes
	 * @since 2.3.0
	 */
	Class<?>[] basePackageClasses() default {};

}

```

## 二、`AutoConfigurationImportSelector`


### 2.1 基本信息

我们需要注意到`AutoConfigurationImportSelector`是实现了接口`DeferredImportSelector`，这意味着`AutoConfigurationImportSelector`采用的是延迟Import的方式来加载自动配置类的`BeanDefinition`

```java
public class AutoConfigurationImportSelector implements DeferredImportSelector, BeanClassLoaderAware,
		ResourceLoaderAware, BeanFactoryAware, EnvironmentAware, Ordered
```

### 2.2 延迟Import

1. 关于延迟Import，我们需要注意到之前`ConfigurationClassPostProcessor.md`文档中`ConfigurationClassParser.processImports`方法处理
2. `DeferredImportSelectorHandler`类的`handle`方法，将`importSelector`使用`DeferredImportSelectorHolder`封装起来，放入`deferredImportSelectors`中
```java
// ConfigurationClassParser.processImports的部分代码逻辑，
if (candidate.isAssignable(ImportSelector.class)) {
	// Candidate class is an ImportSelector -> delegate to it to determine imports
	Class<?> candidateClass = candidate.loadClass();
	ImportSelector selector = ParserStrategyUtils.instantiateClass(candidateClass, ImportSelector.class,
			this.environment, this.resourceLoader, this.registry);
	Predicate<String> selectorFilter = selector.getExclusionFilter();
	if (selectorFilter != null) {
		exclusionFilter = exclusionFilter.or(selectorFilter);
	}
	if (selector instanceof DeferredImportSelector) {
		// 这里处理延迟Import逻辑
		this.deferredImportSelectorHandler.handle(configClass, (DeferredImportSelector) selector);
	}
	else {
		String[] importClassNames = selector.selectImports(currentSourceClass.getMetadata());
		Collection<SourceClass> importSourceClasses = asSourceClasses(importClassNames, exclusionFilter);
		processImports(configClass, currentSourceClass, importSourceClasses, exclusionFilter, false);
	}
}

private class DeferredImportSelectorHandler {

	@Nullable
	private List<DeferredImportSelectorHolder> deferredImportSelectors = new ArrayList<>();

	/**
	 * Handle the specified {@link DeferredImportSelector}. If deferred import
	 * selectors are being collected, this registers this instance to the list. If
	 * they are being processed, the {@link DeferredImportSelector} is also processed
	 * immediately according to its {@link DeferredImportSelector.Group}.
	 * @param configClass the source configuration class
	 * @param importSelector the selector to handle
	 */
	// DeferredImportSelectorHandler类的handle方法，将importSelector使用DeferredImportSelectorHolder封装起来，放入deferredImportSelectors中
	public void handle(ConfigurationClass configClass, DeferredImportSelector importSelector) {
		DeferredImportSelectorHolder holder = new DeferredImportSelectorHolder(configClass, importSelector);
		if (this.deferredImportSelectors == null) {
			DeferredImportSelectorGroupingHandler handler = new DeferredImportSelectorGroupingHandler();
			handler.register(holder);
			handler.processGroupImports();
		}
		else {
			this.deferredImportSelectors.add(holder);
		}
	}

	public void process() {
		List<DeferredImportSelectorHolder> deferredImports = this.deferredImportSelectors;
		this.deferredImportSelectors = null;
		try {
			if (deferredImports != null) {
				DeferredImportSelectorGroupingHandler handler = new DeferredImportSelectorGroupingHandler();
				deferredImports.sort(DEFERRED_IMPORT_COMPARATOR);
				deferredImports.forEach(handler::register);
				handler.processGroupImports();
			}
		}
		finally {
			this.deferredImportSelectors = new ArrayList<>();
		}
	}
}
```
3. 我们需要把目光投向配置类解析的前奏：`ConfigurationClassParser`类的`parse`方法解析配置类，我们可以看到在方法的末尾处理，会使用`deferredImportSelectorHandler`处理延迟Import

```java
// ConfigurationClassParser类的parse方法解析配置类
public void parse(Set<BeanDefinitionHolder> configCandidates) {
	for (BeanDefinitionHolder holder : configCandidates) {
		BeanDefinition bd = holder.getBeanDefinition();
		try {
			if (bd instanceof AnnotatedBeanDefinition) {
				parse(((AnnotatedBeanDefinition) bd).getMetadata(), holder.getBeanName());
			}
			else if (bd instanceof AbstractBeanDefinition && ((AbstractBeanDefinition) bd).hasBeanClass()) {
				parse(((AbstractBeanDefinition) bd).getBeanClass(), holder.getBeanName());
			}
			else {
				parse(bd.getBeanClassName(), holder.getBeanName());
			}
		}
		catch (BeanDefinitionStoreException ex) {
			throw ex;
		}
		catch (Throwable ex) {
			throw new BeanDefinitionStoreException(
					"Failed to parse configuration class [" + bd.getBeanClassName() + "]", ex);
		}
	}
	// 在此处延迟处理Import
	this.deferredImportSelectorHandler.process();
}
```

4. 使用`DeferredImportSelectorGroupingHandler`对所有的`DeferredImportSelector`进行分组，并将所有分组后的`DeferredImportSelector`逐一处理。而我们的重中之重即`AutoConfigurationImportSelector.getImportGroup`返回的`AutoConfigurationGroup`，该类将调用`AutoConfigurationImportSelector.getAutoConfigurationEntry`来加载所有的`META-INF/spring.factories`文件中的`org.springframework.boot.autoconfigure.EnableAutoConfiguration`的`value`值，即我们需要的自动配置类（对于这里的处理，我们需要从更高的一个角度看待处理所有的`DeferredImportSelector`，而不是专注于`AutoConfigurationImportSelector`）
```java
// DeferredImportSelectorHandler
public void process() {
	List<DeferredImportSelectorHolder> deferredImports = this.deferredImportSelectors;
	this.deferredImportSelectors = null;
	try {
		if (deferredImports != null) {
			DeferredImportSelectorGroupingHandler handler = new DeferredImportSelectorGroupingHandler();
			deferredImports.sort(DEFERRED_IMPORT_COMPARATOR);
			// 根据DeferredImportSelector的ImportGroup，将相同一组DeferredImportSelector放到一起
			deferredImports.forEach(handler::register);
			// 按分组来处理
			handler.processGroupImports();
		}
	}
	finally {
		this.deferredImportSelectors = new ArrayList<>();
	}
}


private class DeferredImportSelectorGroupingHandler {

	private final Map<Object, DeferredImportSelectorGrouping> groupings = new LinkedHashMap<>();

	private final Map<AnnotationMetadata, ConfigurationClass> configurationClasses = new HashMap<>();

	public void register(DeferredImportSelectorHolder deferredImport) {
		// AutoConfigurationImportSelector类的getImportGroup方法，返回AutoConfigurationGroup.class
		Class<? extends Group> group = deferredImport.getImportSelector().getImportGroup();
		// 使用DeferredImportSelectorGrouping将同一组类型的Import，放到一起
		DeferredImportSelectorGrouping grouping = this.groupings.computeIfAbsent(
				(group != null ? group : deferredImport),
				key -> new DeferredImportSelectorGrouping(createGroup(group)));
		grouping.add(deferredImport);
		this.configurationClasses.put(deferredImport.getConfigurationClass().getMetadata(),
				deferredImport.getConfigurationClass());
	}

	public void processGroupImports() {
		for (DeferredImportSelectorGrouping grouping : this.groupings.values()) {
			Predicate<String> exclusionFilter = grouping.getCandidateFilter();
			// 我们需要特别关注此处的grouping.getImports()，该方法是通过AutoConfigurationGroup处理分组后的DeferredImportSelector
			grouping.getImports().forEach(entry -> {
				ConfigurationClass configurationClass = this.configurationClasses.get(entry.getMetadata());
				try {
					// 再处理延迟加载的自动配置类
					processImports(configurationClass, asSourceClass(configurationClass, exclusionFilter),
							Collections.singleton(asSourceClass(entry.getImportClassName(), exclusionFilter)),
							exclusionFilter, false);
				}
				catch (BeanDefinitionStoreException ex) {
					throw ex;
				}
				catch (Throwable ex) {
					throw new BeanDefinitionStoreException(
							"Failed to process import candidates for configuration class [" +
									configurationClass.getMetadata().getClassName() + "]", ex);
				}
			});
		}
	}

	private Group createGroup(@Nullable Class<? extends Group> type) {
		Class<? extends Group> effectiveType = (type != null ? type : DefaultDeferredImportSelectorGroup.class);
		return ParserStrategyUtils.instantiateClass(effectiveType, Group.class,
				ConfigurationClassParser.this.environment,
				ConfigurationClassParser.this.resourceLoader,
				ConfigurationClassParser.this.registry);
	}
}

// DeferredImportSelectorGrouping
public Iterable<Group.Entry> getImports() {
	for (DeferredImportSelectorHolder deferredImport : this.deferredImports) {
		// 此时会使用AutoConfigurationGroup来处理
		this.group.process(deferredImport.getConfigurationClass().getMetadata(),
				deferredImport.getImportSelector());
	}
	// 然后再查询出所有的Import
	return this.group.selectImports();
}

// AutoConfigurationGroup
public void process(AnnotationMetadata annotationMetadata, DeferredImportSelector deferredImportSelector) {
	Assert.state(deferredImportSelector instanceof AutoConfigurationImportSelector,
			() -> String.format("Only %s implementations are supported, got %s",
					AutoConfigurationImportSelector.class.getSimpleName(),
					deferredImportSelector.getClass().getName()));
	// 非常重要的地方即调用AutoConfigurationImportSelector.getAutoConfigurationEntry，此时将加载所有的META-INF/spring.factories文件中的org.springframework.boot.autoconfigure.EnableAutoConfiguration的value值，即我们需要的自动配置类
	AutoConfigurationEntry autoConfigurationEntry = ((AutoConfigurationImportSelector) deferredImportSelector)
			.getAutoConfigurationEntry(annotationMetadata);
	this.autoConfigurationEntries.add(autoConfigurationEntry);
	for (String importClassName : autoConfigurationEntry.getConfigurations()) {
		this.entries.putIfAbsent(importClassName, annotationMetadata);
	}
}

// 自动配置类在经过一些过滤后，返回所有可以加载的配置类
// AutoConfigurationGroup
public Iterable<Entry> selectImports() {
	if (this.autoConfigurationEntries.isEmpty()) {
		return Collections.emptyList();
	}
	// 自动配置类在经过一些过滤后，返回所有可以加载的配置类
	Set<String> allExclusions = this.autoConfigurationEntries.stream()
			.map(AutoConfigurationEntry::getExclusions).flatMap(Collection::stream).collect(Collectors.toSet());
	Set<String> processedConfigurations = this.autoConfigurationEntries.stream()
			.map(AutoConfigurationEntry::getConfigurations).flatMap(Collection::stream)
			.collect(Collectors.toCollection(LinkedHashSet::new));
	processedConfigurations.removeAll(allExclusions);

	return sortAutoConfigurations(processedConfigurations, getAutoConfigurationMetadata()).stream()
			.map((importClassName) -> new Entry(this.entries.get(importClassName), importClassName))
			.collect(Collectors.toList());
}

```


## 三、`AutoConfigurationPackages.Registrar`

AutoConfigurationPackages类型的作用：用于存储自动配置包以便后续引用（例如，由JPA实体扫描器引用）的类。关于此类及注解的更多作用暂时不明

```java
static class Registrar implements ImportBeanDefinitionRegistrar, DeterminableImports {

	@Override
	public void registerBeanDefinitions(AnnotationMetadata metadata, BeanDefinitionRegistry registry) {
		// 向容器中注入 BasePackages 的 BeanDefinition，并在ConstructorArgumentValues的下标0的位置，存储packageName
		register(registry, new PackageImports(metadata).getPackageNames().toArray(new String[0]));
	}

	@Override
	public Set<Object> determineImports(AnnotationMetadata metadata) {
		return Collections.singleton(new PackageImports(metadata));
	}

}

// PackageImports
PackageImports(AnnotationMetadata metadata) {
	// 获取注解@AutoConfigurationPackage的属性
	AnnotationAttributes attributes = AnnotationAttributes
			.fromMap(metadata.getAnnotationAttributes(AutoConfigurationPackage.class.getName(), false));
	List<String> packageNames = new ArrayList<>();
	// 获取basePackages的值
	for (String basePackage : attributes.getStringArray("basePackages")) {
		packageNames.add(basePackage);
	}
	// 获取basePackageClasses类型所在包的值
	for (Class<?> basePackageClass : attributes.getClassArray("basePackageClasses")) {
		packageNames.add(basePackageClass.getPackage().getName());
	}
	// 如果都为空，则取注解所在类的包的值
	if (packageNames.isEmpty()) {
		packageNames.add(ClassUtils.getPackageName(metadata.getClassName()));
	}
	this.packageNames = Collections.unmodifiableList(packageNames);
}

// AutoConfigurationPackages
// 该方法的作用就是向容器中注入 BasePackages 的 BeanDefinition，并在ConstructorArgumentValues的下标0的位置，存储packageName
public static void register(BeanDefinitionRegistry registry, String... packageNames) {
	// 	private static final String BEAN = AutoConfigurationPackages.class.getName();
	if (registry.containsBeanDefinition(BEAN)) {
		BeanDefinition beanDefinition = registry.getBeanDefinition(BEAN);
		ConstructorArgumentValues constructorArguments = beanDefinition.getConstructorArgumentValues();
		constructorArguments.addIndexedArgumentValue(0, addBasePackages(constructorArguments, packageNames));
	}
	else {
		GenericBeanDefinition beanDefinition = new GenericBeanDefinition();
		beanDefinition.setBeanClass(BasePackages.class);
		beanDefinition.getConstructorArgumentValues().addIndexedArgumentValue(0, packageNames);
		beanDefinition.setRole(BeanDefinition.ROLE_INFRASTRUCTURE);
		registry.registerBeanDefinition(BEAN, beanDefinition);
	}
}
```


