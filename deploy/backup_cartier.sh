#!/bin/bash
# =============================================================================
# 奥贝通讯 · 每日自动备份脚本
# -----------------------------------------------------------------------------
# 整理自线上实际使用的 /root/backup_cartier.sh。
# ★ 已脱敏：数据库 root 口令一律用环境变量传入，切勿把真实口令写进仓库。
#
# 备份内容：
#   1) 主库（cartier）全量
#   2) 自定义代码（app/ extend/ 自研静态资源 public/demo public/dl）
#   3) 用户上传目录 public/uploads（相册）
#   4) Nginx 站点配置
# 保留策略：最近 14 天（KEEP=14），过期文件自动删除。
#
# 用法：
#   export MYSQL_PWD='你的数据库口令'      # 或改用 --defaults-extra-file
#   bash backup_cartier.sh
#   建议加入 crontab：  30 3 * * * /bin/bash /root/backup_cartier.sh
# =============================================================================
set -u
D=$(date +%Y%m%d_%H%M)
ROOT=/www/wwwroot/cartier.us.cc
OUT=/www/backup/cartier
KEEP=14
DB_USER=root
mkdir -p "$OUT/db" "$OUT/files"
LOG=$OUT/backup.log
echo "=== $D 开始 ===" >> "$LOG"

# 1) 数据库全量（--single-transaction 不锁表）
mysqldump -u"$DB_USER" --single-transaction --quick --routines cartier 2>/dev/null \
  | gzip > "$OUT/db/cartier_$D.sql.gz"
echo "  db: cartier=$(du -h "$OUT/db/cartier_$D.sql.gz" 2>/dev/null | cut -f1)" >> "$LOG"

# 2) 代码与配置（不含 vendor/thinkphp/runtime 等可重建内容）
tar czf "$OUT/files/code_$D.tar.gz" -C "$ROOT" \
  app extend public/static/admin public/static/js public/static/leaflet public/demo public/dl \
  --exclude='app/*/runtime' --exclude='*.log' 2>/dev/null
echo "  code: $(du -h "$OUT/files/code_$D.tar.gz" 2>/dev/null | cut -f1)" >> "$LOG"

# 3) 用户上传（相册等隐私数据）
tar czf "$OUT/files/uploads_$D.tar.gz" -C "$ROOT/public" uploads 2>/dev/null
echo "  uploads: $(du -h "$OUT/files/uploads_$D.tar.gz" 2>/dev/null | cut -f1)" >> "$LOG"

# 4) Nginx 站点配置
tar czf "$OUT/files/nginx_$D.tar.gz" -C /www/server/panel/vhost \
  nginx/cartier.us.cc.conf nginx/extension/cartier.us.cc 2>/dev/null
echo "  nginx conf: $(du -h "$OUT/files/nginx_$D.tar.gz" 2>/dev/null | cut -f1)" >> "$LOG"

# 5) 清理过期（保留最近 $KEEP 天）
find "$OUT/db" "$OUT/files" -type f -mtime +$KEEP -delete 2>/dev/null
chown -R www:www "$OUT" 2>/dev/null
echo "  保留策略: 最近 $KEEP 天 | 当前总占用: $(du -sh "$OUT" 2>/dev/null | cut -f1)" >> "$LOG"
echo "=== $D 完成 ===" >> "$LOG"
