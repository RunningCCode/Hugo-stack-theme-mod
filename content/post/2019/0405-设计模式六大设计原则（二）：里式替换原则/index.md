---

title: "设计模式六大设计原则（二）：里式替换原则"
slug: "设计模式六大设计原则（二）：里式替换原则"
description:
date: "2019-04-05"
lastmod: "2019-04-05"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["设计模式"]

---
# 一、里氏替换原则的概念
里氏替换由Barbara Liskov女士提出，其给出了两种定义：
- > If for each object o1 of type S there is an object o2 of
  type T such that for all programs P defined in terms of T,the behavior of P is unchanged when o1 is substituted for o2 then S is a subtype of T.（如果对每一个类型为S的对象o1，都有类型为T的对象o2，使得以T定义的所有程序P在所有的对象o1都代换成o2时，程序P的行为没有发生变化，那么类型S是类型T的子类型。）

- > Functions that use pointers or references to base classes must be able to use objects of derived classes without knowing it.（所有引用基类的地方必须能透明地使用其子类的对象。）
# 二、里氏替换原则的含义
结合我的理解，我认为里氏替换有两层含义：
## （一）对于业务而言，能够运用多态透明的使用子类对象，增强代码复用
- **子类必须完全实现父类的方法，且实现的方法不能破坏父类的职责定义。**
  因为若破坏了职责定义后，对于通过父类引用操作子类对象的程序来讲，会破坏多态的封装，使得程序普适性降低。反之，则可以充分发挥多态的优点，提高代码的复用性。
## （二）父类引用的子类对象可以安全的替换为子类引用，增强代码扩展性
- **重载父类的方法时输入参数不能缩小**。
  在缩小的情况下，父类引用替换为子类引用的时候，可能会出现子类并没有重写父类同名同参数列表方法，但是却调用到了子类的方法。反之，一个程序模块的功能本来是通过父类引用操作子类对象来实现，但现在又面临扩展功能，且我们的需求没有普适到对所有的子类都扩展这个功能，我们希望通过重建（参数列表为父类型的通过重建子类）或修改（代码内实例引用为父类型的通过修改）来扩展这个方法，若程序符合里氏替换原则，这种扩展就是安全的。
# 三、里氏替换规范的行为——继承类与实现接口的方式对比
无论采取继承类或实现接口，我们都应该遵循里氏替换原则，保证职责定义不被破坏，父类引用能安全的被子类对象替换。那么这两种方式，在实际开发中，有什么需要注意的地方，应该怎么处理嘞
## （一）继承类
继承类的优点在于能够实现便捷、直观的共享代码，也能实现多态，但继承是把双刃剑，也有需要注意的地方：
### 1.父类内部实现之间依赖需警惕
基类代码:

```
public class Base {
    private static final int MAX_NUM = 1000;
    private int[] arr = new int[MAX_NUM];
    private int count;
    public void add(int number){
        if(count<MAX_NUM){
            arr[count++] = number;    
        }
    }
    public void addAll(int[] numbers){
        for(int num : numbers){
            add(num);
        }
    }
}
```
子类代码：
```
public class Child extends Base {
    
    private long sum;

    @Override
    public void add(int number) {
        super.add(number);
        sum+=number;
    }

    @Override
    public void addAll(int[] numbers) {
        super.addAll(numbers);
        for(int i=0;i<numbers.length;i++){
            sum+=numbers[i];
        }
    }
    
    public long getSum() {
        return sum;
    }
}
```
基类的add方法和addAll方法用于将数字添加到内部数组中，子类在此基础上添加了成员变量sum，用于表示数组元素之和。
```
public static void main(String[] args) {
    Child c = new Child();
    c.addAll(new int[]{1,2,3});
    System.out.println(c.getSum());
}
```
期望结果是1+2+3=6，可是结果却是12。为什么嘞，这是因为子类调用的父类的addAll方法依赖的add方法同时也被子类重写了，这里先addALL再自己统计一遍和相当于统计了两遍和。

此时若想正确输出需要我们把子类的addAll方法修改为：
```
@Override
public void addAll(int[] numbers) {
    super.addAll(numbers);
}
```
可是，这样又会产生新的一个问题，如果父类修改了add方法的实现为：
```
public void addAll(int[] numbers){
    for(int num : numbers){
        if(count<MAX_NUM){
            arr[count++] = num;    
        }
    }
}
```
那么输出又会变为0了。

从这个例子我们可以看出：
如果父类内部方法可能存在依赖，重写方法不仅仅改变了被重写的方法，同时另一个方法（假设为A）也导致出现了偏差，此时若按照原有的职责定义去调用父类的A方法，可能会导致出乎意料的结果。并且，若就算子类在编写时意识到了父类方法间的依赖，修改为正确实现，那么父类就无法自由的修改内部实现了。

这个问题产生的原因在于我们重写方法时往往容易只关注父类被重写方法的职责定义，而容易忽视父类其他方法是否存在依赖此方法。导致我们还是破坏了父类行为的职责定义，违反了里氏替换原则，其具有一定的隐蔽性。这就要求我们在编写子类实现的时候必须注意到其他方法受没受影响。同时依赖于内部方法的父类方法也不能随意修改，若被修改方法依赖的方法在其中一个子类被重写。那么就算父类在本类没有改变职责定义，实现结果并没有区别，但是若该子类调用，也有可能导致子类预期职责偏差的风险。
### 2.继承关系难以界定
继承反映的是‘是不是’的关系，假设有两个类，鸟类有会fly（）的方法，此时我们需要添加一个企鹅类，从常识上来看企鹅应该是鸟类的子类。但是由于企鹅的个性，他不能飞，此时就产生了矛盾，原本我们在父类定义了鸟会飞的职责，按照里氏替换原则，我们企鹅这个子类的fly（）方法必须符合职责定义，但是实际上无法符合，所以就无法实现继承，这与常识相违背。
### 3.存在单继承限制
继承只能继承一个类，相比接口缺少一定灵活性。
## （二）实现接口
实现接口相比继承就灵活多了，也没有那么多弊端，因为接口仅仅包含职责定义，并没有包含代码实现。其优点在于：
- 实现多态
- 同时子类可以实现多个接口，相比继承更为灵活

但是与继承类的方式相比，也有不足的地方，其不能实现代码的共享，虽然能够在实现类中通过注入公共类，用公共类实现代码共享，但是却没有继承便捷，直观。
## （三）建议
- 无论是继承类还是实现接口，都需要按父类职责定义实现方法
- 优先使用接口+注入而非继承
- 运用继承时，实现父类内部方法时最好不要互相依赖，若需要依赖，可以使用final修饰被依赖的方法，因为父类对于子类来说最好是封装好的，子类不考虑内部实现也能自由的重写父类方法，同时注意行为实现的普适性，只实现真正公共的部分。
- 运用继承时，子类尽量不要重写父类方法，若需重写也不能破坏父类的职责定义，需了解父类具体实现，了解父类的方法之间的依赖关系。






本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。