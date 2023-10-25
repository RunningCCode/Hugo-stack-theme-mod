---

title: "elasticsSearch学习笔记"
slug: "elasticsSearch学习笔记"
description:
date: "2019-08-06"
lastmod: "2019-08-06"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["es"]

---
# 一、前言
在分布式搜索引擎中，elasticsSearch逐渐变成一种标准了，其通过简单连贯的RESTful API让全文搜索变得简单并隐藏Lucene的复杂性。但底层还是使用Lucene来实现搜索功能。
# 二、核心概念
- index: 索引，是一类数据的抽象。
- type: 类型，是一类数据的具体抽象。更多情况一个index只对应一个type，type类似数据库中的一张表，并且在逻辑定义上也经常是1对1的关系，如elasticsSearch的type中存订单数据需要被搜索的字段，并且有一个字段是订单号，我们通过字段搜索到订单号后通常会在数据库再查一次，返回详情。
- document: 与Lucene里面的Document一样，就是表示可以被搜索的一条数据。
- field：与Lucene里面的field一样，表示的是document的每个字段。
- shard：elasticsSearch集群中存储数据的基本单位单位，一个索引有多个shard，在集群中不可以再次被分隔。
- 协调节点：集群中任意节点都可以接受客户端请求，接受请求的节点称为协调节点。
- segmentFile: shard中数据持久化的磁盘文件，一个shard对应多个segmentFile。
- fsync：Unix系统调用函数, 用来将内存缓冲区buffer中的数据存储到文件系统. 这里具体是指将文件缓存cache中的所有segment刷新到磁盘的操作。
# 三、基本原理
## 1.分布式策略
### （1）数据分布
索引创建可以指定分片的数量以及副本的数量，分片数量在创建之后无法改变，副本数量在之后可以改变，随着集群中节点的增加与删除，各个分片与副本会重新分配到各个节点中。分片和副本不会分配到一个节点上，分片通过hash算法平均分布在各个节点上，也可以自定义分片分布规则（让在集群的某些节点和某个节点创建分片），如通过自定义分片分布规则实现冷热分离提高性能。因为这种分片机制，我们可以通过增加集群中节点保证一台机器的分片不会太多提高搜索性能。
### （2）高可用
集群中会自动选举一个master节点，master节点的主要作用是管理集群，维护索引元数据等。master挂掉，集群重新选举master节点，master节点然后切换节点的身份为master。
### （3）写和读
写请求被路由到只往primaryShard写，然后会自动同步到replicaShard，读的话primaryShard和replicaShard读都可以。
## 2.基本原理
### （1）写入过程
协调节点接收到写入请求，将写入请求数据通过哈希算法路由到对应的shard的primaryShard上去。primaryShard的节点接收到请求数据，首先把segment fiel以及transLog（事务日志）写入自己的应用内存buffer当中，然后默认每隔1s,将buffer中的数据refresh数据到osCache（文件系统缓存）中。此时客户端就能查询到数据了。这个过程非常快，因为并没有涉及到数据的持久化（所以是准实时的）。当translog文件过大或达到一定时间（默认30分钟）会触发flush操作，flush操作会将segmentfile统一flush到磁盘文件，同时生成一个commitpoint,记录生成的segmentfile，然后清空translog。

注意：
- 故障恢复时，elasticsSearch将根据当前的commitpoint文件加载segmentFile（恢复搜索功能），然后通过translog事务日志，重做所有操作来恢复数据。
- 当数据尚且在buffer或osCache、translog也在osCache中时可能会丢数据，也可设定参数保证数据不丢失，但会牺牲吞吐量和性能。Elasticsearch 2.0之后, 每次写请求(如index、delete、update、bulk等)完成时, 都会触发fsync将translog中的segment刷到磁盘, 然后才会返回200 OK的响应;

### （2）删除数据的过程
删除有点类似伪删除，它先是通过将对应删除的记录写入磁盘上的.del文件，标志那些document被删除（如果此时搜索将会搜索到这些文档但不会返回）。当segment File多到一定程度时候，ES将执行物理删除操作, 彻底清除这些文档。
### （3）修改数据的过程
修改数据是先删后增，将原来的数据标志位deleted状态，然后新写入一个document。
### （4）读数据的过程（传入document的id）
通过document 的id hash到指定分片，然后根据负载均衡算法（默认轮询），路由到该分片节点之一读取数据。
### （5）搜索数据的过程
协调节点，把请求发送到所有拥有该索引的节点上去，但是对于主parimaryShard和replicaShard只会查其中之一，每个shard把查询结果的docId返回给协调节点。接着协调节点根据docId去实际存放数据的节点拉取docment，由协调节点进行合并、排序、分页等操作，然后返回给客户端。
# 四、如何性能优化
## 1.提高osCache覆盖率
elasticsSearch的高性能很大程度依赖于osCache的大小，毕竟走内存肯定比走硬盘快，所以可以提高filesystemCache的大小尽可能覆盖多的segment文件来提高性能。
## 2.数据预热
做一个子系统，每隔一段对热点数据搜索一下。因为osCache实际上还是基于LRU缓存的。
## 3.冷热分离
将热数据专门写一个索引，冷数据又单独写个索引，通过控制分片规则分放在不同的机器，因为热数据数据量少，没有冷数据的话，可以保证尽可能多的数据都在osCache里面，而因为冷数据不走热数据节点，避免oscache频繁切换数据的开销。
## 4.模型设计
写入es模型的就完成Type之间的关联，建立冗余字段（别在es中join）,因为如果在搜索中运用到了索引之间的关联效率是很低的。
## 5.避免深度分页
假设查询100页，会有1-100页的数据到协调节点来，然后协调节点才完成排序、筛选、分页，这是深度分页。应对方案有两种，一是我们的系统设计不允许翻那么深的页，或默认翻的越深，性能越差。二是利用elasticsSearch的ScrollAPI，ScrollAPI允许我们做一个初始阶段搜索并且持续批量从Elasticsearch里拉取结果直到没有结果剩下，缺点是只能一页一页往后翻，不能跳着翻。




本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。