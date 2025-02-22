---

title: "分布式锁之Redis锁和ZK锁"
slug: "分布式锁之Redis锁和ZK锁"
description:
date: "2019-08-20"
lastmod: "2019-08-20"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["分布式锁"]

---
# 分布式锁
分布式系统中，常见的分布式锁有两种，一种是基于Redis实现的分布式锁，一种是基于ZooKeeper锁。本篇文章简要介绍下其原理及方案。
# Redis锁
## redis锁简单版本
### 上锁
先说上锁的命令，上锁的命令是：set {lockName} {randomVal} nx px 30000。

其中，nx 参数的意思是不存在锁的时候设置，px参数表示毫秒数，该条命令表示当不存在lockName键的时候，为其设置值为randomVal，并设置过期时间为30000毫秒。当redis中存在该键是redis返回nil。其他线程（包括其他机器）来获取锁的时候，可以用轮询来判断是否上锁成功，达到阻塞其他线程的目的。
### 解锁
解锁，我们需要实现的需求是不能删除掉其他线程设置的锁。因为某些情况比如锁超时，其他线程还是会获取到锁。所以必须先判断锁是不是自己设置的再进行删除，由于redis没有提供一个原子命令判断当前值是什么再进行删除，所以必须向redis传入lua脚本以确保解锁操作的原子性。解锁的原理是传入随机值进行解锁，脚本中会判断当前Key存不存在，存在的话再判断值是否与传入的随机值相等，相等则将其删除。

### 缺点
这种上锁方案有很明显的的缺点，如：

- 一是这种方案并不是很可靠，被上锁的redis宕机后容易丢数据，就算是配置了哨兵，也存在主备切换的时候可能丢数据。
- 二是不能实现公平锁。
- 三是轮询阻塞这种方式开销有点大。
- 四是不可实现线程重入。
- 没有续约机制

针对第一点，redis官方建议使用基于redisCluster的redlock（红锁）方案。这种方案核心要点就是需要在大多数redis节点上获取锁成功才算成功。但这就意味着开销变大了，并且针对红锁这种方案，网络上也有些大佬们提出质疑。
### 解决方案
这种简单版本的redis分布式锁方案并不能解决这些问题，如果要解决可以使用redission框架，redission运用了队列、redis发布订阅机制，看门狗机制，较为复杂的加锁、释放锁脚本解决了这些问题。redission支持可重入锁、公平锁、红锁等，并且将redis锁按JDK的Lock接口进行了封装，操作简单易用。

# ZK锁
## 简单版本的不公平ZK锁
### 上锁
以在ZooKeeper中成功创建临时节点为标识，创建成功则获取锁成功，创建失败则监听该节点，直到节点删除在尝试创建临时节点。
为什么使用临时节点？避免服务宕机，导致死锁问题。
### 解锁
删除节点即解锁成功。
### 方案缺点
这种方案的缺点是锁是不公平的，并且节点删除唤醒的其他监听线程比较多，效率没有接下来介绍的使用临时顺序节点的方案只唤醒下一个监听节点的方式高。
## 基于临时顺序节点的公平ZK锁
### 上锁
每次尝试获取锁都尝试创建一个临时顺序节点，并且获取当且父节点下的所有临时顺序节点，如果前面还有节点，则获取锁不成功，此时将主线程阻塞，监听前面一个节点被删除，如果被删除再唤醒主线程。反之如果当前创建的临时顺序节点前面没有节点则获取锁成功。
### 解锁
删除当前临时顺序节点即解锁成功。
### 解决的问题
这种方案实现的是公平锁，以前的并发竞争ZK临时节点创建，改为依次唤醒，降低了一定开销。
# 两种方案的对比
个人觉得对于分布式系统来说，redisCluster红锁的设计不是很优雅，感觉基于zookeeper集群高可用的zk锁更优雅一些。所以如果做技术选型的话，个人倾向zk锁。但是如果技术架构中没有搭建zookeeper，可能选择的是springcloud那一套，选择redisssion封装的redis锁也行。



本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。