# 零信任IAM系统 - 答辩PPT大纲

**项目名称：** 基于零信任架构的身份认证与授权系统设计与实现  
**答辩时间：** 预计15-20分钟  
**PPT页数：** 建议20-25页

---

## 第一部分：开场与项目介绍（3-4页，2分钟）

### 第1页：封面
- **标题**：基于零信任架构的身份认证与授权系统设计与实现
- **副标题**：Design and Implementation of Identity Authentication and Authorization System Based on Zero Trust Architecture
- **学生信息**：姓名、学号、专业、指导教师
- **日期**：2025年

### 第2页：目录
1. 项目背景与意义
2. 系统设计与架构
3. 核心功能实现
4. 系统部署与测试
5. 项目总结与展望

### 第3页：项目背景
**内容要点：**
- 传统安全模型的局限性
  - 基于边界防护，内网即可信
  - 静态授权策略，缺乏动态评估
  - 粗粒度访问控制（RBAC）
- 零信任架构的兴起
  - "永不信任，始终验证"
  - 动态风险评估
  - 细粒度访问控制（ABAC）

**配图建议：**
- 传统安全模型 vs 零信任模型对比图

### 第4页：研究意义
**理论意义：**
- 深入研究零信任架构在IAM中的应用
- 探索动态风险评估算法

**实践意义：**
- 设计并实现完整的零信任IAM系统
- 展示容器化部署和自动化运维

**应用价值：**
- 为企业级应用提供安全的IAM解决方案
- 易于扩展和定制

---

## 第二部分：系统设计与架构（5-6页，4分钟）

### 第5页：系统总体架构
**内容要点：**
- 微服务架构设计
- 四层架构：用户层、接入层、服务层、数据层

**配图建议：**
```
用户层：浏览器、API客户端、移动应用
    ↓
接入层：Web Portal (Go SSR)
    ↓
服务层：Keycloak、OPA、Risk Service
    ↓
数据层：MySQL
```

### 第6页：技术栈选型
**表格展示：**

| 层次 | 技术选型 | 说明 |
|------|---------|------|
| 容器编排 | Kubernetes | 容器编排平台 |
| 身份认证 | Keycloak | OIDC/OAuth2 |
| 授权引擎 | OPA | 策略引擎 |
| 风险评估 | Go 1.22 | 自研微服务 |
| Web门户 | Go SSR | 服务端渲染 |
| 数据库 | MySQL 8.0 | 关系型数据库 |
| 自动化部署 | Ansible | 配置管理 |

### 第7页：零信任流程设计
**流程图：**
```
用户请求
  ↓
1. 身份认证 (Keycloak)
  - OIDC登录
  - JWT令牌生成
  ↓
2. 风险评估 (Risk Service)
  - 多维度评分
  - 返回风险分数
  ↓
3. 授权决策 (OPA)
  - ABAC策略
  - 风险阈值检查
  ↓
允许/拒绝访问
```

### 第8页：核心组件设计
**四个核心组件：**

1. **Keycloak (身份认证)**
   - OIDC协议支持
   - JWT令牌管理

2. **Risk Service (风险评估)**
   - Go语言实现
   - 5个评分规则

3. **OPA (授权决策)**
   - ABAC策略引擎
   - Rego策略语言

4. **MySQL (数据存储)**
   - 用户数据
   - 持久化存储

### 第9页：数据库设计
**ER图或表结构：**
```sql
users 表：
- id (主键)
- username (唯一)
- email
- created_at

audit_logs 表（待实现）：
- id (主键)
- user_id
- action
- resource
- risk_score
- allowed
- timestamp
```

### 第10页：部署架构
**Kubernetes部署架构图：**
- Namespace: security
- 4个Deployment/StatefulSet
- Service网络配置
- PVC持久化存储

---

## 第三部分：核心功能实现（6-7页，5分钟）

### 第11页：功能模块概览
**四大功能模块：**
1. ✅ 身份认证模块
2. ✅ 风险评估模块
3. ✅ 授权决策模块
4. ✅ Web门户模块

### 第12页：身份认证实现
**Keycloak OIDC流程：**
- 用户登录流程
- JWT令牌生成
- 令牌验证机制

**代码示例：**
```go
// OIDC登录处理
func loginHandler(w http.ResponseWriter, r *http.Request) {
    authURL := oidcConfig.AuthCodeURL(state)
    http.Redirect(w, r, authURL, http.StatusFound)
}
```

### 第13页：风险评估算法
**5个评分规则：**

| 规则 | 条件 | 分数 |
|------|------|------|
| 失败登录 | failedLoginCount > 3 | +20-40 |
| 地理异常 | geo != "CN" | +20 |
| 特权操作 | action == "admin" | +20 |
| 缺失UA | userAgent == "" | +10 |
| 夜间访问 | 22:00-06:00 | +10 |

**分数范围：** 0-100

**代码示例：**
```go
func computeScore(req ScoreRequest) (int, []string) {
    score := 0
    reasons := []string{}
    
    if req.FailedLoginCount > 3 {
        score += min(20 + req.FailedLoginCount*5, 40)
        reasons = append(reasons, "many_failed_logins")
    }
    // ... 其他规则
    
    return score, reasons
}
```

### 第14页：授权策略实现
**OPA ABAC策略：**

```rego
package authz

default allow = false

# 允许读取订单（低风险）
allow {
  input.action == "read"
  input.resource == "orders"
  not high_risk
}

# 允许管理员操作（需要admin角色且低风险）
allow {
  input.action == "admin"
  roles_contains("admin")
  not high_risk
}

# 高风险定义
high_risk {
  input.score >= 70
}
```

### 第15页：Web门户实现
**功能特性：**
- 响应式设计
- OIDC登录集成
- 实时风险评估
- 结果可视化展示

**界面截图：**
- 首页表单
- 评估结果页

### 第16页：API接口设计
**Risk Service API：**
```
POST /score
请求：{userId, roles, resource, action, ...}
响应：{score: 35, reasons: [...]}
```

**OPA API：**
```
POST /v1/data/authz/allow
请求：{sub, roles, resource, action, score}
响应：{result: true/false}
```

### 第17页：容器化实现
**Dockerfile多阶段构建：**
```dockerfile
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY . .
RUN go build -o /out/risk-service

FROM gcr.io/distroless/base-debian12
COPY --from=build /out/risk-service /
ENTRYPOINT ["/risk-service"]
```

**优势：**
- 镜像体积小（< 20MB）
- 安全性高（distroless）
- 构建速度快

---

## 第四部分：系统部署与测试（4-5页，3分钟）

### 第18页：自动化部署
**Ansible部署流程：**
1. 初始化CentOS环境
2. 安装Kubernetes集群
3. 部署应用服务
4. 验证系统状态

**部署时间：** 25-30分钟

**命令示例：**
```bash
ansible-playbook -i inventory/hosts.ini playbooks/00-all.yml
```

### 第19页：测试用例
**5个测试场景：**

1. **正常访问（低风险）**
   - 预期：允许，分数 0-20

2. **地理异常访问**
   - 预期：允许，分数 20-30

3. **多次失败登录**
   - 预期：允许/拒绝，分数 40-60

4. **高风险访问**
   - 预期：拒绝，分数 ≥ 70

5. **管理员操作**
   - 预期：需要admin角色

### 第20页：测试结果
**测试统计：**
- 测试用例数：5个
- 通过率：100%
- 平均响应时间：< 100ms

**性能指标：**
- Risk Service响应时间：< 50ms
- OPA决策时间：< 30ms
- 系统可用性：99%+

### 第21页：系统演示
**现场演示内容：**
1. 访问Web Portal
2. 提交评估请求
3. 查看风险分数
4. 展示授权决策
5. 查看Kubernetes集群状态

**演示截图：**
- Web界面
- 评估结果
- kubectl命令输出

---

## 第五部分：项目总结与展望（3-4页，2分钟）

### 第22页：项目成果
**已完成的工作：**
- ✅ 完整的零信任IAM系统
- ✅ 4个核心微服务
- ✅ 自动化部署流程
- ✅ 完整的技术文档
- ✅ 5个测试用例

**项目指标：**
- 代码行数：~600行
- 文档行数：~3000行
- 配置文件：20+个
- 部署时间：25-30分钟

### 第23页：技术亮点
**创新点：**
1. **多维度风险评估**
   - 5个评分规则
   - 动态风险计算

2. **灵活的授权策略**
   - ABAC策略引擎
   - 易于扩展

3. **容器化部署**
   - Kubernetes编排
   - 自动化运维

4. **完整的文档**
   - 需求分析
   - 系统设计
   - 部署指南

### 第24页：不足与改进
**当前不足：**
- ⏳ 单节点部署，未实现高可用
- ⏳ 缺少监控告警系统
- ⏳ 审计日志功能待完善
- ⏳ HTTPS支持待实现

**改进方向：**
1. 多节点集群部署
2. 集成Prometheus监控
3. 完善审计日志
4. 添加HTTPS支持
5. 性能优化和压力测试

### 第25页：总结与致谢
**项目总结：**
- 成功实现了完整的零信任IAM系统
- 掌握了Kubernetes、微服务、IAM等关键技术
- 具备了系统设计和实现能力

**收获与体会：**
- 深入理解了零信任架构
- 掌握了容器化部署技术
- 提高了工程实践能力

**致谢：**
- 感谢指导老师的悉心指导
- 感谢同学们的帮助和支持

---

## 答辩准备建议

### 时间分配
- 项目介绍：2分钟
- 系统设计：4分钟
- 功能实现：5分钟
- 部署测试：3分钟
- 总结展望：2分钟
- **总计：16分钟**（留4分钟回答问题）

### 演讲技巧
1. **语速适中**：不要太快，确保评委能听清
2. **重点突出**：强调创新点和技术亮点
3. **逻辑清晰**：按照PPT顺序，层层递进
4. **准备演示**：提前测试系统，确保能正常运行
5. **预演练习**：至少完整演练2-3次

### 可能的提问及回答

**Q1: 为什么选择零信任架构？**
A: 传统的基于边界防护的安全模型已经无法满足现代企业的需求，零信任架构通过"永不信任，始终验证"的原则，提供了更高的安全性。

**Q2: 风险评分算法是如何设计的？**
A: 我设计了5个评分规则，包括失败登录次数、地理位置、特权操作、User-Agent和访问时间。每个规则根据风险程度赋予不同的分数，最终归一化到0-100的范围。

**Q3: 为什么使用Kubernetes？**
A: Kubernetes提供了强大的容器编排能力，支持自动化部署、健康检查、自动恢复等功能，非常适合微服务架构的部署和管理。

**Q4: 系统的可扩展性如何？**
A: 系统采用模块化设计，可以轻松添加新的风险评分规则和授权策略。同时，Kubernetes支持水平扩展，可以根据负载动态调整副本数。

**Q5: 如果要部署到生产环境，还需要做哪些工作？**
A: 需要实现多节点集群、添加HTTPS支持、集成监控告警系统、完善审计日志、进行性能优化和压力测试等。

**Q6: OPA和传统的RBAC有什么区别？**
A: RBAC是基于角色的访问控制，比较粗粒度。OPA支持ABAC（基于属性的访问控制），可以综合考虑用户、资源、环境等多个维度，提供更细粒度的授权决策。

---

## PPT制作建议

### 设计风格
- **配色方案**：蓝紫色渐变（#667eea → #764ba2）
- **字体选择**：
  - 标题：微软雅黑 Bold
  - 正文：微软雅黑 Regular
  - 代码：Consolas / Courier New
- **图表工具**：
  - 架构图：draw.io / Visio
  - 流程图：draw.io / ProcessOn
  - 数据图表：Excel / ECharts

### 内容要求
- **简洁明了**：每页不超过5个要点
- **图文并茂**：多用图表，少用文字
- **代码精简**：只展示关键代码片段
- **数据支撑**：用数据说话，展示测试结果

### 动画效果
- **适度使用**：不要过度使用动画
- **统一风格**：使用相同的动画效果
- **突出重点**：用动画强调关键内容

---

**祝答辩顺利！🎓**

