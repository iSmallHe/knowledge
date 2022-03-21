
# spring中的拓展类

1. BeanDefinitionRegistryPostProcessor
    BeanDefinitionRegistryPostProcessor extends BeanFactoryPostProcessor
    主要方法：void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) throws BeansException;
    执行时机：在spring启动的主流程的invokeBeanFactoryPostProcessors中执行
2. BeanFactoryPostProcessor
    主要方法：void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException;
    执行时机：在spring启动的主流程的invokeBeanFactoryPostProcessors中执行

3. InstantiationAwareBeanPostProcessor
    InstantiationAwareBeanPostProcessor extends BeanPostProcessor
    主要方法：
        1. default boolean postProcessAfterInstantiation(Object bean, String beanName) throws BeansException
        执行时机：在spring中主流程的finishBeanFactoryInitialization中的bean创建过程的doCreateBean的populateBean方法
        主要作用：用户自主进行属性注入，越过spring的注入流程
        2. default PropertyValues postProcessProperties(PropertyValues pvs, Object bean, String beanName) throws BeansException
        执行时机：在spring中主流程的finishBeanFactoryInitialization中的bean创建过程的doCreateBean的populateBean方法
        主要作用：属性注入，用于处理@Autowired @Value @Resource 等等属性注入注解
        3. default PropertyValues postProcessPropertyValues(PropertyValues pvs, PropertyDescriptor[] pds, Object bean, String beanName) throws BeansException
        执行时机：在spring中主流程的finishBeanFactoryInitialization中的bean创建过程的doCreateBean的populateBean方法
        主要作用：属性注入，后续会删除该方法，目前已标注@Deprecated
4. SmartInstantiationAwareBeanPostProcessor
    SmartInstantiationAwareBeanPostProcessor extends InstantiationAwareBeanPostProcessor
    主要方法：
        1. default Class<?> predictBeanType(Class<?> beanClass, String beanName) throws BeansException 
        执行时机：
        主要作用：类型推断，主要作用并不明晰，目前看到的示例有：AOP(AbstractAutoProxyCreator)
        2. default Constructor<?>[] determineCandidateConstructors(Class<?> beanClass, String beanName) throws BeansException
        执行时机：在spring中主流程的finishBeanFactoryInitialization中的bean创建过程的doCreateBean的createBeanInstance方法
        主要作用：用于决定候选类的构造器方法，即用于后续生成bean实例的方式
        3. default Object getEarlyBeanReference(Object bean, String beanName) throws BeansException
        执行时机：在spring中主流程的finishBeanFactoryInitialization中的bean创建过程的doCreateBean
        主要作用：主要用于处理返回早期实例bean的引用，此时bean还未完善。例如AOP(AbstractAutoProxyCreator)
5. BeanPostProcessor
    主要方法：
        1. default Object postProcessBeforeInstantiation(Class<?> beanClass, String beanName) throws BeansException
        执行时机：
        2. default Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException
        执行时机：

6. MergedBeanDefinitionPostProcessor
    MergedBeanDefinitionPostProcessor extends BeanPostProcessor
    主要方法：
        1. void postProcessMergedBeanDefinition(RootBeanDefinition beanDefinition, Class<?> beanType, String beanName)
        执行时机：
        2. default void resetBeanDefinition(String beanName)
        执行时机：

7. InitializingBean
    主要方法：void afterPropertiesSet() throws Exception;
    执行时机：在spring中主流程的finishBeanFactoryInitialization中的bean创建过程的doCreateBean的initializeBean方法

8. SmartInitializingSingleton
    主要方法：void afterSingletonsInstantiated()
    执行时机：在spring中主流程的finishBeanFactoryInitialization中的preInstantiateSingletons方法中
    主要作用：用户可对单例bean进行自定义操作