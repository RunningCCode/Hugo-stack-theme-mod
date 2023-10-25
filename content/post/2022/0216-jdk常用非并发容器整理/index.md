---

title: "jdk常用非并发容器整理"
slug: "jdk常用非并发容器整理"
description:
date: "2022-02-16"
lastmod: "2022-02-16"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["并发"]

---
> 根据数据结构总结jdk常见的非并发容器，小结。

#### 数据结构
##### 基于数组
###### ArrayList
###### ArrayDeque(循环数组)
- 只需要双端队列效果时使用，比linkedList还要快
- 不提供索引方法
- 判断元素存不存在需遍历 效率低
###### EnumMap
- 特殊的 专门提供给键为enum使用的map
- 数组的索引和枚举的ordinal对应，get方法直接是先把枚举的ordinal获取到然后从数组里面获取值。
##### 基于链表
应用场景： 要求有序，两端访问情况多
###### LinkedList
- 可作队列（双端队列）
- 可作List
##### 基于hash（数组+链表（红黑树））
应用场景：不需要重复元素，随机访问
###### hashMap
- 在并发操作中扩容操作容易形成环，引起死循环，应当使用并发容器ConcurrentHashMap
######   hashSet
##### 基于排序二叉树
应用场景：需要有序
- TreeMap
- TreeSet
##### 基于链表+hash
应用场景：需要实现访问排序
- LinkedHashMap
- LinkedHashSet
##### 基于位向量
###### EnumSet
- 原理: 使用long 64位 保存枚举集合，二进制中的一个位表示一个元素的两种状态，0表示不包含该枚举值，1表示包含该枚举值。
- 两个实现RegularEnumSet(一个long保存数据)，JumboEnumSet（long数组保存）
###### BitSet
- 可以方便地对指定位置的位进行操作，与其他位向量进行位运算。
- 原理：内部使用long数组存储位向量，构造函数传入需要构造的位向量的位数。
##### 基于堆（完全二叉树）
###### 概念
- 要求最后一层不一定是满的，但要求最后一层几点从左到右是连续的，不能间隔
- 种类 分为最大堆（根节点的值最大）与最小堆（根节点的值最小）
- 存储结构 数组，因为堆是完全二叉树，所以每个节点的位置可以对应数组的下标
###### PriorityQueue
- 优先级队列
- 单端队列
- 应用：实时求中间值，实时求最大或最小值，优先级任务队列。







本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。