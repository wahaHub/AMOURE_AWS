# Amoure V2 后端实现文档 - 对话与动态模块（Conversation & Feed Module）

## 模块概述

对话与动态模块包含两个紧密相关的功能：对话管理和动态内容管理。对话模块负责处理匹配用户间的即时消息会话，动态模块负责用户动态内容的发布与互动。两个模块共同构建了 Amoure V2 的社交生态系统。

## 对话管理子模块 (Conversation Management)

### 1. 控制器层设计 (Controller Layer)
**文件位置**: `com.amoure.api.v2.controller.ConversationV2Controller`

#### 核心设计理念
```java
/**
 * 核心设计：
 * 1. 互相喜欢关系检查：确保所有互相喜欢的用户都有对应的IM对话
 * 2. 自动创建对话：为缺失对话的互相喜欢关系自动创建腾讯IM对话
 * 3. 数据集成：结合本地backend用户数据和腾讯IM对话数据
 * 4. 实时同步：保证用户看到的对话列表与其喜欢关系保持一致
 */
```

#### 主要API端点

##### 获取对话列表
```java
@GetMapping
public Result<Map<String, Object>> getConversations(
    @RequestParam(required = false) String cursor,
    @RequestParam(defaultValue = "20") Integer limit
)
```

**业务流程**:
1. **关系检查**: 检查用户的所有互相喜欢关系
2. **对话同步**: 为没有对话的互相喜欢用户自动创建IM对话
3. **数据整合**: 返回所有对话及完整的用户信息
4. **分页支持**: 支持游标分页机制

##### 获取IM对话列表（备用接口）
```java
@GetMapping("/im")
public Result<Map<String, Object>> getImConversations(
    @RequestParam(required = false) String cursor,
    @RequestParam(defaultValue = "20") Integer limit
)
```

**设计目的**:
- 提供直接的IM服务调用
- 支持不同的数据源或格式需求
- 作为主接口的备用方案

### 2. 服务层集成
**文件位置**: `com.amoure.api.v2.service.ImService`

#### 核心功能设计

##### 对话自动创建机制
**业务逻辑**:
1. **匹配关系查询**: 查找所有相互喜欢的用户关系
2. **对话存在检查**: 检查每个匹配关系是否已有对话
3. **自动创建对话**: 为缺失的关系创建腾讯IM对话
4. **用户数据整合**: 获取对话参与者的完整用户信息

##### 腾讯IM集成
**技术特点**:
- **云端对话管理**: 利用腾讯IM的云端对话存储
- **实时消息同步**: 支持实时消息推送和同步
- **多端同步**: 支持Web端、移动端消息同步
- **消息历史**: 完整的消息历史记录管理

#### 响应数据设计
**ConversationResponse模型**:
```java
public class ConversationResponse {
    private List<ConversationItem> conversations;  // 对话列表
    private PaginationInfo pagination;             // 分页信息
    private ConversationStats stats;               // 对话统计
    
    public Map<String, Object> toMap();           // 转换为响应格式
}
```

## 动态内容子模块 (Feed Management)

### 1. 控制器层设计 (Controller Layer)
**文件位置**: `com.amoure.api.v2.controller.FeedV2Controller`

#### 主要API端点

##### 获取动态列表
```java
@GetMapping
public Result<Map<String, Object>> getPosts(
    @RequestParam(defaultValue = "all") String type,
    @RequestParam(required = false) String userId,
    @RequestParam(required = false) String cursor,
    @RequestParam(defaultValue = "15") Integer limit
)
```

**查询类型支持**:
- `all` - 获取全部动态（推荐流）
- `user` - 获取指定用户的动态

**分页机制**:
- 支持游标分页
- 默认每页15条动态
- 支持自定义分页大小

##### 发布动态
```java
@PostMapping
public Result<Map<String, Object>> createPost(@RequestBody @Valid CreatePostRequest request)
```

**内容支持**:
- 文本内容
- 图片内容（通过PhotoService集成）
- 内容审核集成

##### 动态互动操作
```java
// 点赞动态
@PostMapping("/{postId}/like")
public Result<Map<String, Object>> likePost(@PathVariable String postId)

// 取消点赞
@DeleteMapping("/{postId}/like") 
public Result<Map<String, Object>> unlikePost(@PathVariable String postId)

// 删除动态
@DeleteMapping("/{postId}")
public Result<Map<String, Object>> deletePost(@PathVariable String postId)
```

### 2. 服务层设计
**文件位置**: `com.amoure.api.v2.service.PostService`

#### 核心业务逻辑

##### 动态内容管理
**发布流程**:
1. **内容校验**: 验证文本长度、图片数量等
2. **内容审核**: 集成内容审核系统
3. **数据存储**: 保存动态内容和关联数据
4. **图片关联**: 通过PhotoService处理动态配图
5. **事件通知**: 发布动态创建事件

##### 动态推荐算法
**推荐策略**:
- **时间权重**: 新发布的动态获得更高权重
- **用户关系**: 优先展示匹配用户的动态
- **互动热度**: 点赞数、评论数影响推荐排序
- **内容质量**: 高质量内容获得更多曝光

##### 点赞系统设计
**点赞逻辑**:
```java
// 点赞操作
public Map<String, Object> likePost(Long userId, String postId) {
    // 1. 检查是否已点赞
    // 2. 创建点赞记录
    // 3. 更新动态统计
    // 4. 发布点赞事件
    // 5. 返回最新状态
}
```

**防重复机制**:
- 数据库唯一约束
- 缓存检查加速
- 幂等性保证

## 数据模型设计

### 对话相关模型

#### Conversation 实体
```java
public class Conversation {
    private Long id;
    private Long user1Id;           // 用户1ID  
    private Long user2Id;           // 用户2ID
    private String imConversationId; // 腾讯IM对话ID
    private LocalDateTime lastMessageTime; // 最后消息时间
    private String lastMessageContent;     // 最后消息内容
    private Integer unreadCount;    // 未读消息数
    private ConversationStatus status; // 对话状态
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

#### ConversationItem 响应模型
```java
public class ConversationItem {
    private String conversationId;  // 对话ID
    private UserSummary otherUser;  // 对话对方用户信息
    private MessagePreview lastMessage; // 最后消息预览
    private Integer unreadCount;    // 未读数量
    private LocalDateTime updateTime; // 更新时间
    private Boolean isOnline;       // 对方在线状态
}
```

### 动态相关模型

#### Post 实体
```java
public class Post {
    private Long id;
    private Long userId;            // 发布用户ID
    private String content;         // 动态内容
    private PostType type;          // 动态类型
    private PostStatus status;      // 动态状态
    private Integer likeCount;      // 点赞数
    private Integer commentCount;   // 评论数
    private List<String> imageUrls; // 图片URL列表
    private Map<String, Object> metadata; // 扩展元数据
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

#### PostLike 点赞实体
```java
public class PostLike {
    private Long id;
    private Long postId;            // 动态ID
    private Long userId;            // 点赞用户ID
    private LocalDateTime createdAt;
    
    // 复合唯一键约束: (post_id, user_id)
}
```

### 枚举定义

#### 对话状态枚举
```java
public enum ConversationStatus {
    ACTIVE("活跃"),
    ARCHIVED("已归档"),
    BLOCKED("已屏蔽"),
    DELETED("已删除");
}
```

#### 动态类型枚举
```java
public enum PostType {
    TEXT("纯文本"),
    IMAGE("图片"),
    TEXT_IMAGE("图文");
}
```

#### 动态状态枚举
```java
public enum PostStatus {
    DRAFT("草稿"),
    PUBLISHED("已发布"),
    REVIEWING("审核中"),
    APPROVED("已通过"),
    REJECTED("已拒绝");
}
```

## 业务逻辑实现

### 对话管理业务逻辑

#### 自动对话创建
**触发条件**:
- 用户查看对话列表时
- 新匹配关系建立时
- 定时同步任务执行时

**创建流程**:
1. **查询匹配关系**: 获取所有相互喜欢的用户对
2. **检查现有对话**: 查询是否已有对应的对话记录
3. **调用IM接口**: 创建腾讯IM云端对话
4. **本地记录同步**: 保存对话信息到本地数据库
5. **用户通知**: 通知双方用户新对话创建

#### 对话列表整合
**数据源整合**:
```java
// 1. 本地对话数据
List<Conversation> localConversations = conversationMapper.findByUserId(userId);

// 2. IM云端数据同步  
List<ImConversation> imConversations = imClient.getConversations(userId);

// 3. 用户信息补充
Map<Long, UserSummary> userSummaries = userService.getBatchUserSummaries(userIds);

// 4. 数据合并排序
List<ConversationItem> result = mergeAndSort(local, cloud, users);
```

### 动态内容业务逻辑

#### 动态发布流程
```java
public Map<String, Object> createPost(Long userId, CreatePostRequest request) {
    // 1. 内容验证
    validatePostContent(request);
    
    // 2. 创建动态实体
    Post post = buildPost(userId, request);
    
    // 3. 处理动态图片
    if (request.hasImages()) {
        List<String> imageUrls = photoService.savePostImages(userId, request.getImages());
        post.setImageUrls(imageUrls);
    }
    
    // 4. 内容审核提交
    if (needsReview(request)) {
        post.setStatus(PostStatus.REVIEWING);
        contentModerationService.submitForReview(post);
    } else {
        post.setStatus(PostStatus.PUBLISHED);
    }
    
    // 5. 保存到数据库
    postMapper.insert(post);
    
    // 6. 发布相关事件
    eventPublisher.publishEvent(new PostCreatedEvent(post));
    
    // 7. 返回结果
    return buildPostResponse(post);
}
```

#### 动态推荐算法
**排序因子**:
```java
public double calculatePostScore(Post post, Long viewerUserId) {
    double score = 0.0;
    
    // 时间衰减因子
    double timeDecay = calculateTimeDecay(post.getCreatedAt());
    score += timeDecay * 0.3;
    
    // 用户关系权重
    double relationshipWeight = calculateRelationshipWeight(post.getUserId(), viewerUserId);
    score += relationshipWeight * 0.4;
    
    // 互动热度
    double engagementScore = calculateEngagement(post.getLikeCount(), post.getCommentCount());
    score += engagementScore * 0.2;
    
    // 内容质量
    double qualityScore = calculateQualityScore(post);
    score += qualityScore * 0.1;
    
    return score;
}
```

## 第三方服务集成

### 腾讯IM集成

#### 对话管理集成
```java
@Service
public class TencentImService {
    
    // 创建对话
    public String createConversation(Long user1Id, Long user2Id) {
        CreateConversationRequest request = new CreateConversationRequest();
        request.setType("C2C"); // 单聊
        request.setMembers(Arrays.asList(user1Id.toString(), user2Id.toString()));
        
        CreateConversationResponse response = imClient.createConversation(request);
        return response.getConversationId();
    }
    
    // 获取对话列表
    public List<ImConversation> getConversations(Long userId) {
        GetConversationListRequest request = new GetConversationListRequest();
        request.setUserId(userId.toString());
        
        GetConversationListResponse response = imClient.getConversationList(request);
        return response.getConversations();
    }
}
```

#### 消息历史同步
**同步策略**:
- **增量同步**: 只同步新消息
- **定时全量**: 定期全量同步校验
- **事件触发**: 基于IM回调事件同步
- **用户触发**: 用户打开对话时同步

### 内容审核集成

#### 文本审核
```java
@Service  
public class ContentModerationService {
    
    public ModerationResult moderateText(String content) {
        TextModerationRequest request = new TextModerationRequest();
        request.setContent(content);
        
        TextModerationResponse response = moderationClient.moderateText(request);
        return convertToResult(response);
    }
}
```

#### 图片审核
**审核流程**:
1. **上传时审核**: 图片上传即时审核
2. **发布时复审**: 动态发布时再次审核
3. **用户举报审核**: 基于举报的人工审核
4. **定期抽审**: 定期随机抽取审核

## 性能优化策略

### 缓存设计

#### 对话列表缓存
```java
// Redis缓存键设计
String cacheKey = "conversations:user:" + userId;

// 缓存结构
{
  "conversations": [...],
  "lastUpdate": "2025-09-06T10:30:00",
  "total": 15
}
```

#### 动态内容缓存
```java
// 用户动态列表缓存
String userPostsKey = "posts:user:" + userId;

// 推荐动态缓存
String recommendPostsKey = "posts:recommend:" + userId;

// 动态详情缓存
String postDetailKey = "post:detail:" + postId;
```

### 数据库优化

#### 索引策略
```sql
-- 对话查询优化
CREATE INDEX idx_conversation_user ON conversations(user1_id, user2_id, status);
CREATE INDEX idx_conversation_time ON conversations(last_message_time DESC);

-- 动态查询优化  
CREATE INDEX idx_post_user_time ON posts(user_id, created_at DESC);
CREATE INDEX idx_post_status_time ON posts(status, created_at DESC);

-- 点赞查询优化
CREATE UNIQUE INDEX idx_post_like_unique ON post_likes(post_id, user_id);
CREATE INDEX idx_post_like_user ON post_likes(user_id, created_at DESC);
```

#### 分页优化
**游标分页实现**:
```java
// 基于时间戳的游标分页
public PageResponse<PostResponse> getPostsWithCursor(String cursor, int limit) {
    LocalDateTime cursorTime = cursor != null ? 
        LocalDateTime.parse(cursor) : LocalDateTime.now();
        
    List<Post> posts = postMapper.findPostsBeforeTime(cursorTime, limit + 1);
    
    boolean hasNext = posts.size() > limit;
    if (hasNext) {
        posts = posts.subList(0, limit);
    }
    
    String nextCursor = hasNext && !posts.isEmpty() ? 
        posts.get(posts.size() - 1).getCreatedAt().toString() : null;
        
    return PageResponse.builder()
        .content(posts)
        .hasNext(hasNext)
        .nextCursor(nextCursor)
        .build();
}
```

## 事件驱动架构

### 对话相关事件
```java
// 对话创建事件
public class ConversationCreatedEvent {
    private final Long conversationId;
    private final Long user1Id;
    private final Long user2Id;
    private final String imConversationId;
}

// 新消息事件
public class NewMessageEvent {
    private final Long conversationId;
    private final Long senderId;
    private final Long receiverId;
    private final String messageContent;
    private final LocalDateTime timestamp;
}
```

### 动态相关事件
```java
// 动态发布事件
public class PostCreatedEvent {
    private final Long postId;
    private final Long userId;
    private final PostType type;
    private final LocalDateTime timestamp;
}

// 动态点赞事件
public class PostLikedEvent {
    private final Long postId;
    private final Long userId;
    private final Long likerId;
    private final LocalDateTime timestamp;
}

// 动态审核事件
public class PostModerationEvent {
    private final Long postId;
    private final ModerationResult result;
    private final String reason;
}
```

## 监控和运维

### 关键指标监控
1. **对话活跃度**: 活跃对话数量、消息发送频率
2. **动态发布量**: 每日动态发布数量、用户参与度
3. **审核效率**: 审核通过率、审核平均时间
4. **系统性能**: API响应时间、缓存命中率
5. **用户体验**: 功能使用率、用户满意度

### 异常处理和降级
**IM服务降级**:
- IM服务不可用时显示本地缓存对话
- 消息发送失败时提供重试机制
- 自动切换备用IM服务

**内容审核降级**:
- 审核服务异常时采用关键词过滤
- 提供人工审核绿色通道
- 建立内容申诉和复审机制

## 最佳实践和注意事项

### 数据一致性保证
1. **分布式事务**: 跨系统操作使用分布式事务
2. **最终一致性**: 接受短期数据不一致
3. **补偿机制**: 提供数据修复和同步机制
4. **幂等设计**: 保证重复操作的安全性

### 用户隐私和安全
1. **权限控制**: 严格的对话和动态访问权限
2. **内容加密**: 敏感消息内容加密存储
3. **审核透明**: 审核结果对用户透明可见
4. **举报机制**: 完善的内容举报和处理流程

### 扩展性考虑
1. **微服务拆分**: 对话和动态可独立拆分
2. **消息队列**: 使用消息队列处理高并发
3. **读写分离**: 查询和写入操作分离优化
4. **国际化支持**: 多语言和多时区支持