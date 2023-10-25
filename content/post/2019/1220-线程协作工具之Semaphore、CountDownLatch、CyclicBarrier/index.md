---

title: "线程协作工具之Semaphore、CountDownLatch、CyclicBarrier"
slug: "线程协作工具之Semaphore、CountDownLatch、CyclicBarrier"
description:
date: "2019-12-20"
lastmod: "2019-12-20"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["并发"]

---
# 各种线程协作工具
## 常见线程协作工具：
- 读写锁ReadWriteLock
- 信号量Semaphore
- 倒计时门栓CountDownLatch
- 循环栅栏CyclicBarrier
- 线程本地变量ThreadLocal

主要讲信号量Semaphore，倒计时门栓CountDownLatch， 循环栅栏CyclicBarrier
然后根据两个LeetCode题目来应用一下。

### 第一题：

三个不同的线程将会共用一个 Foo 实例。

线程 A 将会调用 one() 方法
线程 B 将会调用 two() 方法
线程 C 将会调用 three() 方法
请设计修改程序，以确保 two() 方法在 one() 方法之后被执行，three() 方法在 two() 方法之后被执行。

#### 原生解法

###### 应用场景及用法

基于notify/wait，所有的线程间通信类似通知的机制本质上都是notifyAll，多能用这个来实现。

```

class Foo {
  private static AtomicInteger flag = new AtomicInteger(0);
    private static Object Lock1 = new Object();
    public Foo() {

    }

    public void first(Runnable printFirst) throws InterruptedException {
        synchronized (Lock1){
            printFirst.run();
            flag.set(2);
            Lock1.notifyAll();
        }
    }

    public void second(Runnable printSecond) throws InterruptedException {
        synchronized (Lock1){
            while (flag.get() != 2){
                Lock1.wait();
            }
            printSecond.run();
            flag.set(3);
            Lock1.notifyAll();
        }
    }

    public void third(Runnable printThird) throws InterruptedException {
        synchronized (Lock1){
            while (flag.get() != 3){
                Lock1.wait();
            }
            printThird.run();
            flag.set(4);
            Lock1.notifyAll();
        }
    }
}

```

#### 倒计时门栓解法

###### 应用场景及用法
- 同时开始。初始化CountDownLatch计数为1，子线程与主线程共享CountDownLatch变量，先启动子线程，然后调用await方法，主线程调用countDown方法，即所有子线程同时开始。
- 主从协作。主线程依赖子线程运行结果，初始化CountDownLatch计数为开辟的子线程个数，然后调用await方法等待，子线程运行完逻辑之后调用countDown方法，达到主线程等待所有子线程完毕之后再继续运行的目的

```

class Foo {
    private CountDownLatch c2;
    private CountDownLatch c3;
    public Foo() {
         c2 = new CountDownLatch(1);
         c3 = new CountDownLatch(1);
    }
    
    public void first(Runnable printFirst) throws InterruptedException {
        printFirst.run();
        c2.countDown();
    }

    public void second(Runnable printSecond) throws InterruptedException {
        c2.await();
        printSecond.run();
        c3.countDown();
    }

    public void third(Runnable printThird) throws InterruptedException {
        c3.await();
        printThird.run();
    }
}

```

#### 信号量解法

##### 应用场景及用法
###### 用法:
传入许可数新键Semaphore对象，可设置是否公平

获取许可方法，有阻塞和非阻塞方式，有响应和不响应中断的方式

方法执行完释放许可
###### 应用场景
- 限制并发访问数量
- 也可用于线程间构建屏障，因为释放许可并不需要当前线程释放，任何线程都能调用release()方法释放许可。

```
public class Foo {
    //声明两个 Semaphore变量
    private Semaphore spa,spb;
    public Foo() {
        //初始化Semaphore为0的原因：如果这个Semaphore为零，如果另一线程调用(acquire)这个Semaphore就会产生阻塞，便可以控制second和third线程的执行
        spa = new Semaphore(0);
        spb = new Semaphore(0);
    }
    public void first(Runnable printFirst) throws InterruptedException {
            printFirst.run();
            //只有等first线程释放Semaphore后使Semaphore值为1,另外一个线程才可以调用（acquire）
            spa.release();
    }
    public void second(Runnable printSecond) throws InterruptedException {
            spa.acquire();
            printSecond.run();
            spb.release();
    }
    public void third(Runnable printThird) throws InterruptedException {
            spb.acquire();
            printThird.run();
    }
}

```

### 第二题：
现在有两种线程，氢 oxygen 和氧 hydrogen，你的目标是组织这两种线程来产生水分子。

存在一个屏障（barrier）使得每个线程必须等候直到一个完整水分子能够被产生出来。

氢和氧线程会被分别给予 releaseHydrogen 和 releaseOxygen 方法来允许它们突破屏障。

这些线程应该三三成组突破屏障并能立即组合产生一个水分子。

你必须保证产生一个水分子所需线程的结合必须发生在下一个水分子产生之前。

换句话说:

如果一个氧线程到达屏障时没有氢线程到达，它必须等候直到两个氢线程到达。
如果一个氢线程到达屏障时没有其它线程到达，它必须等候直到一个氧线程和另一个氢线程到达。
书写满足这些限制条件的氢、氧线程同步代码。

 

示例 1:

输入: "HOH"
输出: "HHO"
解释: "HOH" 和 "OHH" 依然都是有效解。
示例 2:

输入: "OOHHHH"
输出: "HHOHHO"
解释: "HOHHHO", "OHHHHO", "HHOHOH", "HOHHOH", "OHHHOH", "HHOOHH", "HOHOHH" 和 "OHHOHH" 依然都是有效解。


限制条件:

输入字符串的总长将会是 3n, 1 ≤ n ≤ 50；
输入字符串中的 “H” 总数将会是 2n；
输入字符串中的 “O” 总数将会是 n。




##### 循环栅栏的用法及应用场景
###### 用法
初始化CyclicBarrier，传入栅栏需拦住的线程数量（也可以再传入一个Runnable接口实现，由最后一个到达集合点的线程执行）,
###### 应用场景
多个线程互相等待，到达一个集合点，然后执行后续任务.

###### 解法：

```

class H2O {
    Semaphore semaphore4H = new Semaphore(2);
    Semaphore semaphore4O = new Semaphore(1);
    CyclicBarrier cyclicBarrier = new CyclicBarrier(3, new Runnable() {
       @Override
       public void run() {
           semaphore4H.release(2);
           semaphore4O.release(1);
       }
   });
    public H2O() {

    }

    public void hydrogen(Runnable releaseHydrogen) throws InterruptedException {
        try {
            semaphore4H.acquire();
            releaseHydrogen.run();
            cyclicBarrier.await();
        } catch (BrokenBarrierException e) {
            e.printStackTrace();
        }

    }

    public void oxygen(Runnable releaseOxygen) throws InterruptedException {
        try {
            semaphore4O.acquire();
            releaseOxygen.run();
            cyclicBarrier.await();
        } catch (BrokenBarrierException e) {
            e.printStackTrace();
        }
    }
}

```











本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。