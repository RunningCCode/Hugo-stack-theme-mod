echo "【创建文章】"
read -p "请输入Slug: " input
current_year=$(date +'%Y')
current_date=$(date +'%m%d')
hugo new "post/$current_year/${current_date}-$input/index.md"
read -p "按 Enter 键继续..."