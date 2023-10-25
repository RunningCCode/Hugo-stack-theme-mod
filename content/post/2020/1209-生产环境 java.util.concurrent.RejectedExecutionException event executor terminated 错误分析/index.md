---

title: "生产环境 java.util.concurrent.RejectedExecutionException: event executor terminated 错误分析"
slug: "生产环境 java.util.concurrent.RejectedExecutionException: event executor terminated 错误分析"
description:
date: "2020-12-09"
lastmod: "2020-12-09"
image:
math:
license:
hidden: false
draft: false
categories: ["踩坑记录"]
tags: ["event executor terminated"]

---
## 缘由
生产上发生了事故，用户服务其中一台服务很多情况下都不可用，于是查询日志，发现了在从redis获取用户信息缓存的时候出现了错误，栈如下：
```
org.springframework.data.redis.RedisSystemException: Unknown redis exception; nested exception is java.util.concurrent.RejectedExecutionException: event executor terminated
	at org.springframework.data.redis.FallbackExceptionTranslationStrategy.getFallback(FallbackExceptionTranslationStrategy.java:53)
	at org.springframework.data.redis.FallbackExceptionTranslationStrategy.translate(FallbackExceptionTranslationStrategy.java:43)
	at org.springframework.data.redis.connection.lettuce.LettuceConnection.convertLettuceAccessException(LettuceConnection.java:270)
	at org.springframework.data.redis.connection.lettuce.LettuceStringCommands.convertLettuceAccessException(LettuceStringCommands.java:799)
	at org.springframework.data.redis.connection.lettuce.LettuceStringCommands.set(LettuceStringCommands.java:180)
	at org.springframework.data.redis.connection.DefaultedRedisConnection.set(DefaultedRedisConnection.java:288)
	at com.hyzh.common.redis.util.RedisDistributedLock.lambda$setRedis$0(RedisDistributedLock.java:152)
	at org.springframework.data.redis.core.RedisTemplate.execute(RedisTemplate.java:228)
	at org.springframework.data.redis.core.RedisTemplate.execute(RedisTemplate.java:188)
	at com.hyzh.common.redis.util.RedisDistributedLock.setRedis(RedisDistributedLock.java:152)
	at com.hyzh.common.redis.util.RedisDistributedLock.lock(RedisDistributedLock.java:71)
	at com.hyzh.common.redis.aspect.DistributedLockAspect.around(DistributedLockAspect.java:70)
	at sun.reflect.GeneratedMethodAccessor748.invoke(Unknown Source)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at org.springframework.aop.aspectj.AbstractAspectJAdvice.invokeAdviceMethodWithGivenArgs(AbstractAspectJAdvice.java:644)
	at org.springframework.aop.aspectj.AbstractAspectJAdvice.invokeAdviceMethod(AbstractAspectJAdvice.java:633)
	at org.springframework.aop.aspectj.AspectJAroundAdvice.invoke(AspectJAroundAdvice.java:70)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:175)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:749)
	at org.springframework.aop.interceptor.ExposeInvocationInterceptor.invoke(ExposeInvocationInterceptor.java:95)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:749)
	at org.springframework.aop.framework.CglibAopProxy$DynamicAdvisedInterceptor.intercept(CglibAopProxy.java:691)
	at com.hyzh.unistars.user.service.impl.UserActionServiceImpl$$EnhancerBySpringCGLIB$$59bb712b.findActionConfigByCode(<generated>)
	at com.hyzh.unistars.user.service.impl.UserActionServiceImpl.findActionConfigByCode(UserActionServiceImpl.java:160)
	at com.hyzh.unistars.user.service.impl.UserActionServiceImpl$$FastClassBySpringCGLIB$$5acd3627.invoke(<generated>)
	at org.springframework.cglib.proxy.MethodProxy.invoke(MethodProxy.java:218)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.invokeJoinpoint(CglibAopProxy.java:771)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:163)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:749)
	at org.springframework.aop.interceptor.ExposeInvocationInterceptor.invoke(ExposeInvocationInterceptor.java:95)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:749)
	at org.springframework.aop.framework.CglibAopProxy$DynamicAdvisedInterceptor.intercept(CglibAopProxy.java:691)
	at com.hyzh.unistars.user.service.impl.UserActionServiceImpl$$EnhancerBySpringCGLIB$$59bb712b.findActionConfigByCode(<generated>)
	at com.hyzh.unistars.user.service.impl.UserTaskServiceImpl.addUserAccountLogsByUserIdsAndCodes(UserTaskServiceImpl.java:505)
	at org.apache.dubbo.common.bytecode.Wrapper53.invokeMethod(Wrapper53.java)
	at org.apache.dubbo.rpc.proxy.javassist.JavassistProxyFactory$1.doInvoke(JavassistProxyFactory.java:47)
	at org.apache.dubbo.rpc.proxy.AbstractProxyInvoker.invoke(AbstractProxyInvoker.java:84)
	at org.apache.dubbo.config.invoker.DelegateProviderMetaDataInvoker.invoke(DelegateProviderMetaDataInvoker.java:56)
	at org.apache.dubbo.rpc.protocol.InvokerWrapper.invoke(InvokerWrapper.java:56)
	at org.apache.dubbo.monitor.support.MonitorFilter.invoke(MonitorFilter.java:92)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.protocol.dubbo.filter.TraceFilter.invoke(TraceFilter.java:81)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.filter.TimeoutFilter.invoke(TimeoutFilter.java:48)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at com.hyzh.common.dubbo.ExceptionFilter.invoke(ExceptionFilter.java:33)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at com.alibaba.csp.sentinel.adapter.dubbo.SentinelDubboProviderFilter.invoke(SentinelDubboProviderFilter.java:73)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at com.hyzh.common.dubbo.DistributedLogTracerInterceptor.invoke(DistributedLogTracerInterceptor.java:41)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.filter.ContextFilter.invoke(ContextFilter.java:96)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.filter.GenericFilter.invoke(GenericFilter.java:148)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.filter.ClassLoaderFilter.invoke(ClassLoaderFilter.java:38)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.filter.EchoFilter.invoke(EchoFilter.java:41)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$1.invoke(ProtocolFilterWrapper.java:82)
	at org.apache.dubbo.rpc.protocol.ProtocolFilterWrapper$CallbackRegistrationInvoker.invoke(ProtocolFilterWrapper.java:157)
	at org.apache.dubbo.rpc.protocol.dubbo.DubboProtocol$1.reply(DubboProtocol.java:152)
	at org.apache.dubbo.remoting.exchange.support.header.HeaderExchangeHandler.handleRequest(HeaderExchangeHandler.java:102)
	at org.apache.dubbo.remoting.exchange.support.header.HeaderExchangeHandler.received(HeaderExchangeHandler.java:193)
	at org.apache.dubbo.remoting.transport.DecodeHandler.received(DecodeHandler.java:51)
	at org.apache.dubbo.remoting.transport.dispatcher.ChannelEventRunnable.run(ChannelEventRunnable.java:57)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:748)
Caused by: java.util.concurrent.RejectedExecutionException: event executor terminated
	at io.netty.util.concurrent.SingleThreadEventExecutor.reject(SingleThreadEventExecutor.java:926)
	at io.netty.util.concurrent.SingleThreadEventExecutor.offerTask(SingleThreadEventExecutor.java:353)
	at io.netty.util.concurrent.SingleThreadEventExecutor.addTask(SingleThreadEventExecutor.java:346)
	at io.netty.util.concurrent.SingleThreadEventExecutor.execute(SingleThreadEventExecutor.java:828)
	at io.netty.util.concurrent.SingleThreadEventExecutor.execute(SingleThreadEventExecutor.java:818)
	at io.netty.util.concurrent.AbstractScheduledEventExecutor.schedule(AbstractScheduledEventExecutor.java:261)
	at io.netty.util.concurrent.AbstractScheduledEventExecutor.schedule(AbstractScheduledEventExecutor.java:177)
	at io.netty.util.concurrent.AbstractEventExecutorGroup.schedule(AbstractEventExecutorGroup.java:50)
	at io.netty.util.concurrent.AbstractEventExecutorGroup.schedule(AbstractEventExecutorGroup.java:32)
	at io.lettuce.core.protocol.CommandExpiryWriter.potentiallyExpire(CommandExpiryWriter.java:164)
	at io.lettuce.core.protocol.CommandExpiryWriter.write(CommandExpiryWriter.java:111)
	at io.lettuce.core.RedisChannelHandler.dispatch(RedisChannelHandler.java:187)
	at io.lettuce.core.StatefulRedisConnectionImpl.dispatch(StatefulRedisConnectionImpl.java:171)
	at io.lettuce.core.AbstractRedisAsyncCommands.dispatch(AbstractRedisAsyncCommands.java:467)
	at io.lettuce.core.AbstractRedisAsyncCommands.set(AbstractRedisAsyncCommands.java:1213)
	at sun.reflect.GeneratedMethodAccessor749.invoke(Unknown Source)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at io.lettuce.core.FutureSyncInvocationHandler.handleInvocation(FutureSyncInvocationHandler.java:57)
	at io.lettuce.core.internal.AbstractInvocationHandler.invoke(AbstractInvocationHandler.java:80)
	at com.sun.proxy.$Proxy219.set(Unknown Source)
	at org.springframework.data.redis.connection.lettuce.LettuceStringCommands.set(LettuceStringCommands.java:178)
... 66 common frames omitted
```
同时，也发现了在用户服务也报了内存溢出日志如下：
```
December 9th 2020, 12:35:16.041	2020-12-09 12:25:52,956 [WARN ] [lettuce-eventExecutorLoop-3-2] [] [i.n.u.c.SingleThreadEventExecutor] Unexpected exception from an event executor: 
java.lang.OutOfMemoryError: GC overhead limit exceeded
```
于是开始重点分析SingleThreadEventExecutor这个类，这个类是netty中eventloop的父类，所以可以理解为他的作用就是轮询读写事件的。
## 分析总结
从栈信息可以看出，错误出现的时机通过netty的channel往redis写数据的时候抛的这个异常，写数据的时候代码会执行到SingleThreadEventExecutor类的excute方法：
```
 private void execute(Runnable task, boolean immediate) {
        boolean inEventLoop = inEventLoop();
        addTask(task);
        if (!inEventLoop) {
            startThread();
            if (isShutdown()) {
                boolean reject = false;
                try {
                    if (removeTask(task)) {
                        reject = true;
                    }
                } catch (UnsupportedOperationException e) {
                    // The task queue does not support removal so the best thing we can do is to just move on and
                    // hope we will be able to pick-up the task before its completely terminated.
                    // In worst case we will log on termination.
                }
                if (reject) {
                    reject();
                }
            }
        }

        if (!addTaskWakesUp && immediate) {
            wakeup(inEventLoop);
        }
    }
```
分析这个方法，大意是将当前写事件提交到SingleThreadEventExecutor任务队列中。报错是在addTask这个方法：
```
/**
     * Add a task to the task queue, or throws a {@link RejectedExecutionException} if this instance was shutdown
     * before.
     */
    protected void addTask(Runnable task) {
        ObjectUtil.checkNotNull(task, "task");
        if (!offerTask(task)) {
            reject(task);
        }
    }
```
这个方法判断如果没有插入任务队列成功就调用reject(task)拒绝任务，reject(task)里面抛出的异常就是我们看到的最外面的异常。于是看一看offerTask方法：
```
    final boolean offerTask(Runnable task) {
        if (isShutdown()) {
            reject();
        }
        return taskQueue.offer(task);
    }
	
	@Override
    public boolean isShutdown() {
        return state >= ST_SHUTDOWN;
    }
	
    private static final int ST_NOT_STARTED = 1;
    private static final int ST_STARTED = 2;
    private static final int ST_SHUTTING_DOWN = 3;
    private static final int ST_SHUTDOWN = 4;
    private static final int ST_TERMINATED = 5;
```
这里可以看出offerTask的时候校验了当前的SingleThreadEventExecutor的状态是否是结束和终止。那么问题来了，是什么导致的SingleThreadEventExecutor的状态为终止的勒，通过前面缘由中日志可以看到SingleThreadEventExecutor也打印了堆溢出的错误日志，搜索这个日志是哪里打印的，发现：
```
private void doStartThread() {
        assert thread == null;
        executor.execute(new Runnable() {
            @Override
            public void run() {
                thread = Thread.currentThread();
                if (interrupted) {
                    thread.interrupt();
                }

                boolean success = false;
                updateLastExecutionTime();
                try {
                    SingleThreadEventExecutor.this.run();
                    success = true;
                } catch (Throwable t) {
                    logger.warn("Unexpected exception from an event executor: ", t);
                } finally {
                    for (;;) {
                        int oldState = state;
                        if (oldState >= ST_SHUTTING_DOWN || STATE_UPDATER.compareAndSet(
                                SingleThreadEventExecutor.this, oldState, ST_SHUTTING_DOWN)) {
                            break;
                        }
                    }

                    // Check if confirmShutdown() was called at the end of the loop.
                    if (success && gracefulShutdownStartTime == 0) {
                        if (logger.isErrorEnabled()) {
                            logger.error("Buggy " + EventExecutor.class.getSimpleName() + " implementation; " +
                                    SingleThreadEventExecutor.class.getSimpleName() + ".confirmShutdown() must " +
                                    "be called before run() implementation terminates.");
                        }
                    }

                    try {
                        // Run all remaining tasks and shutdown hooks. At this point the event loop
                        // is in ST_SHUTTING_DOWN state still accepting tasks which is needed for
                        // graceful shutdown with quietPeriod.
                        for (;;) {
                            if (confirmShutdown()) {
                                break;
                            }
                        }

                        // Now we want to make sure no more tasks can be added from this point. This is
                        // achieved by switching the state. Any new tasks beyond this point will be rejected.
                        for (;;) {
                            int oldState = state;
                            if (oldState >= ST_SHUTDOWN || STATE_UPDATER.compareAndSet(
                                    SingleThreadEventExecutor.this, oldState, ST_SHUTDOWN)) {
                                break;
                            }
                        }

                        // We have the final set of tasks in the queue now, no more can be added, run all remaining.
                        // No need to loop here, this is the final pass.
                        confirmShutdown();
                    } finally {
                        try {
                            cleanup();
                        } finally {
                            // Lets remove all FastThreadLocals for the Thread as we are about to terminate and notify
                            // the future. The user may block on the future and once it unblocks the JVM may terminate
                            // and start unloading classes.
                            // See https://github.com/netty/netty/issues/6596.
                            FastThreadLocal.removeAll();

                            STATE_UPDATER.set(SingleThreadEventExecutor.this, ST_TERMINATED);
                            threadLock.countDown();
                            int numUserTasks = drainTasks();
                            if (numUserTasks > 0 && logger.isWarnEnabled()) {
                                logger.warn("An event executor terminated with " +
                                        "non-empty task queue (" + numUserTasks + ')');
                            }
                            terminationFuture.setSuccess(null);
                        }
                    }
                }
            }
        });
    }
```
这个方法，这个方法里面同时在finally设置了状态为ST_TERMINATED，这个方法大意是启动eventloop真正的线程来轮询读写事件，这个方法将在首次执行excute方法的时候被调用，注意这里的executor变量是一个线程池，于是查阅资料才认识到，eventloopgroup下的每个eventloop实际上都会引用到一个线程池，这个线程池线程数目与eventloop总大小相同，是fork/join框架创建的，真正执行轮询逻辑实际上是这个线程池去提交的。eventloop的意义实际上只是为了保存任务队列。真正的去轮询任务队列的逻辑是由其代理的线程池去执行的。

这样也就清楚了，整个事故实际很简单，就是先由于内存溢出的错误导致eventloop的状态为终止，这个终止状态据我看到的代码貌似是不可逆的，然后当在调用chanel.write的时候提交任务到eventloop校验状态为终止所以报了拒绝错误。

解决这个bug的重要途径是找到内存溢出的原因，这里就不赘述了，因为在网上没有搜到这个错的原因，所以好奇跟了一下代码，同时对netty的eventloop加深了一丢丢理解，所以这里做个记录。






本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。