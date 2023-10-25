---

title: "BUG：方法 A 有环绕切面 a 包含方法 B 有环绕切面 b，然后在 a 切面调用 b 方法，B 方法回调 A 方法的切入点方法，导致的 AopContext.currentProxy () 拿不到方法 A 的代理类"
slug: "BUG：方法 A 有环绕切面 a 包含方法 B 有环绕切面 b，然后在 a 切面调用 b 方法，B 方法回调 A 方法的切入点方法，导致的 AopContext.currentProxy () 拿不到方法 A 的代理类"
description:
date: "2021-08-03"
lastmod: "2021-08-03"
image:
math:
license:
hidden: false
draft: false
categories: ["踩坑记录"]
tags: ["切面","AopContext"]

---
# BUG
前段时间写了个幂等框架 环绕通知是这么写的
```
 @Around("idempotence()")
    public Object around(ProceedingJoinPoint proceedingJoinPoint) throws Throwable {

        //略
        
        boolean isExists = !idempotenceClient.saveIfAbsent(idempotenceId, () -> {
            ResultWrapper resultWrapper = new ResultWrapper();
            Object result = null;
            try {
                result = proceedingJoinPoint.proceed(args);
            } catch (Throwable e) {
                resultWrapper.setHasException(true);
                resultWrapper.setException(e);
            }
            try {
                resultWrapper.setResult((Serializable) result);
            } catch (ClassCastException e) {
                resultType[0] = true;
                log.error("class={}必须实现序列化接口", result.getClass().getName());
            }
            resultWrapperFlag[0]=resultWrapper;
            return resultWrapper;
        });
       //略
        }


    }
```
其中proceedingJoinPoint.proceed(args)是切入点方法逻辑，里面调用了AopContext.currentProxy()获取当前类的代理类。但是获取的代理类却有点奇怪，不能强转为我想象中的被切入对象。缘由是我的切入点逻辑被包含在idempotenceClient#saveIfAbsent方法中去回调了，但saveIfAbsent也有切面，springboot设置当前代理类是在JdkDynamicAopProxy（JDK代理对象）或CglibAopProxy.DynamicAdvisedInterceptor （CGLIB代理对象）的invoke或intercept方法里面。这里以JdkDynamicAopProxy#invoke方法为例：
```
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable{
//略
	if (this.advised.exposeProxy) {
				// Make invocation available if necessary.
				oldProxy = AopContext.setCurrentProxy(proxy);
				setProxyContext = true;
			}
//略
}
```

AopContext：
```
	private static final ThreadLocal<Object> currentProxy = new NamedThreadLocal<>("Current AOP proxy");

	@Nullable
	static Object setCurrentProxy(@Nullable Object proxy) {
		Object old = currentProxy.get();
		if (proxy != null) {
			currentProxy.set(proxy);
		}
		else {
			currentProxy.remove();
		}
		return old;
	}
	public static Object currentProxy() throws IllegalStateException {
		Object proxy = currentProxy.get();
		if (proxy == null) {
			throw new IllegalStateException(
					"Cannot find current proxy: Set 'exposeProxy' property on Advised to 'true' to make it available, and " +
							"ensure that AopContext.currentProxy() is invoked in the same thread as the AOP invocation context.");
		}
		return proxy;
	}
```
可以看到，AopContext.currentProxy()取到代理类实际上就是在一个线程变量里面取，而这个线程变量在执行代理类方法的时候被设置进去,所以，我这里取被代理对象只能取到当前被代理对象，而由于当前方法最近的切面是idempotenceClient这个类生成的切面，所以只能取到idempotenceClient的代理类。说起来有点绕。

# 总结
当在切面逻辑方法中用另一个切面方法来回调proceedingJoinPoint.proceed(args)方法的时候，需要注意AopContext.currentProxy()取到的是另一个切面方法对应的代理类对象。









本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。