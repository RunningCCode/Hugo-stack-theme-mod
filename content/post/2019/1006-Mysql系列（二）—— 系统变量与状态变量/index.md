---

title: "Mysql系列（二）—— 系统变量与状态变量"
slug: "Mysql系列（二）—— 系统变量与状态变量"
description:
date: "2019-10-06"
lastmod: "2019-10-06"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["mysql","数据库"]

---
# 系统变量
## 什么是系统变量
系统变量，就是Mysql针对自己程序运行的一些参数配置。例如通过系统变量我们可以指定诸如允许同时连入的客户端数量、客户端和服务器通信方式、表的默认存储引擎、查询缓存的大小等设置项。
## 系统变量的分类

- GLOBAL：全局变量，影响服务器的整体操作。
- SESSION：会话变量，影响某个客户端连接的操作。（注：SESSION有个别名叫LOCAL）

注：

1. 在服务器启动时，会将每个全局变量初始化为其默认值（可以通过命令行或选项文件中指定的选项更改这些默认值）。然后服务器还为每个连接的客户端维护一组会话变量，客户端的会话变量在连接时使用相应全局变量的当前值初始化。
2. 并不是所有系统变量都具有GLOBAL和SESSION的作用范围。有一些系统变量只具有GLOBAL作用范围，比方说max_connections，表示服务器程序支持同时最多有多少个客户端程序进行连接。有一些系统变量只具有SESSION作用范围，比如insert_id，表示在对某个包含AUTO_INCREMENT列的表进行插入时，该列初始的值。有一些系统变量的值既具有GLOBAL作用范围，也具有SESSION作用范围，比如我们default_storage_engine（存储引擎），而且其实大部分的系统变量都是这样的。

## 如何查看系统变量
命令：SHOW [GLOBAL|SESSION] VARIABLES [LIKE 匹配的模式]（不写GLOBAL或SESSION等同于SESSION）;
## 如何设置系统变量
- 通过启动选项设置，如命令：`mysqld --default-storage-engine=MyISAM --max-connections=10`，就是配置默认存储引擎为MyISAM，最大连接数为10。

注：在类Unix系统中，启动脚本有mysqld、mysqld_safe、mysql.server，其中mysqld代表直接启动mysql服务器程序，mysqld_safe会在此基础上启动一个监控进程，它会将服务器程序的出错信息和其他诊断信息重定向到某个文件中，产生出错日志，mysql.server也可以启动Mysql,使用命令`mysql.server start`,效果跟mysqld_safe一样，mysqld_multi是用于单机多个mysql服务端进程的启动，停止脚本。

每个MySQL程序都有许多不同的选项。例如，使用mysql --help可以看到mysql程序支持的启动选项，mysqld_safe --help可以看到mysqld_safe程序支持的启动选项。查看mysqld支持的启动选项有些特别，需要使用mysqld --verbose --help。

- 在my.cnf配置文件中添加启动选项

配置文件形如：

```
[server]
(具体的启动选项...)

[mysqld]
(具体的启动选项...)

[mysqld_safe]
(具体的启动选项...)

[client]
(具体的启动选项...)

[mysql]
(具体的启动选项...)

[mysqladmin]
(具体的启动选项...)
```

像这个配置文件里就定义了许多个组，组名分别是server、mysqld、mysqld_safe、client、mysql、mysqladmin。每个组下边可以定义若干个启动选项。

如在server组下面配置：

```
[server]
default-storage-engine=MyISAM
max-connections=10
```

表示默认存储引擎为MyISAM，最大连接数为10。

- 服务器程序运行过程中设置

命令： SET [GLOBAL|SESSION] 系统变量名 = 值 或 SET [@@(GLOBAL|SESSION).]系统变量名 = 值（不写GLOBAL或SESSION等同于SESSION）;

例如：

语句一：SET GLOBAL default_storage_engine = MyISAM;

语句二：SET @@GLOBAL.default_storage_engine = MyISAM;

**注：如果某个客户端改变了某个系统变量在`GLOBAL`作用范围的值，并不会影响该系统变量在当前已经连接的客户端作用范围为`SESSION`的值，只会影响后续连入的客户端在作用范围为`SESSION`的值。**

# 二、状态变量

## 什么是状态变量

MySQL服务器程序中维护了好多关于程序运行状态的变量，它们被称为状态变量，由于状态变量是用来显示服务器程序运行状况的，所以它们的值只能由服务器程序自己来设置，我们程序员是不能设置的。与系统变量类似，状态变量也有GLOBAL和SESSION两个作用范围的。比方说Threads_connected表示当前有多少客户端与服务器建立了连接，Handler_update表示已经更新了多少行记录。

## 查看状态变量命令
SHOW [GLOBAL|SESSION] STATUS [LIKE 匹配的模式]（不写GLOBAL或SESSION等同于SESSION;













本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。