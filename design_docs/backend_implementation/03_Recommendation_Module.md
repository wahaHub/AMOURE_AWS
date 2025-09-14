# Amoure V2 后端实现文档 - 推荐系统模块（Recommendation Module）

## 模块概述

推荐系统模块是 Amoure V2 匹配引擎的核心组件，负责为用户提供个性化的匹配推荐。该模块采用混合缓存策略，结合Redis缓存和实时推荐算法，提供高性能的推荐服务，并具备完善的降级和兜底机制。

## 核心组件架构

### 1. 控制器层 (Controller Layer)
**文件位置**: `com.amoure.api.v2.controller.RecommendationV2Controller`

#### 主要职责
- 处理推荐相关的HTTP请求
- 统一的响应格式化和分页处理
- 用户身份验证和权限控制

#### 核心API端点
- `GET /api/v2/recommendation` - 获取推荐用户列表

#### API设计特点
```java
@GetMapping
public Result<Map<String, Object>> getRecommendations()
```

**响应格式**:
```json
{
  "users": {
    "userId1": { /* UserDetailResponse数据 */ },
    "userId2": { /* UserDetailResponse数据 */ }
  },
  "total": 15
}
```

**设计优势**:
- **统一格式**: 所有用户数据通过 `UserDetailResponse.toMap()` 标准化
- **灵活结构**: 支持按用户ID索引的数据结构，便于前端处理
- **无分页**: 返回完整推荐列表，前端可自由控制展示

### 2. 服务层 (Service Layer)
**文件位置**: `com.amoure.api.v2.service.RecommendationService`

#### 核心设计理念
采用 **缓存优先 + 兜底策略** 的双重保障机制：
1. **首选**: Redis缓存中获取预计算推荐
2. **兜底**: 实时推荐算法动态生成

#### 核心方法解析

##### 主入口方法
```java
public Map<Long, UserDetailResponse> getRecommendations(Long userId)
```

**执行流程**:
1. 尝试从Redis缓存获取推荐列表
2. 缓存命中：返回预计算结果
3. 缓存未命中：触发实时推荐生成
4. 异常处理：返回空列表确保服务可用性

##### Redis缓存获取
```java
private Map<Long, UserDetailResponse> getRecommendationsFromRedis(Long userId)
```

**处理逻辑**:
1. **缓存键构建**: `CacheKeyConstants.RECOMMEND_USERS_KEY + userId`
2. **数据格式**: JSON数组格式存储用户ID列表
3. **数据解析**: 使用Fastjson解析用户ID列表
4. **批量查询**: 调用UserService批量获取用户详情
5. **异常处理**: 缓存异常不影响主流程

##### 实时推荐兜底
```java
private Map<Long, UserDetailResponse> getRecommendationsFromDatabase(Long userId)
```

**兜底策略**:
1. **手动触发**: 调用 `UserRecommendJobV2.manualTriggerRecommendationForUser()`
2. **实时计算**: 基于用户特征实时生成推荐
3. **结果缓存**: 生成的推荐结果自动缓存到Redis
4. **失败处理**: 算法失败时返回空列表，不阻塞用户体验

#### 依赖组件注入
```java
private final RecommendationMapper recommendationMapper;     // 推荐数据DAO
private final UserService userService;                      // 用户服务
private final UserRecommendJobV2 userRecommendJobV2;       // 推荐算法作业
private final StringRedisTemplate redisTemplate;            // Redis缓存
```

## 缓存设计架构

### Redis缓存策略

#### 缓存键设计
```java
String key = CacheKeyConstants.RECOMMEND_USERS_KEY + userId;
```

**命名规范**: 
- 前缀标识: `RECOMMEND_USERS_KEY`
- 用户标识: 实际的用户ID
- 示例: `recommend:users:12345`

#### 缓存数据格式
**存储格式**: JSON数组
```json
[123, 456, 789, 1011, 1213]
```

**数据特点**:
- **轻量级**: 仅存储用户ID，减少存储空间
- **高效解析**: 使用Fastjson快速解析
- **易维护**: 数据结构简单，便于调试

#### 缓存生命周期
1. **写入时机**: 推荐算法执行完成后
2. **更新策略**: 定时任务 + 手动触发
3. **失效机制**: TTL过期 + 手动清除
4. **一致性保证**: 最终一致性模型

## 推荐算法核心组件

### UserRecommendJobV2 - 推荐算法引擎
**文件位置**: `com.amoure.api.v2.job.UserRecommendJobV2`

#### 算法概述
`UserRecommendJobV2` 是 Amoure V2 推荐系统的核心算法引擎，采用基于管理员评分的多维度推荐策略，提供定时批量推荐和实时推荐两种模式。

#### 核心配置参数
```java
// 推荐配置常量
private static final int RECOMMEND_EXPIRE_DAYS = 3;    // 推荐结果过期时间
private static final double HIGH_POOL_RATIO = 0.3;     // 高质量用户池比例
private static final double MEDIUM_POOL_RATIO = 0.5;   // 中等质量用户池比例
private static final int RECOMMEND_SIZE = 15;          // 推荐用户数量

// 评分权重配置
private static final int ADMIN_SCORE_WEIGHT = 3;       // 管理员评分权重
private static final int LIKE_COUNT_WEIGHT = 3;        // 点赞数权重
private static final int LOGIN_SCORE_WEIGHT = 2;       // 登录活跃度权重
```

#### 主要功能模块

##### 1. 定时推荐任务
**触发方式**: `@XxlJob("UserRecommendJobV2")` 每天00:01执行

**执行流程**:
```java
public void calculateRecommendPool() {
    // 1. 获取所有符合条件的用户
    List<UserInfo> users = getQualifiedUsers();
    
    // 2. 计算每个用户的分数
    List<UserScoreV2> userScores = calculateUserScores(users);
    
    // 3. 根据分数排序并分配到不同池
    Map<String, List<UserScoreV2>> poolMap = assignUsersToPools(userScores);
    
    // 4. 为每个活跃用户生成推荐队列并保存到Redis
    generateAndSaveRecommendations(poolMap);
}
```

**算法优势**:
- **批量处理**: 一次性为所有活跃用户生成推荐
- **分池策略**: 按质量将用户分为HIGH/MEDIUM/LOW三个池
- **缓存预热**: 提前计算推荐结果，提高响应速度
- **定期更新**: 每日更新确保推荐时效性

##### 2. 用户筛选算法
**方法**: `getQualifiedUsers()`

**筛选条件**:
1. **基础条件**:
   - 账户状态为 `ACTIVE`
   - 机器审核状态为 `APPROVED`
   
2. **资料完整度检查**:
   - 使用 `userService.isProfileComplete()` 验证
   - 确保用户档案信息完整
   
3. **头像审核检查**:
   - 通过 `hasApprovedAvatar()` 验证
   - 确保用户有审核通过的头像

**代码实现**:
```java
private List<UserInfo> getQualifiedUsers() {
    return basicUsers.stream()
            .filter(user -> {
                // 资料完整度检查
                boolean isComplete = userService.isProfileComplete(user.getId());
                // 头像审核检查
                boolean hasApprovedAvatar = hasApprovedAvatar(user.getId());
                return isComplete && hasApprovedAvatar;
            })
            .collect(Collectors.toList());
}
```

##### 3. 多维度评分系统
**数据模型**: `UserScoreV2`
```java
public static class UserScoreV2 {
    private Long userId;
    private int adminScore;          // 管理员评分 (0-100)
    private int likeCount;           // 获得点赞数
    private int loginScore;          // 登录活跃度分数
    private int totalScore;          // 总分
    private UserInfo userInfo;       // 用户信息
    private UserProfile userProfile; // 用户档案
}
```

**评分计算算法**:
```java
private List<UserScoreV2> calculateUserScores(List<UserInfo> users) {
    for (UserInfo user : users) {
        // 1. 管理员评分 (权重x3)
        int adminScore = user.getAdminScore() * ADMIN_SCORE_WEIGHT;
        
        // 2. 点赞数评分 (权重x3, 统计最近30天)
        int likeCount = calculateLikeCount(user.getId()) * LIKE_COUNT_WEIGHT;
        
        // 3. 登录活跃度评分 (权重x2)
        int loginScore = calculateLoginScore(user.getLastLoginTime(), now) * LOGIN_SCORE_WEIGHT;
        
        // 4. 总分计算
        int totalScore = adminScore + likeCount + loginScore;
    }
}
```

**登录活跃度算法**:
- 24小时内登录: 10分
- 72小时内登录: 5分  
- 超过72小时: 0分

##### 4. 智能分池策略
**方法**: `assignUsersToPools()`

**分池规则**:
```java
// 按总分降序排序后分配
- HIGH池: 前30%的高质量用户
- MEDIUM池: 中间50%的中等质量用户  
- LOW池: 后20%的低质量用户
```

**分配逻辑**:
```java
private Map<String, List<UserScoreV2>> assignUsersToPools(List<UserScoreV2> scores) {
    scores.sort((s1, s2) -> s2.getTotalScore() - s1.getTotalScore());
    
    int totalSize = scores.size();
    int highEnd = (int) (totalSize * HIGH_POOL_RATIO);
    int mediumEnd = highEnd + (int) (totalSize * MEDIUM_POOL_RATIO);
    
    Map<String, List<UserScoreV2>> poolMap = new HashMap<>();
    poolMap.put("HIGH", scores.subList(0, highEnd));
    poolMap.put("MEDIUM", scores.subList(highEnd, mediumEnd));
    poolMap.put("LOW", scores.subList(mediumEnd, totalSize));
    
    return poolMap;
}
```

##### 5. 个性化推荐生成
**方法**: `generateAndSaveRecommendations()`

**推荐策略**:
```java
// 推荐组成比例
int highCount = (int) (RECOMMEND_SIZE * 0.3);   // 30% 高质量用户
int mediumCount = (int) (RECOMMEND_SIZE * 0.5); // 50% 中等质量用户  
int lowCount = RECOMMEND_SIZE - highCount - mediumCount; // 20% 低质量用户
```

**排除逻辑**:
```java
private Set<Long> getExcludeUserIds(Long userId) {
    Set<Long> excludeIds = new HashSet<>();
    excludeIds.add(userId);                           // 排除自己
    excludeIds.addAll(getSentAndReceivedLikes(userId)); // 排除已互动用户
    excludeIds.addAll(getBlockedUsers(userId));        // 排除已拉黑用户
    excludeIds.addAll(getBlockedByUsers(userId));      // 排除拉黑了我的用户
    return excludeIds;
}
```

##### 6. 实时推荐兜底
**方法**: `manualTriggerRecommendationForUser()`

**应用场景**:
- Redis缓存未命中时的兜底机制
- 用户资料更新后的即时推荐刷新
- 新用户的首次推荐生成

**实现特点**:
```java
public List<Long> manualTriggerRecommendationForUser(Long userId) {
    // 1. 实时获取所有符合条件的用户
    List<UserInfo> users = getQualifiedUsers();
    
    // 2. 实时计算分数并分池
    List<UserScoreV2> userScores = calculateUserScores(users);
    Map<String, List<UserScoreV2>> poolMap = assignUsersToPools(userScores);
    
    // 3. 为指定用户生成个性化推荐
    Set<Long> excludeUserIds = getExcludeUserIds(userId);
    List<Long> recommendUsers = selectFromPools(poolMap, excludeUserIds);
    
    // 4. 保存到Redis缓存
    saveToRedisCache(userId, recommendUsers);
    
    return recommendUsers;
}
```

##### 7. AI自动评分系统
**触发方式**: `@XxlJob("batchUpdateAdminScoreJob")`

**评分条件**:
- 注册超过24小时
- 管理员评分为空或0分  
- 账号状态正常

**AI评分流程**:
```java
private boolean performAIScoring(Long userId) {
    // 1. 收集用户数据
    UserScoringData userData = collectUserDataForAI(userId);
    
    // 2. 调用AI评分服务
    Integer aiScore = aiScoringService.scoreUser(userData);
    
    // 3. 保存评分结果
    userInfo.setAdminScore(aiScore, -1L); // -1表示AI评分
    
    // 4. 清除推荐缓存，触发重新生成
    redisTemplate.delete(CacheKeyConstants.RECOMMEND_USERS_KEY + userId);
}
```

**AI评分数据模型**:
```java
public static class UserScoringData {
    private Long userId;
    private String nickname;
    private Integer age;
    private String gender;
    private String occupation;
    private String degree;
    private String selfIntroduction;
    private String location;
    private List<String> photoUrls;  // 最多5张照片
}
```

#### 性能优化特性

##### 1. 批量查询优化
```java
// 使用V2的批量查询接口
List<UserInfo> basicUsers = userInfoMapper.selectList(queryWrapper);

// 批量获取用户互动数据
List<UserLike> sentLikes = userLikeMapper.findBetweenUsers(userId, null);
```

##### 2. 缓存策略优化
```java
// 推荐结果缓存到Redis，3天过期
String key = CacheKeyConstants.RECOMMEND_USERS_KEY + userId;
String jsonValue = JSON.toJSONString(recommendUsers);
redisTemplate.opsForValue().set(key, jsonValue, RECOMMEND_EXPIRE_DAYS, TimeUnit.DAYS);
```

##### 3. 异常处理机制
```java
// 各个模块独立异常处理，确保系统稳定性
try {
    List<Long> recommendUsers = generateRecommendations(userId);
} catch (Exception e) {
    log.error("推荐生成失败，返回空列表", e);
    return new ArrayList<>();
}
```

#### 监控和日志

##### 关键监控指标
- **用户池分布**: 高/中/低质量用户数量统计
- **评分分布**: 管理员评分、AI评分比例
- **推荐成功率**: 推荐生成成功/失败统计  
- **缓存命中率**: Redis缓存使用情况
- **算法执行时间**: 各个步骤的性能监控

##### 重要日志记录
```java
log.info("符合条件的用户数量: {}", users.size());
log.info("用户分池完成 - HIGH: {}, MEDIUM: {}, LOW: {}", 
        poolMap.get("HIGH").size(), 
        poolMap.get("MEDIUM").size(), 
        poolMap.get("LOW").size());
log.info("推荐队列生成完成，成功为{}个用户生成推荐", successCount);
```

### 推荐算法集成

#### RecommendationService集成
**算法触发**:
```java
List<Long> recommendUserIds = userRecommendJobV2.manualTriggerRecommendationForUser(userId);
```

**集成特性**:
- **缓存优先**: 优先从Redis获取预计算推荐
- **实时兜底**: 缓存失效时自动触发实时推荐
- **异常隔离**: 推荐算法异常不影响其他功能
- **性能保证**: 异步处理，响应时间稳定

#### 兜底算法策略
**多级降级**:
1. **一级**: Redis缓存推荐
2. **二级**: 实时推荐算法
3. **三级**: 基础活跃用户推荐
4. **四级**: 返回空结果（不阻塞用户）

## 性能优化设计

### 批量数据获取优化
**方法**: `userService.getBatchCompleteUserProfiles(userId, recommendUserIds)`

**优化技术**:
1. **单次批量查询**: 替代循环单次查询
2. **并发查询**: 并行获取用户信息、档案、照片、认证状态
3. **内存优化**: 合理控制批量查询大小
4. **连接池优化**: 高效利用数据库连接

### 异常处理和降级
**异常隔离**:
```java
try {
    // Redis获取逻辑
} catch (Exception e) {
    log.error("从Redis获取推荐列表失败", e);
    return new HashMap<>(); // 返回空结果，不影响兜底流程
}
```

**降级策略**:
1. **服务降级**: Redis异常时自动切换到数据库
2. **功能降级**: 推荐算法异常时返回基础推荐
3. **性能降级**: 高负载时减少推荐数量
4. **用户体验保护**: 任何异常都不影响核心功能

### 监控和日志设计

#### 关键日志点
1. **缓存命中率**: 监控Redis缓存效果
   ```java
   log.info("从Redis缓存获取到推荐列表: userId={}, count={}", userId, recommendations.size());
   ```

2. **兜底触发**: 记录缓存失效情况
   ```java
   log.warn("Redis缓存未命中，使用数据库兜底策略: userId={}", userId);
   ```

3. **算法性能**: 监控推荐算法执行时间
4. **异常处理**: 详细记录各类异常情况

#### 性能监控指标
- **响应时间**: 推荐接口平均响应时间
- **缓存命中率**: Redis缓存命中率统计
- **算法效率**: 实时推荐算法执行时间
- **推荐质量**: 用户对推荐结果的互动率
- **系统负载**: 推荐系统资源使用情况

## 数据模型设计

### Recommendation实体
**职责**: 推荐记录持久化存储
- 推荐关系映射
- 推荐算法版本追踪
- 推荐质量评分记录
- 推荐生成时间戳

### 推荐缓存模型
**Redis存储结构**:
```
Key: recommend:users:{userId}
Value: JSON array of user IDs
TTL: 1小时（可配置）
```

**数据一致性**:
- **写入**: 推荐算法执行后异步写入
- **读取**: 优先从缓存读取
- **更新**: 定时刷新 + 手动触发
- **清理**: TTL自动过期 + 手动清除

## 与其他模块的集成

### UserService集成
**接口**: `getBatchCompleteUserProfiles`
- **输入**: 当前用户ID + 推荐用户ID列表
- **输出**: 完整的用户详情Map
- **特性**: 批量优化 + 权限验证 + 数据过滤

### 推荐算法集成
**接口**: `UserRecommendJobV2`
- **手动触发**: `manualTriggerRecommendationForUser`
- **批量推荐**: 定时任务批量生成
- **算法配置**: 支持参数调优和策略切换

### 缓存服务集成
**接口**: `StringRedisTemplate`
- **基础操作**: get/set/del
- **过期控制**: TTL管理
- **连接管理**: 连接池优化

## 扩展性和可维护性

### 算法策略扩展
**策略模式支持**:
```java
public interface RecommendationStrategy {
    List<Long> recommend(Long userId, int limit);
    boolean supports(RecommendationType type);
}
```

**多策略支持**:
- 协同过滤算法
- 内容匹配算法
- 深度学习推荐
- 混合推荐策略

### 缓存策略扩展
**多级缓存**:
1. **L1缓存**: JVM本地缓存（用户会话）
2. **L2缓存**: Redis分布式缓存
3. **L3缓存**: 数据库查询缓存

### 配置化管理
**可配置项**:
```properties
# 推荐数量配置
recommendation.default.limit=20
recommendation.max.limit=100

# 缓存配置
recommendation.cache.ttl=3600
recommendation.cache.enable=true

# 算法配置
recommendation.algorithm.timeout=30s
recommendation.fallback.enable=true
```

## 最佳实践和注意事项

### 性能优化建议
1. **批量操作**: 优先使用批量接口减少网络开销
2. **缓存预热**: 在低峰期预生成热点用户推荐
3. **异步处理**: 推荐生成和缓存更新异步执行
4. **负载均衡**: 推荐算法计算资源合理分配

### 数据一致性保证
1. **最终一致性**: 接受短期数据不一致
2. **缓存刷新**: 定期刷新缓存确保数据新鲜度
3. **版本控制**: 推荐算法版本化管理
4. **数据校验**: 推荐结果有效性验证

### 异常处理规范
1. **优雅降级**: 异常不影响用户基础体验
2. **快速失败**: 避免长时间等待和资源浪费
3. **详细日志**: 完整记录异常上下文信息
4. **监控告警**: 关键异常及时通知相关人员

### 安全和隐私考虑
1. **数据脱敏**: 缓存中避免存储敏感信息
2. **权限控制**: 确保推荐结果符合隐私设置
3. **访问控制**: Redis访问权限严格控制
4. **数据清理**: 及时清理过期和无效的推荐数据

## 未来优化方向

### 算法优化
1. **机器学习**: 引入更先进的推荐算法
2. **实时更新**: 基于用户行为实时调整推荐
3. **多目标优化**: 平衡推荐质量和多样性
4. **冷启动优化**: 改善新用户推荐体验

### 架构优化
1. **微服务拆分**: 推荐系统独立微服务
2. **流处理**: 实时数据流处理架构
3. **容器化部署**: 支持弹性扩缩容
4. **多区域部署**: 全球化服务支持

### 功能扩展
1. **个性化配置**: 用户自定义推荐偏好
2. **推荐解释**: 为用户解释推荐原因
3. **反馈循环**: 用户反馈优化推荐算法
4. **A/B测试**: 推荐策略效果对比测试