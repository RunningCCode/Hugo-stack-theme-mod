---

title: "在Spring容器刷新之前如何改变application配置文件属性"
slug: "在Spring容器刷新之前如何改变application配置文件属性"
description:
date: "2020-07-13"
lastmod: "2020-07-13"
image:
math:
license:
hidden: false
draft: false
categories: ["技术杂谈"]
tags: ["SpringBoot"]

---
# 缘由
在工作中经常遇到需要写一个公共jar包封装其他开源框架，提供一些最佳实践配置的情况，但是有些开源框架又要求配在配置文件里面，如果业务项目引用了公共jar包，还需要去配很多东西就很烦。解决这个问题最方便的思路是能不能就在jar包里面用java代码的形式增加或修改属性源，但必须在spring容器刷新之前，因为引用的开源框架会在容器刷新时初始化。

因为前面粗浅研究过过springboot，了解到springboot在启动过程中从spring.factories文件加载所有的SpringApplicationRunListener，并在容器启动过程中回调所有SpringApplicationRunListener注册的监听方法。在默认情况下，这里的RunListener只有一个就是EventPublishingRunListener，这个EventPublishingRunListener间接的又发布了很多ApplicationEvent给ApplicationListener（这里的ApplicationListener也是扫描spring.factories文件发现的，所以除了在spring.factories注册SpringApplicationRunListener，也可以注册ApplicationListener），ApplicationListener，是springboot提供的一个扩展点，可以直接通过注册bean实现来监听各种实现，但是得注意了，普通注册bean（注解的方式）来监听容器刷新前的事件是不行的，原因很简单，容器都还没刷新怎么发现到ApplicationListener的呀。所以必须使用spring.factories的方式提前加载。

# 做法
做法很简单。有两种方式，第一种注册RunListener，第二种注册ApplicationListener。
## 第一种
### 第一步
先新建一个SpringApplicationRunListener，为了避免冲突，把这个order设为1，在EventPublishingRunListener之后。
```
public class MyListener implements SpringApplicationRunListener, Ordered {

    public MyListener(SpringApplication application, String[] args) {


    }

    @Override
    public void starting() {

    }

    @Override
    public void environmentPrepared(ConfigurableEnvironment environment) {
        MutablePropertySources m = environment.getPropertySources();
        Properties p = new Properties();
        p.put("test", "123");
		  //addFirst优先级是最高的，如果已经存在值，将会覆盖
         m.addFirst(new PropertiesPropertySource("mypop",p));
    }

    @Override
    public void contextPrepared(ConfigurableApplicationContext context) {

    }

    @Override
    public void contextLoaded(ConfigurableApplicationContext context) {

    }

    @Override
    public void started(ConfigurableApplicationContext context) {

    }

    @Override
    public void running(ConfigurableApplicationContext context) {

    }

    @Override
    public void failed(ConfigurableApplicationContext context, Throwable exception) {

    }

    @Override
    public int getOrder() {
        return 1;
    }
}

```
### 第二步
在META-INF文件夹新建spring.factories文件，添加一行，注册上面的SpringApplicationRunListener:`org.springframework.boot.SpringApplicationRunListener=com.cman777.springc.sample.MyListener`。

## 第二种
### 第一步
```

public class ConfigListener4RunSprboot implements ApplicationListener<ApplicationPreparedEvent> {
    @Override
    public void onApplicationEvent(ApplicationPreparedEvent event) {
        ConfigurableEnvironment env = event.getApplicationContext().getEnvironment();
        MutablePropertySources m = env.getPropertySources();
        Properties p = new Properties();
        p.put("test", "123");
        //addFirst优先级是最高的，如果已经存在值，将会覆盖
        m.addFirst(new PropertiesPropertySource("mypop",p));
    }
}
```
### 第二步
在META-INF文件夹新建spring.factories文件，添加一行，注册上面的ApplicationListener:`org.springframework.context.ApplicationListener=com.cman777.springc.sample.ConfigListener4RunSprboot`。








本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。