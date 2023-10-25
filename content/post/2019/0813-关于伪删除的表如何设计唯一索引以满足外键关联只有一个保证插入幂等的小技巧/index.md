---

title: "关于伪删除的表如何设计唯一索引以满足外键关联只有一个保证插入幂等的小技巧"
slug: "关于伪删除的表如何设计唯一索引以满足外键关联只有一个保证插入幂等的小技巧"
description:
date: "2019-08-13"
lastmod: "2019-08-13"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["数据库"]

---
刚来公司时看到很多表都有一个valid_code字段，最开始还不懂是什么含义，问了同事才明白。


比如一张业务表有id，code，外键code,state,valid_code。state有两个状态表示数据是否存在，删除就是修改这个字段。

valid_code我们的规则是如果是有效数据我们设为0，如果删除这条数据我们需要将valid_code置为一个随机数也好uuid也好都行。

我们的背景是这张业务表只会关联这个外键所关联的实体的一次记录，并且用的是伪删除逻辑，通过改变state状态标志数据的删除或存在。

需求是需要控制这张表的插入操作的幂等性，。

valid_code正是通过数据库的唯一索引机制来控制的，我们将外键code和valid_code构建一条唯一索引，这样就能保证如果valid_code相同，就只有一个关联的外键实体。






本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。