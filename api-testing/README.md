# Amoure API Testing Suite

## 🎯 概述

这是Amoure项目的完整API测试套件，包含V1和V2两套API的Postman集合、环境配置和自动化测试脚本。

## 📁 目录结构

```
api-testing/
├── README.md                          # 本文档
├── environments/                      # 环境配置
│   ├── Local-Development.postman_environment.json
│   └── AWS-Development.postman_environment.json
├── postman/                          # Postman集合
│   ├── Amoure-V1-API.postman_collection.json
│   ├── Amoure-V1-API-Part2.json
│   ├── Amoure-V2-API.postman_collection.json
│   └── Amoure-V2-Core-Features.json
├── test-data/                        # 测试数据
│   ├── users.csv
│   └── test-scenarios.json
└── scripts/                          # 自动化脚本
    ├── run-tests.sh
    └── health-check.js
```

## 🚀 快速开始

### 1. 导入Postman集合

**步骤：**
1. 打开Postman
2. 点击 **Import** 
3. 导入文件：
   - `environments/Local-Development.postman_environment.json`
   - `environments/AWS-Development.postman_environment.json`
   - `postman/Amoure-V1-API.postman_collection.json`
   - `postman/Amoure-V2-API.postman_collection.json`

### 2. 选择环境

- **本地测试**: 选择 "Local Development" 环境
- **AWS测试**: 选择 "AWS Development" 环境

### 3. 运行认证流程

**重要**: 必须先运行登录接口获取Token，再执行其他需要认证的接口

#### V1测试流程：
1. `🔐 Authentication` → `SMS Login`
2. 验证Token已自动保存
3. 运行其他V1接口

#### V2测试流程：
1. `🔐 V2 Authentication` → `V2 SMS Login`  
2. 验证Token已自动保存
3. 运行其他V2接口

## 🔧 环境配置详解

### 变量说明

| 变量名 | 描述 | 示例值 |
|--------|------|--------|
| `base_url` | 基础URL | `http://localhost:8080` |
| `base_url_v1` | V1 API基础路径 | `http://localhost:8080/api/app` |
| `base_url_v2` | V2 API基础路径 | `http://localhost:8080/api/v2` |
| `token` | 认证Token | 自动设置 |
| `user_id` | 当前用户ID | 自动设置 |
| `test_mobile` | 测试手机号 | `13800138000` |
| `test_sms_code` | 测试验证码 | `888888` |
| `target_user_id` | 目标用户ID | `2` |

### AWS环境配置

需要更新ALB地址：
1. 获取ECS ALB DNS名称：
   ```bash
   aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `amoure-dev`)].DNSName' --output text --region us-east-1
   ```

2. 更新环境变量中的`base_url`

## 📋 测试清单

### ✅ V1 API测试项目

#### 认证模块
- [ ] SMS登录
- [ ] 登出
- [ ] Token自动保存和使用

#### 用户模块  
- [ ] 获取用户信息
- [ ] 更新用户资料
- [ ] 用户列表查询

#### 交互模块
- [ ] 点赞用户
- [ ] 获取心动列表
- [ ] 交互历史

#### 文件模块
- [ ] 文件上传到S3
- [ ] 文件URL生成

### ✅ V2 API测试项目

#### 认证模块
- [ ] V2增强登录
- [ ] 设备信息追踪

#### 用户模块
- [ ] 用户详细信息
- [ ] 增强的资料结构

#### 交互模块
- [ ] 统一交互接口 (like/super_like/pass/block)
- [ ] 心动列表筛选
- [ ] 拉黑列表管理
- [ ] 匹配检测

#### 推荐模块
- [ ] 智能推荐列表
- [ ] 推荐算法验证

#### 会话模块
- [ ] 对话列表
- [ ] IM对话管理

### ✅ 基础设施测试

#### Redis Session
- [ ] Token跨服务器共享
- [ ] 会话过期处理
- [ ] 并发Session管理

#### S3存储
- [ ] 文件上传功能
- [ ] 预签名URL生成
- [ ] 文件删除功能

#### 错误处理
- [ ] 无效Token处理
- [ ] 参数验证
- [ ] 业务逻辑错误

## 🔬 高级测试功能

### 1. 自动Token管理

所有集合都包含自动Token管理：
- **登录时**: 自动保存Token到环境变量
- **请求时**: 自动添加Token到Header
- **过期时**: 提示重新登录

### 2. 响应验证

每个请求都包含：
- HTTP状态码验证
- 业务响应码验证  
- 数据结构验证
- 性能指标检查

### 3. 链式依赖

测试请求按依赖关系排序：
- 登录 → 获取用户信息 → 交互操作
- 自动传递必要参数
- 失败时中断后续测试

## 🎯 测试策略

### 冒烟测试
快速验证核心功能：
1. V1/V2登录
2. 用户信息获取
3. 基础交互操作

### 功能测试
完整业务流程验证：
1. 用户注册登录流程
2. 完整社交交互流程
3. 文件上传下载流程

### 集成测试
跨版本兼容性：
1. V1/V2数据一致性
2. Redis Session共享
3. S3存储一致性

## 📊 测试报告

使用Postman CLI运行并生成报告：

```bash
# 安装newman
npm install -g newman

# 运行V1测试
newman run postman/Amoure-V1-API.postman_collection.json \
  -e environments/Local-Development.postman_environment.json \
  --reporters html,cli \
  --reporter-html-export v1-test-report.html

# 运行V2测试  
newman run postman/Amoure-V2-API.postman_collection.json \
  -e environments/Local-Development.postman_environment.json \
  --reporters html,cli \
  --reporter-html-export v2-test-report.html
```

## 🚨 注意事项

### 测试环境准备
1. **本地测试**: 确保Spring Boot应用在localhost:8080运行
2. **AWS测试**: 确保ECS服务正常运行
3. **数据库**: 确保有测试用户数据
4. **Redis**: 确保Session功能正常

### 测试数据管理
- 使用固定的测试用户ID
- 避免污染生产数据
- 定期清理测试数据

### 安全注意
- 不要在集合中硬编码真实密码
- 使用环境变量管理敏感信息
- 定期更新测试Token

---

## 🆘 故障排除

### 常见问题

**1. Token无效**
- 检查登录接口是否成功
- 验证Token格式和有效期
- 确认Header名称为`satoken`

**2. 环境连接失败**
- 检查base_url配置
- 验证网络连接
- 确认服务运行状态

**3. 跨版本数据不一致**
- 检查数据库连接
- 验证Redis配置
- 确认V1/V2使用相同数据源

---

*最后更新: 2025-09-13*  
*维护者: Amoure团队*