# ClassPathXmlApplicationContext 源码解析

![title](../../image/ClassPathXmlApplicationContext.png)

```java
public ClassPathXmlApplicationContext(
        String[] configLocations, boolean refresh, @Nullable ApplicationContext parent)
        throws BeansException {
    // 调用父级构造方法，在 AbstractApplicationContext 的构造方法中会初始化 resourcePatternResolver = PathMatchingResourcePatternResolver 。并设置parent（假使parent不为空）
    super(parent);
    // 解析并设置配置文件位置，在resolvePath的过程中，getEnvironment的时候如果environment未初始化，会默认生成StandardEnvironment，并解析配置文件路径
    setConfigLocations(configLocations);
    if (refresh) {
        refresh();
    }
}
```

## 拓展

### obtainFreshBeanFactory
```java
protected ConfigurableListableBeanFactory obtainFreshBeanFactory() {
    refreshBeanFactory();
    return getBeanFactory();
}

// 继承自 AbstractRefreshableApplicationContext 的方法
protected final void refreshBeanFactory() throws BeansException {
    // 重置BeanFactory
    if (hasBeanFactory()) {
        destroyBeans();
        closeBeanFactory();
    }
    try {
        // 创建新的 BeanFactory = DefaultListableBeanFactory
        DefaultListableBeanFactory beanFactory = createBeanFactory();
        beanFactory.setSerializationId(getId());
        // 此处设置 beanFactory 的属性 allowBeanDefinitionOverriding 和 allowCircularReferences （当变量不为null的时候），两者默认值都是true
        // allowBeanDefinitionOverriding ：是否允许 BeanDefinition 覆盖，默认允许
        // allowCircularReferences ： 是否允许循环引用，默认允许
        customizeBeanFactory(beanFactory);
        // 重中之重，即解析xml文件，生成 BeanDefinition
        loadBeanDefinitions(beanFactory);
        // BeanFactory 在此处 放入 ApplicationContext 中
        synchronized (this.beanFactoryMonitor) {
            this.beanFactory = beanFactory;
        }
    }
    catch (IOException ex) {
        throw new ApplicationContextException("I/O error parsing bean definition source for " + getDisplayName(), ex);
    }
}
```