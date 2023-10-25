---

title: "idea快速生成entity、dao、service"
slug: "idea快速生成entity、dao、service"
description:
date: "2019-07-04"
lastmod: "2019-07-04"
image:
math:
license:
hidden: false
draft: false
categories: ["学习笔记"]
tags: ["数据库逆向"]

---
经常写一些业务代码，学会快速生成项目上业务代码所需的类entity、dao、service类对我们提高工作效率很有帮助，整理步骤如下：
## 一、准备工作
1. 在idea中连接数据库
2. 下载idea的CodeMaker插件
## 二、生成实体类
准备生成实体类的groovy脚本,这里我直接用写好了的脚本，因为不懂groovy，只能是在脚本上猜着改改，但实体类生成都差不多，猜着改改勉强能改到满足自己要求，下面把脚本贴上：
```
import com.intellij.database.model.DasTable
import com.intellij.database.model.ObjectKind
import com.intellij.database.util.Case
import com.intellij.database.util.DasUtil
import java.io.*
import java.text.SimpleDateFormat
import java.lang.*;

/*
 * Available context bindings:
 *   SELECTION   Iterable<DasObject>
 *   PROJECT     project
 *   FILES       files helper
 */
packageName = ""
typeMapping = [
        (~/(?i)bigint/)                             : "Long",
        (~/(?i)int|tinyint|smallint|mediumint/)      : "Integer",

        (~/(?i)bool|bit/)                        : "Boolean",
        (~/(?i)float|double|decimal|real/)       : "Double",
        (~/(?i)datetime|timestamp|date|time/)    : "Date",
        (~/(?i)blob|binary|bfile|clob|raw|image/): "InputStream",
        (~/(?i)/)                                : "String"
]


FILES.chooseDirectoryAndSave("Choose directory", "Choose where to store generated files") { dir ->
  SELECTION.filter { it instanceof DasTable && it.getKind() == ObjectKind.TABLE }.each { generate(it, dir) }
}

def generate(table, dir) {
  def className = javaName(table.getName(), true)
  def fields = calcFields(table)
  packageName = getPackageName(dir)
  PrintWriter printWriter = new PrintWriter(new OutputStreamWriter(new FileOutputStream(new File(dir, className + ".java")), "UTF-8"))
  printWriter.withPrintWriter {out -> generate(out, className, fields,table)}

//    new File(dir, className + ".java").withPrintWriter { out -> generate(out, className, fields,table) }
}

// 获取包所在文件夹路径
def getPackageName(dir) {
  return dir.toString().replaceAll("\\\\", ".").replaceAll("/", ".").replaceAll("^.*src(\\.main\\.java\\.)?", "") + ";"
}

def generate(out, className, fields,table) {
  out.println "package $packageName"
  out.println ""
  out.println "import com.yunhuakeji.component.base.annotation.doc.ApiField;"
  out.println "import com.yunhuakeji.component.base.annotation.entity.Code;"
  out.println "import com.yunhuakeji.component.base.bean.entity.base.BaseEntity;"
  out.println "import com.yunhuakeji.component.base.enums.entity.YesNoCodeEnum;"
  out.println "import lombok.Getter;"
  out.println "import lombok.Setter;"
  out.println "import lombok.ToString;"
  out.println "import io.swagger.annotations.ApiModel;"
  out.println "import io.swagger.annotations.ApiModelProperty;"
  out.println "import java.time.LocalDateTime;"
  out.println "import javax.persistence.Table;"
  out.println "import javax.persistence.Column;"
  //out.println "import import java.util.Date;"


  Set types = new HashSet()

  fields.each() {
    types.add(it.type)
  }

  if (types.contains("Date")) {
    out.println "import java.time.LocalDateTime;"
  }

  if (types.contains("InputStream")) {
    out.println "import java.io.InputStream;"
  }
  out.println ""
  out.println "/**\n" +
          " * @Description  \n" +
          " * @Author  chenzhicong\n" +
          " * @Date "+ new SimpleDateFormat("yyyy-MM-dd").format(new Date()) + " \n" +
          " */"
  out.println ""
  out.println "@Setter"
  out.println "@Getter"
  out.println "@ToString"
  out.println "@Table ( name =\""+table.getName() +"\" )"
  out.println "public class $className  extends BaseEntity {"
  out.println ""
  out.println genSerialID()
  fields.each() {
    if(!"universityId".equals(it.name)&&
            !"operatorId".equals(it.name)&&
            !"createdDate".equals(it.name)&&
            !"state".equals(it.name)&&
            !"stateDate".equals(it.name)&&
            !"memo".equals(it.name)){
      out.println ""
      // 输出注释
      if (isNotEmpty(it.commoent)) {
        out.println "\t/**"
        out.println "\t * ${it.commoent.toString()}"
        out.println "\t */"
      }

      if (it.annos != "") out.println "   ${it.annos.replace("[@Id]", "")}"

      // 输出成员变量

      out.println "\tprivate ${it.type} ${it.name};"
    }

  }

  // 输出get/set方法
//    fields.each() {
//        out.println ""
//        out.println "\tpublic ${it.type} get${it.name.capitalize()}() {"
//        out.println "\t\treturn this.${it.name};"
//        out.println "\t}"
//        out.println ""
//
//        out.println "\tpublic void set${it.name.capitalize()}(${it.type} ${it.name}) {"
//        out.println "\t\tthis.${it.name} = ${it.name};"
//        out.println "\t}"
//    }
  out.println ""
  out.println "}"
}

def calcFields(table) {
  DasUtil.getColumns(table).reduce([]) { fields, col ->
    def spec = Case.LOWER.apply(col.getDataType().getSpecification())

    def typeStr = typeMapping.find { p, t -> p.matcher(spec).find() }.value
    if("Date".equals(typeStr)){
      typeStr="LocalDateTime"
    }

    if(col.getName().toString().startsWith("PK_")){
      typeStr = "Long"
    }



    def comm =[
            colName : col.getName(),
            name :  javaName(col.getName(), false),
            type : typeStr,
            commoent: col.getComment(),
            annos: "\t@Column(name = \""+col.getName()+"\" )"]
    if(isNotEmpty(col.getComment())){
      comm.annos +="\r\n\t@ApiField(desc = \""+col.getComment()+"\")"
    }
 /*   if(col.getComment().startsWith("pk_")){
      comm.annos +="\r\n\t@Id"
    }*/


    if(Case.LOWER.apply(comm.name.toString()).startsWith("pk")){
      comm.annos +="\r\n\t@Id"
    }
    if("id".equals(Case.LOWER.apply(col.getName()))){
      comm.annos +=["@Id"]}
    fields += [comm]
  }
}

// 处理类名（这里是因为我的表都是以t_命名的，所以需要处理去掉生成类名时的开头的T，
// 如果你不需要那么请查找用到了 javaClassName这个方法的地方修改为 javaName 即可）
def javaClassName(str, capitalize) {
  def s = com.intellij.psi.codeStyle.NameUtil.splitNameIntoWords(str)
          .collect { Case.LOWER.apply(it).capitalize() }
          .join("")
          .replaceAll(/[^\p{javaJavaIdentifierPart}[_]]/, "_")
  // 去除开头的T  http://developer.51cto.com/art/200906/129168.htm
  s = s[1..s.size()-1]
  capitalize || s.length() == 1? s : Case.LOWER.apply(s[0]) + s[1..-1]
}

def javaName(str, capitalize) {
//    def s = str.split(/(?<=[^\p{IsLetter}])/).collect { Case.LOWER.apply(it).capitalize() }
//            .join("").replaceAll(/[^\p{javaJavaIdentifierPart}]/, "_")
//    capitalize || s.length() == 1? s : Case.LOWER.apply(s[0]) + s[1..-1]
  def s = com.intellij.psi.codeStyle.NameUtil.splitNameIntoWords(str)
          .collect { Case.LOWER.apply(it).capitalize() }
          .join("")
          .replaceAll(/[^\p{javaJavaIdentifierPart}[_]]/, "_")
  capitalize || s.length() == 1? s : Case.LOWER.apply(s[0]) + s[1..-1]
}

def isNotEmpty(content) {
  return content != null && content.toString().trim().length() > 0
}

static String changeStyle(String str, boolean toCamel){
  if(!str || str.size() <= 1)
    return str

  if(toCamel){
    String r = str.toLowerCase().split('_').collect{cc -> Case.LOWER.apply(cc).capitalize()}.join('')
    return r[0].toLowerCase() + r[1..-1]
  }else{
    str = str[0].toLowerCase() + str[1..-1]
    return str.collect{cc -> ((char)cc).isUpperCase() ? '_' + cc.toLowerCase() : cc}.join('')
  }
}

static String genSerialID()
{
  return "\tprivate static final long serialVersionUID =  "+Math.abs(new Random().nextLong())+"L;"
}
```

把脚本保存为groovy格式然后移动到项目目录中入图所示：

![](https://oscimg.oschina.net/oscnet/ed5de6116f7c38043f4ad9b53346a4edb02.jpg)

接下来就可以直接在idea右侧database中对需要生成实体类的表执行脚本了，如图所示，点击右侧的database-选择表右键-选择scripted-Extensions-然后选择添加的脚本

![](https://oscimg.oschina.net/oscnet/d42330aae6e357a22e6ec1bea521d2848a2.jpg)

之后选择生成的目录为entity目录：
![](https://oscimg.oschina.net/oscnet/902d5543b2823b61e6d757faa631159d68b.jpg)

之后类就生成好了：

![](https://oscimg.oschina.net/oscnet/ff7cdee65fb56475454596db3ca6a210930.jpg)

其中继承的类，引入的包，注解都可以在脚本中修改。

## 三、生成service、serviceImpL和dao
与实体生成不一样，这里使用codemaker插件功能生成。先在codemaker中添加模板。
进入settings，搜索codemaker，进入codemaker相关配置项。

![](https://oscimg.oschina.net/oscnet/9e4e88cc29bfbd7d151bdae78ec460f0a90.jpg)

添加所需要的模板，以生成Dao为例：上面只需要改className，这里写入${class0.className}Dao，表示取输入的类的类名后面加个Dao

![](https://oscimg.oschina.net/oscnet/877eb0c8026146c3db8d175d07d7e003f44.jpg)

模板代码也是使用现成的，自己根据需要猜着改就行，模板代码如下：
dao/mapper模板：
```
########################################################################################
##
## Common variables:
##  $YEAR - yyyy
##  $TIME - yyyy-MM-dd HH:mm:ss
##  $USER - 陈之聪
##
## Available variables:
##  $class0 - the context class, alias: $class
##  $class1 - the selected class, like $class1, $class2
##  $ClassName - generate by the config of "Class Name", the generated class name
##
## Class Entry Structure:
##  $class0.className - the class Name
##  $class0.packageName - the packageName
##  $class0.importList - the list of imported classes name
##  $class0.fields - the list of the class fields
##          - type: the field type
##          - name: the field name
##          - modifier: the field modifier, like "private",or "@Setter private" if include annotations
##  $class0.allFields - the list of the class fields include all fields of superclass
##          - type: the field type
##          - name: the field name
##          - modifier: the field modifier, like "private",or "@Setter private" if include annotations
##  $class0.methods - the list of class methods
##          - name: the method name
##          - modifier: the method modifier, like "private static"
##          - returnType: the method returnType
##          - params: the method params, like "(String name)"
##  $class0.allMethods - the list of class methods include all methods of superclass
##          - name: the method name
##          - modifier: the method modifier, like "private static"
##          - returnType: the method returnType
##          - params: the method params, like "(String name)"#
########################################################################################
package $class0.PackageName;

import com.mapper.GeneralMapper;


/**
 *
 * @author chenzhicong
 * @version $Id: ${ClassName}.java, v 0.1 $TIME $USER Exp $$
 */
public interface  $ClassName extends GeneralMapper<${class0.className}>{



}
```
service、serviceImpl操作方法类似，就不赘述了，按照上面的方法分别建立模板就行。

模板建立好了之后，我们就只需要在刚刚生成的实体类中按快捷键Alt+Insert（或者右键-Generate）-选择对应模板-然后选择生成目录：

![](https://oscimg.oschina.net/oscnet/da459e2cf8c0ebe3114bedd39f2b499dd3d.jpg)

这里好像只能生成在entity同目录，不能选择其他目录，需要我们移动到对应的包。
生成后的dao如图所示：

![](https://oscimg.oschina.net/oscnet/f89dff8c8408951f3f1db714d4093c1da3b.jpg)

## 总结
至此，代码就生成完毕了，这个方法让自己初次接触到了groovy脚本，不过还是不会怎么用，不过凑合复制粘贴别人的脚本也能改改。先就这样吧，以后遇到相关该脚本的问题再百度。










本文原载于[runningccode.github.io](https://runningccode.github.io)，遵循CC BY-NC-SA 4.0协议，复制请保留原文出处。