---

title: "Springboot下的SpringMVC配置解析 ——WebMvcConfigurerAdapter和WebMvcConfigurationSupport"
slug: "Springboot下的SpringMVC配置解析 ——WebMvcConfigurerAdapter和WebMvcConfigurationSupport"
description:
date: "2019-10-12"
lastmod: "2019-10-12"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["SpringMVC"]

---
# 一、前言
Sprinboot中配置SpringMVC主要是继承WebMvcConfigurerAdapter（1.x版本）或者WebMvcConfigurationSupport（2.x版本）。这次主要介绍下web应用的一些常用配置。
# 二、开始配置
## （一）配置参数解析器
参数解析器的作用，通俗来说，参数解析器的作用是将请求中的参数映射到我们Controller方法参数,比如说通过参数解析器，我们可以将前端传过来的token参数做一下处理，从redis中取出用户信息，直接映射为一个userInfo对象，然后Controller方法的参数就直接是UserInfo类型的对象就可以了。如何使用勒？下面是一个简单范例，这里只贴出伪代码：

首先我们创建一个解析器类，并且实现HandlerMethodArgumentResolver接口。

```
public class TokenHandlerMethodArgumentResolver implements HandlerMethodArgumentResolver {
    private RedissonClient redissonClient;
    private UserDao userDao;
    public TokenHandlerMethodArgumentResolver(RedisClient redisClient, UserDao userDao) {
        this.redissonClient = redisClient;
        this.userDao = userDao;
    }
    @Override
    public boolean supportsParameter(MethodParameter methodParameter) {
        return User.class.isAssignableFrom(methodParameter.getParameterType());
    }

    @Override
    public Object resolveArgument(MethodParameter methodParameter, ModelAndViewContainer modelAndViewContainer, NativeWebRequest nativeWebRequest, WebDataBinderFactory webDataBinderFactory) throws Exception{
        HttpServletRequest nativeRequest = (HttpServletRequest) nativeWebRequest.getNativeRequest();
        String token = nativeRequest.getHeader("token");
        RBucket<String> userIdBucket = redissonClient.getBucket(token);
        if(StringUtils.isNotBlank(userIdBucket.get())){
            User user = userDao.getById(userIdBucket.get());
        }
        return user;
    }
}
```

然后创建类MyWebConfig，继承WebMvcConfigurerAdapter并实现ApplicationContextAware接口，为什么实现ApplicationContextAware，是为了从IOC容器当中取出redissonClient和userDao，用于构造TokenHandlerMethodArgumentResolver。

```
public class MyWebConfig extends WebMvcConfigurerAdapter implements ApplicationContextAware {
    private UserDao userDao;
    private RedissonClient redissonClient;
    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> argumentResolvers) {
       argumentResolvers.add(new TokenHandlerMethodArgumentResolver(redissonClient,userDao));
        super.addArgumentResolvers(argumentResolvers);
    }
    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        userDao = applicationContext.getBean(UserDao.class);
        redissonClient = applicationContext.getBean(RedissonClient.class);
    }
}
```

如上，HandlerMethodArgumentResolver最重要的两个方法是`boolean supportsParameter(MethodParameter methodParameter)` 和
`Object resolveArgument(MethodParameter methodParameter, ModelAndViewContainer modelAndViewContainer, NativeWebRequest nativeWebRequest, WebDataBinderFactory webDataBinderFactory)`,前者是如果返回ture表示使用该解析器进行解析，后者就是返回处理后的方法参数。另外例子中比较关键的方法有通过NativeWebRequest获取HttpServletRequest的方法 nativeWebRequest.getNativeRequest()。

这里的逻辑是，如果参数中有参数的类型是User类型，那么直接通过token去获取注入在这里。对于我们来说，如果需要用户信息就只需要在Controller中加个User参数，就自动有了，不需要自己查，就可以很方便的引用用户的相关信息。

## （二）配置数据序列化

配置数据序列化有两种方式，一个是通过添加Formatter，一个是添加Converter，两者区别不大，SpingMVC内部处理Formatter时也是包装了一层Converter。同时这里值得注意的是，Formatter和Converter是在SpringMVC使用默认RequestParamMethodArgumentResolver或ServletModelAttributeMethodProcessor参数解析器情况下使用的，如果你自定义了参数解析器，那么其接管的参数，转换规则由自定义参数解析器里面的逻辑来确定。

另外主要被应用于form表单参数或query参数字段，Json传参不是用这个，Json传参默认参数解析器是：RequestResponseBodyMethodProcessor，针对的主要是@RequestBody修饰的方法参数,调用的消息转换器会用Jackson的ObjectMapper来序列化或反序列化，所以如果是JSON传参，配置这个东西没有用。

### 1.配置Formatter
以配置一个LocalDateTime类与字符串之间的转换为例：

首先新建一个类LocalDateTimeFormatter如下：

```
public class LocalDateTimeFormatter implements Formatter<LocalDateTime> {
    private static final DateTimeFormatter dateTimeFormatter =  DateTimeFormatter.ofPattern("yyyy-MM-dd HH:ss:mm");
    @Override
    public LocalDateTime parse(String s, Locale locale) throws ParseException {
        return LocalDateTime.parse(s, dateTimeFormatter);
    }

    @Override
    public String print(LocalDateTime localDateTime, Locale locale) {
        return dateTimeFormatter.format(localDateTime);
    }
}
```

其中parse方法主要是将字符串转换为对象的逻辑，print方法是将对象转换为字符串的逻辑。

然后注册该Formatter,在MyWebConfig重写public void addFormatters(FormatterRegistry registry) 方法：

```
  @Override
    public void addFormatters(FormatterRegistry registry) {
        registry.addFormatter(new LocalDateTimeFormatter());
        super.addFormatters(registry);
    }
```

这样，当不是json传参的时候，默认情况下会使用这个自定义的格式化器进行字符串和对象的转换。

### 2.配置Converter

一般情况下我们使用Formatter替代Converter,两者作用差不多。Converter的好处是因为有两个泛型参数，可以限制需要转换的类型和要转换为的类型,但翻看源码发现在引用converter的时候判断选用哪个converter传入的来源类型貌似都是String（就算query参数是一个数字），感觉formatter已经够用了，这里存疑把。

converter的用法很简单，只需要往spring容器里面注册一个实现了org.springframework.core.convert.converter的bean，除了这种形式，也可以直接注册ConverterFactory实现获取converter的工厂方法`<T extends R> Converter<S, T> getConverter(Class<T> targetType)`，用在一个来源类型，多个目标类型的场景。另外还有GenericConverter，需实现`Object convert(@Nullable Object source, TypeDescriptor sourceType, TypeDescriptor targetType)`方法，用于多个来源类型，多个目标类型的场景，返回值直接为转换后的值。

## （三）配置静态资源映射

配置静态资源重写的方法为：`void addResourceHandlers(ResourceHandlerRegistry registry)`,如重写方法为：

```
 @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/upload/**").addResourceLocations("classpath:/upload/");
        super.addResourceHandlers(registry);
    }
```
其中`addResourceHandler("/upload/**").addResourceLocations("classpath:/upload/")`的意思表示将URL:项目访问url+upload/xxx映射到classpath下的upload目录里面名为XXX的静态资源，其中addResourceLocations参数为变长参数，可以映射多个路径，也可以前面加'file:'，映射磁盘上任意目录，如：`file:/D://upload/`，表示映射到d盘的upload目录。

## （四）配置过滤器

添加过滤器只需要注册一个FilterRegistrationBean类对象到spring容器即可，如在测试环境注册一个允许跨域的过滤器：

```
    @Conditional(value = {TestCondition.class})
    @Bean
    public FilterRegistrationBean corsFilter() {
        UrlBasedCorsConfigurationSource urlBasedCorsConfigurationSource =
                new UrlBasedCorsConfigurationSource();
        CorsConfiguration corsConfiguration = new CorsConfiguration();
        corsConfiguration.addAllowedOrigin("*");
        corsConfiguration.addAllowedHeader("*");
        corsConfiguration.addAllowedMethod("*");
        urlBasedCorsConfigurationSource.registerCorsConfiguration("/**", corsConfiguration);
        FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
        filterRegistrationBean.setOrder(10);
        filterRegistrationBean.setFilter(new CorsFilter(urlBasedCorsConfigurationSource));
        filterRegistrationBean.setName("corsFilter");
        filterRegistrationBean.addUrlPatterns("/*");
        return filterRegistrationBean;
    }
```

@Conditional注解标识在上面表示在测试环境即引用的aplication-test.yml|properties，这里的value应该传入一个org.springframework.context.annotation.Condition接口实现类的Class对象。这里传入的是TestCondition。代码如下：

```
 @Override
    public boolean matches(ConditionContext conditionContext, AnnotatedTypeMetadata annotatedTypeMetadata) {
        Environment environment = conditionContext.getEnvironment();
        String[] activeProfiles = environment.getActiveProfiles();
        if (null != activeProfiles) {
            for (String x : activeProfiles) {
                if ("test".equals(x)) {
                    return true;
                }
            }
        }
        return false;
    }
```

另外对于自定义的过滤器，常规操作如下：

- 继承OncePerRequestFilter抽象类，实现doFilterInternal方法。
- 将这个Filter对象注入到filterRegistrationBean，并配置其他信息，如order，已经过滤的Url。

如：

```
@Bean
    public FilterRegistrationBean myFilter() {
        FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
        filterRegistrationBean.setFilter(new MyFilter());
        //order越小，优先级越高
        filterRegistrationBean.setOrder(1);
        filterRegistrationBean.addUrlPatterns("/*");
        filterRegistrationBean.setName("myFilter");
        return filterRegistrationBean;
    }
```

## (四）配置拦截器

拦截器与过滤器的区别在于过滤器的优先级比拦截器高，Filter是作用于Servlet前，而Interceptor则相对于Filter更靠后一点。另外Filter不可以使用IOC容器资源，Interceptor则可以。过滤器能完成的功能，通过Interceptor都可以完成，通常情况下，推荐使用Interceptor。

配置拦截器的步骤是：

### 1.创建类继承HandlerInterceptorAdapter。

HandlerInterceptorAdapter有三个方法可以重写，未重写前不做任何处理。三个方法是：

```
//在业务处理器处理请求之前被执行
public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)throws Exception {
        return true;
}
//在业务处理器处理请求返回响应之前执行
public void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler, ModelAndView modelAndView)throws Exception {
}
//返回响应之后执行
public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex)throws Exception {
}
```

### 2.注册拦截器

在MyWebConfig类重写方法void addInterceptors(InterceptorRegistry registry)，如：

```
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 可以多个拦截器组成一个拦截器链
        // addPathPatterns 用于添加拦截规则
        // excludePathPatterns 用于排除拦截
        registry.addInterceptor(new MyInterceptor())
                .addPathPatterns("/**")
                .excludePathPatterns("/swagger*/**");
        super.addInterceptors(registry);
    }
```

# 三、小结
以上就是基于Springboot下的SpringMVC常用配置方法，基本上能满足常用项目配置需求，其他就暂时不作了解了。















本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。