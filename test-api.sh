#!/bin/bash

BASE_URL="http://localhost:8080"

echo "========================================"
echo "Risk Service API 测试"
echo "========================================"
echo ""

# 测试 1: 健康检查
echo "测试 1: 健康检查"
echo "GET $BASE_URL/health"
curl -s "$BASE_URL/health"
echo ""
echo ""

# 测试 2: 低风险场景
echo "测试 2: 低风险场景（正常用户，工作时间，中国地区）"
echo "POST $BASE_URL/score"
curl -s -X POST "$BASE_URL/score" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "Mozilla/5.0",
    "geo": "CN",
    "time": "2024-01-01T12:00:00Z",
    "failedLoginCount": 0
  }' | jq .
echo ""

# 测试 3: 高风险场景
echo "测试 3: 高风险场景（多次失败登录，非中国地区，夜间，缺失UA）"
echo "POST $BASE_URL/score"
curl -s -X POST "$BASE_URL/score" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user456",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "",
    "geo": "US",
    "time": "2024-01-01T23:00:00Z",
    "failedLoginCount": 5
  }' | jq .
echo ""

# 测试 4: 管理员操作
echo "测试 4: 管理员操作（特权操作）"
echo "POST $BASE_URL/score"
curl -s -X POST "$BASE_URL/score" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "admin123",
    "roles": ["admin"],
    "resource": "users",
    "action": "admin",
    "ip": "1.2.3.4",
    "userAgent": "Mozilla/5.0",
    "geo": "CN",
    "time": "2024-01-01T12:00:00Z",
    "failedLoginCount": 0
  }' | jq .
echo ""

# 测试 5: 夜间访问
echo "测试 5: 夜间访问（22:00-06:00）"
echo "POST $BASE_URL/score"
curl -s -X POST "$BASE_URL/score" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user789",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "Mozilla/5.0",
    "geo": "CN",
    "time": "2024-01-01T02:30:00Z",
    "failedLoginCount": 0
  }' | jq .
echo ""

echo "========================================"
echo "测试完成！"
echo "========================================"

