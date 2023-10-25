---

title: "Springboot浅析（三）——容器刷新流程"
slug: "Springboot浅析（三）——容器刷新流程"
description:
date: "2020-03-02"
lastmod: "2020-03-02"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["SpringBoot"]

---
# 一、 先了解下各种后置处理器扩展点
## (一)BeanFactoryPostProcessor——bean工厂后置处理
BeanFactory 标准初始化完毕后(经过包扫描后所有的 BeanDefinition 已经被注册)，可以对这个 BeanFactory 进行后置处理。
## (二)BeanDefinitionRegistryPostProcessor——bean定义注册表后置处理
BeanFactoryPostProcessor的子接口，多了一个postProcessBeanDefinitionRegistry方法，这个方法允许在Bean实例化之前对BeanDefinitionRegistry（bean定义注册表）进行后置处理。
## (三)BeanPostProcessor——bean后置处理器
提供对实例化后的bean进行后置处理的扩展点。一般用于对将要实例化到容器的bean进行再次加工。
## (四)MergedBeanDefinitionPostProcessor——合并Bean定义后置处理器

BeanPostProcessor的子接口，多一个`postProcessMergedBeanDefinition(RootBeanDefinition beanDefinition, Class<?> beanType, String beanName)` 方法，用于后置处理合并Bean定义。

# 二、容器刷新流程
## （一）主要代码
```
//最终调到AbstractApplicationContext的refresh方法
public void refresh() throws BeansException, IllegalStateException {
    synchronized (this.startupShutdownMonitor) {
        // Prepare this context for refreshing.
        // 初始化前的预处理，初始化Environment里面的PropertySources(猜测是webXML里面的东西)，debug下没有什么用
        prepareRefresh();

        // Tell the subclass to refresh the internal bean factory.
        //  获取BeanFactory,直接返回的是前面初始化的beanFactory,只不过设置了一下SerializationId
        ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

        // Prepare the bean factory for use in this context.
        // 3. BeanFactory的预处理配置
	//(1) 在容器注册了ApplicationContextAwareProcessor这个Bean后置处理器用于处理实现了XXXAware接口的bean，调用其setXXX方法。
	//(2)忽略一些自动注入，以及添加一些自动注入的支持，为什么要忽略这些自动注入勒，因为当beanDefinition的AutowireMode为1（按setXXX方法的名称进行注入）和2（按setXXX方法返回值类型进行自动注入）时，若自动注入生效，该Bean的setXXX方法将被自动注入，那么为了避免和XXXAware接口冲突，所以进行了忽略。
	//(3) 添加一些自动注入支持，包含BeanFactory，ResourceLoader，ApplicationEventPublisher，ApplicationContext。
	//(4) 在容器注册了new ApplicationListenerDetector(this)这个Bean后置处理器用于收集所有实现了ApplicationListener接口的bean并收集到容器中的一个集合中。
        prepareBeanFactory(beanFactory);

        try {
            // Allows post-processing of the bean factory in context subclasses.
            // 4. 准备BeanFactory完成后进行的后置处理
	    //以servlet环境为例：
	    //(1) 添加了一个bean的后置处理器处理ServletContextAware和ServletConfigAware，用于注入ServletContext和ServletConfig。
	    //(2) 往容器注册Scope，Scope描述的是Spring容器如何新建Bean实例的，这里注册了Request以及Session两个Scope并且注册ServletRequest、ServletResponse、HttpSession、WebRequest为自动装配。
	    //(3)当判断容器的basePackages属性不为null的时候进行包扫描（但debug下这里没执行）。
	    //(4)当判断容器的annotatedClasses属性不为null也进行注册(debug下没执行)。
            postProcessBeanFactory(beanFactory);

            // Invoke factory processors registered as beans in the context.
            // 5. 执行BeanFactory创建后的后置处理器，
			// 这一步里面会处理ConfigurationClassPostProcessor这个bd后置处理器完成所有的bd注册
            invokeBeanFactoryPostProcessors(beanFactory);

            // Register bean processors that intercept bean creation.
            // 6. 注册Bean的后置处理器
            registerBeanPostProcessors(beanFactory);

            // Initialize message source for this context.
            // 7. 初始化MessageSource
            initMessageSource();

            // Initialize event multicaster for this context.
            // 8. 初始化事件派发器
            initApplicationEventMulticaster();

            // Initialize other special beans in specific context subclasses.
            // 9. 子类的多态onRefresh，比如在 ServletWebServerApplicationContext.onRefresh方法中启动了web容器
            onRefresh();

            // Check for listener beans and register them.
            // 10. 注册监听器
            registerListeners();
            //到此为止，BeanFactory已创建完成
            // Instantiate all remaining (non-lazy-init) singletons.
            // 11. 初始化所有剩下的单例Bean
            finishBeanFactoryInitialization(beanFactory);
            // Last step: publish corresponding event.
            // 12. 完成容器的创建工作
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
            // 13. 清除缓存
            resetCommonCaches();
        }
    }
}
```

## (二)核心点
###  1.prepareBeanFactory(beanFactory)-BeanFactory的预处理配置
 ```
 protected void prepareBeanFactory(ConfigurableListableBeanFactory beanFactory) {
    // Tell the internal bean factory to use the context's class loader etc.
    // 设置BeanFactory的类加载器、表达式解析器等
    beanFactory.setBeanClassLoader(getClassLoader());
    beanFactory.setBeanExpressionResolver(new StandardBeanExpressionResolver(beanFactory.getBeanClassLoader()));
    beanFactory.addPropertyEditorRegistrar(new ResourceEditorRegistrar(this, getEnvironment()));

    // Configure the bean factory with context callbacks.
    //  配置一个BeanPostProcessor，这个Bean后处理器将实现了以下几个Aware的bean分别回调对应的方法
    beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));
	// 配置ignoreDependencyInterface，是的这些类型自动装配无效，但实测@Autowired注入时还是能装配，故这里的意思是为了避免其他bd设置了自动注入，即AutowireMode，而不是指使用@Autowired注解进行的依赖注入。
    beanFactory.ignoreDependencyInterface(EnvironmentAware.class);
    beanFactory.ignoreDependencyInterface(EmbeddedValueResolverAware.class);
    beanFactory.ignoreDependencyInterface(ResourceLoaderAware.class);
    beanFactory.ignoreDependencyInterface(ApplicationEventPublisherAware.class);
    beanFactory.ignoreDependencyInterface(MessageSourceAware.class);
    beanFactory.ignoreDependencyInterface(ApplicationContextAware.class);

    // BeanFactory interface not registered as resolvable type in a plain factory.
    // MessageSource registered (and found for autowiring) as a bean.
    // 自动注入的支持
    beanFactory.registerResolvableDependency(BeanFactory.class, beanFactory);
    beanFactory.registerResolvableDependency(ResourceLoader.class, this);
    beanFactory.registerResolvableDependency(ApplicationEventPublisher.class, this);
    beanFactory.registerResolvableDependency(ApplicationContext.class, this);

    // Register early post-processor for detecting inner beans as ApplicationListeners.
    // 配置一个可加载所有监听器的组件
    beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));

    // Detect a LoadTimeWeaver and prepare for weaving, if found.
    if (beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
        beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
        // Set a temporary ClassLoader for type matching.
        beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
    }

    // Register default environment beans.
    // 注册了默认的运行时环境、系统配置属性、系统环境的信息
    if (!beanFactory.containsLocalBean(ENVIRONMENT_BEAN_NAME)) {
        beanFactory.registerSingleton(ENVIRONMENT_BEAN_NAME, getEnvironment());
    }
    if (!beanFactory.containsLocalBean(SYSTEM_PROPERTIES_BEAN_NAME)) {
        beanFactory.registerSingleton(SYSTEM_PROPERTIES_BEAN_NAME, getEnvironment().getSystemProperties());
    }
    if (!beanFactory.containsLocalBean(SYSTEM_ENVIRONMENT_BEAN_NAME)) {
        beanFactory.registerSingleton(SYSTEM_ENVIRONMENT_BEAN_NAME, getEnvironment().getSystemEnvironment());
    }
}
 ```

这里主要干了四件事：
1. 在容器注册了ApplicationContextAwareProcessor这个Bean后置处理器用于处理实现了XXXAware接口的bean，调用其setXXX方法。
2. 忽略一些自动注入，以及添加一些自动注入的支持，为什么要忽略这些自动注入勒，因为当beanDefinition的AutowireMode为1（按setXXX方法的名称进行注入）和2（按setXXX方法返回值类型进行自动注入）时，若自动注入生效，该Bean的setXXX方法将被自动注入，那么为了避免和XXXAware接口冲突，所以进行了忽略。
3. 添加一些自动注入支持，包含BeanFactory，ResourceLoader，ApplicationEventPublisher，ApplicationContext。
4. 在容器注册了new ApplicationListenerDetector(this)这个Bean后置处理器用于收集所有实现了ApplicationListener接口的bean并收集到容器中的一个集合中。
### 2.postProcessBeanFactory(beanFactory)-准备BeanFactory完成后进行的后置处理
以servlet为例:这里的ApplicationContext实现实际上为AnnotationConfigServletWebServerApplicationContext。在AnnotationConfigServletWebServerApplicationContext类中该方法主要是完成了：
1. 往容器注册了一个bean的后置处理器处理ServletContextAware和ServletConfigAware，用于注入ServletContext和ServletConfig。
2. 往容器注册Scope，Scope描述的是Spring容器如何新建Bean实例的，这里注册了Request以及Session两个Scope并且注册ServletRequest、ServletResponse、HttpSession、WebRequest为自动装配。
3. 当判断容器的basePackages属性不为null的时候进行包扫描（但debug下这里没执行）。
4. 当判断容器的annotatedClasses属性不为null也进行注册(debug下没执行)。
## 3.invokeBeanFactoryPostProcessors(beanFactory)-执行BeanFactory创建后的后置处理器
代码：
```
protected void invokeBeanFactoryPostProcessors(ConfigurableListableBeanFactory beanFactory) {
    // 执行BeanFactory后置处理器
    PostProcessorRegistrationDelegate.invokeBeanFactoryPostProcessors(beanFactory, getBeanFactoryPostProcessors());

    // Detect a LoadTimeWeaver and prepare for weaving, if found in the meantime
    // (e.g. through an @Bean method registered by ConfigurationClassPostProcessor)
    if (beanFactory.getTempClassLoader() == null && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
        beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
        beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
    }
}
```

进入  PostProcessorRegistrationDelegate.invokeBeanFactoryPostProcessors(beanFactory, getBeanFactoryPostProcessors())：

```
public static void invokeBeanFactoryPostProcessors(
        ConfigurableListableBeanFactory beanFactory, List<BeanFactoryPostProcessor> beanFactoryPostProcessors) {

    // Invoke BeanDefinitionRegistryPostProcessors first, if any.
    //用于存放已经执行了的processedBeans
    Set<String> processedBeans = new HashSet<>();

    // 这里要判断BeanFactory的类型，默认SpringBoot创建的BeanFactory是DefaultListableBeanFactory
    // 这个类实现了BeanDefinitionRegistry接口，则此if结构必进
    if (beanFactory instanceof BeanDefinitionRegistry) {
        BeanDefinitionRegistry registry = (BeanDefinitionRegistry) beanFactory;
        List<BeanFactoryPostProcessor> regularPostProcessors = new LinkedList<>();
        List<BeanDefinitionRegistryPostProcessor> registryProcessors = new LinkedList<>();
		//遍历已经注册到beanFactory的BeanFactoryPostProcessor后置处理器，然后分类为regularPostProcessors和registryProcessors
        for (BeanFactoryPostProcessor postProcessor : beanFactoryPostProcessors) {
            if (postProcessor instanceof BeanDefinitionRegistryPostProcessor) {
                BeanDefinitionRegistryPostProcessor registryProcessor =
                        (BeanDefinitionRegistryPostProcessor) postProcessor;
                registryProcessor.postProcessBeanDefinitionRegistry(registry);
                registryProcessors.add(registryProcessor);
            }
            else {
                regularPostProcessors.add(postProcessor);
            }
        }

        // Do not initialize FactoryBeans here: We need to leave all regular beans
        // uninitialized to let the bean factory post-processors apply to them!
        // Separate between BeanDefinitionRegistryPostProcessors that implement
        // PriorityOrdered, Ordered, and the rest.
     	//这个currentRegistryProcessors变量用于分阶段执行方法，因为有PriorityOrdered和Ordered接口的存在
        List<BeanDefinitionRegistryPostProcessor> currentRegistryProcessors = new ArrayList<>();
  
        // First, invoke the BeanDefinitionRegistryPostProcessors that implement PriorityOrdered.
        // 首先，调用实现PriorityOrdered接口的BeanDefinitionRegistryPostProcessors并添加到processedBeans
        String[] postProcessorNames =
                beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
        for (String ppName : postProcessorNames) {
            if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
                currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                processedBeans.add(ppName);
            }
        }
		//排序
        sortPostProcessors(currentRegistryProcessors, beanFactory);
        //添加到registryProcessors
        registryProcessors.addAll(currentRegistryProcessors);
        //执行
        invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
        currentRegistryProcessors.clear();

        // Next, invoke the BeanDefinitionRegistryPostProcessors that implement Ordered.
        // 接下来，调用实现Ordered接口的BeanDefinitionRegistryPostProcessors。
        postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
        for (String ppName : postProcessorNames) {
            if (!processedBeans.contains(ppName) && beanFactory.isTypeMatch(ppName, Ordered.class)) {
                currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                processedBeans.add(ppName);
            }
        }
		//排序
        sortPostProcessors(currentRegistryProcessors, beanFactory);
        //添加到registryProcessors
		registryProcessors.addAll(currentRegistryProcessors);
		//执行
        invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
        currentRegistryProcessors.clear();

        // Finally, invoke all other BeanDefinitionRegistryPostProcessors until no further ones appear.
        // 最后，调用所有其他BeanDefinitionRegistryPostProcessor
        boolean reiterate = true;
        while (reiterate) {
            reiterate = false;
            postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
            for (String ppName : postProcessorNames) {
                if (!processedBeans.contains(ppName)) {
                    currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                    processedBeans.add(ppName);
                    reiterate = true;
                }
            }
			//排序添加执行
            sortPostProcessors(currentRegistryProcessors, beanFactory);
            registryProcessors.addAll(currentRegistryProcessors);
            invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
            currentRegistryProcessors.clear();
        }

        // Now, invoke the postProcessBeanFactory callback of all processors handled so far.
        // 回调所有BeanFactoryPostProcessor的postProcessBeanFactory方法
        invokeBeanFactoryPostProcessors(registryProcessors, beanFactory);
        invokeBeanFactoryPostProcessors(regularPostProcessors, beanFactory);
        // 先回调BeanDefinitionRegistryPostProcessor的postProcessBeanFactory方法
        // 再调用BeanFactoryPostProcessor的postProcessBeanFactory方法
    }

    // 如果BeanFactory没有实现BeanDefinitionRegistry接口，则进入下面的代码流程
    else {
        // Invoke factory processors registered with the context instance.
        // 调用在上下文实例中注册的工厂处理器。
        invokeBeanFactoryPostProcessors(beanFactoryPostProcessors, beanFactory);
    }

    // 下面的部分是回调BeanFactoryPostProcessor，思路与上面的几乎一样
  
    // Do not initialize FactoryBeans here: We need to leave all regular beans
    // uninitialized to let the bean factory post-processors apply to them!
    String[] postProcessorNames =
            beanFactory.getBeanNamesForType(BeanFactoryPostProcessor.class, true, false);

    // Separate between BeanFactoryPostProcessors that implement PriorityOrdered,
    // Ordered, and the rest.
    List<BeanFactoryPostProcessor> priorityOrderedPostProcessors = new ArrayList<>();
    List<String> orderedPostProcessorNames = new ArrayList<>();
    List<String> nonOrderedPostProcessorNames = new ArrayList<>();
    for (String ppName : postProcessorNames) {
        if (processedBeans.contains(ppName)) {
            // skip - already processed in first phase above
        }
        else if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
            priorityOrderedPostProcessors.add(beanFactory.getBean(ppName, BeanFactoryPostProcessor.class));
        }
        else if (beanFactory.isTypeMatch(ppName, Ordered.class)) {
            orderedPostProcessorNames.add(ppName);
        }
        else {
            nonOrderedPostProcessorNames.add(ppName);
        }
    }

    // First, invoke the BeanFactoryPostProcessors that implement PriorityOrdered.
    sortPostProcessors(priorityOrderedPostProcessors, beanFactory);
    invokeBeanFactoryPostProcessors(priorityOrderedPostProcessors, beanFactory);

    // Next, invoke the BeanFactoryPostProcessors that implement Ordered.
    List<BeanFactoryPostProcessor> orderedPostProcessors = new ArrayList<>();
    for (String postProcessorName : orderedPostProcessorNames) {
        orderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
    }
    sortPostProcessors(orderedPostProcessors, beanFactory);
    invokeBeanFactoryPostProcessors(orderedPostProcessors, beanFactory);

    // Finally, invoke all other BeanFactoryPostProcessors.
    List<BeanFactoryPostProcessor> nonOrderedPostProcessors = new ArrayList<>();
    for (String postProcessorName : nonOrderedPostProcessorNames) {
        nonOrderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
    }
    invokeBeanFactoryPostProcessors(nonOrderedPostProcessors, beanFactory);

    // Clear cached merged bean definitions since the post-processors might have
    // modified the original metadata, e.g. replacing placeholders in values...
    // 清理缓存
    beanFactory.clearMetadataCache();
}
```
上面代码有点长主要干得事有：
1. 第一步获取已经注册到容器（与beanDifinitionMap相区别，这里用了容器内beanFactoryPostProcessors这个变量存的而不是从beanDefinition获取的）的beanFactoryPostProcessor的beanFactoryPostProcessors，并筛选实现了BeanDefinitionRegistryPostProcessor接口的，执行其postProcessBeanDefinitionRegistry方法.
2. 第二步获取容器内已注册的beanDefinition中BeanDefinitionRegistryPostProcessor类型的bean，筛选实现了PriorityOrdered接口的，进行排序，然后回调其postProcessBeanDefinitionRegistry。这里执行最重要的ConfigurationClassPostProcessor，他会对当前beandifinitonMap中的带有configraution注解的进行处理，比如处理[@Component](https://my.oschina.net/u/3907912) 、@ComponentScan 、[@Import](https://my.oschina.net/u/3201731) 、@ImportResource、@PropertySource 、@ComponentScan 、@Import 、@ImportResource 、@Bean注解，注册所有的beanDefinition,等一下展开讲这个ConfigurationClassPostProcessor。
3. 第三步获取容器内已注册的beanDefinition中BeanDefinitionRegistryPostProcessor类型的bean，会根据是否实现PriorityOrdered接口Ordered接口进行排序（大体顺序是PriorityOrdered优先Ordered优先没实现接口的，同一接口的按方法返回值确定顺序），然后调用其postProcessBeanDefinitionRegistry方法。
4. 第四步执行上面所有beanDefinitionRegistryPostProcessor类型的bean的postBeanFactory方法。
5. 第五步对于ApplicationContext内（与beanDifinitionMap相区别，这里用了beanFactoryPostProcessors这个变量存而不是beanDefinition存）的beanFactoryPostProcessor，不属于BeanDefinitionRegistryPostProcessor接口的（即只是BeanFactoryProcessor），调用其postBeanFactory方法。
6. 第六步调用其他所有BeanFactoryPostProcessor的postBeanFactory方法，也会解析PriorityOrdered及Ordered接口。

接下来重点看一看在第二步执行的ConfigurationClassPostProcessor的源码，内部就不详细展开了，大概的流程已经写入注释中：

```
public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
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
```

这里的意思是获取容器Id,获取其是否调用过，如果没有则继续执行processConfigBeanDefinitions。看一看   processConfigBeanDefinitions(registry)方法：
```
public void processConfigBeanDefinitions(BeanDefinitionRegistry registry) {
    List<BeanDefinitionHolder> configCandidates = new ArrayList<>();
    String[] candidateNames = registry.getBeanDefinitionNames();

    // 确定配置类和组件
	//带有@Configuration注解的bd的configurationClass值设为full，
	//带有@Component 、@ComponentScan 、@Import 、@ImportResource注解或方法中添加了带@Bean的方法
	//（只是将带bean的方法收集起来，并没有注册bd）的设为configurationClass值设为lite，并加入到configCandidates
    for (String beanName : candidateNames) {
        BeanDefinition beanDef = registry.getBeanDefinition(beanName);
        if (ConfigurationClassUtils.isFullConfigurationClass(beanDef) ||
                ConfigurationClassUtils.isLiteConfigurationClass(beanDef)) {
            if (logger.isDebugEnabled()) {
                logger.debug("Bean definition has already been processed as a configuration class: " + beanDef);
            }
        }
        else if (ConfigurationClassUtils.checkConfigurationClassCandidate(beanDef, this.metadataReaderFactory)) {
            configCandidates.add(new BeanDefinitionHolder(beanDef, beanName));
        }
    }

    // Return immediately if no @Configuration classes were found
    if (configCandidates.isEmpty()) {
        return;
    }

    // Sort by previously determined @Order value, if applicable
    // 对配置类进行排序
    configCandidates.sort((bd1, bd2) -> {
        int i1 = ConfigurationClassUtils.getOrder(bd1.getBeanDefinition());
        int i2 = ConfigurationClassUtils.getOrder(bd2.getBeanDefinition());
        return Integer.compare(i1, i2);
    });

    // Detect any custom bean name generation strategy supplied through the enclosing application context
    // 加载获取BeanNameGenerator
    SingletonBeanRegistry sbr = null;
    if (registry instanceof SingletonBeanRegistry) {
        sbr = (SingletonBeanRegistry) registry;
        if (!this.localBeanNameGeneratorSet) {
            BeanNameGenerator generator = (BeanNameGenerator) sbr.getSingleton(CONFIGURATION_BEAN_NAME_GENERATOR);
            if (generator != null) {
                this.componentScanBeanNameGenerator = generator;
                this.importBeanNameGenerator = generator;
            }
        }
    }

    if (this.environment == null) {
        this.environment = new StandardEnvironment();
    }

    // Parse each @Configuration class
    // 初始化配置类解析器
    ConfigurationClassParser parser = new ConfigurationClassParser(
            this.metadataReaderFactory, this.problemReporter, this.environment,
            this.resourceLoader, this.componentScanBeanNameGenerator, registry);
	//需要解析的配置类集合
    Set<BeanDefinitionHolder> candidates = new LinkedHashSet<>(configCandidates);
    //已经解析的配置类集合
	Set<ConfigurationClass> alreadyParsed = new HashSet<>(configCandidates.size());
    do {
        // 解析配置类，最重要的方法
		//对configCandidates按照@Order进行排序并遍历进行递归一直解析父类，
		//需解析@PropertySource 、@ComponentScan 、@Import 、@ImportResource 、@Bean注解(注这一步还没有对扫描到的组件完全进行Bd注册，
		//而只是注册了包扫描到的bd以及处理@Import注解时实现了ImportBeanDefinitionRegistrar或者ImportSelector接口的bd,
		//并且这里会先处理一个类的嵌套配置类）
        parser.parse(candidates);
		//校验
        parser.validate();
        Set<ConfigurationClass> configClasses = new LinkedHashSet<>(parser.getConfigurationClasses());
        configClasses.removeAll(alreadyParsed);

        // Read the model and create bean definitions based on its content
        if (this.reader == null) {
            this.reader = new ConfigurationClassBeanDefinitionReader(
                    registry, this.sourceExtractor, this.resourceLoader, this.environment,
                    this.importBeanNameGenerator, parser.getImportRegistry());
        }
        //解析配置类中的内容
		//将通过@Import、@Bean注解方式注册的类以及处理@ImportResource注解引入的配置文件解析成BeanDefinition，然后注册到BeanDefinitionMap中。
        this.reader.loadBeanDefinitions(configClasses);
        alreadyParsed.addAll(configClasses);
        candidates.clear();
        if (registry.getBeanDefinitionCount() > candidateNames.length) {
		   //当前的bdNames
            String[] newCandidateNames = registry.getBeanDefinitionNames();
			//上一次解析之前的bdNames
            Set<String> oldCandidateNames = new HashSet<>(Arrays.asList(candidateNames));
			//这次解析的bdNames
            Set<String> alreadyParsedClasses = new HashSet<>();
            for (ConfigurationClass configurationClass : alreadyParsed) {
                alreadyParsedClasses.add(configurationClass.getMetadata().getClassName());
            }
			//遍历当前bdNames，若不是以前有的，并且是配置类，并且没有被解析到，则添加到candidates，下一次循环再解析一次
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

    // Register the ImportRegistry as a bean in order to support ImportAware @Configuration classes
    // 将ImportRegistry注册为Bean，以支持ImportAware 和@Configuration类
    if (sbr != null && !sbr.containsSingleton(IMPORT_REGISTRY_BEAN_NAME)) {
        sbr.registerSingleton(IMPORT_REGISTRY_BEAN_NAME, parser.getImportRegistry());
    }

    // 清除缓存
    if (this.metadataReaderFactory instanceof CachingMetadataReaderFactory) {
        // Clear cache in externally provided MetadataReaderFactory; this is a no-op
        // for a shared cache since it'll be cleared by the ApplicationContext.
        ((CachingMetadataReaderFactory) this.metadataReaderFactory).clearCache();
    }
}
```
## 4.registerBeanPostProcessors(beanFactory)-注册bean后置处理器（包含MergedBeanDefinitionPostProcessor）
注册逻辑跟注册beanFactoryPostProcessor差不多，注册顺序都会判断priorityOrdered与Ordered接口，并且先注册MergedBeanDefinitionPostProcessor再注册beanFactoryPostProcessor。

这里有两个MergedBeanDefinitionPostProcessor，一个是AutowiredAnnotationBeanPostProcessor，一个是ApplicationListenerDetector。

- AutowiredAnnotationBeanPostProcessor 会解析bean的自动注入属性，判断是否有需要依赖的项，并通过registerExternallyManagedConfigMember注册依赖项。
- ApplicationListenerDetector 作用，收集一个beanName为键，是否单例为值的map。

## 5.  initMessageSource()-初始化MessageSource
messageSource主要是spring提供的国际化组件，与之对应的yml配置是：
```
spring: 
  messages:
    basename: i18n/messages
    encoding: UTF-8
```
这样messageSource的getMessage方法就可以通过在i18n目录下查找对应的messageXXX.properties文件，于参数中的Locale进行对比，返回对应国际化后的message。

messageSource中的方法有：
```
//有默认值返回
String getMessage(String code, @Nullable Object[] args, @Nullable String defaultMessage, Locale locale);
//无默认值，找不到抛异常
String getMessage(String code, @Nullable Object[] args, Locale locale) throws NoSuchMessageException;
//MessageSourceResolvable封装了code,args,defaultMessage
String getMessage(MessageSourceResolvable resolvable, Locale locale) throws NoSuchMessageException;
```

参数解释：
- code 信息的键，properties中的key、
- args,用于模板替换message中的参数。
- locale 国家地区
- MessageSourceResolvable  封装了code,args,defaultMessage，code参数为String[]数组形式，通过遍历调用的方式去获取信息，只要其中一个code能够获取到值，便直接返回。查询不出数据时且defaultMessage为空时，直接抛出NoSuchMessageException异常。

源码这里会检查bd里面是否有messageSource，没有的话直接初始化默认的messageSource，DelegatingMessageSource类。
## 6. initApplicationEventMulticaster()-初始化事件广播器
这里也是扫描bd中有没有applicationEventMulticaster，如果没有则使用默认的SimpleApplicationEventMulticaster，这里需要注意的是，在这之前，springboot启动过程中其实也有事件分发，比如SpringApplicationRunListener的start方法在容器开始的时候就被调用了，它是如何做的勒？实际上它是使用的内部的SimpleApplicationEventMulticaster来完成的事件广播。而这里和后面将要注册的listener不是使用的同一个事件广播器。
## 7.onRefresh
不同的web容器会多态实现，比如ServletWebServerApplicationContext会创建嵌入式Servlet容器。
## 8.registerListeners()-注册监听器
注册监听器，并广播早期事件（只是一个供springboot自己用的一个扩展点，这个扩展点允许在后置处理器和监听器都被创建好，其余的单实例Bean还没有创建时广播一些早期事件），通过debug看这里目前没有任何早期事件存入。
## 9.finishBeanFactoryInitialization(beanFactory)-初始化单例bean
比较核心，初始化其他的单例bean，解决了循环依赖。
## 10.finishRefresh()
清除资源缓存(如扫描的ASM元数据)、处理生命周期处理器（Lifecycle接口）、发布容器刷新完成的事件。ServletWebServerApplicationContext在最后会调用 WebServer 的start方法。









本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。