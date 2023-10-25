---

title: "JDK并发包温故知新系列（四）—— CAS原理与JDK8的优化"
slug: "JDK并发包温故知新系列（四）—— CAS原理与JDK8的优化"
description:
date: "2019-10-04"
lastmod: "2019-10-04"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["并发"]

---
# 什么是CAS
CAS-CompareAndSet，是JDK原子变量类AtomicInteger、AtomicLong、AtomicInteger、AtomicBoolean、AtomicReference等实现的基础，例如对于一个共享变量int，就算是简单的自增操作也不是原子性的，多线程同时自增，可能会导致变量的值比预期结果小。但是可以使用AtomicInteger的incrementAndGet() 方法操作变量，这样结果和预期值一样。跟传统的加锁不同，getAndDecrement()方法并没有给代码加锁。代码类似于：

```
public final int incrementAndGet() {
    for (;;) {
        int current = get();
        int next = current + 1;
        if (compareAndSet(current, next))
            return next;
    }
}

```

底层通过sun.misc.Unsafe的本地方法compareAndSwapInt实现，这个方法是原子的。

# 与synchronized的对比
- 乐观锁与悲观锁的区别
- 性能对比

synchronized是阻塞的，CAS更新是非阻塞的，只是会重试，不会有线程上下文切换开销，对于大部分比较简单的操作，无论是在低并发还是高并发情况下，这种乐观非阻塞方式的性能都要远高于悲观阻塞式方式。

# 应用场景

- 用来实现乐观非阻塞算法，确保当前线程方法体内使用的共享变量不被其他线程改变，CAS广泛运用在非阻塞容器中。
- 用来实现悲观阻塞式算法，其用在了显式锁的原理实现，如可重入计数中，调用lock()方法时将通过CAS方法将其设为1，调用unlock则设为递减1。如果同时多个线程调用Lock方法那么必然会导致原子修改不成功，保证了锁的机制，排他性。

# 可能存在的问题
- ABA问题，普通的CAS操作并不是原子的，因为有可能另一个线程改了值但是又改回了值，那么乐观锁的方式是不能保证原子性的，若业务需要规避这种情况那么可以使用AtomicStampedReference的```compareAndSet(V expectedReference, V newReference, int expectedStamp, int newStamp)```方法，只有值和时间戳都相等的时候才进行原子更新，每次更新都把当前时间修改进原子变量。

# JDK8的优化
JAVA8新增了LongAdder、DoubleAdder对原子变量进行进一步优化，主要是利用了分段CAS的机制，如果不用LongAdder，用AtomicLong的话，在高并发情况下，会产生一直自旋，导致效率不高。他将一个数分成若干个数，CompareAndSet方法的参数只是比较的这若干个数中的一个数，从而降低了自旋的概率，提高了效率。




本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。