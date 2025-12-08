#!/bin/bash

# 确保脚本遇到错误时退出
set -e

echo "--- 1. 正在查找需要转换的 UTF-16LE 文件... ---"

# 1. 查找并列出所有 utf-16le 文件，存储到列表中
find . -name "*.mq4" -exec file -i {} \; | grep 'charset=utf-16le' | awk -F ':' '{print $1}' > utf16_files.txt

echo "--- 2. 开始批量转换文件到 UTF-8 ---"
# 2. 批量转换这些文件为 UTF-8
while IFS= read -r file; do
  echo "  -> Converting $file"
  # iconv 转换：从 UTF-16LE 到 UTF-8，并通过临时文件安全覆盖
  iconv -f UTF-16LE -t UTF-8 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done < utf16_files.txt

# 3. 清理列表文件
//rm utf16_files.txt

echo "--- 转换完成！请执行 git status 查看变更。 ---"