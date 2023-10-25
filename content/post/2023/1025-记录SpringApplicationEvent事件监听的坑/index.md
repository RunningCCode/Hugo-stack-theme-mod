---

title: "记录SpringApplicationEvent事件监听的坑"
slug: "记录SpringApplicationEvent事件监听的坑"
description:
date: "2023-10-25"
lastmod: "2023-10-25"
image:
math:
license:
hidden: false
draft: false
categories: ["踩坑记录"]
tags: ["SpringBoot"]

---
### 监听器会被执行多次

如果在spring.factories注册一个监听器，形如:`org.springframework.context.ApplicationListener=com.zerofinance.xpay.commons.component.knife4j.Knife4jCfg4SpringStartListener`

```java
public class Knife4jCfg4SpringStartListener implements ApplicationListener<ApplicationPreparedEvent> {



    @Override
    public void onApplicationEvent(ApplicationPreparedEvent event) {
            ConfigurableEnvironment env = event.getApplicationContext().getEnvironment();
            MutablePropertySources m = env.getPropertySources();
            Properties p = new Properties();
            p.put("knife4j.enable", "true");
            if (EnvUtils.isTestLower(event.getApplicationContext().getEnvironment())) {

            } else {
                p.put("knife4j.production","true");
            }
            m.addFirst(new PropertiesPropertySource("knife4jCfg", p));

        
    }
}

```

则该监听器监听逻辑会被执行多次。

### 原因分析

#### 1. ApplicationContext有多个

在BootstrapApplicationListener中会创建一个bootstrap ApplicationContext。这个ApplciationContext也会发布相应的事件。

#### 2. RestartListener会在ContextRefreshedEvent事件触发时补发ApplicationPreparedEvent事件

RestartListener 在容器刷新时会监听 ContextRefreshedEvent 事件，然后广播ApplicationPreparedEvent 事件。至于为什么要重新广播，原因是：

因为在应用重启的场景中，已经存在一个完整的应用上下文（即 ConfigurableApplicationContext），其他事件的处理已经在应用启动时完成，不需要重新处理。而 ApplicationPreparedEvent 是在应用启动或重启时都需要处理的事件，因此需要重新广播。

举个例子，假设你的应用需要从多个配置源中读取配置，比如环境变量、命令行参数、配置文件等。在应用启动时，Spring Boot 会依次广播 ApplicationEnvironmentPreparedEvent、ApplicationContextInitializedEvent、ApplicationPreparedEvent 和 ApplicationStartedEvent 事件。在这些事件的处理过程中，Spring Boot 会解析并加载所有的配置源，并将它们合并成一个 Environment 对象，用于后续的应用配置。

在容器刷新时，由于已经存在一个完整的应用上下文，这些事件的处理已经完成，不需要重新执行。而 ApplicationPreparedEvent 事件则需要重新广播，因为它涉及到应用的预热、预加载等操作，需要重新执行以确保应用正确启动。

#### 3.AbstractApplicationContext#publishEvent方法会补发事件到父容器

AbstractApplicationContext类源码摘要：

```java
protected void publishEvent(Object event, @Nullable ResolvableType eventType) {
    Assert.notNull(event, "Event must not be null");

    // Decorate event as an ApplicationEvent if necessary
    ApplicationEvent applicationEvent;
    if (event instanceof ApplicationEvent) {
      applicationEvent = (ApplicationEvent) event;
    }
    else {
      applicationEvent = new PayloadApplicationEvent<>(this, event);
      if (eventType == null) {
        eventType = ((PayloadApplicationEvent<?>) applicationEvent).getResolvableType();
      }
    }

    // Multicast right now if possible - or lazily once the multicaster is initialized
    if (this.earlyApplicationEvents != null) {
      this.earlyApplicationEvents.add(applicationEvent);
    }
    else {
      getApplicationEventMulticaster().multicastEvent(applicationEvent, eventType);
    }

    // Publish event via parent context as well...
    if (this.parent != null) {
      if (this.parent instanceof AbstractApplicationContext) {
        ((AbstractApplicationContext) this.parent).publishEvent(event, eventType);
      }
      else {
        this.parent.publishEvent(event);
      }
    }
  }
```

在 Spring 应用上下文中，父子上下文的事件广播存在着一定的继承关系。当一个事件被子上下文发布时，如果父上下文也存在，那么这个事件将被传播到父上下文，然后再由父上下文向它的监听器广播。这样做的目的是为了让父上下文及其监听器也能够感知到子上下文发生的事件。

在 publishEvent() 方法中，如果当前上下文有一个父上下文，那么它会再次将事件传递给父上下文的 publishEvent() 方法。










本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。