const express = require('express');
const app = express();

// 環境変数からポートとアプリ名を取得
const PORT = process.env.PORT || 3000;
const APP_NAME = process.env.APP_NAME || 'K8s Demo App';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

// リクエスト数カウンター
let requestCount = 0;
const startTime = Date.now();

// ミドルウェア: JSON解析
app.use(express.json());

// ミドルウェア: リクエストロギング
app.use((req, res, next) => {
  requestCount++;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// ルート: ホームページ
app.get('/', (req, res) => {
  res.json({
    message: `Welcome to ${APP_NAME}!`,
    version: APP_VERSION,
    environment: ENVIRONMENT,
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString()
  });
});

// ルート: ヘルスチェック
app.get('/health', (req, res) => {
  // 簡単なヘルスチェック
  const uptime = Date.now() - startTime;
  const health = {
    status: 'healthy',
    uptime: `${Math.floor(uptime / 1000)} seconds`,
    timestamp: new Date().toISOString(),
    version: APP_VERSION
  };

  res.status(200).json(health);
});

// ルート: Readiness probe
app.get('/ready', (req, res) => {
  // アプリが準備完了かチェック
  // 実際のアプリではDB接続などをチェック
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// ルート: メトリクス
app.get('/metrics', (req, res) => {
  const uptime = Date.now() - startTime;
  const metrics = {
    app_name: APP_NAME,
    version: APP_VERSION,
    environment: ENVIRONMENT,
    hostname: require('os').hostname(),
    total_requests: requestCount,
    uptime_seconds: Math.floor(uptime / 1000),
    memory_usage: {
      rss: `${Math.round(process.memoryUsage().rss / 1024 / 1024)} MB`,
      heapTotal: `${Math.round(process.memoryUsage().heapTotal / 1024 / 1024)} MB`,
      heapUsed: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)} MB`
    },
    cpu_usage: process.cpuUsage(),
    node_version: process.version,
    platform: process.platform
  };

  res.json(metrics);
});

// ルート: 環境変数確認
app.get('/config', (req, res) => {
  res.json({
    app_name: APP_NAME,
    version: APP_VERSION,
    environment: ENVIRONMENT,
    port: PORT
  });
});

// ルート: エラーテスト (デバッグ用)
app.get('/error', (req, res) => {
  res.status(500).json({
    error: 'Test error endpoint',
    message: 'This is intentionally returning an error'
  });
});

// 404ハンドラー
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    message: 'The requested resource was not found'
  });
});

// エラーハンドラー
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// グレースフルシャットダウン
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

// サーバー起動
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(50));
  console.log(`${APP_NAME} started successfully!`);
  console.log(`Version: ${APP_VERSION}`);
  console.log(`Environment: ${ENVIRONMENT}`);
  console.log(`Listening on: http://0.0.0.0:${PORT}`);
  console.log(`Hostname: ${require('os').hostname()}`);
  console.log('='.repeat(50));
});

module.exports = app;
