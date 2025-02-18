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



## 三、`AutoConfigurationPackages.Registrar`



## 四、四大皆空

