# Amoure V2 后端实现文档 - 总览

## 文档概述

本文档集详细分析了 Amoure V2 后端系统的完整实现，涵盖了所有核心业务模块的架构设计、业务逻辑、数据模型和技术实现。文档基于实际代码分析，为开发团队提供深入的系统理解和维护指南。

## 系统架构总览

Amoure V2 采用分层架构设计，基于 Spring Boot 框架构建，集成了现代化的技术栈和设计模式：

### 技术栈
- **框架**: Spring Boot 2.x + Spring MVC + MyBatis-Plus
- **安全**: Sa-Token 权限认证框架
- **数据库**: MySQL + Redis
- **消息队列**: 事件驱动架构 (ApplicationEventPublisher)
- **文件存储**: 阿里云 OSS / 云存储服务
- **第三方服务**: 腾讯IM、内容审核服务

### 架构层次
```
┌─────────────────────────────────────────────────────────────────┐
│                        控制器层 (Controller Layer)                 │
│  AuthV2Controller | UserV2Controller | InteractionV2Controller  │
│  RecommendationV2Controller | ConversationV2Controller | ...     │
└─────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────┐
│                         服务层 (Service Layer)                    │
│   AuthService | UserService | UserInteractionService |         │
│   RecommendationService | PhotoService | VerificationService   │
└─────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────┐
│                      数据访问层 (Data Access Layer)               │
│  UserInfoMapper | UserProfileMapper | UserLikeMapper | ...     │
└─────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────┐
│                        数据存储层 (Data Storage)                   │
│              MySQL Database + Redis Cache + OSS Storage         │
└─────────────────────────────────────────────────────────────────┘
```

## 核心模块组织

### 按功能域划分的模块结构

#### 1. 用户管理域 (User Management Domain)
- **认证模块** (`01_Authentication_Module.md`)
  - 用户登录、注册、登出
  - 策略模式登录实现
  - Sa-Token 安全集成

- **用户管理模块** (`02_User_Management_Module.md`)
  - 用户信息管理
  - 档案更新和状态管理
  - 批量数据优化

- **照片管理模块** (`05_Photo_Management_Module.md`)
  - 照片上传、审核、展示
  - 多类型照片分类管理
  - 智能状态保持机制

#### 2. 社交互动域 (Social Interaction Domain)
- **用户交互模块** (`04_User_Interaction_Module.md`)
  - 点赞、匹配、拉黑功能
  - 心动列表管理
  - 事件驱动匹配逻辑

- **推荐系统模块** (`03_Recommendation_Module.md`)
  - 个性化推荐算法
  - 缓存优先策略
  - 实时推荐兜底

#### 3. 内容管理域 (Content Management Domain)
- **对话与动态模块** (`06_Conversation_Feed_Module.md`)
  - IM 对话管理
  - 动态内容发布
  - 腾讯IM集成

#### 4. 支撑服务域 (Supporting Services Domain)
- **其他核心模块** (`07_Additional_Modules.md`)
  - 认证验证服务
  - 举报管理系统
  - 作业调度框架
  - 工具类和配置

## 设计模式和架构原则

### 1. 设计模式应用

#### 策略模式 (Strategy Pattern)
```java
// 登录策略模式
public interface LoginStrategy {
    LoginUserInfo doLogin(LoginRequest request);
    boolean supports(LoginTypeEnum loginType);
}

// 具体实现
@Component("v2SmsLoginStrategy")
public class SmsLoginStrategy implements LoginStrategy;

@Component("v2EmailLoginStrategy") 
public class EmailLoginStrategy implements LoginStrategy;
```

#### 建造者模式 (Builder Pattern)
```java
// 响应对象构建
UserDetailResponse response = UserDetailResponse.builder()
    .userId(userInfo.getId().toString())
    .nickname(userProfile.getUsername())
    .age(userProfile.getAge())
    .build();
```

#### 事件驱动模式 (Event-Driven Pattern)
```java
// 事件发布
eventPublisher.publishEvent(new UserMatchedEvent(userId1, userId2, matchId));

// 事件监听
@EventListener
public void handleUserLoginEvent(UserLoginEvent event);
```

### 2. 架构原则

#### 单一职责原则 (Single Responsibility Principle)
- 每个服务类专注于单一业务领域
- 控制器只负责HTTP请求处理和参数验证
- 服务层专注业务逻辑实现

#### 依赖倒置原则 (Dependency Inversion Principle)
```java
// 依赖抽象而非具体实现
private final List<LoginStrategy> loginStrategies;
private final ApplicationEventPublisher eventPublisher;
```

#### 开闭原则 (Open-Closed Principle)
- 通过策略模式支持新登录方式扩展
- 通过事件机制支持功能解耦和扩展
- 通过接口抽象支持不同实现切换

## 数据模型设计

### 1. 核心实体关系

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  UserInfo   │────▶│ UserProfile │     │  UserPhoto  │
│             │     │             │◄────│             │
│ - id        │     │ - userId    │     │ - userId    │
│ - status    │     │ - nickname  │     │ - photoUrl  │
│ - lastLogin │     │ - age       │     │ - photoType │
└─────────────┘     │ - location  │     │ - status    │
                    └─────────────┘     └─────────────┘
                            ▲
                            │
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │  UserLike   │     │ UserMatch   │     │  UserBlock  │
    │             │     │             │     │             │
    │ - userId    │     │ - user1Id   │     │ - userId    │
    │ - targetId  │     │ - user2Id   │     │ - blockedId │
    │ - isMutual  │     │ - status    │     │ - createdAt │
    └─────────────┘     └─────────────┘     └─────────────┘
```

### 2. 值对象设计 (Value Objects)
- **UserTags**: 用户标签集合
- **QAAnswers**: 问答答案集合
- **LocationFlexibility**: 位置灵活性配置
- **RelationshipStatus**: 关系状态信息

### 3. 枚举类型系统
- **AccountStatus**: 账户状态枚举
- **PhotoType**: 照片类型枚举
- **ReviewStatus**: 审核状态枚举
- **InteractionType**: 交互类型枚举

## 性能优化策略

### 1. 数据库优化
```sql
-- 核心查询索引
CREATE INDEX idx_user_status ON user_info(account_status, machine_review_status);
CREATE INDEX idx_user_like_mutual ON user_likes(user_id, target_user_id, is_mutual);
CREATE INDEX idx_recommendation_time ON recommendations(user_id, created_at DESC);
```

### 2. 缓存策略
```
L1 缓存 (JVM本地缓存)
├── 用户会话缓存
└── 热点数据缓存

L2 缓存 (Redis分布式缓存)  
├── 推荐结果缓存 (1小时TTL)
├── 用户详情缓存 (30分钟TTL)
└── 交互数据缓存 (15分钟TTL)

L3 缓存 (数据库查询缓存)
├── MySQL查询缓存
└── 连接池缓存
```

### 3. 批量操作优化
- **批量用户查询**: `getBatchCompleteUserProfiles`
- **批量照片获取**: `batchGetApprovedUserPhotos`
- **批量认证状态**: `batchGetApprovedVerificationStatus`

## 安全设计

### 1. 认证与授权
```java
// Sa-Token 集成
@PostMapping("/api/v2/user/profile")
public Result<Boolean> updateProfile(@RequestBody UpdateRequest request) {
    Long currentUserId = StpUtil.getLoginIdAsLong(); // 自动获取当前用户
    // ...
}
```

### 2. 数据验证
```java
// 参数校验
public Result<UserDetailResponse> getUserDetail(
    @RequestParam @Valid String userId,
    @RequestParam(required = false) String fields
) {
    // 自动参数验证 + 业务逻辑验证
}
```

### 3. 权限控制
- **用户访问权限**: 严格的用户数据访问控制
- **操作权限验证**: 关键操作的权限预检查
- **数据脱敏**: 敏感信息的访问控制

## 监控和运维

### 1. 关键性能指标 (KPIs)
- **用户活跃度**: 日活跃用户数、用户留存率
- **匹配效率**: 匹配成功率、推荐点击率
- **系统性能**: API响应时间、系统吞吐量
- **业务转化**: 注册转化率、付费转化率

### 2. 监控体系
```java
// 业务监控
@Component
public class BusinessMetrics {
    // 用户注册监控
    public void recordRegistration(String source);
    
    // 匹配成功监控  
    public void recordMatch(Long userId1, Long userId2);
    
    // 系统异常监控
    public void recordException(String module, Exception e);
}
```

### 3. 日志策略
- **DEBUG**: 详细执行步骤，开发调试使用
- **INFO**: 关键业务节点，生产环境标准日志
- **WARN**: 业务异常警告，需要关注但不影响主流程
- **ERROR**: 系统错误，需要立即处理的异常情况

## 扩展性和未来规划

### 1. 微服务拆分规划
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   用户服务        │  │   推荐服务        │  │   交互服务        │
│ UserService     │  │RecommendService │  │InteractionSvc   │
│ AuthService     │  │                 │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   内容服务        │  │   消息服务        │  │   通知服务        │
│ PostService     │  │ ConversationSvc │  │NotificationSvc  │
│ PhotoService    │  │ ImService       │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### 2. 技术演进规划
- **容器化部署**: Docker + Kubernetes
- **服务网格**: Istio 服务治理
- **消息队列**: RabbitMQ/Kafka 异步处理
- **分布式追踪**: SkyWalking/Zipkin 链路追踪

### 3. 功能扩展方向
- **AI推荐**: 机器学习推荐算法优化
- **实时通讯**: WebSocket 实时消息推送
- **内容审核**: AI内容审核集成
- **国际化**: 多语言和多地区支持

## 最佳实践指南

### 1. 代码开发规范
- **命名规范**: 使用清晰、语义化的命名
- **注释规范**: 关键业务逻辑必须有详细注释
- **异常处理**: 统一的异常处理和错误响应
- **单元测试**: 核心业务逻辑必须有单元测试覆盖

### 2. 数据库设计规范
- **索引设计**: 基于查询模式设计合适索引
- **数据分页**: 大数据量查询必须分页处理
- **事务控制**: 合理控制事务边界和隔离级别
- **数据迁移**: 提供完整的数据库版本管理

### 3. 接口设计规范
- **RESTful API**: 遵循REST设计原则
- **版本管理**: 向前兼容的API版本管理
- **响应格式**: 统一的响应数据结构
- **错误码**: 标准化的错误码体系

## 文档使用指南

### 1. 面向开发者
- **新人入职**: 按模块顺序阅读，建立系统全貌认知
- **功能开发**: 重点关注相关模块的业务逻辑和数据模型
- **问题排查**: 结合日志和监控信息定位问题模块

### 2. 面向架构师
- **系统设计**: 参考架构模式和设计原则
- **性能优化**: 关注性能优化策略和最佳实践
- **扩展规划**: 基于现有架构进行扩展设计

### 3. 面向运维人员
- **部署配置**: 关注配置参数和环境依赖
- **监控告警**: 基于关键指标设置监控规则
- **故障处理**: 参考常见问题和处理方案

---

**文档维护说明**: 
本文档集基于 Amoure V2 系统的实际代码实现编写，随着系统演进会持续更新。建议开发团队定期审核和更新文档内容，确保文档与代码实现保持同步。