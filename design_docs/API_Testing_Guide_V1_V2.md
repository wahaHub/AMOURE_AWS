# Amoure API 测试指南 (V1 & V2)

## 概述

Amoure后台系统现在同时支持V1和V2两套API，本文档提供完整的测试指南和Postman集合配置。

### 🔧 系统架构
- **V1 API**: 路径在 `/api/app/*` - 原有稳定API
- **V2 API**: 路径在 `/api/v2/*` - 新版本优化API  
- **基础设施**: AWS ECS + ElastiCache Redis + S3
- **认证**: Sa-Token + Redis Session

### 🌐 环境信息
- **本地开发**: http://localhost:8080
- **AWS开发环境**: [ECS ALB地址]
- **数据库**: PostgreSQL (AWS RDS)
- **缓存**: ElastiCache Redis (支持Session共享)
- **存储**: AWS S3 (替代阿里云OSS)

---

## 🔐 认证体系

### 认证流程
1. **获取Token**: 调用登录接口获取Sa-Token
2. **携带Token**: 后续请求Header中包含: `satoken: {token_value}`
3. **会话管理**: Redis存储，支持多服务器共享

### 免认证接口
以下接口无需Token:
- `/api/app/auth/login` - V1登录
- `/api/v2/auth/login` - V2登录
- `/api/app/sms/**` - 短信验证码
- `/actuator/**` - 系统监控
- `/swagger-ui/**` - API文档

---

## 📋 V1 API (Legacy) - `/api/app/*`

### 1. 认证相关
**Base URL**: `/api/app/auth`

| 接口 | 方法 | 路径 | 描述 |
|------|------|------|------|
| 登录 | POST | `/login` | 用户登录获取Token |
| 登出 | POST | `/logout` | 退出登录 |
| 注销 | POST | `/deactivate` | 注销账号 |
| 绑定微信 | POST | `/bindWechat` | 绑定微信账号 |
| 绑定Apple | POST | `/bindApple` | 绑定Apple账号 |
| 绑定手机 | POST | `/bindPhone` | 绑定手机号 |

### 2. 用户管理
**Base URL**: `/api/app/user`

| 接口 | 方法 | 路径 | 描述 |
|------|------|------|------|
| 用户信息 | GET | `/info` | 获取用户信息 |
| 更新资料 | PUT | `/update` | 更新用户资料 |
| 用户列表 | GET | `/list` | 获取用户列表 |

### 3. 交互功能
**Base URL**: `/api/app/interaction`

| 接口 | 方法 | 路径 | 描述 |
|------|------|------|------|
| 点赞/喜欢 | POST | `/like` | 用户互动操作 |
| 心动列表 | GET | `/likes` | 获取心动用户列表 |

### 4. 动态/帖子
**Base URL**: `/api/app/post`

| 接口 | 方法 | 路径 | 描述 |
|------|------|------|------|
| 发布动态 | POST | `/create` | 发布新动态 |
| 动态列表 | GET | `/list` | 获取动态列表 |
| 点赞动态 | POST | `/like` | 点赞动态 |

### 5. 文件上传
**Base URL**: `/api/app/file`

| 接口 | 方法 | 路径 | 描述 |
|------|------|------|------|
| 上传文件 | POST | `/upload` | 上传图片/文档 |

---

## 🚀 V2 API (New) - `/api/v2/*`

### 1. 认证相关 (V2)
**Base URL**: `/api/v2/auth`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 登录 | POST | `/login` | V2登录接口 | 优化响应结构 |

### 2. 用户管理 (V2)  
**Base URL**: `/api/v2/users`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 用户详情 | GET | `/{userId}` | 获取用户详细信息 | 增强数据结构 |
| 更新资料 | PUT | `/profile` | 更新用户资料 | 字段验证优化 |

### 3. 交互功能 (V2)
**Base URL**: `/api/v2/interactions`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 用户交互 | POST | `/` | 点赞/喜欢/拉黑等 | 统一交互接口 |
| 心动列表 | GET | `/likes` | 获取心动列表 | 支持筛选分页 |
| 拉黑列表 | GET | `/blocks` | 获取拉黑列表 | 新增功能 |

### 4. 推荐系统 (V2)
**Base URL**: `/api/v2/recommendations`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 推荐列表 | GET | `/` | 获取推荐用户 | 智能推荐算法 |

### 5. 动态/帖子 (V2)
**Base URL**: `/api/v2/feed`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 动态流 | GET | `/` | 获取个性化动态流 | 算法优化 |

### 6. 会话管理 (V2)
**Base URL**: `/api/v2/conversations`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 对话列表 | GET | `/` | 获取对话列表 | 实时更新 |
| IM对话 | GET | `/im` | 获取IM对话 | 消息状态管理 |

### 7. 认证验证 (V2)
**Base URL**: `/api/v2/verification`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 提交认证 | POST | `/submit` | 提交身份认证 | 多类型认证 |
| 认证状态 | GET | `/status` | 查看认证状态 | 详细进度 |

### 8. 工单系统 (V2)
**Base URL**: `/api/v2/workorders`

| 接口 | 方法 | 路径 | 描述 | 新特性 |
|------|------|------|------|--------|
| 创建工单 | POST | `/` | 创建客服工单 | 类型分类 |
| 工单列表 | GET | `/` | 获取工单列表 | 状态筛选 |

---

## 🧪 Postman测试配置

### 环境变量设置

创建两个环境：**Local** 和 **AWS Dev**

#### Local Environment
```json
{
  "base_url_v1": "http://localhost:8080/api/app",
  "base_url_v2": "http://localhost:8080/api/v2", 
  "token": "",
  "user_id": ""
}
```

#### AWS Dev Environment  
```json
{
  "base_url_v1": "https://[ALB-DNS]/api/app",
  "base_url_v2": "https://[ALB-DNS]/api/v2",
  "token": "",
  "user_id": ""
}
```

### 全局Headers
```json
{
  "Content-Type": "application/json",
  "satoken": "{{token}}"
}
```

---

## 📝 测试流程

### Phase 1: 基础认证测试

#### 1.1 V1 登录测试
```http
POST {{base_url_v1}}/auth/login
Content-Type: application/json

{
  "loginType": "SMS", 
  "mobile": "13800138000",
  "smsCode": "888888"
}
```

**期望响应:**
```json
{
  "code": 200,
  "data": {
    "userId": 123,
    "token": "xxx",
    "userInfo": {...}
  }
}
```

#### 1.2 V2 登录测试  
```http
POST {{base_url_v2}}/auth/login
Content-Type: application/json

{
  "loginType": "SMS",
  "mobile": "13800138000", 
  "smsCode": "888888"
}
```

### Phase 2: 用户功能测试

#### 2.1 V1 用户信息
```http
GET {{base_url_v1}}/user/info
satoken: {{token}}
```

#### 2.2 V2 用户详情
```http  
GET {{base_url_v2}}/users/{{user_id}}
satoken: {{token}}
```

### Phase 3: 交互功能测试

#### 3.1 V2 用户交互
```http
POST {{base_url_v2}}/interactions
satoken: {{token}}
Content-Type: application/json

{
  "targetUserId": 456,
  "type": "like"
}
```

#### 3.2 V2 心动列表
```http
GET {{base_url_v2}}/interactions/likes?type=liked_by_me&page=1&size=20
satoken: {{token}}
```

### Phase 4: 文件存储测试

#### 4.1 S3文件上传
```http
POST {{base_url_v1}}/file/upload
satoken: {{token}}
Content-Type: multipart/form-data

file: [选择文件]
folderPath: avatars
```

### Phase 5: Redis Session测试

#### 5.1 会话一致性验证
1. 在一个Postman环境中登录获取Token
2. 在另一个环境中使用相同Token
3. 验证会话是否在多服务器间共享

---

## 🔍 测试检查清单

### ✅ V1 API测试
- [ ] 登录获取Token
- [ ] 用户信息CRUD
- [ ] 文件上传功能  
- [ ] 交互功能
- [ ] 动态发布/列表

### ✅ V2 API测试  
- [ ] V2登录接口
- [ ] 用户详情获取
- [ ] 统一交互接口
- [ ] 推荐系统
- [ ] 会话管理
- [ ] 认证验证
- [ ] 工单系统

### ✅ 基础设施测试
- [ ] Redis Session共享
- [ ] S3文件存储
- [ ] 错误处理
- [ ] 认证授权
- [ ] 跨版本兼容性

---

## 🚨 已知问题

1. **健康检查端点缺失**: `/api/app/check/health` 路径不存在
2. **Sa-Token配置警告**: `activity-timeout` 配置项已过期

---

## 📦 Postman Collection 配置

### Pre-request Script (全局)
```javascript
// 自动设置认证Token
if (pm.collectionVariables.get("token")) {
    pm.request.headers.add({
        key: "satoken",
        value: pm.collectionVariables.get("token")
    });
}
```

### 登录后处理 Script
```javascript
// V1/V2登录接口的Tests脚本
if (pm.response.code === 200) {
    const response = pm.response.json();
    if (response.code === 200 && response.data) {
        // 保存Token到环境变量
        pm.collectionVariables.set("token", response.data.token || response.data.tokenValue);
        pm.collectionVariables.set("user_id", response.data.userId || response.data.id);
        console.log("Token saved:", pm.collectionVariables.get("token"));
    }
}
```

### V1 Collection 样例

#### 1. V1 短信登录
```json
{
  "name": "V1 SMS Login",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Content-Type", 
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"loginType\": \"SMS\",\n  \"mobile\": \"13800138000\",\n  \"smsCode\": \"888888\"\n}"
    },
    "url": {
      "raw": "{{base_url_v1}}/auth/login",
      "host": ["{{base_url_v1}}"],
      "path": ["auth", "login"]
    }
  }
}
```

#### 2. V1 获取用户信息
```json
{
  "name": "V1 Get User Info", 
  "request": {
    "method": "GET",
    "header": [
      {
        "key": "satoken",
        "value": "{{token}}"
      }
    ],
    "url": {
      "raw": "{{base_url_v1}}/user/info",
      "host": ["{{base_url_v1}}"],
      "path": ["user", "info"]
    }
  }
}
```

### V2 Collection 样例

#### 1. V2 登录
```json
{
  "name": "V2 Login",
  "request": {
    "method": "POST", 
    "header": [
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"loginType\": \"SMS\",\n  \"mobile\": \"13800138000\",\n  \"smsCode\": \"888888\"\n}"
    },
    "url": {
      "raw": "{{base_url_v2}}/auth/login",
      "host": ["{{base_url_v2}}"],
      "path": ["auth", "login"]
    }
  }
}
```

#### 2. V2 用户交互
```json
{
  "name": "V2 User Interaction",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Content-Type",
        "value": "application/json"
      },
      {
        "key": "satoken", 
        "value": "{{token}}"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"targetUserId\": 456,\n  \"type\": \"like\"\n}"
    },
    "url": {
      "raw": "{{base_url_v2}}/interactions",
      "host": ["{{base_url_v2}}"],
      "path": ["interactions"]
    }
  }
}
```

#### 3. V2 推荐列表
```json
{
  "name": "V2 Get Recommendations",
  "request": {
    "method": "GET",
    "header": [
      {
        "key": "satoken",
        "value": "{{token}}"
      }
    ],
    "url": {
      "raw": "{{base_url_v2}}/recommendations",
      "host": ["{{base_url_v2}}"],
      "path": ["recommendations"]
    }
  }
}
```

---

## 🔧 测试自动化

### Collection Runner 配置
1. **测试顺序**: 先V1登录 → V1功能测试 → V2登录 → V2功能测试
2. **数据驱动**: 使用CSV文件批量测试用户数据
3. **断言验证**: 检查响应码、数据结构、业务逻辑

### 监控指标
- **响应时间**: < 2秒
- **成功率**: > 95%
- **数据一致性**: V1/V2数据同步
- **Session共享**: 多实例会话一致

---

## 📞 问题反馈

如发现API问题请记录：
- 请求URL和参数
- 响应内容  
- 错误日志
- 期望行为

**关键测试重点:**
1. **V1/V2兼容性** - 确保两套API不冲突
2. **Redis Session** - 验证多服务器会话共享
3. **S3存储** - 测试文件上传下载功能
4. **认证系统** - Sa-Token在V1/V2中正常工作

---

*文档生成时间: 2025-09-13*  
*版本: 1.0*  
*作者: Amoure团队*