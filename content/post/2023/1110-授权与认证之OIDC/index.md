---
title: "授权与认证认证"
slug: "授权与认证之认证"
description:
date: "2023-11-10T14:20:14+08:00"
lastmod: "2023-11-10T14:20:14+08:00"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["认证","OIDC"]

---

## OIDC-OpenID Connect
OIDC-OpenID Connect,是基于OAuth的扩展协议。
### 解决的问题
OAuth2.0只是描述授权的协议，并不关心客户端是否能验证用户是谁，而只关心获取用户数据的权利。
但OIDC提出了一个ID令牌的概念，这个ID令牌就是JSON Web Token（JWT）,携带OP-对应OAUTH中的认证服务器，认证用户之后获取的用户身份相关信息。
当RP(对应OAuth的客户端)收到这个ID令牌后,就知道了用户是谁，不光能解决授权问题，也能解决单点登录问题。
### OIDC中的角色
- OP OpenID Provider,OpenId提供商,对应OAUTH中的认证服务器
- RP Relying Party,依赖方，对应OAuth中的客户端
### 三种模式
对应的，OIDC中也规定了三种获取OpenId的流程
#### authorization code flow 授权码流
最常用的流程，主要用在web应用以及原生app场景。id token主要依靠后端而不是前端比如javascript和OP进行交互来获取。
##### 流程
1. 客户端准备一个包含所需请求参数的身份验证请求。
2. 客户端将请求发送到授权服务器。
3. 授权服务器对终端用户进行身份验证。
4. 授权服务器获得终端用户的同意/授权。
5. 授权服务器使用授权代码将终端用户重定向回客户端。
6. 客户端使用令牌端点的授权码请求响应。
7. 客户端接收响应，该响应在响应正文中包含ID Token和Access Token。
8. 客户端验证ID令牌并检索终端用户的唯一标识符。
#### implicit flow 隐式流
对于基于浏览器（javascript）的应用，它们往往没有后端，id token是直接从OP的重定向里面得到的（依靠前端代码）。
##### 流程
Client prepares an Authentication Request containing the desired request parameters.
1. 客户端准备一个包含所需请求参数的身份验证请求。
2. 客户端将请求发送到授权服务器。
3. 授权服务器对终端用户进行身份验证。
4. 授权服务器获得终端用户的同意/授权。
5. 授权服务器将终端用户发送回一个ID令牌，如果请求，还有一个访问令牌。
6. 客户端验证ID令牌并检索终端用户的唯一标识符。
#### hybrid flow 混合流
上面两种方式的综合，前后端独立获取id token，这种方式很少使用
##### 流程
1. 客户端准备一个包含所需请求参数的身份验证请求。
2. 客户端将请求发送到授权服务器。
3. 授权服务器对终端用户进行身份验证。
4. 授权服务器获得终端用户的同意/授权。
5. 授权服务器将终端用户发送回客户端，其中包含授权代码和一个或多个附加参数（取决于response_type）。
6. 客户端使用授权码请求授权服务器的令牌接口。
7. 客户端接收响应，该响应在响应正文中包含ID Token和Access Token。
8. 客户端验证ID令牌并检索终端用户的主题标识符。
### 总结
OIDC的授权码流和隐式流分别对应OAuth中的授权码模式和隐式模式授权模式,只不过多返回了个IDToken。而混合流则是隐式授权模式+授权码模式
在授权服务器响应授权码code和请求AccessToken时都可以响应ID_TOKEN和AccessToken。



### 参考文献

[Proof Key for Code Exchange by OAuth Public Clients](https://datatracker.ietf.org/doc/html/rfc7636)

### 版权信息

本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。