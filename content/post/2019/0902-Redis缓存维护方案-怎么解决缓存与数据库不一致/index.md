---

title: "Redis缓存维护方案-怎么解决缓存与数据库不一致"
slug: "Redis缓存维护方案-怎么解决缓存与数据库不一致"
description:
date: "2019-09-02"
lastmod: "2019-09-02"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["Redis","缓存"]

---
一般常用的缓存方案有两种：
## 第一种
- 读的时候，先读缓存，缓存没有的话，读数据库，取出数据后放入缓存，同时返回响应。
- 更新的时候，先删除缓存，在更新数据库。
## 第二种
- 读的时候，先读缓存，缓存没有的话，读数据库，取出数据后放入缓存，同时返回响应。
- 更新的时候，先更新数据库，再删除缓存。

第二种是Cache Aside Pattern的原本思路，第一种也有在用。为什么会造成这两种分歧勒？原因在于：

- 第一种方案引入了缓存-数据库双写不一致的问题，即读数据（写缓存）与修改数据（写数据库）并发的情况下，在删除缓存后与修改数据数据库事务提交间隙，此时来了个读请求，而且读请求跑的比较快，一下就执行完了，就会把旧的数据刷到缓存里面，这样就导致了缓存中的数据直到下一次修改数据库之前肯定是与数据库不一致的
- 第二种方案也会导致双写不一致，此时缓存中无数据，先是一个读数据的请求，在查询和设置缓存间隙突然来了个数据更新请求，而且数据更新请求跑的很快，一下就执行完了，这时在读数据请求这个线程里面设置的值却是较老的值，这样就导致了缓存中的数据直到下一次修改数据库之前肯定是与数据库不一致的。另外第二种方案还有一个情况，在更新的时候，如果删除缓存失败（应用突然宕机或redis不可用），也会引入数据库和缓存不一致的问题。

总结一下两种方案的数据库缓存不一致场景：
- 第一种：a线程删除缓存 - b线程读数据库值为A并设置缓存值为A - a线程更新数据库值为B
- 第二种有两种情况：

1. a线程读数据库值为A - b线程更新数据库值为B - b线程删除缓存 - a线程设置缓存值为A；

2. a线程更新数据库值为B-由于网络延迟或宕机没有删除缓存-系统恢复后-b线程读缓存值为A。

另外还有一种导致缓存数据库不一致的原因还有读写分离，由于主从同步延迟，如果采取上面的两种方案，在极端情况下（从库读延迟），也有可能导致读请求写入缓存中的可能是旧数据。

## 解决方案
一般来说，我们对缓存的一致性要求并没有很高，只要求最终一致性，在较短的时间内不一致都是能忍受的。不论是前面哪一种方案，就算发生了，再来一次更新请求只要不发生同样的情况，缓存都会被再次刷成一致的。所以解决方案从简易到复杂就有缓存过期时间兜底，保证“更新数据库、删除缓存”和“读数据库并设置缓存”的之间串行化。
### 1.缓存过期时间兜底
就算更新操作非常少，没有更新操作，也有一个缓存过期时间，在缓存过期之后再次刷新缓存。
### 2.串行化更新数据库和写缓存
解决这个目标的关键主要目的是保证“删除缓存、更新数据库”和“读数据库并设置缓存”两者之间要保证串行化。
基于此，可能的优化有以下几种：
- 更新数据以及更新缓存整个过程用消息队列或加锁实现，即修改数据的时候通过mq通知修改，更新数据库、更新缓存。（适用于预热场景，对某些数据进行预热）。
- 更新数据的时候发送消息队列，更新数据库并删除缓存，读数据的时候如果没命中缓存先从数据库查出来返回，在发送消息队列，读数据库并设置缓存。
### 3.如果引入了读写分离
- 通过消费binlog日志消息，再次发送消息到mq去删除缓存，读数据若没有缓存的时候也发送消息到mq读数据并设置缓存。
- 通过延迟删缓存处理，但需控制延时时间，不能太长，导致这段时间缓存一直延迟。

## 今天看到的延时双删
网上的延时双删方案：
- 读的时候，先读缓存，缓存没有的话，读数据库，取出数据后放入缓存，同时返回响应。
- 更新的时候，先删除缓存，在更新数据库,然后延时删缓存。

个人思考：
这种方案在写线程更删除缓存到更新数据库这段时间内，插入读请求，则到下一次延时双删之前会导致数据库缓存不一致。

那么是否能够修改成：
- 读的时候，先读缓存，缓存没有的话，读数据库，取出数据后放入缓存，同时返回响应。
- 更新的时候，先更新数据库,再删除缓存，然后再延时删缓存。

相比前面谈的先更新数据库再删除缓存，第一是缓解数据库读库延迟的影响，第二是用延时删缓存缓解前面谈到的先更新数据库再删除缓存的缓存不一致情况，即缓存没有的情况下，读请求读数据库和删缓存操作中间来了个写请求一下子执行完了，导致缓存脏数据。使用延时双删，可以在延时后把脏数据删掉（一般延时时间比缓存过期时间短的多），除非读请求线程太慢太慢了，延时的时间过了，都还没有设置缓存（本事读请求一般比写请求快，所以这种情况我们可以一定程度忽略）。第三是为了控制避免不必要的延时，前面先即时删一次缓存，而不是次次都延时。

个人觉得这样，貌似更合理一些。






本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。