// シンプルなテストスクリプト
const http = require('http');

console.log('Running tests...\n');

// テスト用のサーバーを起動
process.env.PORT = 3001;
process.env.APP_NAME = 'Test App';
const app = require('./server');

// テストを実行
setTimeout(() => {
  const tests = [
    { path: '/', name: 'Home endpoint' },
    { path: '/health', name: 'Health check' },
    { path: '/ready', name: 'Readiness probe' },
    { path: '/metrics', name: 'Metrics endpoint' },
    { path: '/config', name: 'Config endpoint' }
  ];

  let passed = 0;
  let failed = 0;

  const runTest = (index) => {
    if (index >= tests.length) {
      console.log('\n' + '='.repeat(50));
      console.log(`Tests completed: ${passed} passed, ${failed} failed`);
      console.log('='.repeat(50));
      process.exit(failed > 0 ? 1 : 0);
      return;
    }

    const test = tests[index];
    http.get(`http://localhost:3001${test.path}`, (res) => {
      if (res.statusCode === 200) {
        console.log(`✓ ${test.name} - PASSED`);
        passed++;
      } else {
        console.log(`✗ ${test.name} - FAILED (Status: ${res.statusCode})`);
        failed++;
      }
      runTest(index + 1);
    }).on('error', (err) => {
      console.log(`✗ ${test.name} - FAILED (${err.message})`);
      failed++;
      runTest(index + 1);
    });
  };

  runTest(0);
}, 1000);
