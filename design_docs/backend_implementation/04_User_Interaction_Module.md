# Amoure V2 后端实现文档 - 用户交互模块（User Interaction Module）

## 模块概述

用户交互模块是 Amoure V2 社交功能的核心，负责处理用户之间的所有互动行为，包括喜欢、超级喜欢、跳过、拉黑等操作，以及相应的匹配逻辑和心动列表管理。该模块采用事件驱动设计，支持复杂的业务逻辑和高性能的批量数据处理。

## 核心组件架构

### 1. 控制器层 (Controller Layer)
**文件位置**: `com.amoure.api.v2.controller.InteractionV2Controller`

#### 主要职责
- 处理用户交互相关的HTTP请求
- 统一的参数校验和响应格式化
- 交互类型转换和权限控制

#### 核心API端点

##### 用户交互操作
```java
@PostMapping
public Result<Map<String, Object>> interactUser(@RequestBody @Valid InteractUserReq request)
```

**支持的交互类型**:
- `like` - 普通点赞
- `super_like` - 超级点赞
- `dislike/pass` - 跳过/不喜欢
- `block` - 拉黑用户
- `unblock` - 解除拉黑

**响应格式**:
```json
{
  "targetUserId": 12345,
  "type": "like",
  "isMatched": true,
  "timestamp": "2025-09-06T10:30:00"
}
```

##### 心动列表查询
```java
@GetMapping("/likes")
public Result<Map<String, Object>> getXindongList(
    @RequestParam String type,
    @RequestParam(required = false) String filter,
    @RequestParam(required = false) String cursor,
    @RequestParam(defaultValue = "20") Integer limit
)
```

**列表类型**:
- `liked_by_me` - 我点赞的用户
- `i_liked` - 点赞我的用户  
- `mutual_liked` - 相互点赞的用户

**筛选条件**:
- `all` - 全部用户
- `recent_online` - 最近在线
- `recent_active` - 最近活跃
- `profile_complete` - 资料完整
- `verified` - 已认证用户

##### 拉黑列表管理
```java
@GetMapping("/blocks")
public Result<Map<String, Object>> getBlockList(
    @RequestParam(defaultValue = "1") Integer page,
    @RequestParam(defaultValue = "20") Integer size
)
```

### 2. 服务层 (Service Layer)
**文件位置**: `com.amoure.api.v2.service.UserInteractionService`

#### 核心业务逻辑

##### 交互操作处理
**主方法**: `interactWithUser`
```java
public InteractionResult interactWithUser(Long userId, Long targetUserId, InteractionType type)
```

**执行流程**:
1. **业务验证** (`validateInteraction`)
   - 防止自我交互
   - 验证目标用户存在性和活跃状态
   - 检查拉黑关系

2. **交互执行** (基于类型分发)
   - LIKE: `executeLike(userId, targetUserId, LIKE_TYPE_REGULAR)`
   - SUPER_LIKE: `executeLike(userId, targetUserId, LIKE_TYPE_SUPER)`
   - PASS: `executePass(userId, targetUserId)`
   - BLOCK: `executeBlock(userId, targetUserId)`
   - UNBLOCK: `executeUnblock(userId, targetUserId)`

3. **结果构建** (`InteractionResult`)
   - 交互类型和时间戳
   - 匹配状态（仅点赞操作）
   - 目标用户ID

##### 点赞和匹配逻辑
**核心方法**: `executeLike`

**匹配算法**:
1. **重复检查**: 防止重复点赞同一用户
2. **点赞记录创建**: 
   ```java
   UserLike userLike = UserLike.builder()
       .userId(userId)
       .targetUserId(targetUserId) 
       .likeType(likeType)
       .isMutual(false)
       .createdAt(LocalDateTime.now())
       .build();
   ```
3. **相互点赞检测**: 查询反向点赞记录
4. **匹配处理**:
   - 更新双方点赞记录为相互状态
   - 创建匹配记录 (`UserMatch`)
   - 发布匹配事件 (`UserMatchedEvent`)

**匹配记录设计**:
```java
UserMatch match = UserMatch.builder()
    .user1Id(Math.min(userId, targetUserId))  // 较小ID作为user1
    .user2Id(Math.max(userId, targetUserId))  // 较大ID作为user2
    .status(MATCH_STATUS_SUCCESS)
    .createdAt(LocalDateTime.now())
    .build();
```

##### 心动列表查询优化
**主方法**: `getLikeUserList`

**查询策略**:
1. **分页查询**: MyBatis-Plus分页插件
2. **数据类型映射**:
   - `TYPE_LIKE_ME`: 查询received likes（别人点赞我）
   - `TYPE_I_LIKE`: 查询sent likes（我点赞别人）
   - `TYPE_MUTUAL`: 查询mutual likes（相互点赞）

3. **批量数据获取**: `batchGetUserData`
   - 并行查询用户信息、档案、认证状态、头像
   - 内存优化的数据结构 (`UserDataPair`)

4. **智能过滤**: `applyLikeUserFilter`
   - 在线状态过滤
   - 活跃状态过滤
   - 资料完整度过滤
   - 认证状态过滤

#### 依赖组件注入
```java
private final UserLikeMapper userLikeMapper;           // 点赞记录DAO
private final UserMatchMapper userMatchMapper;         // 匹配记录DAO
private final UserInfoMapper userInfoMapper;           // 用户信息DAO
private final UserProfileMapper userProfileMapper;     // 用户档案DAO
private final UserBlockMapper userBlockMapper;         // 拉黑记录DAO
private final UserVerificationMapper userVerificationMapper; // 认证记录DAO
private final ApplicationEventPublisher eventPublisher;      // 事件发布器
private final PhotoService photoService;               // 照片服务
private final VerificationService verificationService; // 认证服务
```

## 数据模型设计

### 实体模型

#### UserLike - 用户点赞实体
```java
public class UserLike {
    private Long id;
    private Long userId;      // 点赞用户ID
    private Long targetUserId; // 被点赞用户ID
    private Integer likeType; // 点赞类型：1-普通，2-超级点赞
    private Boolean isMutual; // 是否相互点赞
    private LocalDateTime createdAt;
    
    public void makeMutual() {
        this.isMutual = true;
    }
}
```

#### UserMatch - 用户匹配实体
```java
public class UserMatch {
    private Long id;
    private Long user1Id;     // 用户1ID（较小值）
    private Long user2Id;     // 用户2ID（较大值）
    private String status;    // 匹配状态
    private LocalDateTime createdAt;
}
```

#### UserBlock - 用户拉黑实体
```java
public class UserBlock {
    private Long id;
    private Long userId;       // 拉黑用户ID
    private Long blockedUserId; // 被拉黑用户ID
    private LocalDateTime createdAt;
}
```

### 枚举定义

#### 交互类型枚举
```java
public enum InteractionType {
    LIKE("like", 1),
    SUPER_LIKE("super_like", 2),
    PASS("pass", 3),
    BLOCK("block", 4),
    UNBLOCK("unblock", 5);
}
```

#### 心动列表类型枚举
```java
public enum XindongType {
    LIKED_BY_ME("liked_by_me", "我点赞的"),
    I_LIKED("i_liked", "点赞我的"),  
    MUTUAL_LIKED("mutual_liked", "相互点赞");
}
```

#### 过滤条件枚举
```java
public enum XindongFilter {
    ALL("all", "全部"),
    RECENT_ONLINE("recent_online", "最近在线"),
    PROFILE_COMPLETE("profile_complete", "资料完整"),
    RECENT_ACTIVE("recent_active", "最近活跃"),
    VERIFIED("verified", "已认证"),
    RECOMMENDED("recommended", "推荐");
}
```

## 性能优化策略

### 批量数据获取优化

#### UserDataPair数据结构
```java
public static class UserDataPair {
    private final UserInfo userInfo;
    private final UserProfile userProfile;
    private final List<UserVerification> verifications;
    private final String avatarUrl;
}
```

**优势**:
- **内存友好**: 封装相关数据减少对象创建
- **一次查询**: 批量获取所有需要的数据
- **类型安全**: 强类型封装避免类型错误

#### 批量查询策略
**方法**: `batchGetUserData`

**优化技术**:
1. **并行查询**: 同时查询用户信息、档案、认证、头像
2. **Map索引**: 使用HashMap快速定位数据
3. **连接复用**: 高效利用数据库连接池
4. **内存控制**: 合理控制批量查询大小

### 分页性能优化

#### MyBatis-Plus集成
```java
Page<UserLike> mybatisPage = new Page<>(page, size);
IPage<UserLike> likePage = userLikeMapper.findReceivedLikes(mybatisPage, userId);
```

**优化特性**:
- **数据库分页**: 利用数据库LIMIT优化
- **索引友好**: 查询条件优化利用索引
- **流式处理**: 大数据量时支持流式处理

#### 过滤器性能优化
**内存过滤 vs 数据库过滤**:
- **简单条件**: 数据库层过滤（WHERE子句）
- **复杂逻辑**: 内存层过滤（业务逻辑）
- **混合策略**: 数据库初筛 + 内存精筛

## 事件驱动架构

### 事件定义和处理

#### 用户匹配事件
```java
public static class UserMatchedEvent {
    private final Long userId1;
    private final Long userId2;
    private final String matchId;
    private final LocalDateTime matchTime;
}
```

**处理逻辑**:
- 发送匹配通知给双方用户
- 更新用户匹配统计数据
- 触发后续推荐算法优化

#### 用户拉黑事件
```java
public static class UserBlockedEvent {
    private final Long userId;
    private final Long targetUserId;
    private final LocalDateTime timestamp;
}
```

**处理逻辑**:
- 清理相关推荐记录
- 更新推荐算法黑名单
- 记录用户行为统计

#### 用户跳过事件
```java
public static class UserPassedEvent {
    private final Long userId;
    private final Long targetUserId;
    private final LocalDateTime timestamp;
}
```

**处理逻辑**:
- 推荐算法负反馈
- 用户偏好学习
- 推荐质量优化

### 异步事件处理
**设计原则**:
- **非阻塞**: 主业务流程不等待事件处理
- **可靠性**: 事件处理失败不影响核心功能
- **幂等性**: 重复事件处理保持结果一致
- **监控性**: 事件处理状态可观测

## 业务规则和约束

### 交互业务规则

#### 自我交互防护
```java
if (userId.equals(targetUserId)) {
    throw new SelfInteractionException("不能与自己交互");
}
```

#### 重复点赞处理
```java
UserLike existingLike = userLikeMapper.findByUserIdAndTargetUserId(userId, targetUserId);
if (existingLike != null) {
    log.warn("用户已点赞过该用户: userId={}, targetUserId={}", userId, targetUserId);
    return true; // 返回现有匹配状态
}
```

#### 拉黑关系检查
```java
private boolean isUserBlocked(Long userId, Long targetUserId) {
    return userBlockMapper.existsBlockBetweenUsers(userId, targetUserId);
}
```

### 匹配业务逻辑

#### 双向匹配确认
**匹配成立条件**:
1. 用户A点赞用户B
2. 用户B之前已点赞用户A
3. 双方都处于活跃状态
4. 双方没有拉黑关系

#### 匹配记录规范化
**ID排序策略**:
```java
.user1Id(Math.min(userId, targetUserId))  // 保证较小ID在前
.user2Id(Math.max(userId, targetUserId))  // 避免重复匹配记录
```

## 异常处理体系

### 自定义异常类

#### 交互相关异常
```java
public static class SelfInteractionException extends RuntimeException
public static class TargetUserNotFoundException extends RuntimeException  
public static class TargetUserInactiveException extends RuntimeException
public static class UserBlockedException extends RuntimeException
```

### 异常处理策略
1. **参数异常**: 返回400错误和具体错误信息
2. **权限异常**: 返回403错误和权限提示
3. **业务异常**: 返回业务错误码和用户友好提示
4. **系统异常**: 返回500错误和通用错误信息

## 常量定义和配置

### 业务常量
**文件位置**: `com.amoure.api.v2.constants.UserInteractionConstants`

```java
// 点赞类型常量
public static final Integer LIKE_TYPE_REGULAR = 1;
public static final Integer LIKE_TYPE_SUPER = 2;

// 匹配状态常量  
public static final String MATCH_STATUS_SUCCESS = "matched";

// 心动列表类型常量
public static final String TYPE_LIKE_ME = "i_liked";
public static final String TYPE_I_LIKE = "liked_by_me"; 
public static final String TYPE_MUTUAL = "mutual_liked";

// 过滤条件常量
public static final String FILTER_ALL_XINDONG = "all";
public static final String FILTER_RECENT_ONLINE_OLD = "recent_online";
public static final String FILTER_RECENT_ACTIVE_OLD = "recent_active";
```

### 日志常量
```java
// 日志模板常量
public static final String LOG_USER_INTERACTION = "用户交互操作: userId={}, targetUserId={}, type={}";
public static final String LOG_USER_MATCHED = "用户匹配成功: userId={}, targetUserId={}, matchId={}";
public static final String LOG_GET_LIKE_USER_LIST = "获取心动用户列表: userId={}, type={}, filter={}, page={}, size={}";
```

## 监控和运维

### 关键监控指标
1. **交互频率**: 各类交互操作的频次统计
2. **匹配成功率**: 点赞转化为匹配的比例
3. **响应时间**: 各接口的平均响应时间
4. **异常率**: 各类异常的发生频率
5. **用户活跃度**: 用户交互行为的活跃程度

### 日志记录策略
**DEBUG级别**:
- 方法入口参数
- 中间处理步骤
- 查询条件和结果

**INFO级别**:
- 关键业务节点
- 匹配成功事件
- 重要状态变更

**WARN级别**:
- 业务异常情况
- 重复操作警告
- 性能警告

**ERROR级别**:
- 系统异常
- 数据一致性问题
- 外部服务调用失败

## 最佳实践和注意事项

### 数据一致性
1. **事务控制**: 关键操作使用数据库事务
2. **幂等设计**: 重复请求保持结果一致
3. **并发处理**: 使用乐观锁处理并发更新
4. **数据校验**: 关键数据变更前后校验

### 性能优化
1. **批量操作**: 优先使用批量接口
2. **缓存策略**: 热点数据合理缓存
3. **索引优化**: 查询字段建立合适索引
4. **分页优化**: 大数据量时优化分页查询

### 安全考虑
1. **权限控制**: 严格的用户权限验证
2. **数据脱敏**: 敏感信息在日志中脱敏
3. **防刷机制**: 频繁操作的限流控制
4. **隐私保护**: 遵循用户隐私设置

### 扩展性设计
1. **策略模式**: 支持不同的匹配策略
2. **配置驱动**: 关键参数可配置化
3. **插件化**: 支持自定义过滤器和处理器
4. **微服务拆分**: 为微服务化预留接口边界