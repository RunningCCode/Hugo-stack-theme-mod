#!/bin/bash

echo "【创建类别】"
read -p "请输入标签名: " input
hugo new tags/"$input"/_index.md
read -p "按 Enter 键继续..."