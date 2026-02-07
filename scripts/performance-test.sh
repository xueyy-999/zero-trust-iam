#!/bin/bash
# 性能测试脚本 - Risk Service (Linux/macOS)
# 用途：测试 risk-service 的并发性能和响应时间

set -e

CONCURRENT=${1:-50}
REQUESTS=${2:-1000}
URL=${3:-"http://localhost:8080/score"}

echo "=== Risk Service Performance Test ==="
echo "Target URL: $URL"
echo "Concurrent Users: $CONCURRENT"
echo "Total Requests: $REQUESTS"
echo ""

# 检查是否安装了 ab (Apache Bench)
if ! command -v ab &> /dev/null; then
    echo "ERROR: Apache Bench (ab) is not installed"
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt-get install apache2-utils"
    echo "  CentOS/RHEL: sudo yum install httpd-tools"
    echo "  macOS: brew install httpd"
    exit 1
fi

# 创建测试数据
TEST_DATA=$(cat <<EOF
{
  "userId": "test-user",
  "roles": ["user"],
  "resource": "orders",
  "action": "read",
  "ip": "192.168.1.100",
  "userAgent": "PerformanceTest/1.0",
  "geo": "CN",
  "time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "failedLoginCount": 0
}
EOF
)

# 保存到临时文件
TEMP_FILE=$(mktemp)
echo "$TEST_DATA" > "$TEMP_FILE"

echo "[START] Running performance test..."
echo ""

# 运行 Apache Bench
ab -n "$REQUESTS" -c "$CONCURRENT" -p "$TEMP_FILE" -T "application/json" "$URL" > /tmp/ab-result.txt 2>&1

# 清理临时文件
rm -f "$TEMP_FILE"

# 解析结果
echo "=== Test Results ==="
grep "Requests per second" /tmp/ab-result.txt
grep "Time per request" /tmp/ab-result.txt
grep "Transfer rate" /tmp/ab-result.txt
echo ""

echo "=== Response Time Statistics ==="
grep "min\|mean\|max" /tmp/ab-result.txt | grep -v "across"
echo ""

echo "=== Percentage of requests served within a certain time ==="
grep "%" /tmp/ab-result.txt | tail -n 8
echo ""

# 检查性能是否达标
AVG_TIME=$(grep "Time per request" /tmp/ab-result.txt | head -n 1 | awk '{print $4}')
if (( $(echo "$AVG_TIME < 50" | bc -l) )); then
    echo "[EXCELLENT] Average response time < 50ms"
elif (( $(echo "$AVG_TIME < 100" | bc -l) )); then
    echo "[GOOD] Average response time < 100ms"
else
    echo "[WARNING] Average response time >= 100ms"
fi

echo ""
echo "=== Test Complete ==="
echo "Full results saved to: /tmp/ab-result.txt"
