---

title: "JDK并发包温故知新系列（三）—— 线程的中断"
slug: "JDK并发包温故知新系列（三）—— 线程的中断"
description:
date: "2019-10-03"
lastmod: "2019-10-03"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["并发"]

---
# 需要进行线程中断的场景
- 很多线程的运行模式是死循环，比如在生产者/消费者模式中，消费者主体就是一个死循环，它不停的从队列中接受任务，执行任务，在停止程序时，我们需要一种"优雅"的方法以关闭该线程。
- 在一些用户启动的任务中，线程是用户启动的，比如手动启动批次任务，在任务执行过程中，用户可能会希望取消该任务。
- 在一些场景中，比如从第三方服务器查询一个结果，我们希望在限定的时间内得到结果，如果得不到，我们会希望取消该任务。
- 有时，我们会启动多个线程做同一件事，比如类似抢火车票，我们可能会让多个好友帮忙从多个渠道买火车票，只要有一个渠道买到了，我们会通知取消其他渠道。
# 涉及的线程方法(Thread对象方法)
- `public boolean isInterrupted() `判断线程中断标志位是否为true
- `public void interrupt()` 设置线程中断标志位为true，但对于线程不同的状态，不一定能设置成功。
- `public static boolean interrupted()` 返回线程中断标志位，并清空。
# 线程对中断的反应
分几种情况：

### RUNNABLE状态-线程调用了start()方法，处于等待系统调度或在运行中

这种情况下只设置中断标志位。

### WAITING/TIMED_WAITING-等待状态
当调用如下方法时进入等待状态，包括的方法有：

WATING：调用了锁资源的wait方法，或调用了join方法。

TIMED_WAITING：wait(long timeout)，sleep(long millis)，join(long millis)。(wait与sleep的区别:是否释放锁)。


抛出InterruptedException异常并且线程中断标志位被清空，针对此一般一般是交由上级处理，若希望线程中断，在catch里面执行清理工作或重设线程标志位。

### BLOCKED-线程处于锁等待队列，试图进入同步块

只设置标志位。

### NEW/TERMINATED-线程结束了或还未调用start()方法

不会有任何效果。

# 注意
不是说调用了interrupt()方法，线程就终止了，需要线程实现者通过代码实现，如下：

```
while (!Thread.currentThread().isInterrupted()) {
//清理逻辑
 }
```





本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。