#!/bin/bash

echo "【创建类别】"
read -p "请输入类别名: " input
hugo new categories/"$input"/_index.md
read -p "按 Enter 键继续..."