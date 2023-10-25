---

title: "JDK并发包温故知新系列（五）—— 显式锁与显式条件"
slug: "JDK并发包温故知新系列（五）—— 显式锁与显式条件"
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
# 显式锁-Lock与ReadWriteLock
JDK针对Lock的主要实现是ReentrantLock，ReadWriteLock实现是ReentrantReadWriteLock。本文主要介绍ReentrantLock。
## ReentrantReadWriteLock
两把锁共享一个等待队列，两把锁的状态都由一个原子变量表示，特有的获取锁和释放锁逻辑。
### ReentrantReadWriteLock的基本原理：
- 读锁的获取,只要求写锁没有被线程持有就可以获取，检查等待队列，逐个唤醒等待读锁线程，遇到等待写锁线程则停止.
- 读锁的释放,释放后，检查写锁和读锁是否被持有，若都没有被持有则唤醒下一个等待线程.
- 写锁的获取,只有读写锁都未被持有才会获取写锁。
- 写锁的释放，唤醒等待队列的下一个线程。
## ReentrantLock
### 主要方法
- void lock();获取锁，阻塞，不响应中断，但会记录中断标志位。
- void lockInterruptibly() throws InterruptedException;获取锁，响应中断
- boolean tryLock();获取锁，不阻塞，实时返回，一般需循环调用
- boolean tryLock(long time, TimeUnit unit) throws InterruptedException;在time的时间内阻塞获取锁，响应中断
- void unlock();释放锁
- Condition newCondition();新建显式条件

注： 这里的响应中断意思是若被其他线程中断（调用interrupt方法）会抛出InterruptedException异常。
### 原理支持
1. 依赖CAS方法,可重入实现用的计数就是用的原子变量。
2. 依赖LockSupport中的方法:

- public static void park()：放弃CPU执行权，CPU不在进行调度，响应中断，当有中断发生时，park会返回，线程中断状态会被设置，另外park也有可能无缘无故的返回，所以一般需要循环检查park的等待条件是否满足。。
- public static void parkNanos(long nanos)：在nanos纳秒内放弃CPU执行权
- public static void parkUntil(long deadline)：放弃执行权直到deadline时间（距离1970年毫秒数）。
- public static void unpark(Thread thread)：重新恢复线程，让其争夺CPU执行权。

### 实现基础AQS

AQS-AbstractQueuedSynchronizer（抽象队列同步器）。

ReadWriteLock在内部注入了AbstractQueuedSynchronizer，上锁和释放锁核心方法都在AQS类当中，AQS维护了两个核心变量，一个是state（当前可重入计数，初始值为0），一个是exclusiveOwnerThread（当前持有锁的线程Thread对象）。另外还维护了一个锁等待队列。

ReentrantLock构造方法传入的boolean值ture为公平锁，false为不公平锁。以不公平锁为例先讲一下上锁和释放锁的原理：

#### 上锁
1. 如果当前锁状态为0（未被锁），则使用CAS获得锁，并设置当前锁内的线程为自己。
2. 如果不为0，且持有锁的线程不是自己，则添加到队列尾部，并调用LockSupport中的park()方法放弃CPU执行权。直到当锁被释放的时候被唤醒，被唤醒后检查自己是否是第一个等待的线程，如果是且能获得锁，则返回，否则继续等待，这个过程中如果发生了中断，lock会记录中断标志位，但不会提前返回或抛出异常。
3. 如果不为0，但持有锁线程是自己，则直接将state加1。

#### 释放锁

就是将AQS内的state变量的值递减1，如果state值为0，则彻底释放锁，会将“加锁线程”变量也设置为null，同时唤醒等待队列中的第一个线程。

#### 公平锁
为什么说上面的是不公平锁，释放锁时不是唤醒队列中第一个线程吗？为什么还会出现不公平的情况了，原因在于如果刚好释放锁，此时有一个线程进来尝试获取锁，可能会存在插队的情况。
##### 公平锁原理
构造方法bollean传入true则代表的是公平锁，在获取锁方法中多了一个检查，意义是只有不存在其他等待时间更长的线程，它才会尝试获取锁。对比不公平锁，其整体性能比较低，低的原因不是这个检查慢，而是会让活跃线程得不到锁，进入等待状态，引起上下文切换，降低了整体的效率，

## 与synchrnized的区别
- tryLock可避免死锁造成的无限等待
- 拥有获取锁信息方法的各种API
- 可以响应中断
- 可以限时

建议： synchronized以前的效率不如显式锁，但现在的版本两者效率上几乎没有区别，所以建议能用synchronized就用synchronized，需要实现synchronized办不到的需求如以上区别时，再考虑ReentrantLock。


## 显示条件

### 什么是显示条件
与wait和notify对应，用于线程协作，通过Lock的Condition newCondition()方法创建对应显示锁的显示条件;
### 方法
主要方法是await()和signal()，await()对应于Object的wait()，signal()对应于notify，signalAll()对应于notifyAll()
### 用法示例
```
public class WaitThread extends Thread {
    private volatile boolean fire = false;
    private Lock lock = new ReentrantLock();
    private Condition condition = lock.newCondition();

    @Override
    public void run() {
        try {
            lock.lock();
            try {
                while (!fire) {
                    condition.await();
                }
            } finally {
                lock.unlock();
            }
            System.out.println("fired");
        } catch (InterruptedException e) {
            Thread.interrupted();
        }
    }

    public void fire() {
        lock.lock();
        try {
            this.fire = true;
            condition.signal();
        } finally {
            lock.unlock();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        WaitThread waitThread = new WaitThread();
        waitThread.start();
        Thread.sleep(1000);
        System.out.println("fire");
        waitThread.fire();
    }
}
```
当主线程调用fire方法时，子线程才被唤醒继续执行。







本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。