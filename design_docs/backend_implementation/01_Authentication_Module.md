# Amoure V2 后端实现文档 - 认证模块（Authentication Module）

## 模块概述

认证模块是 Amoure V2 系统的核心安全模块，负责用户的登录、注册、登出、注销等核心认证功能。该模块采用策略模式设计，支持多种登录方式，并集成了 Sa-Token 安全框架。

## 核心组件架构

### 1. 控制器层 (Controller Layer)
**文件位置**: `com.amoure.api.v2.controller.AuthV2Controller`

#### 主要职责
- 处理所有认证相关的HTTP请求
- 统一返回格式和错误处理
- IP地址获取和请求日志记录

#### 核心API端点
- `POST /api/v2/auth/login` - 用户登录
- `POST /api/v2/auth/logout` - 用户登出  
- `POST /api/v2/auth/register` - Web端用户注册
- `POST /api/v2/auth/deactivate` - 账户注销（软删除）
- `POST /api/v2/auth/activity` - 更新用户活跃状态
- `DELETE /api/v2/auth/user` - 删除用户（调用UserService）

#### 设计特点
- 使用 `@Valid` 注解进行参数校验
- 统一的异常处理和响应格式
- 自动获取客户端真实IP地址（支持代理）
- 集成 Sa-Token 进行会话管理

### 2. 服务层 (Service Layer)
**文件位置**: `com.amoure.api.v2.service.AuthService`

#### 核心功能

##### 登录处理流程
1. **参数验证和转换**: 将V2请求格式转换为兼容V1的格式
2. **策略选择**: 根据登录类型动态选择对应的登录策略
3. **用户状态验证**: 基于新数据模型验证用户账户状态
4. **事件发布**: 新用户注册事件和用户登录事件
5. **活跃状态更新**: 更新用户最后登录时间和活跃足迹
6. **日志记录**: 成功和失败的登录尝试记录

##### 登出和注销处理
- **安全登出**: 清理会话信息并记录日志
- **软删除注销**: 标记账户为删除状态，保留数据完整性
- **事件通知**: 发布相应的业务事件

#### 依赖注入组件
- `List<LoginStrategy> loginStrategies` - 所有登录策略实现
- `LoginLogService loginLogService` - 登录日志服务
- `UserInfoMapper userInfoMapper` - 用户信息数据访问
- `UserService userService` - 用户业务逻辑服务
- `ApplicationEventPublisher eventPublisher` - 事件发布器

### 3. 策略模式实现 (Strategy Pattern)

#### 策略接口
**文件位置**: `com.amoure.api.v2.service.strategy.LoginStrategy`

```java
public interface LoginStrategy {
    LoginUserInfo doLogin(LoginRequest request);
    boolean supports(LoginTypeEnum loginType);
}
```

#### 短信登录策略实现
**文件位置**: `com.amoure.api.v2.service.strategy.impl.login.SmsLoginStrategy`

##### 处理流程
1. **参数校验**: 验证手机号和验证码非空
2. **验证码校验**: 调用验证码服务验证SMS验证码
3. **用户验证**: 通过手机号查找或创建用户
4. **登录执行**: 构建登录响应信息

##### 核心依赖
- `VerifyCodeService verifyCodeService` - 验证码验证服务
- `LoginCommonService loginCommonService` - 登录通用逻辑服务

#### 扩展支持
- **邮箱登录策略**: 支持邮箱验证码登录
- **微信登录策略**: 支持微信第三方登录
- **其他社交登录**: 可扩展更多第三方登录方式

## 数据模型对接

### 新旧数据模型适配
认证服务实现了新V2数据模型与旧V1系统的兼容适配：

```java
// V2请求转换为V1请求格式
com.amoure.api.model.request.LoginRequest legacyRequest = new com.amoure.api.model.request.LoginRequest();
legacyRequest.setLoginType(loginTypeCode);
legacyRequest.setMobile(request.getMobile());
legacyRequest.setEmail(request.getEmail());
```

### 用户状态验证
基于新数据模型的用户状态验证逻辑：
- 账户状态检查 (`AccountStatus`)
- 机器审核状态检查 (`MachineReviewStatus`)
- 登录权限验证

## 事件驱动架构

### 用户注册事件
```java
public static class UserRegisteredEvent {
    private final Long userId;
    private final String nickname;  
    private final String avatar;
}
```

### 用户登录事件
```java
public static class UserLoginEvent {
    private final Long userId;
    private final LocalDateTime loginTime;
}
```

### 用户活跃事件
```java
public class UserActivityEvent {
    private final Long userId;
    private final String clientIp;
}
```

## 安全机制

### Sa-Token 集成
- **会话管理**: 自动处理用户会话状态
- **权限控制**: 支持基于角色和权限的访问控制  
- **多端登录**: 支持Web端和移动端同时登录
- **会话过期**: 自动处理会话超时和续期

### IP地址追踪
- 支持代理和负载均衡环境
- 优先级: X-Forwarded-For > X-Real-IP > RemoteAddr
- 用于安全审计和风控分析

### 错误处理
- 统一的异常处理机制
- 敏感信息过滤
- 详细的错误日志记录

## 性能和可扩展性

### 策略模式优势
- **解耦设计**: 登录逻辑与具体实现分离
- **易于扩展**: 新增登录方式只需实现Strategy接口
- **配置灵活**: 可通过配置动态启用/禁用登录方式

### 事件异步处理
- **非阻塞**: 登录流程不被后续处理阻塞
- **解耦**: 业务逻辑与附加处理分离
- **可靠性**: 事件失败不影响主流程

### 缓存策略
- 验证码缓存（Redis）
- 用户会话缓存（Sa-Token）
- 登录状态缓存

## 监控和日志

### 日志等级和内容
- **DEBUG**: 详细的处理步骤和参数
- **INFO**: 关键业务节点和成功操作
- **WARN**: 异常状态和警告信息
- **ERROR**: 错误异常和失败操作

### 关键监控指标
- 登录成功率
- 登录响应时间
- 验证码验证成功率
- 异常登录尝试频率

## 配置和部署

### 环境配置
- 验证码服务配置
- Sa-Token配置
- 数据库连接配置
- Redis缓存配置

### 扩展配置
- 登录策略启用/禁用
- 会话超时时间
- 验证码有效期
- IP白名单配置

## 与其他模块的交互

### 上游依赖
- **验证码服务**: 短信和邮箱验证码验证
- **用户服务**: 用户信息查询和更新
- **登录日志服务**: 登录行为记录

### 下游通知
- **推荐系统**: 用户登录事件触发推荐更新
- **消息系统**: 用户活跃状态更新
- **统计系统**: 用户行为数据收集

## 最佳实践和注意事项

### 安全最佳实践
1. 所有敏感操作都进行日志记录
2. 验证码使用完毕后立即失效
3. 登录失败次数限制和账户锁定
4. 异常IP访问检测和拦截

### 性能优化建议
1. 合理使用数据库事务
2. 避免在事务中进行外部服务调用
3. 异步处理非关键业务逻辑
4. 缓存热点数据减少数据库压力

### 代码维护指南
1. 新增登录方式需实现LoginStrategy接口
2. 事件处理器需要保证幂等性
3. 异常处理需要提供用户友好的错误信息
4. 关键路径需要添加详细的日志记录