echo "--- 开始对 utf16_files.txt 中的文件执行 BOM 清理 ---"

# 遍历列表中的每一个文件
while IFS= read -r file; do
  echo "  -> Cleaning BOM from $file"
  
  # 1. 移除文件开头的 UTF-8 BOM，并创建 .bak 备份
  # 注意：我们必须先检查文件是否存在，以防路径问题
  if [ -f "$file" ]; then
    sed -i.bak "1s/^\xef\xbb\xbf//" "$file"
    
    # 2. 移除备份文件 (如果存在)
    if [ -f "$file.bak" ]; then
        rm "$file.bak"
    fi
  else
    echo "  -> 警告: 文件 $file 未找到，跳过清理。"
  fi
done < utf16_files.txt

# 3. 清理文件列表本身
# rm utf16_files.txt

echo "--- 目标 BOM 清理完成！utf16_files.txt 已删除。 ---"