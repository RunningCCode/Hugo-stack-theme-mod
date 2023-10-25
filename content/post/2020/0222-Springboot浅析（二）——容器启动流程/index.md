---

title: "Springboot浅析（二）——容器启动流程"
slug: "Springboot浅析（二）——容器启动流程"
description:
date: "2020-02-22"
lastmod: "2020-02-22"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["SpringBoot"]

---
大概是水平有限，最近跟读代码与相关书籍感觉巨费时间，想深入弄明白所有的东西很难，所以也只能带着问题来学习springboot了，以后遇到确切的问题再做深入了解把，给自己定个目标，暂时只弄清楚容器启动大体流程，了解组件扫描，自动配置，解决循环依赖这几个问题。
一般启动的Main方法为`SpringApplication.run(启动类.class, args);`,跟下去的话会发现调用的就是new SpringApplication(启动类).run(args)由于容器刷新内容最关键也最复杂，先来了解下除容器刷新之外的流程。
## （一） SpringApplication的初始化
### 1.代码
```
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) { 
  this.resourceLoader = resourceLoader;
  Assert.notNull(primarySources, "PrimarySources must not be null"); 
  //通常情况下primarySources就是启动类，暂时理解这里就是将启动类设置为主配置资源来源
 this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources)); 
 //通过类路径中寻找相关类，判断当前环境是NONE（标准环境(classPath下没有javax.servlet.Servlet以及org.springframework.web.context.ConfigurableWebApplicationContext）、SERVLET（Servlet环境）、REACTIVE（响应式）
 this.webApplicationType = WebApplicationType.deduceFromClasspath();
//添加initializers，设置初始化器，这些初始化器将在在容器刷新前回调，原理是通过SpringFactoriesLoader的loadFactoryNames方法在 spring.factories文件中找到的ApplicationContextInitializer接口的配置的实现类的全限定类名，并实例化。
  setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
 //同上，设置ApplicationListener，添加 spring.factories文件中ApplicationListener配置的响应实现类。
  setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class)); 
  //通过构造一个运行时异常，然后去栈帧中寻找方法名为main的方法来得到入口类的名字并设置为mainApplicationClass
 this.mainApplicationClass = deduceMainApplicationClass(); 
}
```
### 2.注
#### （1）ApplicationContextInitializer有哪些？
debug发现有这些：

![](https://oscimg.oschina.net/oscnet/up-b2d6af51181e84b4c62f569fe118e81c814.png)

他们的作用是：
- ConfigurationWarningsApplicationContextInitializer：报告IOC容器的一些常见的错误配置
- ContextIdApplicationContextInitializer：设置Spring应用上下文的ID
- DelegatingApplicationContextInitializer：加载 application.properties 中 context.initializer.classes 配置的类
- ServerPortInfoApplicationContextInitializer：将内置servlet容器实际使用的监听端口写入到 Environment 环境属性中
- SharedMetadataReaderFactoryContextInitializer：创建一个 SpringBoot 和 ConfigurationClassPostProcessor 共用的 CachingMetadataReaderFactory 对象
- ConditionEvaluationReportLoggingListener：将 ConditionEvaluationReport 写入日志
#### （2）ApplicationListener有哪些
debug发现有这些：

![](https://oscimg.oschina.net/oscnet/up-059a6e0b28bd290f5d4e2771d39cc212d82.png)

他们的作用是：
- ClearCachesApplicationListener：应用上下文加载完成后对缓存做清除工作
- ParentContextCloserApplicationListener：监听双亲应用上下文的关闭事件并往自己的子应用上下文中传播
- FileEncodingApplicationListener：检测系统文件编码与应用环境编码是否一致，如果系统文件编码和应用环境的编码不同则终止应用启动
- AnsiOutputApplicationListener：根据 spring.output.ansi.enabled 参数配置 AnsiOutput
- ConfigFileApplicationListener：从常见的那些约定的位置读取配置文件
- DelegatingApplicationListener：监听到事件后转发给 application.properties 中配置的 context.listener.classes 的监听器
- ClasspathLoggingApplicationListener：对环境就绪事件 ApplicationEnvironmentPreparedEvent 和应用失败事件 ApplicationFailedEvent 做出响应
- LoggingApplicationListener：配置 LoggingSystem。使用 logging.config 环境变量指定的配置或者缺省配置
- LiquibaseServiceLocatorApplicationListener：使用一个可以和 SpringBoot 可执行jar包配合工作的版本替换 LiquibaseServiceLocator
- BackgroundPreinitializer：使用一个后台线程尽早触发一些耗时的初始化任务

#### （3）REACTIVE是什么
REACTIVE是响应式编程的东西，指的是应用WebFlux框架下的应用环境，是NIO同步非阻塞IO，未来可能替代当前的MVC，由于是比较新的技术，应用场景比较有限，暂时不做深入了解。

## （二）容器刷新之前的操作
### 1.代码
```
public ConfigurableApplicationContext run(String... args) {  
//这个组件是用来监控启动时间的，不是很重要
StopWatch stopWatch = new StopWatch();  
stopWatch.start();  
ConfigurableApplicationContext context = null;  
//SpringBootExceptionReporter这个东西是一个异常解析器，实现类只有一个是FailureAnalyzers，
//用于打印异常信息，这个集合在下面③处会初始化，集合里面装了针对各式各样的解析器，
//在catch到异常后，会遍历这个集合，寻找合适的解析器，然后打印异常日志
Collection<SpringBootExceptionReporter> exceptionReporters = new ArrayList<>(); 
//刷新系统属性java.awt.headless的值，如果没有值则设为true，这个值表示无头模式（意指缺少显示设备，键盘或鼠标的系统配置），
//在无头模式下java.awt.Toolkit将使用特定的无头模式下的实现类，因为就算没有显示设备，有些操作任能够被允许。
configureHeadlessProperty();  
//①
SpringApplicationRunListeners listeners = getRunListeners(args);  
listeners.starting();  
try {  
//②
  ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);  
  ConfigurableEnvironment environment = prepareEnvironment(listeners, applicationArguments);
  //配置系统参数spring.beaninfo.ignore,默认值为ture，字面意思是跳过搜索BeanInfo类，但具体是什么我暂时也不清楚。
  configureIgnoreBeanInfo(environment);
  //③
  Banner printedBanner = printBanner(environment);  
  //④
  context = createApplicationContext();  
  //⑤
  exceptionReporters = getSpringFactoriesInstances(SpringBootExceptionReporter.class,  
 new Class[]{ConfigurableApplicationContext.class}, context);  
 //⑥
  prepareContext(context, environment, listeners, applicationArguments, printedBanner);  
  refreshContext(context);  
  //刷新后的处理，是个空实现
  afterRefresh(context, applicationArguments); 
  //计时器结束
  stopWatch.stop();  
 if (this.logStartupInfo) {  
  new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);  
  }  
  //发布started事件
  listeners.started(context);  
  //运行器回调，即实现了ApplicationRunner接口或CommandLineRunner接口的bean
  callRunners(context, applicationArguments);  
} catch (Throwable ex) {  
  handleRunFailure(context, ex, exceptionReporters, listeners);  
 throw new IllegalStateException(ex);  
}  
  
try {  
  listeners.running(context);  
} catch (Throwable ex) {  
  handleRunFailure(context, ex, exceptionReporters, null);  
 throw new IllegalStateException(ex);  
}  
return context;
}
```
### 2.代码注释
#### ①
内部又是调getSpringFactoriesInstances方法，取spring.factories中所有的SpringApplicationRunListener，然后对外暴露SpringApplicationRunListeners。
SpringApplicationRunListeners封装所有的SpringApplicationRunListener，用于容器启动间的事件发布到所有的SpringApplicationRunListener中。

SpringApplicationRunListener中定义的方法有：
- void starting();首次启动run方法时立即调用。可用于非常早期的初始化。
- void environmentPrepared(ConfigurableEnvironment environment);准备好环境（Environment构建完成），但在创建ApplicationContext之前调用。
- void contextPrepared(ConfigurableApplicationContext context);在创建和构建ApplicationContext之后，但在加载之前调用。
- void contextLoaded(ConfigurableApplicationContext context);ApplicationContext已加载但在刷新之前调用。
- void started(ConfigurableApplicationContext context);ApplicationContext已刷新，应用程序已启动，但尚未调用CommandLineRunners和ApplicationRunners
- void running(ConfigurableApplicationContext context);在运行方法彻底完成之前立即调用，刷新ApplicationContext并调用所有CommandLineRunners和ApplicationRunner。
- void failed(ConfigurableApplicationContext context, Throwable exception);在运行应用程序时失败时调用。

值得注意的是，started、running、failed方法是 SpringBoot2.0 才加入的。

通过Debug，发现默认情况下加载的listeners有一个，类型为 EventPublishingRunListener。它在SpringBoot应用启动的不同时间点发布不同应用事件类型(ApplicationEvent)，如果有哪些事件监听者(ApplicationListener)对这些事件感兴趣，则可以接收并且处理。SpringApplicationRunListener与ApplicationListener的区别是SpringApplicationRunListener比ApplicationListener更靠前，SpringApplicationRunListener监听的是SpringApplication相关方法的执行，属于第一层监听器，他会发布相应的事件给ApplicationListener。

#### ②
根据不同的webApplicationType完成Environment的初始化，一般是使用StandardServletEnvironment实现类，Environment用于描述应用程序当前的运行环境，其抽象了两个方面的内容：配置文件(profile)和属性(properties)，其实就是对应的配置文件、环境变量、命令行参数里面的内容。这里Environment构建完成时发布了environmentPrepared事件,并且将最新的配置值绑定到了SpringbootApplication中，也就是当前的对象中。比如yml里面配的spring. main开头的一些属性值。
#### ③
根据Enviroment中配置获取对应的banners没有则用默认的SpringbootBanner打印启动信息，就是启动应用时候控制台打印的logo
#### ④
根据WebApplicationType,反射创建不同的ApplicationContext实现（Servlet是AnnotationConfigServletWebServerApplicationContext）。这里Servlet是AnnotationConfigServletWebServerApplicationContext，在他的父类GenericApplicationContext构造方法中,其中注入了一个DefaultListableBeanFactory,这个BeanFactory很关键，实际上AnnotationConfigServletWebServerApplicationContext的BeanFactory能力就是从DefaultListableBeanFactory扩展而来。 另外在这一步中也注册了ConfigurationClassPostProcessor、DefaultEventListenerFactory、EventListenerMethodProcessor、AutowiredAnnotationBeanPostProcessor、CommonAnnotationBeanPostProcessor这些beanDefinition，作为基础组件。ConfigurationClassPostProcessor这个组件是最重要的，其他的暂时没有深究什么作用，ConfigurationClassPostProcessor是BeanFactoryPostProcessor，负责在容器刷新时加载扫描配置类注解进行组件解析，注册BeanDefinition。
#### ⑤
创建一系列SpringBootExceptionReporter，创建流程是通过SpringFactoriesLoader获取到所有实现SpringBootExceptionReporter接口的class，
#### ⑥
初始化ApplicationContext，主要完成以下工作:
- 将准备好的Environment设置给ApplicationContext
- 进一步执行ApplicationContext的后置处理，包括注册BeanName生成器， 设置资源加载器和类加载器，设置类型转换器ConversionService等等，这里的东西暂时不用深究。
- 遍历调用所有的ApplicationContextInitializer的 initialize()方法来对已经创建好的ApplicationContext进行进一步的处理。
- 调用SpringApplicationRunListener的 contextPrepared()方法，通知所有的监听者：ApplicationContext已经准备完毕。
- 创建启动类的beanDefiniton注册到容器中。
- 调用SpringApplicationRunListener的 contextLoaded()方法，通知所有的监听者：ApplicationContext已经装载完毕。

## 小结
容器刷新前，整个流程分三个步骤：
1. 初始化SpringApplication对象，比如设置webApplicationType，加载ApplicationListener，ApplicationContextInitializer。
2. 初始化Environment对象，封装配置文件，命令行参数。
3. 初始化ConfigurableApplicationContext（与ApplicationContext的区别是ConfigurableApplicationContext可以对容器进行写，而ApplicationContext只提供读的方法)，并且将启动类的beanDefiniton先行注册到容器中。
   这是主线程可以看到的，其他没有看到的ApplicationContextInitializer与ApplicationListener干了什么暂时还没有进行深究。










本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。