# ベースイメージ
FROM node:18-alpine

# 作業ディレクトリを設定
WORKDIR /app

# package.json と (もし存在すれば) package-lock.json をコピー
# 本雛形には lockfile を同梱していない。実プロジェクトでは `npm ci` 利用を推奨する。
COPY package*.json ./

# 雛形のため npm install を使用 (lockfile 非依存)。
# 実プロジェクトでは package-lock.json を生成 (npm install したあと commit) し、
# 下記行を `RUN npm ci --omit=dev` に置き換えること。
RUN npm install --omit=dev --no-audit --no-fund

# アプリケーションのソースコードをコピー
COPY . .

# 非rootユーザーを作成
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# 非rootユーザーに切り替え
USER nodejs

# アプリケーションが使用するポートを公開
EXPOSE 3000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# アプリケーションを起動
CMD ["npm", "start"]
