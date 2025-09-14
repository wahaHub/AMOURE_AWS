# Amoure GraphQL 查询层实施方案 (完整用户数据版)

## 📋 **项目概述**

基于 Amoure Dating API 分析，通过 **GraphQL统一数据模型** + **按需字段查询** 解决核心性能瓶颈：消除N+1查询问题，同时实现完整用户数据的统一管理。

### **核心策略**
- ✅ **统一用户模型**: 一个 UserComplete 涵盖所有用户信息
- ✅ **按需字段查询**: GraphQL 只返回请求的字段
- ✅ **聚合业务查询**: 一次查询获取多个相关数据
- ✅ **智能缓存策略**: 基于业务场景的分层缓存

### **目标优化场景**
| 场景 | 当前问题 | 解决方案 | 预期提升 |
|------|----------|----------|----------|
| **推荐Tab** | 1+15次API调用 | 1次轻量聚合 | **75%** |
| **动态Tab** | 3次API+大图片 | 分页+懒加载 | **67%** |  
| **喜欢页** | 3次分离+筛选 | 1次智能聚合 | **70%** |
| **消息页** | N+1次用户详情 | 1次批量查询 | **80%+** |
| **用户详情** | 6次串行调用 | 1次完整查询 | **83%** |

---

## 🔍 **核心问题分析 & 分层加载策略**

### **问题本质**
1. **N+1 查询问题**: 获取列表后循环调用详情API
2. **首屏阻塞问题**: 大图片/完整信息阻塞首屏渲染

### **分层加载策略**
| 层次 | 数据类型 | 加载时机 | 传输大小 | 用途 |
|------|----------|----------|----------|------|
| **L1 - 核心数据** | 基本信息+缩略图 | 立即(首屏) | ~5KB/用户 | 列表渲染 |
| **L2 - 扩展数据** | 额外照片+详细资料 | 按需懒加载 | ~20KB/用户 | 交互展开 |
| **L3 - 完整数据** | 高清图片+全部信息 | 用户点击时 | ~100KB/用户 | 详情页面 |

### **具体问题分析**

#### **1. 推荐Tab - 从串行到并行+分层**
```dart
// ❌ 当前实现 - 16次串行API，2.0秒
Future<void> loadHomeRecommendTab() async {
  final user = await getUserDetail();                    // 1️⃣ 用户基本信息
  final recommendations = await getRecommendUsers();     // 2️⃣ 推荐用户ID列表(15个)
  
  // N+1问题：15个推荐用户详情
  for (userId in recommendations) {
    final userDetail = await getUserDetail(userId);      // 3️⃣~17️⃣ 
  }
  
  // 然后每个用户还要获取照片...
  final unreadCount = await getUnreadMessageCount();     // 最后统计
}

// ✅ GraphQL方案 - 1次查询+分层加载，0.4秒
Future<void> loadHomeRecommendTab() async {
  // L1: 一次性获取所有必要信息(15个用户基本信息+首张缩略图)
  final dashboard = await HomeService.getHomeRecommendDashboard();
  _renderUserCards(dashboard); // 立即渲染卡片，75KB数据包
  
  // L2: 用户滑动时懒加载额外照片
  void onUserCardSwipe(String userId) {
    final photos = await getUserPhotos(userId, offset: 1, limit: 4);
  }
}
```

#### **2. 动态Tab - 分页+明细分离**
```dart
// ❌ 当前实现 - 3次API+大图片包，1.5秒
Future<void> loadHomePostsTab() async {
  final user = await getUserDetail();                    // 1️⃣ 
  final posts = await getRecommendPosts();               // 2️⃣ 包含大图片(~500KB)
  final unreadCount = await getUnreadMessageCount();     // 3️⃣
  // 首屏被大图片阻塞
}

// ✅ GraphQL方案 - 分页列表+详情分离，0.3秒
Future<void> loadHomePostsTab() async {
  // L1: 首屏加载缩略信息(20条动态，仅缩略图)
  final dashboard = await HomeService.getHomePostsDashboard(page: 1);
  _renderPostList(dashboard); // 100KB，立即渲染
  
  // L2: 点击某条动态时加载完整信息+评论
  void onPostTap(String postId) {
    final detail = await PostService.getPostDetail(postId); // 50KB单独查询
  }
}
```

#### **3. 喜欢页 - 聚合+分页+懒加载**
```dart
// ❌ 当前实现 - 3次分离API+重复筛选，1.2秒
Future<void> loadXindongTabs() async {
  // 每次都要调用3个API
  final likedMe = await getLikedMe(filter: filter, page: 1);     
  final myLikes = await getMyLikes(filter: filter, page: 1);      
  final mutualLikes = await getMutualLikes(filter: filter, page: 1);
  // 筛选条件变化时重复请求3个接口
}

// ✅ GraphQL方案 - 一次聚合查询+智能分页，0.4秒
Future<void> loadXindongTabs() async {
  // L1: 一次查询获取3个Tab的首页数据+筛选统计
  final dashboard = await InteractionsService.getInteractionsDashboard(
    likedMeFilter: currentFilter,
    // 3个Tab的分页参数一次传入
  ); // 60KB，立即渲染3个Tab
  
  // L2: 点击用户卡片获取扩展信息
  void onUserCardTap(String userId) {
    final extended = await getUserExtended(userId); // 25KB
  }
}
```

---

## 🚀 **GraphQL Schema设计 (分层优化)**

### **1. 统一用户数据模型**

```graphql
# ===== 完整用户信息模型 (涵盖所有API数据) =====
type User {
  # 基础身份信息
  id: ID!
  nickname: String!
  avatarUrl: String
  phone: String              # 脱敏显示
  email: String
  
  # 个人资料信息
  gender: Gender!             # MALE/FEMALE
  birthDate: String           # ISO格式日期
  age: Int!                   # 计算年龄
  locationCode: String        # 地区编码
  locationName: String        # 地区名称
  language: String            # 用户语言偏好 zh/en
  idealPartnerAvatar: String  # 理想伴侣照片
  
  # VIP会员信息
  isVip: Boolean!
  vipLevel: Int!              # 0-普通用户, 1-VIP等级
  vipExpireTime: String       # 会员过期时间
  
  # 活跃状态信息
  lastLoginTime: String       # 最后登录时间
  activeDaysLastWeek: Int!    # 上周活跃天数
  
  # 所有认证信息 (统一结构)
  verifications: [Verification!]!
  
  # 第三方账号绑定信息
  binding: UserBinding
  
  # 照片信息
  photos: [UserPhoto!]!
  
  # 用户发布的帖子ID列表
  postIds: [ID!]!
  
  # Q&A问答
  qaAnswers: [QAAnswer!]!
  
  # 地理位置灵活性偏好
  locationFlexibility: [LocationFlexibilityAnswer!]!
  
  trustScore: Int             # 信任分数
  
  # 位置信息 (详细)
  latitude: Float
  longitude: Float
  
  # 个人详细信息
  bio: String                 # 自我介绍
  profession: String          # 职业
  school: String              # 学校
  work: String                # 工作
  height: String              # 身高
  incomeRange: String         # 收入范围
  marriageStatus: String      # 婚姻状态
  hasChildren: Int            # 是否有孩子
  wantChildren: Int           # 是否想要孩子
  smokingHabit: String        # 吸烟习惯
  drinkingHabit: String       # 饮酒习惯
  religion: String            # 宗教信仰
  hobbies: [String!]          # 兴趣爱好
}

# ===== 统一认证类型 =====
type Verification {
  status: VerificationStatusType!    # PENDING, APPROVED, REJECTED
  type: VerificationType!           # IDENTITY, EDUCATION, CAREER, MARRIAGE, REAL_PERSON
  description: String               # 认证详细信息/描述
  trustScore: Int                   # 该认证对信任分数的贡献
}

enum VerificationStatusType {
  PENDING
  APPROVED
  REJECTED
}

enum VerificationType {
  IDENTITY
  EDUCATION
  CAREER
  MARRIAGE
  REAL_PERSON
}

# ===== 照片类型 =====
type UserPhoto {
  id: ID!
  url: String!              # 原图URL
  thumbnailUrl: String!     # 缩略图URL
  isPrimary: Boolean!
  order: Int!
}

# ===== 第三方绑定信息类型 =====
type UserBinding {
  phoneNumber: String          # 脱敏手机号
  phoneBindStatus: Boolean!
  wechatBindStatus: Boolean!
  wechatInfo: String          # 脱敏微信信息
  appleBindStatus: Boolean!
  appleInfo: String           # 脱敏Apple信息
  emailBindStatus: Boolean!
  emailInfo: String           # 脱敏邮箱信息
  googleBindStatus: Boolean!
  googleInfo: String          # 脱敏Google信息
}

# ===== Q&A问答类型 =====
type QAAnswer {
  questionId: String!
  questionKey: String!
  question: String!
  answer: String
  answeredAt: String
}

# ===== 地理位置灵活性类型 =====
type LocationFlexibilityAnswer {
  questionId: String!
  questionKey: String!
  question: String!
  answer: String!
  options: [String!]!       # 可选答案列表
}

# ===== 枚举类型定义 =====
enum Gender {
  MALE
  FEMALE
}


```

### **2. 业务聚合类型定义**

```graphql
# ===== 推荐用户相关字段直接在User类型中 =====
# matchScore, distance, matchReason 等字段可以根据上下文动态计算

# ===== 动态类型 =====
type Post {
  id: ID!
  content: String!
  mediaUrls: [String!]!       # 图片/视频URL列表
  author: User!               # 作者完整信息，按需返回字段
  likeCount: Int!
  commentCount: Int!
  createdTime: String!
  updateTime: String
  isLiked: Boolean!           # 当前用户是否已点赞
  location: String
  comments(limit: Int = 20, offset: Int = 0): [PostComment!]!
}

type PostComment {
  id: ID!
  content: String!
  authorName: String!       # 评论作者信息
  authorAvatarThumbnail : String!
  createdTime: String!
}

# ===== 用户互动/喜欢类型 =====
type UserLike {
  user: User!                 # 用户信息
  interactionType: InteractionType!  # 互动类型: LIKE, SUPER_LIKE
  type: UserLikeType!        # 喜欢关系类型: 谁喜欢我/我喜欢谁/互相喜欢
}

enum InteractionType {
  LIKE
  SUPER_LIKE
}

enum UserLikeType {
  LIKED_ME      # 谁喜欢我
  MY_LIKE       # 我喜欢谁
  MUTUAL        # 互相喜欢
}

enum UserActionType {
  LIKE          # 喜欢
  SUPER_LIKE    # 超级喜欢
  DISLIKE       # 不喜欢
  BLOCK         # 拉黑
  REPORT        # 举报
}

enum LikeFilter {
  ALL          # 全部心动
  RECENT_ONLINE    # 最近在线
  COMPLETE_PROFILE # 资料完整
  RECENT_ACTIVE    # 最近活跃
  MULTI_VERIFIED   # 多重认证
  PLATFORM_RECOMMENDED # 平台推荐
}

# ===== 会话类型 =====
type Conversation {
  id: ID!                     # 会话ID
  targetUserId: ID!           # 对方用户ID
  lastMessage: String
  lastMessageTime: String
  unreadCount: Int!
}

# ===== 消息类型 =====
type ImMessage {
  id: ID!                     # 消息ID
  conversationId: ID!         # 会话ID
  senderId: ID!               # 发送者ID
  receiverId: ID!             # 接收者ID
  messageType: MessageType!   # 消息类型
  content: String             # 消息内容
  mediaUrl: String           # 媒体文件URL
  sendTime: String!
  status: MessageStatus!      # 消息状态
}

enum MessageType {
  TEXT
  IMAGE
  VOICE
  VIDEO
}

enum MessageStatus {
  SENT
  DELIVERED
  READ
}
```

### **3. GraphQL查询根类型 - 基于Flutter页面优化设计**

```graphql
type Query {
  # ===== 首页相关查询 (HomePage) =====
  
  # 首页推荐Tab - 一次获取推荐用户列表
  homeRecommendationFeed: HomeRecommendationResponse!
  
  # 首页动态Tab - 分页获取动态列表
  homeFeed(
    current: Int = 1,
    pageSize: Int = 20,
    sortType: Int = 1  # 1=最新, 2=最热
  ): PostListResponse!
  
  
  # ===== 心动页面相关查询 (XindongPage) =====
  
  # 心动页面聚合数据 - 解决3个Tab分离查询问题
  xindongDashboard(
    filter: LikeFilter = ALL,           # 筛选条件
    likedMePage: Int = 1,               # 对我心动分页
    likedMePageSize: Int = 50,
    myLikesPage: Int = 1,               # 我心动的分页  
    myLikesPageSize: Int = 50,
    mutualLikesPage: Int = 1,           # 互相心动分页
    mutualLikesPageSize: Int = 50
  ): XindongDashboardResponse!
  
  
  # ===== 消息页面相关查询 (MessagesPage) =====
  
  # 消息页面聚合数据 - 解决会话列表N+1查询问题
  messagesDashboard: MessagesDashboardResponse!
  
  # 分页获取会话历史
  conversationHistory(
    current: Int = 1,
    pageSize: Int = 20
  ): ConversationListResponse!
  
  
  # ===== 个人资料页面相关查询 (ProfilePage) =====
  
  # 我的个人资料完整信息
  myProfile: ProfileDashboardResponse!
  
  # 查看他人详细资料 (ProfileDetailPage)
  userProfile(userId: ID!): UserProfileDetailResponse!
  
  
  # ===== 聊天页面相关查询 (ChatPage) =====
  
  # 获取对方用户信息 (聊天页面使用)
  chatTargetUser(targetUserId: ID!): User!
  
  
  # ===== 动态详情页相关查询 (FeedDetailPage) =====
  
  # 动态详情
  postDetail(postId: ID!): Post!
  
  # 动态评论列表 (简化，不分页)
  postComments(postId: ID!): PostCommentListResponse!
  
  
  # ===== 用户动态页面查询 (UserFeedsPage) =====
  
  # 特定用户的动态列表
  userPosts(
    userId: ID!,
    current: Int = 1,
    pageSize: Int = 20
  ): PostListResponse!
  
  
  # ===== 辅助查询 =====
  
  # 刷新IM用户签名
  refreshImUserSig: UserSigVO!
  

  
  # 获取当前用户基础信息 (用于导航栏等)
  currentUserBasic: User!
}


# ===== 页面专用响应类型 =====

# 首页推荐响应
type HomeRecommendationResponse {
  users: [User!]!                    # 推荐用户列表 (按需返回字段)
}

# 心动页面聚合响应  
type XindongDashboardResponse {
  likedMe: UserLikeListResponse!     # 对我心动
  myLikes: UserLikeListResponse!     # 我心动的  
  mutualLikes: UserLikeListResponse! # 互相心动
}

# 消息页面聚合响应
type MessagesDashboardResponse {
  conversations: [ConversationWithUser!]!  # 会话列表(包含用户信息)
}

type ConversationWithUser {
  id: ID!
  targetUser: User!                       # 对方用户信息
  lastMessage: String
  lastMessageTime: String  
  unreadCount: Int!
  conversationType: String                # 会话类型
}

# 个人资料页面响应
type ProfileDashboardResponse {
  user: User!                             # 完整用户信息
  profileCompleteness: Float!             # 资料完整度百分比 (0.0-1.0)
  vipInfo: UserVipDetail!
}

# 用户详情页响应
type UserProfileDetailResponse {
  user: User!                            # 目标用户完整信息
  relationshipStatus: RelationshipStatus! # 与当前用户的关系状态
}

type RelationshipStatus {
  Iliketarget: Boolean!                  # 我是否喜欢TA
  targetlikeme: Boolean!                 # TA是否喜欢我
  isMatched: Boolean!                    # 是否匹配
  isBlocked: Boolean!                    # 是否被拉黑
}






 
 
 type Mutation {
   # ===== 推荐页面操作 =====
   # 用户喜欢操作 (喜欢/超级喜欢)
   likeUser(
     targetUserId: ID!,
     type: InteractionType!   # LIKE, SUPER_LIKE
   ): InteractionResult!
   
     # 用户行为操作 (喜欢/不喜欢/拉黑/举报)
  actionUser(
    targetUserId: ID!,
    type: UserActionType!    # LIKE, SUPER_LIKE, DISLIKE, BLOCK, REPORT
    metadata: String         # 额外信息，如举报原因等
  ): ActionUserResult!
   
   # ===== 动态操作 =====
   # 发布动态
   publishPost(input: PostPublishInput!): Post!
   
   # 点赞动态
   likePost(postId: ID!): Boolean!
   
   # 发布评论
   publishComment(input: CommentPublishInput!): PostComment!
   
     # ===== 消息操作 =====
  # 标记会话已读 (同步给后台统计)
  markConversationRead(conversationId: ID!): Boolean!
 }
 
 # ===== Mutation输入类型 =====
 input PostPublishInput {
   content: String!
   mediaUrls: [String!]
   location: String
   visibility: String  # PUBLIC, PRIVATE
 }
 
 input CommentPublishInput {
   postId: ID!
   content: String!
   replyTo: ID  # 回复的评论ID
 }
 
 
 
 # ===== Mutation结果类型 =====
type InteractionResult {
  isMatched: Boolean!  # 是否匹配成功
  matchedUser: User    # 如果匹配成功，返回匹配的用户信息
}

type ActionUserResult {
  success: Boolean!    # 操作是否成功
  isMatched: Boolean   # 如果是喜欢操作且匹配成功
  matchedUser: User    # 匹配的用户信息
}
 
 # ===== 通用响应类型定义 =====
 type PostListResponse {
   records: [Post!]!
   total: Int!
   size: Int!
   current: Int!
   pages: Int!
   hasMore: Boolean!
 }
 
 type PostCommentListResponse {
  records: [PostComment!]!
}
 
 type UserLikeListResponse {
   records: [UserLike!]!
   total: Int!
   size: Int!
   current: Int!
   pages: Int!
   hasMore: Boolean!
 }
 
 type ConversationListResponse {
   records: [Conversation!]!
   total: Int!
   size: Int!
   current: Int!
   pages: Int!
   hasMore: Boolean!
 }
 
 
 
 # ===== 辅助类型 =====
 
 type UserSigVO {
   userSig: String!
   sdkAppId: Int!
   imUserId: String!
 }
 
 type UserVipDetail {
   isVip: Boolean!
   vipLevel: Int!
   vipExpireTime: String
   remainingDays: Int
   features: [String!]!        # 当前拥有的特权
 }
 ```
 
 ---
 
 ### **4. Flutter页面GraphQL查询字段定义**

### **HomePage - 首页推荐Tab**
**使用Query**: `homeRecommendationFeed`
**必需字段** (几乎全部用户字段，除了binding、gender、birthDate、phone、email、incomeRange、hobbies):
```graphql
users {
  # 基础信息
  id                    # 用户ID
  nickname              # 昵称
  age                   # 年龄
  avatarUrl             # 头像
  locationName          # 位置
  language              # 语言偏好
  idealPartnerAvatar    # 理想伴侣照片
  
  # VIP会员信息
  isVip                 # VIP状态
  vipLevel              # VIP等级
  vipExpireTime         # 会员过期时间
  
  # 活跃状态信息
  lastLoginTime         # 最后登录时间
  activeDaysLastWeek    # 上周活跃天数
  
  # 认证信息
  verifications {       # 认证标签
    status              # 认证状态
    type                # 认证类型
    description         # 认证描述
    trustScore          # 信任分数
  }
  
  # 照片信息
  photos {              # 所有照片
    id
    url                 # 原图
    thumbnailUrl        # 缩略图
    isPrimary           # 是否主图
    order               # 排序
  }
  
  # 用户发布的帖子ID列表
  postIds
  
  # Q&A问答
  qaAnswers {
    questionId
    questionKey
    question
    answer
    answeredAt
  }
  
  # 地理位置灵活性偏好
  locationFlexibility {
    questionId
    questionKey
    question
    answer
    options
  }
  
  trustScore            # 信任分数
  
  # 位置信息
  latitude
  longitude
  
  # 个人详细信息
  bio                   # 自我介绍
  profession            # 职业
  marriageStatus        # 婚姻状态
  hasChildren           # 是否有孩子
  wantChildren          # 是否想要孩子
  smokingHabit          # 吸烟习惯
  drinkingHabit         # 饮酒习惯
  religion              # 宗教信仰
}
```

### **HomePage - 首页动态Tab**
**使用Query**: `homeFeed(current: Int, pageSize: Int, sortType: Int)`
**返回**: PostListResponse
**必需字段**:
```graphql
records {
  id                    # 动态ID
  content               # 动态内容
  likeCount            # 点赞数
  commentCount         # 评论数
  createdTime          # 发布时间
  updateTime           # 更新时间
  location             # 动态位置
  mediaUrls            # 媒体文件URLs
  isLiked              # 是否已点赞
  author {             # 作者信息
    id                 # 作者ID
    nickname           # 作者昵称
    avatarUrl          # 作者头像
    age                # 作者年龄
    locationName       # 作者位置
    profession         # 职业/学校/公司
    verifications      # 认证信息 (字符串格式)
  }
}
hasMore               # 是否有更多
```

### **XindongPage - 心动页面**
**使用Query**: `xindongDashboard(filter: LikeFilter, likedMePage: Int, myLikesPage: Int, mutualLikesPage: Int)`

**Tab1 - 对我心动 (likedMe)**:
```graphql
likedMe.records {
  user {
    id                 # 用户ID
    nickname           # 昵称
    avatarUrl          # 头像
    age                # 年龄
    locationName       # 位置
    profession         # 职业
    school             # 学校
    work               # 工作
    height             # 身高
    lastLoginTime      # 最后登录时间
    activeDaysLastWeek # 上周活跃天数
    verifications {    # 认证信息
      status
      type
      trustScore
    }
    photos(limit: 1) { # 第一张照片
      thumbnailUrl
    }
  }
  interactionType      # LIKE/SUPER_LIKE
  type                 # LIKED_ME
}
```

**Tab2 - 我心动的 (myLikes)**:
```graphql
myLikes.records {
  user {
    id                 # 用户ID
    nickname           # 昵称
    avatarUrl          # 头像
    age                # 年龄
    locationName       # 位置
    school             # 学校
    work               # 工作
    height             # 身高
    verifications {    # 认证状态
      status
      type
    }
  }
  interactionType      # LIKE/SUPER_LIKE
  type                 # MY_LIKE
}
```

**Tab3 - 互相心动 (mutualLikes)**:
```graphql
mutualLikes.records {
  user {
    id                 # 用户ID
    nickname           # 昵称
    avatarUrl          # 头像
    age                # 年龄
    locationName       # 位置
    school             # 学校
    work               # 工作
    height             # 身高
    isVip              # VIP状态
    vipLevel           # VIP等级
  }
  interactionType      # LIKE/SUPER_LIKE
  type                 # MUTUAL
}
```

### **MessagesPage - 消息页面**
**使用Query**: `messagesDashboard`
**必需字段**:
```graphql
conversations {
  id                   # 会话ID
  lastMessage          # 最后消息
  lastMessageTime      # 最后消息时间
  unreadCount          # 未读数
  conversationType     # 会话类型
  targetUser {         # 对方用户信息
    id                 # 用户ID
    nickname           # 昵称
    age                # 年龄
    avatarUrl          # 头像
    height             # 身高
    locationName       # 位置
    activeDaysLastWeek # 上周活跃天数
    school             # 学校
    work               # 工作
  }
}
```

### **ProfilePage - 个人资料页面**
**使用Query**: `myProfile`
**必需字段**: 完整User类型
```graphql
user {
  # 完整User类型的所有字段
  id, nickname, avatarUrl, phone, email
  gender, birthDate, age, locationCode, locationName, language, idealPartnerAvatar
  isVip, vipLevel, vipExpireTime
  lastLoginTime, activeDaysLastWeek
  verifications { status, type, description, trustScore }
  binding { phoneBindStatus, wechatBindStatus, appleBindStatus, emailBindStatus, googleBindStatus }
  photos { id, url, thumbnailUrl, isPrimary, order }
  postIds
  qaAnswers { questionId, questionKey, question, answer, answeredAt }
  locationFlexibility { questionId, questionKey, question, answer, options }
  trustScore, latitude, longitude
  bio, profession, school, work, height, incomeRange, marriageStatus
  hasChildren, wantChildren, smokingHabit, drinkingHabit, religion, hobbies
}

# 资料完整度 (0.0-1.0)
profileCompleteness

# VIP详情
vipInfo {
  isVip, vipLevel, vipExpireTime, remainingDays, features
}
```

### **ProfileDetailPage - 他人资料详情页**
**使用Query**: `userProfile(userId: ID!)`
**必需字段**: 与homeRecommendationFeed完全一样 + 关系状态
```graphql
user {
  # 基础信息
  id, nickname, age, avatarUrl, locationName, language, idealPartnerAvatar
  
  # VIP会员信息
  isVip, vipLevel, vipExpireTime
  
  # 活跃状态信息
  lastLoginTime, activeDaysLastWeek
  
  # 认证信息
  verifications {
    status, type, description, trustScore
  }
  
  # 照片信息
  photos {
    id, url, thumbnailUrl, isPrimary, order
  }
  
  # 用户发布的帖子ID列表
  postIds
  
  # Q&A问答
  qaAnswers {
    questionId, questionKey, question, answer, answeredAt
  }
  
  # 地理位置灵活性偏好
  locationFlexibility {
    questionId, questionKey, question, answer, options
  }
  
  trustScore, latitude, longitude
  
  # 个人详细信息
  bio, profession, marriageStatus, hasChildren, wantChildren
  smokingHabit, drinkingHabit, religion
}

# 关系状态
relationshipStatus {
  Iliketarget          # 我是否喜欢TA
  targetlikeme         # TA是否喜欢我
  isMatched            # 是否匹配
  isBlocked            # 是否被拉黑
}
```

### **ChatPage - 聊天页面**
**使用Query**: `chatTargetUser(targetUserId: ID!)`
**必需字段**:
```graphql
id                     # 用户ID
nickname               # 昵称
avatarUrl              # 头像
age                    # 年龄
locationName           # 位置
isVip                  # VIP状态
vipLevel               # VIP等级
lastLoginTime          # 最后登录时间
activeDaysLastWeek     # 上周活跃天数
photos(limit: 1) {     # 第一张照片
  thumbnailUrl
}
```

### **FeedDetailPage - 动态详情页**
**使用Query**: `postDetail(postId: ID!)` 和 `postComments(postId: ID!)`

**动态详情**:
```graphql
id                     # 动态ID
content                # 动态内容
mediaUrls              # 媒体URLs
likeCount             # 点赞数
commentCount          # 评论数
createdTime           # 创建时间
updateTime            # 更新时间
location              # 位置
isLiked               # 是否已点赞
author {              # 作者信息
  id                  # 作者ID
  nickname            # 作者昵称
  avatarUrl           # 作者头像
  age                 # 作者年龄
  locationName        # 作者位置
  school              # 学校
  work                # 工作
  height              # 身高
}
comments {            # 评论列表内嵌
  id                  # 评论ID
  content             # 评论内容
  createdTime         # 创建时间
  authorName          # 评论者昵称
  authorAvatarThumbnail # 评论者头像缩略图
}
```

### **UserFeedsPage - 用户动态页面**
**使用Query**: `userPosts(userId: ID!, current: Int, pageSize: Int)`
**必需字段**: 与首页动态Tab相同的字段结构