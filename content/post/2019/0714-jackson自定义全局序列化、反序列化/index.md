---

title: "jackson自定义全局序列化、反序列化"
slug: "jackson自定义全局序列化、反序列化"
description:
date: "2019-07-27"
lastmod: "2019-07-27"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["jackson","自定义序列化"]

---
需要自定义Jackson序列化和反序列化有两种方式，一种是全局定义，一种是非全局定义。先来看看全局定义。全局定义的步骤如下，以定义一个localDateTime的序列化和反序列化为例：
# 一、创建序列化类
创建一个序列化类然后继承JsonSerializer，重写serialize序列化方法。其中第一个参数localDateTime为JsonSerializer的泛型，表示的是被序列化的类型的值，第二个参数jsonGenerator表示的是用于输出生成的Json内容，第三个参数暂时没明白什么应用场景。重写方法一般是将想要序列化的字符串传入 jsonGenerator.writeString。
```
public final class LocalDateTimeSerializer extends JsonSerializer<LocalDateTime> {
    public static final LocalDateTimeSerializer INSTANCE = new LocalDateTimeSerializer();

    public LocalDateTimeSerializer() {
    }
    @Override
    public void serialize(LocalDateTime localDateTime, JsonGenerator jsonGenerator, SerializerProvider serializerProvider) throws IOException, JsonProcessingException {
        jsonGenerator.writeString(DateUtil.format(localDateTime, DateUtil.DateTimeFormatEnum.DATE_TIME_FORMAT_4));
    }
}
```
# 二、创建反序列化类
创建两个类，一个类继承JsonDeserializer，一个类继承KeyDeserializer,重写deserialize反序列化方法。参数jsonParser用于读取json内容的解析，deserializationContext可用于访问此有关反序列化的上下文（暂时也不知道怎么用），返回值则是JsonDeserializer的泛型对象，表示要反序列化的对象。一般用法是通过jsonParser.getText().trim()获取该字段json字符串，然后将该字符串转换为对象返回。
```
public final class LocalTimeDeserializer extends JsonDeserializer<LocalTime> {
    public static final LocalTimeDeserializer INSTANCE = new LocalTimeDeserializer();

    public LocalTimeDeserializer() {
    }
    @Override
    public LocalTime deserialize(JsonParser jsonParser, DeserializationContext deserializationContext) throws IOException, JsonProcessingException {
        String text = jsonParser.getText().trim();
        return LocalTime.parse(text, DateUtil.DATE_TIME_FORMATTER_6);
    }
}
```
```
public final class LocalDateTimeKeyDeserializer extends KeyDeserializer {
    public static final LocalDateTimeKeyDeserializer INSTANCE = new LocalDateTimeKeyDeserializer();

    public LocalDateTimeKeyDeserializer() {
    }
    @Override
    public Object deserializeKey(String s, DeserializationContext deserializationContext) throws IOException, JsonProcessingException {
        return StringUtils.isBlank(s) ? null : LocalDateTime.parse(s, DateUtil.DATE_TIME_FORMATTER_4);
    }
}
```
# 三、将两个类注册进入jackson核心对象objectMapper
```
@Bean
public ObjectMapper objectMapper(){
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.setVisibility(PropertyAccessor.ALL, JsonAutoDetect.Visibility.ANY);
        //不注释,会导致swagger报错
        //objectMapper.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL);
        //关闭日期序列化为时间戳的功能
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        //关闭序列化的时候没有为属性找到getter方法,报错
        objectMapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);
        //关闭反序列化的时候，没有找到属性的setter报错
        objectMapper.disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
        //序列化的时候序列对象的所有属性
        objectMapper.setSerializationInclusion(JsonInclude.Include.ALWAYS);
        //反序列化的时候如果多了其他属性,不抛出异常
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        //如果是空对象的时候,不抛异常
        objectMapper.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
        SimpleModule simpleModule = new SimpleModule();
        //json值序列化
        simpleModule.addSerializer(LocalDateTime.class, LocalDateTimeSerializer.INSTANCE);
        //json值反序列化
        simpleModule.addDeserializer(LocalDateTime.class, LocalDateTimeDeserializer.INSTANCE);
        //json键序列化
        simpleModule.addKeySerializer(LocalDateTime.class,LocalDateTimeSerializer.INSTANCE);
        //json键反序列化
        simpleModule.addKeyDeserializer(LocalDateTime.class, LocalDateTimeKeyDeserializer.INSTANCE);
        objectMapper.registerModule(simpleModule);
        return objectMapper;
    }
```
# 四、总结
以上，通过objectMapper的配置，完成了全局序列化、反序列化的配置，如果不需要全局则通过@jsonserialize或
@JsonDeserialize指定使用的序列化、反序列化类。







本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。