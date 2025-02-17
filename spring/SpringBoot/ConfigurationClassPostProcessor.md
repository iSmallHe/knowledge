# ConfigurationClassPostProcessor

该类用于加载标注`@Configuration`的配置类，主要执行逻辑在于实现了接口`BeanDefinitionRegistryPostProcessor`，执行时机在`AbstractApplicationContext`的模板方法`refresh`中的步骤`invokeBeanFactoryPostProcessors`

## 一、BeanDefinitionRegistryPostProcessor

`BeanDefinitionRegistryPostProcessor` 是 Spring 容器中的一个扩展接口，它允许开发者在 Spring 容器的 `BeanDefinition` 注册过程中进行干预，修改或添加 `BeanDefinition`。这个接口提供了一个 `postProcessBeanDefinitionRegistry` 方法，可以在 Spring 容器初始化时，修改 bean 的定义。

### 1.1 主要作用：

1. **修改或增加 Bean 定义**：
   `BeanDefinitionRegistryPostProcessor` 主要的作用是让你在 Spring 容器加载 Bean 定义之前，添加或修改现有的 `BeanDefinition`。这意味着你可以在 Spring 容器初始化阶段完成一些自定义的 Bean 注册工作。

2. **扩展 BeanDefinition 注册过程**：
   通过实现该接口，开发者可以访问 `BeanDefinitionRegistry`，在容器创建 Bean 时进行更细粒度的控制。例如，动态地注册或调整 Bean 的生命周期、作用域等。

3. **延迟处理 Bean 定义**：
   `BeanDefinitionRegistryPostProcessor` 会在 Spring 容器加载完 Bean 定义后，但在实际创建 Bean 之前执行。这提供了一个在 Bean 创建之前的处理机会。

### 1.2 使用场景：

- **动态注册 Bean**：例如，可以根据条件或环境变量动态地注册不同的 Bean。
- **自定义 BeanDefinition**：如果你需要修改或增强某个 Bean 的定义，`BeanDefinitionRegistryPostProcessor` 提供了一个理想的钩子。
- **实现依赖注入的扩展**：通过修改 Bean 定义，可以实现更复杂的依赖注入逻辑。

### 1.3 示例代码：

```java
import org.springframework.beans.factory.config.BeanDefinitionRegistry;
import org.springframework.beans.factory.support.BeanDefinitionRegistryPostProcessor;
import org.springframework.beans.factory.support.GenericBeanDefinition;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

@Configuration
public class CustomBeanDefinitionRegistryPostProcessor implements BeanDefinitionRegistryPostProcessor {

    @Override
    public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
        // 动态注册一个 BeanDefinition
        GenericBeanDefinition beanDefinition = new GenericBeanDefinition();
        beanDefinition.setBeanClass(MyCustomBean.class);
        registry.registerBeanDefinition("myCustomBean", beanDefinition);
    }

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
        // 不做处理
    }
}
```

在上面的示例中，我们实现了 `BeanDefinitionRegistryPostProcessor`，并在 `postProcessBeanDefinitionRegistry` 方法中动态地注册了一个新的 Bean。

### 1.4 注意事项：
- `BeanDefinitionRegistryPostProcessor` 是 Spring 的一个扩展机制，用得不多，但它非常强大，能实现一些灵活的功能。
- 它的执行时机是在容器的 `BeanDefinition` 被读取之后，但在 Bean 实例化之前。

## 二、基础信息

该类继承了常用的接口：
1. `BeanDefinitionRegistryPostProcessor`：动态注册 Bean；自定义 BeanDefinition；实现依赖注入的扩展
2. `PriorityOrdered`
3. `ResourceLoaderAware`
4. `BeanClassLoaderAware`
5. `EnvironmentAware`
```java
public class ConfigurationClassPostProcessor implements BeanDefinitionRegistryPostProcessor,
		PriorityOrdered, ResourceLoaderAware, BeanClassLoaderAware, EnvironmentAware
```

### 2.1 @AliasFor

在 Spring 框架中，`@AliasFor` 注解用于注解属性之间建立别名关系，通常应用于自定义注解时。它可以使注解的一个属性与另一个属性互为别名，即这两个属性的值可以相互替代或共享。

**作用：**
- **属性别名**：在自定义注解中，`@AliasFor` 使得不同的属性能够共享同一个值，即在一个注解中你可以通过多个属性设置同一个值，Spring 会自动处理它们作为别名。
- **简化配置**：有助于简化注解的使用，特别是在需要灵活配置多个属性时。

**使用场景：**
- 在 Spring 中，尤其是自定义注解时，`@AliasFor` 可以帮助减少冗余，使得用户在使用注解时更方便，避免重复配置相同的值。

**示例代码：**

```java
import org.springframework.core.annotation.AliasFor;
import java.lang.annotation.*;

@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface MyAnnotation {
    @AliasFor("alias")  // name 和 alias 是互为别名
    String name() default "";

    @AliasFor("name")
    String alias() default "";
}

public class Example {
    @MyAnnotation(name = "Spring")  // 或者使用 alias = "Spring"
    public class MyClass {
    }
}
```

**解释：**
1. `@AliasFor("alias")` 让 `name` 和 `alias` 互为别名。
2. `@AliasFor("name")` 让 `alias` 和 `name` 互为别名。
3. 当你使用 `@MyAnnotation(name = "Spring")` 或 `@MyAnnotation(alias = "Spring")` 时，它们会共享相同的值 `Spring`。
4. Spring 会自动将这两个属性的值视为相同，因此你不需要同时为两个属性赋相同的值。

**使用场景举例：**
`@AliasFor` 在一些注解如 `@RequestMapping` 和 `@GetMapping` 中也有应用。例如：

```java
@RequestMapping("/home")
public class HomeController {
    @GetMapping("/greeting")
    public String greeting() {
        return "Hello!";
    }
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@RequestMapping(method = RequestMethod.GET)
public @interface GetMapping {

	/**
	 * Alias for {@link RequestMapping#name}.
	 */
	@AliasFor(annotation = RequestMapping.class)
	String name() default "";

	/**
	 * Alias for {@link RequestMapping#value}.
	 */
	@AliasFor(annotation = RequestMapping.class)
	String[] value() default {};

	/**
	 * Alias for {@link RequestMapping#path}.
	 */
	@AliasFor(annotation = RequestMapping.class)
	String[] path() default {};

	/**
	 * Alias for {@link RequestMapping#params}.
	 */
	@AliasFor(annotation = RequestMapping.class)
	String[] params() default {};

	/**
	 * Alias for {@link RequestMapping#headers}.
	 */
	@AliasFor(annotation = RequestMapping.class)
	String[] headers() default {};

	/**
	 * Alias for {@link RequestMapping#consumes}.
	 * @since 4.3.5
	 */
	@AliasFor(annotation = RequestMapping.class)
	String[] consumes() default {};

	/**
	 * Alias for {@link RequestMapping#produces}.
	 */
	@AliasFor(annotation = RequestMapping.class)
	String[] produces() default {};

}
```

在上面的例子中，`@GetMapping` 和 `@RequestMapping` 都会使用 `@AliasFor` 来实现属性的映射，使得 `value` 或 `path` 属性具有相同的功能。

**总结：**
- `@AliasFor` 可以让注解的多个属性共享相同的值，简化了配置和使用。
- 它广泛应用于 Spring 框架中，尤其是在自定义注解和注解组合使用时。


### 2.2 @Repeatable

`@Repeatable` 是 Java 8 引入的一个注解，用于标识一个注解可以在同一个元素上多次使用。它的作用是让一个注解可以被重复应用，而不需要开发者显式地为每个注解创建一个容器类（通常是一个数组或集合）。

**作用：**
1. **使注解可重复使用**：`@Repeatable` 使得开发者可以在同一个 Java 元素（如类、方法、字段等）上多次使用同一个注解。
2. **简化注解容器的使用**：通常情况下，如果需要多个相同类型的注解，必须将它们包含在一个容器注解（如数组）中。使用 `@Repeatable` 后，容器注解就会自动生成，简化了代码。

**使用方法：**

- 为了让一个注解可以被重复应用，需要定义一个“容器注解”。容器注解是一个注解，内部包含一个数组，用来保存多个被重复使用的注解。
- 这个容器注解通过 `@Repeatable` 注解来标识，指明它是一个用于包含重复注解的容器。

**示例：**

**步骤1：定义可重复使用的注解**
首先，我们定义一个普通的注解，并使用 `@Repeatable` 来指定容器注解。

```java
import java.lang.annotation.*;

@Target(ElementType.TYPE)  // 注解应用于类上
@Retention(RetentionPolicy.RUNTIME)
@Repeatable(Tasks.class)  // 使用 @Repeatable 标记为可重复使用
public @interface Task {
    String value();
}
```

**步骤2：定义容器注解**
然后，我们定义一个容器注解，它包含一个 `Task` 类型的数组。

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Tasks {
    Task[] value();  // 容器注解，内部包含 Task 数组
}
```

**步骤3：使用重复注解**
现在，我们可以在同一个类上多次使用 `@Task` 注解。

```java
@Task("Task 1")
@Task("Task 2")
@Task("Task 3")
public class MyClass {
    // 类体
}
```

**步骤4：读取重复注解**
通过反射，我们可以读取到这些重复的注解。

```java
public class Main {
    public static void main(String[] args) {
        Class<MyClass> clazz = MyClass.class;
        
        // 读取容器注解
        Tasks tasks = clazz.getAnnotation(Tasks.class);
        
        if (tasks != null) {
            for (Task task : tasks.value()) {
                System.out.println(task.value());
            }
        }
    }
}
```

**输出：**
```
Task 1
Task 2
Task 3
```

**关键点：**
1. **`@Repeatable`**：使得注解能够在同一个元素上重复使用。
2. **容器注解**：`@Repeatable` 需要指定一个容器注解，这个容器注解用来包含所有重复的注解。
3. **简化代码**：通过 `@Repeatable` 和容器注解，Java 8 使得多个相同类型的注解更加直观和简洁。

**小结：**
- `@Repeatable` 让你在同一个 Java 元素上多次应用同一类型的注解，避免了显式使用数组或集合来存放多个注解。
- 它通常与容器注解配合使用，使得多次使用的注解可以通过反射获取到。

### 2.3 @Inherited

`@Inherited` 是 Java 提供的一个注解，主要作用是标记某个注解是可继承的。具体来说，当一个类使用了一个被 `@Inherited` 注解标记的注解时，其子类将自动继承该注解。

**作用：**
1. **让注解可继承**：当父类的某个注解被标记为 `@Inherited` 时，子类会自动继承这个注解。通常只有类级别的注解支持这种继承行为。
2. **简化继承关系中的注解使用**：通过继承父类的注解，可以避免在每个子类中重复添加相同的注解，提升代码的复用性。

**使用方式：**
`@Inherited` 注解只能应用于 **类注解** 上。它不影响方法、字段、构造函数等元素上的注解。

**示例：**

**步骤1：定义一个带 `@Inherited` 的注解**
首先，我们定义一个注解，并将其标记为 `@Inherited`。

```java
import java.lang.annotation.*;

@Inherited  // 使得该注解可被继承
@Target(ElementType.TYPE)  // 该注解只能应用于类上
@Retention(RetentionPolicy.RUNTIME)
public @interface MyAnnotation {
    String value() default "Inherited Annotation";
}
```

**步骤2：在父类上使用注解**
然后，我们在父类中使用这个注解。

```java
@MyAnnotation(value = "This is the parent class annotation")
public class ParentClass {
    // 父类的内容
}
```

**步骤3：子类会自动继承父类的注解**
我们创建一个子类，它会自动继承父类上的注解。

```java
public class ChildClass extends ParentClass {
    // 子类的内容
}
```

**步骤4：通过反射读取注解**
通过反射，我们可以验证子类是否继承了父类的注解。

```java
public class Main {
    public static void main(String[] args) {
        // 获取子类的注解
        if (ChildClass.class.isAnnotationPresent(MyAnnotation.class)) {
            MyAnnotation annotation = ChildClass.class.getAnnotation(MyAnnotation.class);
            System.out.println("Annotation value: " + annotation.value());
        } else {
            System.out.println("No annotation found");
        }
    }
}
```

**输出：**
```
Annotation value: This is the parent class annotation
```

**关键点：**
1. `@Inherited` 只能作用于类注解，且只有类级别的注解才会被继承。
2. `@Inherited` 注解只影响 **类继承关系**。如果子类继承父类，但父类的注解没有 `@Inherited` 标记，子类是不会自动继承该注解的。
3. 它不会影响方法、字段或构造函数上的注解。

**注意事项：**
- **不是所有注解都能继承**：`@Inherited` 仅适用于类注解，对于其他类型的注解（例如方法注解、字段注解等），它不会起作用。
- **只影响类的继承**：即使子类继承了父类，但父类的注解如果没有 `@Inherited`，子类将无法继承该注解。

**小结：**
- `@Inherited` 注解用于使得一个类注解能够被子类继承，这样在子类中无需重复声明相同的注解。
- 它是继承关系中的一种便利工具，特别适合需要在类层面统一配置的注解（如日志、权限控制等）。

## 三、加载Configuration

1. 防止容器重复加载配置类相关的`BeanDefinition`
2. 获取容器中所有的配置类名称
3. 配置类按`order`排序，设置`BeanName`生成器，设置环境，不过由于实现了接口`EnvironmentAware`，所以它是能直接拿到`environment`
4. 创建`@Configuration`类的解析器`ConfigurationClassParser`，读取器`ConfigurationClassBeanDefinitionReader`
5. 循环处理：解析配置类，读取器读取配置类相关的`BeanDefinition`
```java
//ConfigurationClassPostProcessor
public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
    // 防止容器重复加载BeanDefinition
    int registryId = System.identityHashCode(registry);
    if (this.registriesPostProcessed.contains(registryId)) {
        throw new IllegalStateException(
                "postProcessBeanDefinitionRegistry already called on this post-processor against " + registry);
    }
    if (this.factoriesPostProcessed.contains(registryId)) {
        throw new IllegalStateException(
                "postProcessBeanFactory already called on this post-processor against " + registry);
    }
    this.registriesPostProcessed.add(registryId);

    processConfigBeanDefinitions(registry);
}

public void processConfigBeanDefinitions(BeanDefinitionRegistry registry) {
    List<BeanDefinitionHolder> configCandidates = new ArrayList<>();
    // 获取BeanFactory中的所有BeanDefinitionName
    String[] candidateNames = registry.getBeanDefinitionNames();

    for (String beanName : candidateNames) {
        // 根据名称获取BeanDefinition
        BeanDefinition beanDef = registry.getBeanDefinition(beanName);
        // 获取BeanDefinition属性configurationClass的value，判断是否为空
        if (beanDef.getAttribute(ConfigurationClassUtils.CONFIGURATION_CLASS_ATTRIBUTE) != null) {
            if (logger.isDebugEnabled()) {
                // Bean 定义已经作为配置类处理过
                logger.debug("Bean definition has already been processed as a configuration class: " + beanDef);
            }
        }
        // 未处理过时，判断该BeanDefinition是否是标注了@Configuration的配置类
        else if (ConfigurationClassUtils.checkConfigurationClassCandidate(beanDef, this.metadataReaderFactory)) {
            configCandidates.add(new BeanDefinitionHolder(beanDef, beanName));
        }
    }

    // Return immediately if no @Configuration classes were found
    if (configCandidates.isEmpty()) {
        return;
    }

    // Sort by previously determined @Order value, if applicable
    // 按order属性排序
    configCandidates.sort((bd1, bd2) -> {
        int i1 = ConfigurationClassUtils.getOrder(bd1.getBeanDefinition());
        int i2 = ConfigurationClassUtils.getOrder(bd2.getBeanDefinition());
        return Integer.compare(i1, i2);
    });

    // Detect any custom bean name generation strategy supplied through the enclosing application context
    // 设置BeanName生成器
    SingletonBeanRegistry sbr = null;
    if (registry instanceof SingletonBeanRegistry) {
        sbr = (SingletonBeanRegistry) registry;
        if (!this.localBeanNameGeneratorSet) {
            BeanNameGenerator generator = (BeanNameGenerator) sbr.getSingleton(
                    AnnotationConfigUtils.CONFIGURATION_BEAN_NAME_GENERATOR);
            if (generator != null) {
                this.componentScanBeanNameGenerator = generator;
                this.importBeanNameGenerator = generator;
            }
        }
    }
    // 设置环境，不过由于实现了接口EnvironmentAware，所以它是能直接拿到environment
    if (this.environment == null) {
        this.environment = new StandardEnvironment();
    }

    // Parse each @Configuration class
    // 创建@Configuration类的解析器
    ConfigurationClassParser parser = new ConfigurationClassParser(
            this.metadataReaderFactory, this.problemReporter, this.environment,
            this.resourceLoader, this.componentScanBeanNameGenerator, registry);

    Set<BeanDefinitionHolder> candidates = new LinkedHashSet<>(configCandidates);
    Set<ConfigurationClass> alreadyParsed = new HashSet<>(configCandidates.size());
    do {
        // 解析配置类
        parser.parse(candidates);
        parser.validate();

        Set<ConfigurationClass> configClasses = new LinkedHashSet<>(parser.getConfigurationClasses());
        // 过滤已解析的配置类
        configClasses.removeAll(alreadyParsed);

        // Read the model and create bean definitions based on its content
        // 创建配置类的BeanDefinition读取器
        if (this.reader == null) {
            this.reader = new ConfigurationClassBeanDefinitionReader(
                    registry, this.sourceExtractor, this.resourceLoader, this.environment,
                    this.importBeanNameGenerator, parser.getImportRegistry());
        }
        // 将该配置类所有关联加载的BeanDefinition全部加载到Spring容器中（1.配置类的@Bean方法；2.@ImportResource导入的；3.@Import导入的ImportBeanDefinitionRegistrar；4.配置类）
        this.reader.loadBeanDefinitions(configClasses);
        alreadyParsed.addAll(configClasses);

        // 清除已解析的配置候选类
        candidates.clear();

        // 如果当前容器中的类定义数量大于当前要加载的配置候选类（可能的情况：1.配置类的@Bean方法；2.@ImportResource导入的；3.@Import导入的ImportBeanDefinitionRegistrar。因为这些情况下解析器无法直接解析，所以在下面的逻辑下过滤掉已处理的配置类，循环进行处理新的配置类的解析）
        if (registry.getBeanDefinitionCount() > candidateNames.length) {
            String[] newCandidateNames = registry.getBeanDefinitionNames();
            Set<String> oldCandidateNames = new HashSet<>(Arrays.asList(candidateNames));
            Set<String> alreadyParsedClasses = new HashSet<>();
            for (ConfigurationClass configurationClass : alreadyParsed) {
                alreadyParsedClasses.add(configurationClass.getMetadata().getClassName());
            }
            for (String candidateName : newCandidateNames) {
                if (!oldCandidateNames.contains(candidateName)) {
                    BeanDefinition bd = registry.getBeanDefinition(candidateName);
                    if (ConfigurationClassUtils.checkConfigurationClassCandidate(bd, this.metadataReaderFactory) &&
                            !alreadyParsedClasses.contains(bd.getBeanClassName())) {
                        candidates.add(new BeanDefinitionHolder(bd, candidateName));
                    }
                }
            }
            candidateNames = newCandidateNames;
        }
    }
    while (!candidates.isEmpty());
    // 注册ImportRegistry作为容器的bean，为了支持 ImportAware @Configuration 类，parser.getImportRegistry()返回的就是import栈
    // Register the ImportRegistry as a bean in order to support ImportAware @Configuration classes
    if (sbr != null && !sbr.containsSingleton(IMPORT_REGISTRY_BEAN_NAME)) {
        sbr.registerSingleton(IMPORT_REGISTRY_BEAN_NAME, parser.getImportRegistry());
    }

    if (this.metadataReaderFactory instanceof CachingMetadataReaderFactory) {
        // Clear cache in externally provided MetadataReaderFactory; this is a no-op
        // for a shared cache since it'll be cleared by the ApplicationContext.
        ((CachingMetadataReaderFactory) this.metadataReaderFactory).clearCache();
    }
}
```

### 3.1 ConfigurationClassParser

#### 3.1.1 构造器

1. `ConfigurationClassParser`的构造方法如下所示，我们需要重点关注`ComponentScanAnnotationParser`，该类主要用于加载注解`@ComponentScan`相关的类

```java
ConfigurationClassParser parser = new ConfigurationClassParser(
				this.metadataReaderFactory, this.problemReporter, this.environment,
				this.resourceLoader, this.componentScanBeanNameGenerator, registry);

public ConfigurationClassParser(MetadataReaderFactory metadataReaderFactory,
        ProblemReporter problemReporter, Environment environment, ResourceLoader resourceLoader,
        BeanNameGenerator componentScanBeanNameGenerator, BeanDefinitionRegistry registry) {

    this.metadataReaderFactory = metadataReaderFactory;
    this.problemReporter = problemReporter;
    this.environment = environment;
    this.resourceLoader = resourceLoader;
    this.registry = registry;
    this.componentScanParser = new ComponentScanAnnotationParser(
            environment, resourceLoader, componentScanBeanNameGenerator, registry);
    this.conditionEvaluator = new ConditionEvaluator(registry, environment, resourceLoader);
}
```

#### 3.1.2 解析

1. 解析配置类的`BeanDefinition`
2. 当前`@Import`导入的类是`DeferredImportSelector`时，不会直接在`parse`方法中处理，而是会在解析的最后进行延迟处理
```java
public void parse(Set<BeanDefinitionHolder> configCandidates) {
    for (BeanDefinitionHolder holder : configCandidates) {
        BeanDefinition bd = holder.getBeanDefinition();
        try {
            // 我们重点关注下注解BeanDefinition的解析过程
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
    // 这里也是重点：当前@Import导入的类是DeferredImportSelector时，不会直接在parse方法中处理，而是会在这里，解析的最后进行延迟处理
    this.deferredImportSelectorHandler.process();
}
```

3. 首先使用`conditionEvaluator`判断当前配置类是否满足注解`@Conditional`的条件，不满足时跳过。然后递归处理配置类及其父类
```java
protected final void parse(AnnotationMetadata metadata, String beanName) throws IOException {
    processConfigurationClass(new ConfigurationClass(metadata, beanName), DEFAULT_EXCLUSION_FILTER);
}

protected void processConfigurationClass(ConfigurationClass configClass, Predicate<String> filter) throws IOException {
    // 判断当前配置类是否满足注解@Conditional的条件，不满足时跳过
    if (this.conditionEvaluator.shouldSkip(configClass.getMetadata(), ConfigurationPhase.PARSE_CONFIGURATION)) {
        return;
    }
    // 判断该配置类是否已被import导入处理过
    ConfigurationClass existingClass = this.configurationClasses.get(configClass);
    if (existingClass != null) {
        if (configClass.isImported()) {
            if (existingClass.isImported()) {
                existingClass.mergeImportedBy(configClass);
            }
            // Otherwise ignore new imported config class; existing non-imported class overrides it.
            return;
        }
        else {
            // Explicit bean definition found, probably replacing an import.
            // Let's remove the old one and go with the new one.
            this.configurationClasses.remove(configClass);
            this.knownSuperclasses.values().removeIf(configClass::equals);
        }
    }
    // 此处循环处理配置类，主要的作用是递归检测将该配置类的父类中是否包含需要加载进入spring容器的内容
    // Recursively process the configuration class and its superclass hierarchy.
    SourceClass sourceClass = asSourceClass(configClass, filter);
    do {
        sourceClass = doProcessConfigurationClass(configClass, sourceClass, filter);
    }
    while (sourceClass != null);
    // 处理完成后加入configurationClasses
    this.configurationClasses.put(configClass, configClass);
}


// 检测配置类的条件是否符合加载需求
//ConditionEvaluator
public boolean shouldSkip(@Nullable AnnotatedTypeMetadata metadata, @Nullable ConfigurationPhase phase) {
    if (metadata == null || !metadata.isAnnotated(Conditional.class.getName())) {
        return false;
    }
    // 此处暂不分析?
    if (phase == null) {
        if (metadata instanceof AnnotationMetadata &&
                ConfigurationClassUtils.isConfigurationCandidate((AnnotationMetadata) metadata)) {
            return shouldSkip(metadata, ConfigurationPhase.PARSE_CONFIGURATION);
        }
        return shouldSkip(metadata, ConfigurationPhase.REGISTER_BEAN);
    }

    List<Condition> conditions = new ArrayList<>();
    // 获取所有的条件类
    for (String[] conditionClasses : getConditionClasses(metadata)) {
        for (String conditionClass : conditionClasses) {
            Condition condition = getCondition(conditionClass, this.context.getClassLoader());
            conditions.add(condition);
        }
    }
    // 排序
    AnnotationAwareOrderComparator.sort(conditions);
    // 判断是否符合条件
    for (Condition condition : conditions) {
        ConfigurationPhase requiredPhase = null;
        if (condition instanceof ConfigurationCondition) {
            requiredPhase = ((ConfigurationCondition) condition).getConfigurationPhase();
        }
        if ((requiredPhase == null || requiredPhase == phase) && !condition.matches(this.context, metadata)) {
            return true;
        }
    }

    return false;
}
```

4. 处理配置类: 1.处理内部配置类；2.处理`@PropertySource`；3.处理`@ComponentScan`；4.处理`@Import`；5.处理`@ImportResource`；6.处理`@Bean methods`；7.处理接口的默认方法；8.最后处理父类

```java
protected final SourceClass doProcessConfigurationClass(
        ConfigurationClass configClass, SourceClass sourceClass, Predicate<String> filter)
        throws IOException {

    if (configClass.getMetadata().isAnnotated(Component.class.getName())) {
        // Recursively process any member (nested) classes first
        processMemberClasses(configClass, sourceClass, filter);
    }

    // Process any @PropertySource annotations
    for (AnnotationAttributes propertySource : AnnotationConfigUtils.attributesForRepeatable(
            sourceClass.getMetadata(), PropertySources.class,
            org.springframework.context.annotation.PropertySource.class)) {
        if (this.environment instanceof ConfigurableEnvironment) {
            processPropertySource(propertySource);
        }
        else {
            logger.info("Ignoring @PropertySource annotation on [" + sourceClass.getMetadata().getClassName() +
                    "]. Reason: Environment must implement ConfigurableEnvironment");
        }
    }

    // Process any @ComponentScan annotations
    Set<AnnotationAttributes> componentScans = AnnotationConfigUtils.attributesForRepeatable(
            sourceClass.getMetadata(), ComponentScans.class, ComponentScan.class);
    if (!componentScans.isEmpty() &&
            !this.conditionEvaluator.shouldSkip(sourceClass.getMetadata(), ConfigurationPhase.REGISTER_BEAN)) {
        for (AnnotationAttributes componentScan : componentScans) {
            // The config class is annotated with @ComponentScan -> perform the scan immediately
            Set<BeanDefinitionHolder> scannedBeanDefinitions =
                    this.componentScanParser.parse(componentScan, sourceClass.getMetadata().getClassName());
            // Check the set of scanned definitions for any further config classes and parse recursively if needed
            for (BeanDefinitionHolder holder : scannedBeanDefinitions) {
                BeanDefinition bdCand = holder.getBeanDefinition().getOriginatingBeanDefinition();
                if (bdCand == null) {
                    bdCand = holder.getBeanDefinition();
                }
                if (ConfigurationClassUtils.checkConfigurationClassCandidate(bdCand, this.metadataReaderFactory)) {
                    parse(bdCand.getBeanClassName(), holder.getBeanName());
                }
            }
        }
    }

    // Process any @Import annotations
    processImports(configClass, sourceClass, getImports(sourceClass), filter, true);

    // Process any @ImportResource annotations
    AnnotationAttributes importResource =
            AnnotationConfigUtils.attributesFor(sourceClass.getMetadata(), ImportResource.class);
    if (importResource != null) {
        String[] resources = importResource.getStringArray("locations");
        Class<? extends BeanDefinitionReader> readerClass = importResource.getClass("reader");
        for (String resource : resources) {
            String resolvedResource = this.environment.resolveRequiredPlaceholders(resource);
            configClass.addImportedResource(resolvedResource, readerClass);
        }
    }

    // Process individual @Bean methods
    Set<MethodMetadata> beanMethods = retrieveBeanMethodMetadata(sourceClass);
    for (MethodMetadata methodMetadata : beanMethods) {
        configClass.addBeanMethod(new BeanMethod(methodMetadata, configClass));
    }

    // Process default methods on interfaces
    processInterfaces(configClass, sourceClass);

    // Process superclass, if any
    if (sourceClass.getMetadata().hasSuperClass()) {
        String superclass = sourceClass.getMetadata().getSuperClassName();
        if (superclass != null && !superclass.startsWith("java") &&
                !this.knownSuperclasses.containsKey(superclass)) {
            this.knownSuperclasses.put(superclass, configClass);
            // Superclass found, return its annotation metadata and recurse
            return sourceClass.getSuperClass();
        }
    }

    // No superclass -> processing is complete
    return null;
}
```

##### 3.1.2.1 处理内部配置类

1. 获取当前配置类的所有内部类
2. 判断该内部类是否是配置类的候选，即是否标注了注解：`@Component`；`@ComponentScan`；`@Import`；`@ImportResource`
3. 内部类需要校验是否循环引入配置的问题，所以这里加入`importStack`栈，然后将内部类当做正常配置类进行解析
```java
private void processMemberClasses(ConfigurationClass configClass, SourceClass sourceClass,
        Predicate<String> filter) throws IOException {
    // 获取当前配置类的所有内部类
    Collection<SourceClass> memberClasses = sourceClass.getMemberClasses();
    if (!memberClasses.isEmpty()) {
        List<SourceClass> candidates = new ArrayList<>(memberClasses.size());
        for (SourceClass memberClass : memberClasses) {
            // 判断该内部类是否是配置类的候选，即是否标注了注解：@Component；@ComponentScan；@Import；@ImportResource
            if (ConfigurationClassUtils.isConfigurationCandidate(memberClass.getMetadata()) &&
                    !memberClass.getMetadata().getClassName().equals(configClass.getMetadata().getClassName())) {
                candidates.add(memberClass);
            }
        }
        OrderComparator.sort(candidates);
        // 内部类需要校验是否循环引入配置的问题，所以这里加入importStack栈，然后将该内部类当做正常配置类进行解析
        for (SourceClass candidate : candidates) {
            if (this.importStack.contains(configClass)) {
                this.problemReporter.error(new CircularImportProblem(configClass, this.importStack));
            }
            else {
                this.importStack.push(configClass);
                try {
                    // 解析配置类
                    processConfigurationClass(candidate.asConfigClass(configClass), filter);
                }
                finally {
                    this.importStack.pop();
                }
            }
        }
    }
}
```

##### 3.1.2.2 处理@PropertySource

>`@PropertySource` 注解用于加载外部的属性文件。它通常用于将一个或多个配置文件中的属性加载到 Spring 环境中，以便可以通过 `@Value` 或 `Environment` 获取这些属性。

1. 只有当当前`environment`是`ConfigurableEnvironment`或其子类时，才能处理`@PropertySource`
```java
// Process any @PropertySource annotations
for (AnnotationAttributes propertySource : AnnotationConfigUtils.attributesForRepeatable(
        sourceClass.getMetadata(), PropertySources.class,
        org.springframework.context.annotation.PropertySource.class)) {
    if (this.environment instanceof ConfigurableEnvironment) {
        processPropertySource(propertySource);
    }
    else {
        logger.info("Ignoring @PropertySource annotation on [" + sourceClass.getMetadata().getClassName() +
                "]. Reason: Environment must implement ConfigurableEnvironment");
    }
}
```

2. 解析`@PropertySource`，并加载配置文件
```java
private void processPropertySource(AnnotationAttributes propertySource) throws IOException {
    // 获取name属性
    String name = propertySource.getString("name");
    if (!StringUtils.hasLength(name)) {
        name = null;
    }
    // 获取encoding属性
    String encoding = propertySource.getString("encoding");
    if (!StringUtils.hasLength(encoding)) {
        encoding = null;
    }
    // 获取配置位置
    String[] locations = propertySource.getStringArray("value");
    Assert.isTrue(locations.length > 0, "At least one @PropertySource(value) location is required");
    boolean ignoreResourceNotFound = propertySource.getBoolean("ignoreResourceNotFound");
    // 创建PropertySource工厂，默认使用DefaultPropertySourceFactory
    Class<? extends PropertySourceFactory> factoryClass = propertySource.getClass("factory");
    PropertySourceFactory factory = (factoryClass == PropertySourceFactory.class ?
            DEFAULT_PROPERTY_SOURCE_FACTORY : BeanUtils.instantiateClass(factoryClass));
    // 解析
    for (String location : locations) {
        try {
            // environment替换占位符
            String resolvedLocation = this.environment.resolveRequiredPlaceholders(location);
            // 加载配置文件
            Resource resource = this.resourceLoader.getResource(resolvedLocation);
            // addPropertySource?
            addPropertySource(factory.createPropertySource(name, new EncodedResource(resource, encoding)));
        }
        catch (IllegalArgumentException | FileNotFoundException | UnknownHostException | SocketException ex) {
            // Placeholders not resolvable or resource not found when trying to open it
            if (ignoreResourceNotFound) {
                if (logger.isInfoEnabled()) {
                    logger.info("Properties location [" + location + "] not resolvable: " + ex.getMessage());
                }
            }
            else {
                throw ex;
            }
        }
    }
}
```

##### 3.1.2.3 处理@ComponentScan

1. 获取配置类的注解`@ComponentScan`
2. 使用`ComponentScanAnnotationParser`解析路径下的所有需要加入`Spring`容器的`bean`(例如：`@Component`)
3. 判断扫描出来的类中是否存在配置类，如果是配置类，则再进行配置类解析
```java
// Process any @ComponentScan annotations
// 获取配置类的注解@ComponentScan
Set<AnnotationAttributes> componentScans = AnnotationConfigUtils.attributesForRepeatable(
        sourceClass.getMetadata(), ComponentScans.class, ComponentScan.class);
if (!componentScans.isEmpty() &&
        !this.conditionEvaluator.shouldSkip(sourceClass.getMetadata(), ConfigurationPhase.REGISTER_BEAN)) {
    for (AnnotationAttributes componentScan : componentScans) {
        // The config class is annotated with @ComponentScan -> perform the scan immediately
        // 使用ComponentScanAnnotationParser解析路径下的所有@Component
        Set<BeanDefinitionHolder> scannedBeanDefinitions =
                this.componentScanParser.parse(componentScan, sourceClass.getMetadata().getClassName());
        // Check the set of scanned definitions for any further config classes and parse recursively if needed
        for (BeanDefinitionHolder holder : scannedBeanDefinitions) {
            BeanDefinition bdCand = holder.getBeanDefinition().getOriginatingBeanDefinition();
            if (bdCand == null) {
                bdCand = holder.getBeanDefinition();
            }
            // 判断扫描出来的类是否存在配置类，是配置类的时候，再走解析配置类方法parse
            if (ConfigurationClassUtils.checkConfigurationClassCandidate(bdCand, this.metadataReaderFactory)) {
                parse(bdCand.getBeanClassName(), holder.getBeanName());
            }
        }
    }
}
```
**详细分析下扫描Component过程**

1. 创建类路径下`Component`的`BeanDefinition`扫描器`ClassPathBeanDefinitionScanner`，并生成`bean`过滤器，默认情况下会加入最重要的`new AnnotationTypeFilter(Component.class)`来过滤出`@Component`相关的`bean`
2. 设置扫描器的`bean`名称生成器
3. 设置包含`bean`过滤器
4. 设置排除`bean`过滤器
5. 设置扫描路径
6. 正式扫描
```java
public Set<BeanDefinitionHolder> parse(AnnotationAttributes componentScan, final String declaringClass) {
    // 创建Component的BeanDefinition扫描器
    ClassPathBeanDefinitionScanner scanner = new ClassPathBeanDefinitionScanner(this.registry,
            componentScan.getBoolean("useDefaultFilters"), this.environment, this.resourceLoader);
    // 设置扫描器的bean名称生成器
    Class<? extends BeanNameGenerator> generatorClass = componentScan.getClass("nameGenerator");
    boolean useInheritedGenerator = (BeanNameGenerator.class == generatorClass);
    scanner.setBeanNameGenerator(useInheritedGenerator ? this.beanNameGenerator :
            BeanUtils.instantiateClass(generatorClass));

    ScopedProxyMode scopedProxyMode = componentScan.getEnum("scopedProxy");
    if (scopedProxyMode != ScopedProxyMode.DEFAULT) {
        scanner.setScopedProxyMode(scopedProxyMode);
    }
    else {
        Class<? extends ScopeMetadataResolver> resolverClass = componentScan.getClass("scopeResolver");
        scanner.setScopeMetadataResolver(BeanUtils.instantiateClass(resolverClass));
    }
    // 资源路径模式
    scanner.setResourcePattern(componentScan.getString("resourcePattern"));
    // 设置包含bean过滤器
    for (AnnotationAttributes filter : componentScan.getAnnotationArray("includeFilters")) {
        for (TypeFilter typeFilter : typeFiltersFor(filter)) {
            scanner.addIncludeFilter(typeFilter);
        }
    }
    // 设置排除bean过滤器
    for (AnnotationAttributes filter : componentScan.getAnnotationArray("excludeFilters")) {
        for (TypeFilter typeFilter : typeFiltersFor(filter)) {
            scanner.addExcludeFilter(typeFilter);
        }
    }
    // 设置是否延迟初始化
    boolean lazyInit = componentScan.getBoolean("lazyInit");
    if (lazyInit) {
        scanner.getBeanDefinitionDefaults().setLazyInit(true);
    }

    Set<String> basePackages = new LinkedHashSet<>();
    // 设置扫描路径
    String[] basePackagesArray = componentScan.getStringArray("basePackages");
    for (String pkg : basePackagesArray) {
        String[] tokenized = StringUtils.tokenizeToStringArray(this.environment.resolvePlaceholders(pkg),
                ConfigurableApplicationContext.CONFIG_LOCATION_DELIMITERS);
        Collections.addAll(basePackages, tokenized);
    }
    for (Class<?> clazz : componentScan.getClassArray("basePackageClasses")) {
        basePackages.add(ClassUtils.getPackageName(clazz));
    }
    // 如果扫描路径为空，则已当前声明类的路径作为扫描路径
    if (basePackages.isEmpty()) {
        basePackages.add(ClassUtils.getPackageName(declaringClass));
    }
    // 添加必要的排除bean过滤器：即过滤当前声明类，防止重复创建
    scanner.addExcludeFilter(new AbstractTypeHierarchyTraversingFilter(false, false) {
        @Override
        protected boolean matchClassName(String className) {
            return declaringClass.equals(className);
        }
    });
    // 正式扫描
    return scanner.doScan(StringUtils.toStringArray(basePackages));
}
// 非常重要的一点：扫描器在使用默认过滤器时，会在ClassPathBeanDefinitionScanner构造中加载过滤器
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
// 1. 重要的@Component过滤器
// 2. JSR-250 'javax.annotation.ManagedBean'
// 3. JSR-330 'javax.inject.Named'
protected void registerDefaultFilters() {
    // 重要的@Component过滤器
    this.includeFilters.add(new AnnotationTypeFilter(Component.class));
    ClassLoader cl = ClassPathScanningCandidateComponentProvider.class.getClassLoader();
    // JSR-250 'javax.annotation.ManagedBean'
    try {
        this.includeFilters.add(new AnnotationTypeFilter(
                ((Class<? extends Annotation>) ClassUtils.forName("javax.annotation.ManagedBean", cl)), false));
        logger.trace("JSR-250 'javax.annotation.ManagedBean' found and supported for component scanning");
    }
    catch (ClassNotFoundException ex) {
        // JSR-250 1.1 API (as included in Java EE 6) not available - simply skip.
    }
    // JSR-330 'javax.inject.Named'
    try {
        this.includeFilters.add(new AnnotationTypeFilter(
                ((Class<? extends Annotation>) ClassUtils.forName("javax.inject.Named", cl)), false));
        logger.trace("JSR-330 'javax.inject.Named' annotation found and supported for component scanning");
    }
    catch (ClassNotFoundException ex) {
        // JSR-330 API not available - simply skip.
    }
}
```
7. 扫描路径下符合`excludeFilters`，`includeFilters`要求的类，并生成`BeanDefinition`
8. 处理这些`BeanDefinition`，如果有注解`@Lazy`；`@Primary`；`@DependsOn`；`@Role`；`@Description`，则解析属性设置到`BeanDefinition`
9. 将`component`的`BeanDefinition`注册到容器里

```java
//ClassPathBeanDefinitionScanner
protected Set<BeanDefinitionHolder> doScan(String... basePackages) {
    Assert.notEmpty(basePackages, "At least one base package must be specified");
    Set<BeanDefinitionHolder> beanDefinitions = new LinkedHashSet<>();
    for (String basePackage : basePackages) {
        // 此时通过排除过滤器，包含过滤器之后，才能被加载
        Set<BeanDefinition> candidates = findCandidateComponents(basePackage);
        for (BeanDefinition candidate : candidates) {
            ScopeMetadata scopeMetadata = this.scopeMetadataResolver.resolveScopeMetadata(candidate);
            candidate.setScope(scopeMetadata.getScopeName());
            String beanName = this.beanNameGenerator.generateBeanName(candidate, this.registry);
            if (candidate instanceof AbstractBeanDefinition) {
                postProcessBeanDefinition((AbstractBeanDefinition) candidate, beanName);
            }
            // 解析注解并设置到BeanDefinition属性中：@Lazy；@Primary；@DependsOn；@Role；@Description
            if (candidate instanceof AnnotatedBeanDefinition) {
                AnnotationConfigUtils.processCommonDefinitionAnnotations((AnnotatedBeanDefinition) candidate);
            }
            if (checkCandidate(beanName, candidate)) {
                BeanDefinitionHolder definitionHolder = new BeanDefinitionHolder(candidate, beanName);
                definitionHolder =
                        AnnotationConfigUtils.applyScopedProxyMode(scopeMetadata, definitionHolder, this.registry);
                beanDefinitions.add(definitionHolder);
                // 将component的BeanDefinition注册到容器里
                registerBeanDefinition(definitionHolder, this.registry);
            }
        }
    }
    return beanDefinitions;
}
public Set<BeanDefinition> findCandidateComponents(String basePackage) {
    if (this.componentsIndex != null && indexSupportsIncludeFilters()) {
        return addCandidateComponentsFromIndex(this.componentsIndex, basePackage);
    }
    else {
        return scanCandidateComponents(basePackage);
    }
}


private Set<BeanDefinition> scanCandidateComponents(String basePackage) {
    Set<BeanDefinition> candidates = new LinkedHashSet<>();
    try {
        // String CLASSPATH_ALL_URL_PREFIX = "classpath*:";
        // resourcePattern = "**/*.class"
        String packageSearchPath = ResourcePatternResolver.CLASSPATH_ALL_URL_PREFIX +
                resolveBasePackage(basePackage) + '/' + this.resourcePattern;
        Resource[] resources = getResourcePatternResolver().getResources(packageSearchPath);
        boolean traceEnabled = logger.isTraceEnabled();
        boolean debugEnabled = logger.isDebugEnabled();
        for (Resource resource : resources) {
            if (traceEnabled) {
                logger.trace("Scanning " + resource);
            }
            if (resource.isReadable()) {
                try {
                    MetadataReader metadataReader = getMetadataReaderFactory().getMetadataReader(resource);
                    // 这里将经理includeFilters，excludeFilters判断
                    if (isCandidateComponent(metadataReader)) {
                        ScannedGenericBeanDefinition sbd = new ScannedGenericBeanDefinition(metadataReader);
                        sbd.setSource(resource);
                        // 
                        if (isCandidateComponent(sbd)) {
                            if (debugEnabled) {
                                logger.debug("Identified candidate component class: " + resource);
                            }
                            candidates.add(sbd);
                        }
                        else {
                            if (debugEnabled) {
                                logger.debug("Ignored because not a concrete top-level class: " + resource);
                            }
                        }
                    }
                    else {
                        if (traceEnabled) {
                            logger.trace("Ignored because not matching any filter: " + resource);
                        }
                    }
                }
                catch (Throwable ex) {
                    throw new BeanDefinitionStoreException(
                            "Failed to read candidate component class: " + resource, ex);
                }
            }
            else {
                if (traceEnabled) {
                    logger.trace("Ignored because not readable: " + resource);
                }
            }
        }
    }
    catch (IOException ex) {
        throw new BeanDefinitionStoreException("I/O failure during classpath scanning", ex);
    }
    return candidates;
}
// 判断excludeFilters，includeFilters
protected boolean isCandidateComponent(MetadataReader metadataReader) throws IOException {
    for (TypeFilter tf : this.excludeFilters) {
        if (tf.match(metadataReader, getMetadataReaderFactory())) {
            return false;
        }
    }
    for (TypeFilter tf : this.includeFilters) {
        if (tf.match(metadataReader, getMetadataReaderFactory())) {
            return isConditionMatch(metadataReader);
        }
    }
    return false;
}
// 判断该类是否能成为component
protected boolean isCandidateComponent(AnnotatedBeanDefinition beanDefinition) {
    AnnotationMetadata metadata = beanDefinition.getMetadata();
    return (metadata.isIndependent() && (metadata.isConcrete() ||
            (metadata.isAbstract() && metadata.hasAnnotatedMethods(Lookup.class.getName()))));
}
```

##### 3.1.2.4 处理@Import

1. 判断是否存在循环`import`的问题
2. `import`的类只处理三类：`ImportSelectorl`；`ImportBeanDefinitionRegistrar`；配置类
3. `ImportSelectorl`：a. 首先会判断是否是`DeferredImportSelector`，来延迟处理`import`；b. 会将`ImportSelectorl.selectImports`返回的类名数组当做需要import的类，再次进入`import`处理流程
4. `ImportBeanDefinitionRegistrar`：直接向`registry`中注册`BeanDefinition`的拓展入口
5. 当做普通配置类进行处理，如果不是，也会当做普通`bean`加入容器

```java
// Process any @Import annotations
processImports(configClass, sourceClass, getImports(sourceClass), filter, true);


private void processImports(ConfigurationClass configClass, SourceClass currentSourceClass,
        Collection<SourceClass> importCandidates, Predicate<String> exclusionFilter,
        boolean checkForCircularImports) {

    if (importCandidates.isEmpty()) {
        return;
    }
    // 判断是否存在循环import的问题
    if (checkForCircularImports && isChainedImportOnStack(configClass)) {
        this.problemReporter.error(new CircularImportProblem(configClass, this.importStack));
    }
    else {
        this.importStack.push(configClass);
        try {
            // import的类只处理三类：ImportSelectorl；ImportBeanDefinitionRegistrar；配置类
            for (SourceClass candidate : importCandidates) {
                if (candidate.isAssignable(ImportSelector.class)) {
                    // 如果import的类是ImportSelectorl的子类
                    // Candidate class is an ImportSelector -> delegate to it to determine imports
                    Class<?> candidateClass = candidate.loadClass();
                    ImportSelector selector = ParserStrategyUtils.instantiateClass(candidateClass, ImportSelector.class,
                            this.environment, this.resourceLoader, this.registry);
                    Predicate<String> selectorFilter = selector.getExclusionFilter();
                    if (selectorFilter != null) {
                        exclusionFilter = exclusionFilter.or(selectorFilter);
                    }
                    // 判断是否是延迟import
                    if (selector instanceof DeferredImportSelector) {
                        // 还记得我们3.1.2 解析步骤时，就有个处理延迟加载的，将在那里进行处理
                        this.deferredImportSelectorHandler.handle(configClass, (DeferredImportSelector) selector);
                    }
                    else {
                        // 不是延迟加载时，直接处理，获取当前需要import的类名
                        String[] importClassNames = selector.selectImports(currentSourceClass.getMetadata());
                        // 生成SourceClass
                        Collection<SourceClass> importSourceClasses = asSourceClasses(importClassNames, exclusionFilter);
                        // 处理ImportSelector需要import的类，
                        processImports(configClass, currentSourceClass, importSourceClasses, exclusionFilter, false);
                    }
                }
                else if (candidate.isAssignable(ImportBeanDefinitionRegistrar.class)) {
                    // 如果import的类是ImportBeanDefinitionRegistrar的子类
                    // Candidate class is an ImportBeanDefinitionRegistrar ->
                    // delegate to it to register additional bean definitions
                    Class<?> candidateClass = candidate.loadClass();
                    ImportBeanDefinitionRegistrar registrar =
                            ParserStrategyUtils.instantiateClass(candidateClass, ImportBeanDefinitionRegistrar.class,
                                    this.environment, this.resourceLoader, this.registry);
                    // 这里处理完成后，将在ConfigurationClassBeanDefinitionReader中进行加载时，再处理ImportBeanDefinitionRegistrar
                    configClass.addImportBeanDefinitionRegistrar(registrar, currentSourceClass.getMetadata());
                }
                else {
                    // 将import的类当做配置类进行处理
                    // Candidate class not an ImportSelector or ImportBeanDefinitionRegistrar ->
                    // process it as an @Configuration class
                    this.importStack.registerImport(
                            currentSourceClass.getMetadata(), candidate.getMetadata().getClassName());
                    processConfigurationClass(candidate.asConfigClass(configClass), exclusionFilter);
                }
            }
        }
        catch (BeanDefinitionStoreException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanDefinitionStoreException(
                    "Failed to process import candidates for configuration class [" +
                    configClass.getMetadata().getClassName() + "]", ex);
        }
        finally {
            this.importStack.pop();
        }
    }
}
```

##### 3.1.2.5 处理@ImportResource

> `@ImportResource` 注解用于加载`Spring`的`XML`配置文件(`XML`描述`Spring`容器中的`Bean`、依赖注入、事务管理、`AOP`配置等等)。它通常用于向`Spring`容器导入一个或多个`XML`配置文件。这个注解对于那些已经有大量`XML`配置的遗留系统特别有用，可以逐步迁移到`Java`配置。

1. 解析注解@ImportResource属性
2. 并将解析后的资源添加到`importedResources`中，后续在`loadBeanDefinitionsForConfigurationClass`中会处理
```java
// Process any @ImportResource annotations
AnnotationAttributes importResource =
        AnnotationConfigUtils.attributesFor(sourceClass.getMetadata(), ImportResource.class);
if (importResource != null) {
    String[] resources = importResource.getStringArray("locations");
    Class<? extends BeanDefinitionReader> readerClass = importResource.getClass("reader");
    for (String resource : resources) {
        String resolvedResource = this.environment.resolveRequiredPlaceholders(resource);
        configClass.addImportedResource(resolvedResource, readerClass);
    }
}

```

##### 3.1.2.6 处理@Bean方法

1. 解析配置类带`@Bean`注解的方法，并添加到`beanMethods`中
2. 处理配置类实现的接口上带有`@Bean`注解的方法，并添加到`beanMethods`中

```java
// Process individual @Bean methods
Set<MethodMetadata> beanMethods = retrieveBeanMethodMetadata(sourceClass);
for (MethodMetadata methodMetadata : beanMethods) {
    configClass.addBeanMethod(new BeanMethod(methodMetadata, configClass));
}

// Process default methods on interfaces
processInterfaces(configClass, sourceClass);

// 处理实现接口上的带有@Bean的默认方法
private void processInterfaces(ConfigurationClass configClass, SourceClass sourceClass) throws IOException {
    for (SourceClass ifc : sourceClass.getInterfaces()) {
        Set<MethodMetadata> beanMethods = retrieveBeanMethodMetadata(ifc);
        for (MethodMetadata methodMetadata : beanMethods) {
            if (!methodMetadata.isAbstract()) {
                // A default method or other concrete method on a Java 8+ interface...
                configClass.addBeanMethod(new BeanMethod(methodMetadata, configClass));
            }
        }
        processInterfaces(configClass, ifc);
    }
}
```
##### 3.1.2.7 处理父类

1. 将当前配置类的父类当做配置类返回到上层方法中，循环处理

```java
// Process superclass, if any
if (sourceClass.getMetadata().hasSuperClass()) {
    String superclass = sourceClass.getMetadata().getSuperClassName();
    if (superclass != null && !superclass.startsWith("java") &&
            !this.knownSuperclasses.containsKey(superclass)) {
        this.knownSuperclasses.put(superclass, configClass);
        // Superclass found, return its annotation metadata and recurse
        // 这里将父类返回，是因为在上层方法中会把返回的类当做配置类循环处理
        return sourceClass.getSuperClass();
    }
}
```

### 3.2 加载配置类相关BeanDefinition

1. 创建读取器`ConfigurationClassBeanDefinitionReader`
2. 加载配置类关联加载的`BeanDefinition`

```java
// Read the model and create bean definitions based on its content
if (this.reader == null) {
    this.reader = new ConfigurationClassBeanDefinitionReader(
            registry, this.sourceExtractor, this.resourceLoader, this.environment,
            this.importBeanNameGenerator, parser.getImportRegistry());
}
this.reader.loadBeanDefinitions(configClasses);
```

3. 判断是否过滤配置类的加载相关的`BeanDefinition`
4. 如果当前配置类是通过其他配置类`import`，则在此处进行注册`BeanDefinition`
5. 将配置类中标注`@Bean`的方法进行注册`BeanDefinition`
6. 加载`@ImportResource`注解解析的`XML`配置文件导入的`BeanDefinition`
7. 加载`@Import`注解导入的`ImportBeanDefinitionRegistrar`类，注入`BeanDefinition`
```java
public void loadBeanDefinitions(Set<ConfigurationClass> configurationModel) {
    TrackedConditionEvaluator trackedConditionEvaluator = new TrackedConditionEvaluator();
    for (ConfigurationClass configClass : configurationModel) {
        loadBeanDefinitionsForConfigurationClass(configClass, trackedConditionEvaluator);
    }
}

private void loadBeanDefinitionsForConfigurationClass(
        ConfigurationClass configClass, TrackedConditionEvaluator trackedConditionEvaluator) {
    // 判断是否要过滤配置类
    if (trackedConditionEvaluator.shouldSkip(configClass)) {
        String beanName = configClass.getBeanName();
        if (StringUtils.hasLength(beanName) && this.registry.containsBeanDefinition(beanName)) {
            this.registry.removeBeanDefinition(beanName);
        }
        this.importRegistry.removeImportingClass(configClass.getMetadata().getClassName());
        return;
    }
    // 如果当前配置类是通过其他配置类import，则在此处进行注册BeanDefinition
    if (configClass.isImported()) {
        registerBeanDefinitionForImportedConfigurationClass(configClass);
    }
    // 将配置类中标注@Bean的方法进行注册BeanDefinition
    for (BeanMethod beanMethod : configClass.getBeanMethods()) {
        loadBeanDefinitionsForBeanMethod(beanMethod);
    }
    // 加载@ImportResource注解解析的XML配置文件导入的BeanDefinition
    loadBeanDefinitionsFromImportedResources(configClass.getImportedResources());
    // 加载@Import注解导入的ImportBeanDefinitionRegistrar类，注入的BeanDefinition
    loadBeanDefinitionsFromRegistrars(configClass.getImportBeanDefinitionRegistrars());
}
```