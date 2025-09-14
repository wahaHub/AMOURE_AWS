# Amoure V2 后端实现文档 - 用户管理模块（User Management Module）

## 模块概述

用户管理模块是 Amoure V2 系统的核心业务模块，负责用户的完整生命周期管理，包括用户信息查询、档案更新、状态管理、权限验证等。该模块采用领域驱动设计（DDD），将复杂的用户业务逻辑进行合理封装和抽象。

## 核心组件架构

### 1. 控制器层 (Controller Layer)
**文件位置**: `com.amoure.api.v2.controller.UserV2Controller`

#### 主要职责
- 处理用户管理相关的HTTP请求
- 统一的参数校验和响应格式化
- 权限控制和用户身份验证

#### 核心API端点
- `GET /api/v2/user` - 获取用户详细信息（支持字段筛选）
- `PATCH /api/v2/user/profile` - 更新用户档案
- `DELETE /api/v2/user/complete` - 完全删除用户账户
- `GET /api/v2/user/friend/{friendUserId}` - 获取好友详细信息

#### 设计特点
- **字段筛选支持**: 通过 `fields` 参数控制返回数据的字段
- **权限自动控制**: 基于 Sa-Token 自动获取当前用户身份
- **统一错误处理**: 标准化的错误响应格式
- **IP地址追踪**: 支持代理环境下的真实IP获取

### 2. 服务层 (Service Layer)
**文件位置**: `com.amoure.api.v2.service.UserService`

#### 核心功能模块

##### 用户信息管理
1. **完整用户信息获取** (`getUserDetail`)
   - 整合基础信息、档案、照片、认证状态、绑定信息
   - 统计信息计算（活跃天数、资料完整度、在线状态）
   - 权限验证和数据过滤

2. **好友信息获取** (`getFriendsDetail`)
   - 仅显示已通过审核的信息
   - 屏蔽敏感的个人绑定信息
   - 访问权限验证和黑名单检查

3. **批量用户信息获取** (`getBatchCompleteUserProfiles`)
   - 性能优化的批量查询
   - 并行权限验证
   - 错误隔离和降级处理

##### 用户档案管理
**核心方法**: `updateUserProfile`

```java
public void updateUserProfile(Long userId, UpdateUserProfileRequest request)
```

**处理流程**:
1. **档案信息更新**
   - 基础属性：昵称、身高、体重、年龄、职业、学历等
   - 扩展信息：家乡、个人简介
   - JSON字段：标签、问答答案、位置灵活性、关系状态

2. **照片管理集成**
   - 调用 PhotoService 处理照片列表更新
   - 支持理想伴侣头像设置

3. **智能内容审核**
   - 自动检测文本内容变化
   - 触发机器审核流程
   - 状态管理和事件通知

##### 用户状态管理
1. **活跃状态计算**
   - 基于 `activefootprints` 字段计算活跃天数
   - 最近活跃和在线状态判断
   - 对齐现有UserManager逻辑

2. **资料完整度评估**
   - 多维度完整度计算
   - 百分比评分系统
   - 实时状态更新

3. **账户生命周期管理**
   - 软删除机制实现
   - 相关数据异步清理
   - 事件驱动的状态同步

#### 依赖组件注入
```java
private final UserInfoMapper userInfoMapper;           // 用户基础信息DAO
private final UserProfileMapper userProfileMapper;     // 用户档案DAO
private final ApplicationEventPublisher eventPublisher; // 事件发布器
private final VerificationService verificationService; // 认证服务
private final PhotoService photoService;              // 照片服务
private final UserBindingService userBindingService;  // 绑定服务
private final UserInteractionService userInteractionService; // 交互服务
```

## 数据模型设计

### 实体模型 (Entity Models)

#### UserInfo 实体
**职责**: 用户基础信息和账户状态管理
- 账户状态 (`AccountStatus`)
- 机器审核状态 (`MachineReviewStatus`)
- 最后登录时间和活跃足迹
- 理想伴侣头像设置

#### UserProfile 实体  
**职责**: 用户详细档案信息
- 个人基础信息（姓名、年龄、身高、体重等）
- 职业和教育背景
- 位置和家乡信息
- JSON格式的扩展字段

### 值对象 (Value Objects)
采用DDD值对象模式，封装复杂业务数据：

#### UserTags - 用户标签
```java
public class UserTags {
    public static UserTags fromJson(String json);
    public String toJson();
}
```

#### QAAnswers - 问答答案
```java  
public class QAAnswers {
    public static QAAnswers fromJson(String json);
    public String toJson();
}
```

#### LocationFlexibility - 位置灵活性
```java
public class LocationFlexibility {
    public static LocationFlexibility fromJson(String json);
    public String toJson();
}
```

#### RelationshipStatus - 关系状态
```java
public class RelationshipStatus {
    public static RelationshipStatus fromJson(String json);  
    public String toJson();
}
```

### 响应模型 (Response Models)

#### UserDetailResponse
**统一的用户详情响应模型**:
- 基础信息字段
- 值对象字段
- 状态信息
- 照片列表
- 认证信息
- 绑定信息（条件展示）
- 统计信息

## 业务逻辑实现

### 权限验证机制

#### validateUserAccess 方法
```java
private UserDetailResponse validateUserAccess(Long currentUserId, Long targetUserId)
```

**验证层级**:
1. **用户存在性检查**: 目标用户是否存在且状态为活跃
2. **账户状态检查**: 是否已删除账号
3. **访问权限检查**: 是否被当前用户屏蔽
4. **异常处理**: 统一的错误响应构建

### 内容审核机制

#### 智能审核触发
**方法**: `checkIfNeedsTextModeration`

**触发条件**:
1. **已通过审核用户**: 仅在敏感内容真正变化时触发
2. **未通过审核用户**: 更新任何敏感字段即触发
3. **敏感字段定义**: 个人简介、问答答案

**审核流程**:
1. 内容变化检测
2. 事件发布 (`UserTextModerationEvent`)
3. 异步审核处理
4. 状态更新和通知

### 性能优化策略

#### 批量查询优化
**方法**: `getBatchCompleteUserProfiles`

**优化技术**:
1. **批量权限验证**: 减少单次查询开销
2. **并行数据获取**: 同时查询用户信息、档案、照片、认证状态
3. **错误隔离**: 单个用户失败不影响整体结果
4. **缓存友好**: 支持多级缓存策略

#### 数据库访问优化
1. **按需查询**: 根据字段筛选参数减少数据传输
2. **索引利用**: 合理使用数据库索引
3. **连接优化**: 减少N+1查询问题
4. **事务管理**: 读写分离和事务边界控制

## 智能文本审核系统

### UserTextModerationJob - 文本审核引擎
**文件位置**: `com.amoure.api.v2.job.UserTextModerationJob`

#### 审核引擎概述
`UserTextModerationJob` 是 Amoure V2 用户管理的核心文本内容智能审核引擎，采用事件驱动的单次执行模式，当用户更新敏感字段时触发，支持XXL-Job的自动重试机制处理AI服务异常。

#### 核心设计特点
```java
// 事件驱动的单次执行Job
@XxlJob("userTextModerationJob")
private static final String[] SENSITIVE_FIELDS = {"selfIntroduction", "qaAnswers"};
private static final boolean SUPPORT_AUTO_RETRY = true;   // 支持XXL-Job自动重试
private static final boolean AI_FAILURE_RETRY = true;     // AI失败时重试
```

#### 主要功能模块

##### 1. 事件驱动审核
**触发方式**: 用户更新敏感内容时事件触发
**执行方法**: `moderateUserText()`

**参数传递格式**:
```java
String param = XxlJobHelper.getJobParam();  // 参数：userId（如：12345）
Long userId = Long.valueOf(param);
```

**审核流程**:
```java
public void moderateUserText() throws Exception {
    try {
        Long userId = Long.valueOf(XxlJobHelper.getJobParam());
        
        // 执行单次审核，不自己处理重试
        boolean success = processUserOnce(userId);
        
        if (!success) {
            // AI调用失败，交给XXL-Job自动重试
            XxlJobHelper.handleFail("AI审核调用失败，等待自动重试");
            return;
        }
        
        XxlJobHelper.handleSuccess("文本审核完成");
    } catch (Exception e) {
        XxlJobHelper.handleFail("执行异常：" + e.getMessage());
        throw e;  // 触发自动重试
    }
}
```

##### 2. 智能重试机制
**XXL-Job集成重试策略**:
- **成功场景**: 审核完成（通过或拒绝）
- **重试场景**: AI服务异常、网络超时
- **失败场景**: 参数错误、用户不存在

**重试优势**:
```java
// 不自己处理重试逻辑，利用XXL-Job的成熟重试机制
private boolean processUserOnce(Long userId) {
    if (hasApiFailures) {
        log.warn("用户文本审核AI调用失败，需要重试: userId={}", userId);
        return false;  // 让XXL-Job自动重试
    }
    return true; // 审核完成
}
```

##### 3. 多维度文本审核
**审核范围**: 敏感字段变化检测
```java
// 重点审核字段
1. 个人简介 (selfIntroduction)
2. 问答答案 (qaAnswers)
```

**审核流程设计**:
```java
private boolean processUserOnce(Long userId) {
    boolean isContentValid = true;
    StringBuilder rejectReasons = new StringBuilder();
    boolean hasApiFailures = false;

    // 1. 个人简介AI检测
    if (StringUtils.isNotBlank(profile.getSelfIntroduction())) {
        ModerationResult introResult = aiModerationService.moderateText(
            profile.getSelfIntroduction(), "个人简介");
        if (introResult.hasError()) {
            hasApiFailures = true;
        } else if (introResult.isRejected()) {
            isContentValid = false;
            rejectReasons.append("个人简介违规: ").append(introResult.getReason());
        }
    }
    
    // 2. 问答答案AI检测
    String qaAnswersText = extractQAAnswersText(profile.getQaAnswers());
    if (StringUtils.isNotBlank(qaAnswersText)) {
        ModerationResult qaResult = aiModerationService.moderateText(qaAnswersText, "问答答案");
        if (qaResult.hasError()) {
            hasApiFailures = true;
        } else if (qaResult.isRejected()) {
            isContentValid = false;
            rejectReasons.append("问答答案违规: ").append(qaResult.getReason());
        }
    }
    
    // 3. 结果处理
    return processAuditResults(user, isContentValid, hasApiFailures, rejectReasons);
}
```

##### 4. JSON问答答案解析
**智能文本提取**: `extractQAAnswersText()`

**解析策略**:
```java
private String extractQAAnswersText(JsonNode qaAnswers) {
    StringBuilder allAnswers = new StringBuilder();
    
    if (qaAnswers.isArray()) {
        // 数组格式：[{question: "xxx", answer: "xxx"}]
        for (JsonNode qaNode : qaAnswers) {
            if (qaNode.has("answer")) {
                String answer = qaNode.get("answer").asText();
                allAnswers.append(answer).append(" ");
            }
        }
    } else if (qaAnswers.isObject()) {
        // 对象格式：{q1: "answer1", q2: "answer2"}
        qaAnswers.fields().forEachRemaining(entry -> {
            String value = entry.getValue().asText();
            allAnswers.append(value).append(" ");
        });
    }
    
    return allAnswers.toString().trim();
}
```

##### 5. 审核状态管理
**状态更新逻辑**:
```java
// 内容违规处理
if (!isContentValid) {
    user.rejectByMachine(rejectReasons.toString());
    userInfoMapper.updateById(user);
    createMachineReviewNotification(user, rejectReasons.toString());
    log.info("用户文本内容审核不通过: userId={}, reason={}", userId, rejectReasons);
} else {
    // 内容合规处理
    user.approveByMachine();
    userInfoMapper.updateById(user);
    log.info("用户文本内容审核通过: userId={}", userId);
}
```

##### 6. 通知系统集成
**审核结果通知**: `createMachineReviewNotification()`

**通知创建流程**:
```java
private void createMachineReviewNotification(UserInfo user, String reason) {
    // TODO: V2系统通知实现
    // SystemNotificationV2 notification = SystemNotificationV2.builder()
    //     .userId(user.getId())
    //     .title("资料审核")
    //     .content("您的资料机审未通过，原因：" + reason)
    //     .notificationType(NotificationType.AUDIT)
    //     .isRead(false)
    //     .relatedId(user.getId())
    //     .build();
    
    log.info("机审驳回通知创建: userId={}, reason={}", user.getId(), reason);
}
```

#### 依赖服务集成
```java
private final UserInfoMapper userInfoMapper;              // V2用户基础信息DAO
private final UserProfileMapper userProfileMapper;        // V2用户档案DAO
private final SystemNotificationService systemNotificationService; // 通知服务
private final AIContentModerationService aiModerationService;      // AI文本审核服务
```

#### 性能优化特性

##### 1. 精准触发机制
- **事件驱动**: 只在敏感内容真正变化时触发
- **字段检测**: 专注个人简介和问答答案两个高风险字段
- **去重处理**: 避免重复审核相同内容

##### 2. 异常处理优化
```java
// 用户不存在时直接返回成功，避免重试
if (user == null) {
    log.error("用户不存在: userId={}", userId);
    return true; // 避免重试
}

// 档案不存在时直接拒绝，避免重试
if (profile == null) {
    user.setMachineReviewStatus(MachineReviewStatus.REJECTED);
    userInfoMapper.updateById(user);
    return true; // 避免重试
}
```

##### 3. AI服务集成优化
```java
// 区分AI调用失败和内容违规
ModerationResult result = aiModerationService.moderateText(text, fieldType);

if (result.hasError()) {
    hasApiFailures = true;  // AI服务异常，需要重试
    log.warn("AI审核失败: userId={}, reason={}", userId, result.getReason());
} else if (result.isRejected()) {
    isContentValid = false; // 内容违规，审核不通过
    log.info("内容违规: userId={}, reason={}", userId, result.getReason());
}
```

#### 监控和统计

##### 关键监控指标
- **审核成功率**: 文本审核完成率
- **AI可用性**: AI服务调用成功率
- **重试统计**: 重试次数和原因分析
- **违规检出率**: 内容违规检测准确性
- **处理性能**: 单次审核平均耗时

##### 重要日志记录
```java
log.info("开始处理V2用户文本审核: userId={}", userId);
log.info("用户文本内容审核通过: userId={}", userId);
log.info("用户文本内容审核不通过: userId={}, reason={}", userId, rejectReasons);
log.warn("用户个人简介违规: userId={}, reason={}", userId, introResult.getReason());
log.warn("用户问答答案违规: userId={}, reason={}", userId, qaResult.getReason());
log.warn("用户文本审核AI调用失败，需要重试: userId={}", userId);
```

#### 业务规则和策略

##### 审核触发条件
1. **已通过审核用户**: 仅在敏感内容真正变化时触发
2. **未通过审核用户**: 更新任何敏感字段即触发
3. **事件驱动**: 通过 `UserTextModerationEvent` 触发

##### 审核内容范围
```java
// 敏感字段定义
private static final String[] SENSITIVE_FIELDS = {
    "selfIntroduction",  // 个人简介
    "qaAnswers"          // 问答答案
};
```

##### 结果处理策略
1. **内容合规**: 设置为 `MachineReviewStatus.APPROVED`
2. **内容违规**: 设置为 `MachineReviewStatus.REJECTED` + 详细原因
3. **AI失败**: 保持当前状态，等待重试
4. **系统异常**: 详细日志记录，任务失败

## 事件驱动设计

### 用户删除事件
```java
public static class UserDeletedEvent {
    private final Long userId;
    private final String clientIp;
    private final LocalDateTime deleteTime;
}
```

**触发场景**: 用户账户软删除
**处理逻辑**: 异步清理相关数据（推荐记录、消息记录等）

### 文本审核事件
```java
public static class UserTextModerationEvent {
    private final Long userId;
    private final LocalDateTime timestamp;
}
```

**触发场景**: 用户更新敏感文本内容
**处理逻辑**: 异步机器审核和人工审核流程

### 登录事件监听
```java
@EventListener
public void handleUserLoginEvent(UserLoginEvent event)
```

**处理逻辑**:
1. 更新最后登录时间
2. 更新活跃足迹 (`activefootprints`)
3. 统计数据更新

## 集成服务接口

### 认证服务集成
**接口**: `VerificationService`
- `getAllVerificationStatus(userId)` - 获取完整认证状态
- `getApprovedVerificationStatus(userId)` - 获取已通过认证
- `batchGetApprovedVerificationStatus(userIds)` - 批量获取认证状态

### 照片服务集成
**接口**: `PhotoService`
- `getUserPhotos(userId)` - 获取用户所有照片
- `getApprovedUserPhotos(userId)` - 获取已审核通过照片
- `batchGetApprovedUserPhotos(userIds)` - 批量获取照片
- `commitPhotos(userId, photoList, idealPartnerAvatar)` - 提交照片更新

### 绑定服务集成
**接口**: `UserBindingService`
- `getUserBindings(userId)` - 获取用户第三方绑定信息

### 交互服务集成
**接口**: `UserInteractionService`
- `isUserBlocked(currentUserId, targetUserId)` - 检查屏蔽关系

## 工具类和实用程序

### UserStatusUtil
**职责**: 用户状态判断和计算工具
- `isUserRecentlyActive()` - 最近活跃判断
- `isUserRecentlyOnline()` - 最近在线判断
- `calculateProfileCompleteness()` - 资料完整度计算
- `calculateActiveDaysFromFootprints()` - 活跃天数计算

### ActiveDaysUtil  
**职责**: 活跃天数管理工具
- `updateActivefootprints()` - 更新活跃足迹
- 时间戳格式转换和计算

## 异常处理体系

### 自定义异常类

#### UserNotFoundException
```java
public static class UserNotFoundException extends RuntimeException {
    public UserNotFoundException(Long userId) {
        super("用户不存在: " + userId);
    }
}
```

#### UserProfileNotFoundException
```java  
public static class UserProfileNotFoundException extends RuntimeException {
    public UserProfileNotFoundException(Long userId) {
        super("用户档案不存在: " + userId);
    }
}
```

### 错误响应构建
UserDetailResponse提供多种错误响应构建方法：
- `createUserNotFoundError()` - 用户不存在错误
- `createUserDeletedError()` - 用户已删除错误  
- `createUserBlockedError()` - 用户被屏蔽错误
- `createGeneralError()` - 通用错误响应

## 监控和日志策略

### 关键日志点
1. **用户信息获取**: 记录访问的用户ID和权限验证结果
2. **档案更新操作**: 记录更新字段和审核触发情况
3. **批量查询性能**: 记录查询用户数量和响应时间
4. **权限验证失败**: 记录访问拒绝的详细原因
5. **异常处理**: 详细的错误堆栈和上下文信息

### 性能监控指标
- 用户信息查询响应时间
- 批量查询性能表现
- 档案更新成功率
- 审核事件触发频率
- 数据库连接池使用情况

## 最佳实践和注意事项

### 数据一致性
1. **事务边界**: 合理定义事务范围，避免长事务
2. **并发控制**: 使用乐观锁处理并发更新
3. **数据同步**: 确保缓存和数据库数据一致性

### 性能优化
1. **懒加载**: 按需加载用户详细信息
2. **缓存策略**: 热点用户数据缓存
3. **批量操作**: 优先使用批量查询减少数据库交互
4. **索引优化**: 合理设计数据库索引

### 安全考虑
1. **数据脱敏**: 敏感信息在日志中脱敏处理
2. **权限控制**: 严格的用户访问权限验证
3. **输入校验**: 所有用户输入进行严格校验
4. **SQL注入防护**: 使用参数化查询

### 扩展性设计
1. **接口抽象**: 核心业务逻辑通过接口暴露
2. **配置驱动**: 关键参数通过配置文件管理
3. **插件化**: 支持审核策略和状态计算的插件化扩展
4. **微服务拆分**: 为未来微服务化预留接口边界