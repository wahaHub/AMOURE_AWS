# Amoure V2 交友应用前后台 API 交互合约规范

## 文档概述

本文档定义了 Amoure 交友应用 V2 版本前台（Flutter）与后台（Spring Boot）之间的完整 API 交互合约。基于重构后的数据库设计（user_info + user_profile 分离架构）和 Clean Architecture 架构，提供更加简洁、高效、现代化的 API 接口。

### 版本信息
- **版本**: v2.0
- **创建日期**: 2025-08-30
- **基础版本**: v1.0 (legacy)
- **维护团队**: Amoure V2 开发团队
- **适用范围**: Flutter Mobile App + Spring Boot Backend
- **数据库架构**: PostgreSQL + MyBatis Plus + Clean Architecture

## 1. 系统架构概览

### 1.1 技术栈对照
| 层级 | 前台 (Flutter) | 后台 (Spring Boot) |
|------|---------------|-------------------|
| 应用框架 | Flutter 3.22 | Spring Boot 2.7+ |
| 状态管理 | GetX + Provider | Spring MVC + Clean Architecture |
| 网络层 | BackendManager + HTTP | RestController + Domain Services |
| 认证 | AuthSessionManager | Sa-Token + SecurityContext |
| 缓存 | CacheManager | Redis + Caffeine |
| 数据库 | 本地 SharedPreferences | PostgreSQL + MyBatis Plus |
| Mock 数据 | V2MockDataManager | - |

### 1.2 服务端口配置
```yaml
# 后台服务端口
amoure-app:     8282  # 客户端 API 服务
amoure-manager: 8181  # 管理后台服务

# 前台配置
development: http://192.168.1.117:8282
test:        https://api.app-test.amoure.cn
production:  https://api.app.amoure.cn
```

### 1.3 V2 架构改进
- **统一响应格式**: 所有 API 使用标准化的 `Result<T>` 响应格式
- **RESTful 设计**: 遵循 REST 最佳实践，使用语义化的 HTTP 方法
- **领域驱动设计**: 基于 Clean Architecture 的分层设计
- **类型安全**: 强类型 DTO/VO 定义，避免字段不一致
- **Mock 数据支持**: 内置 Mock Data 系统，支持离线开发测试

## 2. API 设计规范

### 2.1 统一响应格式

所有 V2 API 接口统一使用以下响应格式：

```json
{
  "success": true,              // 是否成功
  "data": {},                  // 响应数据(具体结构见各接口)
  "message": "操作成功",         // 响应消息
  "timestamp": "2025-08-30T10:30:00Z",  // 响应时间
  "requestId": "uuid-string"    // 请求追踪ID
}
```

### 2.2 错误响应格式

```json
{
  "success": false,
  "data": null,
  "message": "具体错误信息",
  "timestamp": "2025-08-30T10:30:00Z",
  "requestId": "uuid-string"
}
```

### 2.3 HTTP 状态码规范

| 状态码 | 场景 | 说明 |
|-------|------|------|
| 200 | 成功 | 请求处理成功 |
| 400 | 客户端错误 | 参数验证失败、业务规则违反 |
| 401 | 认证失败 | Token 无效或过期 |
| 403 | 权限不足 | 有认证但无权限访问 |
| 404 | 资源不存在 | 请求的资源不存在 |
| 429 | 限流 | 请求频率过高 |
| 500 | 服务器错误 | 系统内部错误 |

### 2.4 Flutter 请求标准

#### 2.4.1 请求头规范
```dart
Map<String, String> headers = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'Authorization': 'Bearer ${token}',  // 需要认证的接口
  'User-Agent': 'Amoure-Flutter/${appVersion}',
  'X-Request-ID': '${UUID.v4()}',     // 请求追踪ID
  'X-Client-Version': '${appVersion}',
  'X-Platform': '${Platform.isIOS ? "iOS" : "Android"}',
};
```

#### 2.4.2 缓存策略配置
```dart
static const Map<String, Duration> apiCacheTTL = {
  '/api/v2/user': Duration(minutes: 15),           // 用户资料
  '/api/v2/recommendation': Duration(minutes: 30), // 推荐列表
  '/api/v2/conversation': Duration(minutes: 5),    // 会话列表
  '/api/v2/feed': Duration(minutes: 5),            // 动态内容
  '/api/v2/interactions/xindong': Duration(minutes: 10), // 心动列表
};
```

## 3. 核心业务 API 合约详细规范

### 3.1 用户管理模块 (/api/v2/user)

#### 3.1.1 获取用户信息

**接口基本信息**
- **URL**: `GET /api/v2/user`
- **描述**: 获取用户完整资料信息，支持获取当前用户或指定用户信息
- **认证**: 需要
- **缓存**: 支持，15分钟TTL

**请求参数**
| 参数名 | 类型 | 必填 | 描述 | 示例 |
|-------|------|------|------|------|
| userId | String | 否 | 用户ID，为空时返回当前用户 | "123" |
| fields | String | 否 | 字段筛选，逗号分隔 | "basic,photos,verification" |

**Flutter 调用示例**
```dart
class UserV2Service extends BaseService {
  /// 获取用户资料
  /// [userId] 用户ID，为空时获取当前用户
  /// [fields] 字段筛选，可选值：basic, photos, verification, qa_answers, location_flexibility
  Future<Map<String, dynamic>> getUserProfile({
    String? userId,
    List<String>? fields,
  }) async {
    final params = <String, String>{};
    if (userId != null) params['userId'] = userId;
    if (fields != null) params['fields'] = fields.join(',');
    
    return await makeRequest(
      '/api/v2/user',
      method: 'GET',
      params: params,
      cacheTTL: Duration(minutes: 15),
    );
  }

  /// 获取当前用户资料（快捷方法）
  Future<UnifiedUserProfile> getCurrentUser() async {
    final response = await getUserProfile();
    return UnifiedUserProfile.fromJson(response['data']);
  }
  
  /// 获取其他用户公开资料
  Future<PublicUserProfile> getOtherUser(String userId) async {
    final response = await getUserProfile(userId: userId);
    return PublicUserProfile.fromJson(response['data']);
  }
}
```

**完整响应格式**
```json
{
  "success": true,
  "data": {
    // 基础信息
    "userId": "123",
    "nickname": "小美",
    "avatar": "https://cdn.amoure.cn/avatars/123.jpg",
    "age": 25,
    "gender": "FEMALE",
    "height": 165,
    "weight": 50,
    "birthDate": "1999-03-15",
    "location": "北京市朝阳区",
    "hometown": "江苏南京",
    "lastActiveTime": "2025-08-30T08:30:00Z",
    
    // 教育和职业信息
    "education": "本科",
    "occupation": "软件工程师",
    "school": "本科", // 兼容前端字段
    "work": "软件工程师", // 兼容前端字段
    "incomeRange": "10-15万",
    
    // 个人详情
    "relationshipStatus": "单身",
    "marriageStatus": "单身", // 兼容字段
    "hasChildren": 0,
    "wantChildren": 1,
    "smokingHabit": "不吸烟",
    "drinkingHabit": "偶尔喝酒",
    "religion": "无宗教信仰",
    "selfIntroduction": "喜欢旅行和美食，希望找到志同道合的人...",
    
    // 照片信息
    "photos": [
      {
        "photoId": "p1",
        "url": "https://cdn.amoure.cn/photos/123/p1.jpg",
        "photoType": 2, // 1-普通, 2-头像, 3-验证照片
        "sortOrder": 1,
        "reviewStatus": "APPROVED"
      },
      {
        "photoId": "p2",
        "url": "https://cdn.amoure.cn/photos/123/p2.jpg",
        "photoType": 1,
        "sortOrder": 2,
        "reviewStatus": "APPROVED"
      }
    ],
    
    // 兴趣爱好
    "hobbies": [
      "旅行",
      "美食",
      "摄影",
      "读书"
    ],
    
    // QA答案（结构化对象格式）
    "qaAnswers": {
      "personality_type": "INTJ",
      "ideal_relationship": "认真恋爱",
      "weekend_activity": "在家放松",
      "travel_preference": "国内旅行",
      "pet_attitude": "喜欢小动物",
      "fitness_habit": "偶尔运动",
      "food_preference": "中式料理",
      "movie_type": "爱情片",
      "music_style": "流行音乐",
      "book_genre": "小说"
    },
    
    // 地理灵活性答案（结构化对象格式）
    "locationFlexibilityAnswers": {
      "acceptLongDistance": "YES", // YES, NO, MAYBE
      "willingToRelocate": "MAYBE",
      "helpPartnerRelocate": "YES"
    },
    
    // 认证状态
    "verificationStatus": {
      "identity": true,        // 身份认证
      "school": false,         // 学历认证
      "career": true,          // 职业认证
      "realPerson": true,      // 真人认证
      "identityTrustScore": 85,
      "schoolTrustScore": 0,
      "careerTrustScore": 92
    },
    
    // 活跃信息
    "activeDays": 3,           // 距离最后活跃天数
    "registrationDays": 180,   // 注册天数
    
    // 其他信息
    "idealPartnerAvatar": "https://cdn.amoure.cn/ideal/123.jpg"
  },
  "message": "获取用户信息成功",
  "timestamp": "2025-08-30T10:30:00Z",
  "requestId": "uuid-123"
}
```

#### 3.1.2 更新用户信息

**接口基本信息**
- **URL**: `PATCH /api/v2/user`
- **描述**: 更新用户资料信息，支持部分字段更新
- **认证**: 需要
- **缓存**: 更新成功后清除缓存

**请求体格式**
```json
{
  // 基础信息（可选更新）
  "nickname": "新昵称",
  "height": 170,
  "weight": 55,
  "selfIntroduction": "更新的个人介绍...",
  
  // QA答案更新
  "qaAnswers": {
    "personality_type": "ENFP",
    "ideal_relationship": "结婚导向",
    "weekend_activity": "户外活动"
  },
  
  // 地理灵活性更新
  "locationFlexibility": {
    "acceptLongDistance": "NO",
    "willingToRelocate": "YES",
    "helpPartnerRelocate": "MAYBE"
  },
  
  // 其他字段
  "hobbies": ["游泳", "健身", "音乐"],
  "smokingHabit": "不吸烟",
  "drinkingHabit": "社交性饮酒"
}
```

**Flutter 调用示例**
```dart
/// 更新用户资料
Future<bool> updateUserProfile({
  String? nickname,
  int? height,
  int? weight,
  String? selfIntroduction,
  Map<String, dynamic>? qaAnswers,
  Map<String, dynamic>? locationFlexibility,
  List<String>? hobbies,
  String? smokingHabit,
  String? drinkingHabit,
}) async {
  final body = <String, dynamic>{};
  if (nickname != null) body['nickname'] = nickname;
  if (height != null) body['height'] = height;
  if (weight != null) body['weight'] = weight;
  if (selfIntroduction != null) body['selfIntroduction'] = selfIntroduction;
  if (qaAnswers != null) body['qaAnswers'] = qaAnswers;
  if (locationFlexibility != null) body['locationFlexibility'] = locationFlexibility;
  if (hobbies != null) body['hobbies'] = hobbies;
  if (smokingHabit != null) body['smokingHabit'] = smokingHabit;
  if (drinkingHabit != null) body['drinkingHabit'] = drinkingHabit;
  
  final response = await makeRequest(
    '/api/v2/user',
    method: 'PATCH',
    body: body,
  );
  
  return response['success'] == true;
}
```

**响应格式**
```json
{
  "success": true,
  "data": true,
  "message": "用户资料更新成功",
  "timestamp": "2025-08-30T10:35:00Z",
  "requestId": "uuid-124"
}
```

#### 3.1.3 保存基础信息

**接口基本信息**
- **URL**: `POST /api/v2/user/basic`
- **描述**: 保存或更新用户基础资料，主要用于注册引导流程
- **认证**: 需要
- **缓存**: 保存成功后清除用户缓存

**请求体格式**
```json
{
  "nickname": "小美",
  "gender": "FEMALE", // MALE, FEMALE
  "birthDate": "1999-03-15",
  "height": 165,
  "locationCode": "110105",
  "locationName": "北京市朝阳区",
  "avatarUrl": "https://cdn.amoure.cn/avatars/123.jpg",
  "idealPartnerAvatar": "https://cdn.amoure.cn/ideal/123.jpg"
}
```

**Flutter 调用示例**
```dart
/// 保存用户基础信息（注册引导使用）
Future<bool> saveBasicInfo({
  required String nickname,
  required String gender,
  required String birthDate,
  int? height,
  String? locationCode,
  String? locationName,
  String? avatarUrl,
  String? idealPartnerAvatar,
}) async {
  final body = {
    'nickname': nickname,
    'gender': gender,
    'birthDate': birthDate,
    'language': 'zh', // 默认中文
  };
  
  if (height != null) body['height'] = height;
  if (locationCode != null) body['locationCode'] = locationCode;
  if (locationName != null) body['locationName'] = locationName;
  if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
  if (idealPartnerAvatar != null) body['idealPartnerAvatar'] = idealPartnerAvatar;
  
  final response = await makeRequest(
    '/api/v2/user/basic',
    method: 'POST',
    body: body,
  );
  
  return response['success'] == true;
}
```

### 3.2 推荐系统模块 (/api/v2/recommendation)

#### 3.2.1 获取每日推荐

**接口基本信息**
- **URL**: `GET /api/v2/recommendation`
- **描述**: 获取当前用户的每日推荐用户列表
- **认证**: 需要
- **缓存**: 支持，30分钟TTL

**请求参数**
| 参数名 | 类型 | 必填 | 描述 | 示例 |
|-------|------|------|------|------|
| date | String | 否 | 日期，YYYY-MM-DD格式 | "2025-08-30" |

**Flutter 调用示例**
```dart
class RecommendationV2Service extends BaseService {
  /// 获取每日推荐
  Future<List<RecommendationUser>> getDailyRecommendations({
    String? date,
  }) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    
    final response = await makeRequest(
      '/api/v2/recommendation',
      method: 'GET',
      params: params,
      cacheTTL: Duration(minutes: 30),
    );
    
    if (response['success'] == true) {
      final users = response['data']['users'] as List;
      return users.map((json) => RecommendationUser.fromJson(json)).toList();
    }
    
    return [];
  }

  /// 刷新推荐列表
  Future<List<RecommendationUser>> refreshRecommendations() async {
    final response = await makeRequest(
      '/api/v2/recommendation/refresh',
      method: 'POST',
    );
    
    if (response['success'] == true) {
      final users = response['data']['users'] as List;
      return users.map((json) => RecommendationUser.fromJson(json)).toList();
    }
    
    return [];
  }
}
```

**完整响应格式**
```json
{
  "success": true,
  "data": {
    "type": "daily",
    "users": [
      {
        // 基础信息
        "userId": "456",
        "nickname": "小帅",
        "avatar": "https://cdn.amoure.cn/avatars/456.jpg",
        "age": 28,
        "gender": "MALE",
        "height": 175,
        "weight": 68,
        "location": "上海市浦东新区",
        "hometown": "广东深圳",
        
        // 教育和职业
        "education": "硕士",
        "occupation": "产品经理",
        "school": "硕士", // 兼容前端字段
        "work": "产品经理", // 兼容前端字段
        
        // 个人信息
        "selfIntroduction": "热爱运动和旅行，喜欢尝试新事物...",
        "relationshipStatus": "单身",
        "marriageStatus": "单身",
        "hasChildren": 0,
        "wantChildren": 1,
        "smokingHabit": "不吸烟",
        "drinkingHabit": "偶尔喝酒",
        "religion": "无宗教信仰",
        
        // 照片
        "photos": [
          {
            "photoId": "p456_1",
            "url": "https://cdn.amoure.cn/photos/456/p1.jpg",
            "photoType": 2,
            "sortOrder": 1
          }
        ],
        
        // 兴趣爱好
        "hobbies": [
          "健身",
          "旅行",
          "摄影"
        ],
        
        // QA答案
        "qaAnswers": {
          "personality_type": "ESFP",
          "ideal_relationship": "认真恋爱",
          "weekend_activity": "户外活动",
          "travel_preference": "国外旅行",
          "fitness_habit": "经常锻炼"
        },
        
        // 地理灵活性
        "locationFlexibilityAnswers": {
          "acceptLongDistance": "YES",
          "willingToRelocate": "NO",
          "helpPartnerRelocate": "MAYBE"
        },
        
        // 认证状态
        "verificationStatus": {
          "identity": true,
          "school": true,
          "career": true,
          "identityTrustScore": 92,
          "schoolTrustScore": 88,
          "careerTrustScore": 95
        },
        
        // 推荐相关
        "tags": ["阳光", "运动达人", "高学历", "真诚交友"],
        "distance": 5.2, // 距离（公里）
        "activeDays": 1, // 最后活跃天数
        "registrationDays": 90,
        "isVip": true,
        "lastActiveTime": "2025-08-30T09:15:00Z",
        "birthDate": "1996-05-20"
      }
      // ... 更多推荐用户
    ],
    "pagination": {
      "hasMore": false,
      "nextCursor": null
    }
  },
  "message": "获取推荐成功",
  "timestamp": "2025-08-30T11:00:00Z",
  "requestId": "uuid-125"
}
```

#### 3.2.2 刷新推荐

**接口基本信息**
- **URL**: `POST /api/v2/recommendation/refresh`
- **描述**: 刷新推荐列表，清除缓存重新获取
- **认证**: 需要
- **缓存**: 清除相关缓存

### 3.3 互动系统模块 (/api/v2/interactions)

#### 3.3.1 用户互动操作

**接口基本信息**
- **URL**: `POST /api/v2/interactions`
- **描述**: 对其他用户进行互动操作（喜欢、超级喜欢、跳过、拉黑）
- **认证**: 需要
- **缓存**: 操作成功后清除相关缓存

**请求体格式**
```json
{
  "targetUserId": 456,
  "type": 1 // 1-喜欢, 2-超级喜欢, 3-跳过, 4-拉黑
}
```

**Flutter 调用示例**
```dart
enum InteractionType { like, superLike, pass, block }

class InteractionV2Service extends BaseService {
  /// 用户互动操作
  Future<InteractionResult> interactWithUser({
    required String targetUserId,
    required InteractionType type,
  }) async {
    int typeValue;
    switch (type) {
      case InteractionType.like:
        typeValue = 1;
        break;
      case InteractionType.superLike:
        typeValue = 2;
        break;
      case InteractionType.pass:
        typeValue = 3;
        break;
      case InteractionType.block:
        typeValue = 4;
        break;
    }
    
    final response = await makeRequest(
      '/api/v2/interactions',
      method: 'POST',
      body: {
        'targetUserId': int.parse(targetUserId),
        'type': typeValue,
      },
    );
    
    if (response['success'] == true) {
      return InteractionResult.fromJson(response['data']);
    }
    
    throw Exception('互动操作失败: ${response['message']}');
  }

  /// 喜欢用户
  Future<InteractionResult> likeUser(String targetUserId) =>
      interactWithUser(targetUserId: targetUserId, type: InteractionType.like);

  /// 超级喜欢用户
  Future<InteractionResult> superLikeUser(String targetUserId) =>
      interactWithUser(targetUserId: targetUserId, type: InteractionType.superLike);

  /// 跳过用户
  Future<InteractionResult> passUser(String targetUserId) =>
      interactWithUser(targetUserId: targetUserId, type: InteractionType.pass);

  /// 拉黑用户
  Future<InteractionResult> blockUser(String targetUserId) =>
      interactWithUser(targetUserId: targetUserId, type: InteractionType.block);
}
```

**响应格式**
```json
{
  "success": true,
  "data": {
    "targetUserId": 456,
    "type": 1,
    "isMatched": true // 是否产生了匹配
  },
  "message": "互动操作成功",
  "timestamp": "2025-08-30T11:05:00Z",
  "requestId": "uuid-126"
}
```

#### 3.3.2 心动列表 (Xindong)

**接口基本信息**
- **URL**: `GET /api/v2/interactions/xindong`
- **描述**: 获取心动列表，包含三种类型的互动关系
- **认证**: 需要
- **缓存**: 支持，10分钟TTL

**请求参数**
| 参数名 | 类型 | 必填 | 描述 | 可选值 |
|-------|------|------|------|--------|
| type | String | 是 | 心动类型 | liked_by_me, i_liked, mutual_liked |
| filter | String | 否 | 筛选条件 | all, recent_online, profile_complete, recent_active, verified, recommended |
| cursor | String | 否 | 分页游标 | 页码字符串 |
| limit | Integer | 否 | 每页数量，默认20 | 1-50 |

**Flutter 调用示例**
```dart
enum XindongType {
  likedByMe,    // 心动我的用户
  iLiked,       // 我心动的用户  
  mutualLiked,  // 相互心动的用户
}

enum XindongFilter {
  all,                // 全部
  recentOnline,      // 最近在线
  profileComplete,   // 资料完整
  recentActive,      // 最近活跃
  verified,          // 已认证
  recommended,       // 推荐
}

class XindongService extends BaseService {
  /// 获取心动列表
  Future<XindongResponse> getXindongList({
    required XindongType type,
    XindongFilter filter = XindongFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    String typeStr;
    switch (type) {
      case XindongType.likedByMe:
        typeStr = 'liked_by_me';
        break;
      case XindongType.iLiked:
        typeStr = 'i_liked';
        break;
      case XindongType.mutualLiked:
        typeStr = 'mutual_liked';
        break;
    }
    
    String filterStr;
    switch (filter) {
      case XindongFilter.all:
        filterStr = 'all';
        break;
      case XindongFilter.recentOnline:
        filterStr = 'recent_online';
        break;
      case XindongFilter.profileComplete:
        filterStr = 'profile_complete';
        break;
      case XindongFilter.recentActive:
        filterStr = 'recent_active';
        break;
      case XindongFilter.verified:
        filterStr = 'verified';
        break;
      case XindongFilter.recommended:
        filterStr = 'recommended';
        break;
    }
    
    final params = {
      'type': typeStr,
      'filter': filterStr,
      'limit': limit.toString(),
    };
    if (cursor != null) params['cursor'] = cursor;
    
    final response = await makeRequest(
      '/api/v2/interactions/xindong',
      method: 'GET',
      params: params,
      cacheTTL: Duration(minutes: 10),
    );
    
    if (response['success'] == true) {
      return XindongResponse.fromJson(response['data']);
    }
    
    throw Exception('获取心动列表失败: ${response['message']}');
  }
}
```

**完整响应格式**
```json
{
  "success": true,
  "data": {
    "type": "liked_by_me", // 请求的类型
    "filter": "all", // 应用的筛选
    "users": [
      {
        // 基础信息
        "userId": "789",
        "nickname": "小丽",
        "avatar": "https://cdn.amoure.cn/avatars/789.jpg",
        "age": 26,
        "gender": "FEMALE",
        "height": 162,
        "location": "深圳市南山区",
        
        // 教育职业
        "education": "本科",
        "occupation": "UI设计师",
        
        // 互动信息
        "interactionTime": "2025-08-30T09:30:00Z", // 互动时间
        "interactionType": 1, // 1-喜欢, 2-超级喜欢
        "isMutual": false, // 是否相互
        
        // 活跃状态
        "activeDays": 2,
        "isOnline": false,
        "lastActiveTime": "2025-08-30T07:45:00Z",
        
        // 认证状态
        "verificationStatus": {
          "identity": true,
          "school": false,
          "career": true,
          "identityTrustScore": 78,
          "careerTrustScore": 85
        },
        
        // 照片（首张）
        "photos": [
          {
            "photoId": "p789_1",
            "url": "https://cdn.amoure.cn/photos/789/p1.jpg",
            "photoType": 2,
            "sortOrder": 1
          }
        ]
      }
      // ... 更多用户
    ],
    "pagination": {
      "hasMore": true,
      "nextCursor": "2",
      "total": 45,
      "currentPage": 1,
      "pageSize": 20
    },
    "stats": {
      "totalCount": 45, // 该类型总数
      "newCount": 3,    // 新增数量
      "mutualCount": 12 // 相互数量（仅对 i_liked 类型有效）
    }
  },
  "message": "获取心动列表成功",
  "timestamp": "2025-08-30T11:10:00Z",
  "requestId": "uuid-127"
}
```

### 3.4 动态内容模块 (/api/v2/feed)

#### 3.4.1 获取动态列表

**接口基本信息**
- **URL**: `GET /api/v2/feed`
- **描述**: 获取动态列表，支持获取全部动态或指定用户动态
- **认证**: 需要
- **缓存**: 支持，5分钟TTL

**请求参数**
| 参数名 | 类型 | 必填 | 描述 | 可选值 |
|-------|------|------|------|--------|
| type | String | 否 | 动态类型，默认all | all, user |
| userId | String | 否 | 用户ID（type为user时使用） | 用户ID字符串 |
| cursor | String | 否 | 游标分页 | 页码字符串 |
| limit | Integer | 否 | 每页数量，默认15 | 1-50 |

**Flutter 调用示例**
```dart
enum FeedType { all, user }

class FeedV2Service extends BaseService {
  /// 获取动态列表
  Future<FeedResponse> getFeedPosts({
    FeedType type = FeedType.all,
    String? userId,
    String? cursor,
    int limit = 15,
  }) async {
    final params = <String, String>{
      'type': type == FeedType.all ? 'all' : 'user',
      'limit': limit.toString(),
    };
    if (userId != null) params['userId'] = userId;
    if (cursor != null) params['cursor'] = cursor;
    
    final response = await makeRequest(
      '/api/v2/feed',
      method: 'GET',
      params: params,
      cacheTTL: Duration(minutes: 5),
    );
    
    if (response['success'] == true) {
      return FeedResponse.fromJson(response['data']);
    }
    
    throw Exception('获取动态失败: ${response['message']}');
  }

  /// 获取全部动态
  Future<FeedResponse> getAllPosts({
    String? cursor,
    int limit = 15,
  }) => getFeedPosts(type: FeedType.all, cursor: cursor, limit: limit);

  /// 获取指定用户动态
  Future<FeedResponse> getUserPosts({
    required String userId,
    String? cursor,
    int limit = 15,
  }) => getFeedPosts(type: FeedType.user, userId: userId, cursor: cursor, limit: limit);
}
```

**完整响应格式**
```json
{
  "success": true,
  "data": {
    "posts": [
      {
        "postId": "p123",
        "author": {
          "userId": "u123",
          "nickname": "小美",
          "avatar": "https://cdn.amoure.cn/avatars/u123.jpg",
          "age": 25,
          "location": "北京市朝阳区",
          "verificationStatus": {
            "identity": true,
            "school": false,
            "career": true
          }
        },
        "content": "今天天气真好！去了颐和园拍照 📸",
        "mediaUrls": [
          "https://cdn.amoure.cn/posts/p123/img1.jpg",
          "https://cdn.amoure.cn/posts/p123/img2.jpg"
        ],
        "postType": 2, // 1-纯文字, 2-图片, 3-视频
        "location": "北京市海淀区颐和园",
        "tags": ["旅行", "摄影", "美景"],
        "stats": {
          "likeCount": 15,
          "commentCount": 3,
          "viewCount": 120,
          "shareCount": 2
        },
        "isLiked": false, // 当前用户是否已点赞
        "visibility": 1, // 1-公开, 2-仅匹配用户, 3-私密
        "reviewStatus": "APPROVED", // 审核状态
        "createdAt": "2025-08-30T10:00:00Z",
        "updatedAt": "2025-08-30T10:00:00Z"
      },
      {
        "postId": "p124",
        "author": {
          "userId": "u456",
          "nickname": "小帅",
          "avatar": "https://cdn.amoure.cn/avatars/u456.jpg",
          "age": 28,
          "location": "上海市浦东新区"
        },
        "content": "周末健身房撸铁 💪 保持好身材才能遇到更好的人",
        "mediaUrls": [],
        "postType": 1,
        "location": null,
        "tags": ["健身", "励志"],
        "stats": {
          "likeCount": 8,
          "commentCount": 1,
          "viewCount": 56,
          "shareCount": 0
        },
        "isLiked": true,
        "visibility": 1,
        "reviewStatus": "APPROVED",
        "createdAt": "2025-08-30T08:30:00Z",
        "updatedAt": "2025-08-30T08:30:00Z"
      }
    ],
    "pagination": {
      "hasMore": true,
      "nextCursor": "2",
      "total": 156,
      "currentPage": 1,
      "pageSize": 15
    }
  },
  "message": "获取动态成功",
  "timestamp": "2025-08-30T11:15:00Z",
  "requestId": "uuid-128"
}
```

#### 3.4.2 发布动态

**接口基本信息**
- **URL**: `POST /api/v2/feed`
- **描述**: 发布新动态
- **认证**: 需要
- **缓存**: 发布成功后清除动态列表缓存

**请求体格式**
```json
{
  "content": "今天心情很好！",
  "mediaUrls": [
    "https://cdn.amoure.cn/temp/img1.jpg",
    "https://cdn.amoure.cn/temp/img2.jpg"
  ],
  "postType": 2,
  "location": "北京市朝阳区",
  "tags": ["心情", "分享"],
  "visibility": 1
}
```

**Flutter 调用示例**
```dart
enum PostType { text, image, video }
enum PostVisibility { public, matchedOnly, private }

/// 发布动态
Future<Post> publishPost({
  required String content,
  List<String>? mediaUrls,
  PostType type = PostType.text,
  String? location,
  List<String>? tags,
  PostVisibility visibility = PostVisibility.public,
}) async {
  int postType;
  switch (type) {
    case PostType.text:
      postType = 1;
      break;
    case PostType.image:
      postType = 2;
      break;
    case PostType.video:
      postType = 3;
      break;
  }
  
  int visibilityValue;
  switch (visibility) {
    case PostVisibility.public:
      visibilityValue = 1;
      break;
    case PostVisibility.matchedOnly:
      visibilityValue = 2;
      break;
    case PostVisibility.private:
      visibilityValue = 3;
      break;
  }
  
  final response = await makeRequest(
    '/api/v2/feed',
    method: 'POST',
    body: {
      'content': content,
      'mediaUrls': mediaUrls ?? [],
      'postType': postType,
      'location': location,
      'tags': tags ?? [],
      'visibility': visibilityValue,
    },
  );
  
  if (response['success'] == true) {
    return Post.fromJson(response['data']);
  }
  
  throw Exception('发布动态失败: ${response['message']}');
}
```

#### 3.4.3 动态互动操作

**接口基本信息**
- **URL**: `POST /api/v2/feed/{postId}/like` 点赞
- **URL**: `DELETE /api/v2/feed/{postId}/like` 取消点赞
- **描述**: 对动态进行点赞或取消点赞操作
- **认证**: 需要
- **缓存**: 操作成功后清除相关缓存

**Flutter 调用示例**
```dart
/// 点赞动态
Future<bool> likePost(String postId) async {
  final response = await makeRequest(
    '/api/v2/feed/$postId/like',
    method: 'POST',
  );
  
  if (response['success'] == true) {
    return response['data']['isLiked'] as bool;
  }
  
  throw Exception('点赞失败: ${response['message']}');
}

/// 取消点赞动态
Future<bool> unlikePost(String postId) async {
  final response = await makeRequest(
    '/api/v2/feed/$postId/like',
    method: 'DELETE',
  );
  
  if (response['success'] == true) {
    return !(response['data']['isLiked'] as bool);
  }
  
  throw Exception('取消点赞失败: ${response['message']}');
}
```

**响应格式**
```json
{
  "success": true,
  "data": {
    "postId": "p123",
    "isLiked": true,
    "likeCount": 16
  },
  "message": "点赞成功",
  "timestamp": "2025-08-30T11:20:00Z",
  "requestId": "uuid-129"
}
```

### 3.5 会话系统模块 (/api/v2/conversation)

#### 3.5.1 获取会话列表

**接口基本信息**
- **URL**: `GET /api/v2/conversation`
- **描述**: 获取当前用户的所有匹配会话列表，自动检查和创建缺失的IM会话
- **认证**: 需要
- **缓存**: 支持，5分钟TTL

**请求参数**
| 参数名 | 类型 | 必填 | 描述 | 示例 |
|-------|------|------|------|------|
| cursor | String | 否 | 分页游标 | "1" |
| limit | Integer | 否 | 每页数量，默认20 | 20 |

**Flutter 调用示例**
```dart
class ConversationV2Service extends BaseService {
  /// 获取会话列表
  Future<List<Conversation>> getConversationList({
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (cursor != null) params['cursor'] = cursor;
    
    final response = await makeRequest(
      '/api/v2/conversation',
      method: 'GET',
      params: params,
      cacheTTL: Duration(minutes: 5),
    );
    
    if (response['success'] == true) {
      final conversations = response['data']['conversations'] as List;
      return conversations.map((json) => Conversation.fromJson(json)).toList();
    }
    
    return [];
  }
}
```

**完整响应格式**
```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "conversationId": "C2C_123_456",
        "otherUserId": "456",
        "otherUserNickname": "小帅",
        "otherUserAvatarUrl": "https://cdn.amoure.cn/avatars/456.jpg",
        "otherUserAge": 28,
        "otherUserLocation": "上海市浦东新区",
        "otherUserOccupation": "产品经理",
        "otherUserCompany": "某科技公司",
        "otherUserEducation": "硕士",
        "otherUserHeight": 175,
        "otherUserSchool": "某大学",
        
        "lastMessage": {
          "messageId": "m789",
          "content": "你好，很高兴认识你",
          "messageType": 1, // 1-文本, 2-图片, 3-语音, 4-视频, 5-表情包
          "sendTime": "2025-08-30T15:30:00Z",
          "senderId": "456",
          "messageStatus": 3 // 1-已发送, 2-已送达, 3-已读
        },
        
        "unreadCount": 2,
        "lastMessageTime": "2025-08-30T15:30:00Z",
        "matchTime": "2025-08-30T10:00:00Z",
        "canSendMessage": true,
        
        "conversationStatus": 1, // 1-正常, 0-删除
        "createdAt": "2025-08-30T10:00:00Z",
        "updatedAt": "2025-08-30T15:30:00Z"
      }
      // ... 更多会话
    ],
    "pagination": {
      "hasMore": false,
      "nextCursor": null,
      "total": 8,
      "currentPage": 1,
      "pageSize": 20
    }
  },
  "message": "获取会话列表成功",
  "timestamp": "2025-08-30T16:00:00Z",
  "requestId": "uuid-130"
}
```

#### 3.5.2 发送消息

**接口基本信息**
- **URL**: `POST /api/v2/conversation/{conversationId}/messages`
- **描述**: 在指定会话中发送消息
- **认证**: 需要
- **缓存**: 发送成功后清除会话缓存

**请求体格式**
```json
{
  "receiverId": 456,
  "messageType": 1,
  "content": "你好，很高兴认识你！",
  "mediaUrl": null
}
```

**Flutter 调用示例**
```dart
enum MessageType { text, image, voice, video, emoji }

/// 发送消息
Future<Message> sendMessage({
  required String conversationId,
  required String receiverId,
  required MessageType messageType,
  required String content,
  String? mediaUrl,
}) async {
  int typeValue;
  switch (messageType) {
    case MessageType.text:
      typeValue = 1;
      break;
    case MessageType.image:
      typeValue = 2;
      break;
    case MessageType.voice:
      typeValue = 3;
      break;
    case MessageType.video:
      typeValue = 4;
      break;
    case MessageType.emoji:
      typeValue = 5;
      break;
  }
  
  final response = await makeRequest(
    '/api/v2/conversation/$conversationId/messages',
    method: 'POST',
    body: {
      'receiverId': int.parse(receiverId),
      'messageType': typeValue,
      'content': content,
      'mediaUrl': mediaUrl,
    },
  );
  
  if (response['success'] == true) {
    return Message.fromJson(response['data']);
  }
  
  throw Exception('发送消息失败: ${response['message']}');
}
```

**响应格式**
```json
{
  "success": true,
  "data": {
    "messageId": "m790",
    "conversationId": "C2C_123_456",
    "senderId": "123",
    "receiverId": "456",
    "messageType": 1,
    "content": "你好，很高兴认识你！",
    "mediaUrl": null,
    "messageStatus": 1,
    "sendTime": "2025-08-30T16:05:00Z",
    "deliveredTime": null,
    "readTime": null,
    "isRecalled": false
  },
  "message": "消息发送成功",
  "timestamp": "2025-08-30T16:05:00Z",
  "requestId": "uuid-131"
}
```

#### 3.5.3 获取消息历史

**接口基本信息**
- **URL**: `GET /api/v2/conversation/{conversationId}/messages`
- **描述**: 获取指定会话的消息历史记录
- **认证**: 需要
- **缓存**: 不缓存（实时性要求高）

**请求参数**
| 参数名 | 类型 | 必填 | 描述 | 示例 |
|-------|------|------|------|------|
| page | Integer | 否 | 页码，默认1 | 1 |
| size | Integer | 否 | 每页数量，默认50 | 50 |

**Flutter 调用示例**
```dart
/// 获取消息历史
Future<MessagesResponse> getMessages({
  required String conversationId,
  int page = 1,
  int size = 50,
}) async {
  final params = {
    'page': page.toString(),
    'size': size.toString(),
  };
  
  final response = await makeRequest(
    '/api/v2/conversation/$conversationId/messages',
    method: 'GET',
    params: params,
  );
  
  if (response['success'] == true) {
    return MessagesResponse.fromJson(response['data']);
  }
  
  throw Exception('获取消息历史失败: ${response['message']}');
}
```

#### 3.5.4 标记消息已读

**接口基本信息**
- **URL**: `PUT /api/v2/conversation/{conversationId}/read`
- **描述**: 标记指定会话的消息为已读
- **认证**: 需要
- **缓存**: 操作成功后清除会话缓存

**Flutter 调用示例**
```dart
/// 标记消息为已读
Future<bool> markMessagesAsRead(String conversationId) async {
  final response = await makeRequest(
    '/api/v2/conversation/$conversationId/read',
    method: 'PUT',
  );
  
  return response['success'] == true;
}
```

### 3.6 举报系统模块 (/api/v2/reports)

#### 3.6.1 提交用户举报

**接口基本信息**
- **URL**: `POST /api/v2/reports`
- **描述**: 提交对其他用户的举报
- **认证**: 需要
- **缓存**: 不缓存

**请求体格式**
```json
{
  "targetUserId": 456,
  "reason": "INAPPROPRIATE_CONTENT", // 举报原因枚举
  "description": "发布了不当内容",
  "evidenceUrls": [
    "https://cdn.amoure.cn/evidence/e1.jpg"
  ]
}
```

**举报原因枚举**
- `INAPPROPRIATE_CONTENT`: 不当内容
- `HARASSMENT`: 骚扰行为
- `FAKE_PROFILE`: 虚假资料
- `SPAM`: 垃圾信息
- `SCAM`: 诈骗行为
- `UNDERAGE`: 未成年人
- `OTHER`: 其他

**Flutter 调用示例**
```dart
enum ReportReason {
  inappropriateContent,
  harassment,
  fakeProfile,
  spam,
  scam,
  underage,
  other,
}

class ReportV2Service extends BaseService {
  /// 举报用户
  Future<ReportResult> reportUser({
    required String targetUserId,
    required ReportReason reason,
    required String description,
    List<String>? evidenceUrls,
  }) async {
    String reasonStr;
    switch (reason) {
      case ReportReason.inappropriateContent:
        reasonStr = 'INAPPROPRIATE_CONTENT';
        break;
      case ReportReason.harassment:
        reasonStr = 'HARASSMENT';
        break;
      case ReportReason.fakeProfile:
        reasonStr = 'FAKE_PROFILE';
        break;
      case ReportReason.spam:
        reasonStr = 'SPAM';
        break;
      case ReportReason.scam:
        reasonStr = 'SCAM';
        break;
      case ReportReason.underage:
        reasonStr = 'UNDERAGE';
        break;
      case ReportReason.other:
        reasonStr = 'OTHER';
        break;
    }
    
    final response = await makeRequest(
      '/api/v2/reports',
      method: 'POST',
      body: {
        'targetUserId': int.parse(targetUserId),
        'reason': reasonStr,
        'description': description,
        'evidenceUrls': evidenceUrls ?? [],
      },
    );
    
    if (response['success'] == true) {
      return ReportResult.fromJson(response['data']);
    }
    
    throw Exception('举报失败: ${response['message']}');
  }
}
```

**响应格式**
```json
{
  "success": true,
  "data": {
    "reportId": "r123",
    "targetUserId": 456,
    "reason": "INAPPROPRIATE_CONTENT",
    "status": "PENDING",
    "createdAt": "2025-08-30T16:10:00Z"
  },
  "message": "举报提交成功",
  "timestamp": "2025-08-30T16:10:00Z",
  "requestId": "uuid-132"
}
```

## 4. Flutter 前端架构最佳实践

### 4.1 Service 层设计模式

```dart
// 基础 Service 接口
abstract class BaseService {
  final BackendManager _backendManager = BackendManager();
  
  /// 统一请求方法
  Future<Map<String, dynamic>> makeRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? params,
    Duration? cacheTTL,
    bool requireAuth = true,
  }) async {
    return await _backendManager.request(
      endpoint: endpoint,
      method: method,
      body: body,
      params: params,
      cacheTTL: cacheTTL,
      requireAuth: requireAuth,
    );
  }
}

// V2 用户服务实现
class UserV2Service extends BaseService {
  static final UserV2Service _instance = UserV2Service._internal();
  factory UserV2Service() => _instance;
  UserV2Service._internal();
  
  Future<UnifiedUserProfile> getCurrentUser() async {
    final response = await makeRequest(
      '/api/v2/user',
      cacheTTL: Duration(minutes: 15),
    );
    return UnifiedUserProfile.fromJson(response['data']);
  }
  
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    final response = await makeRequest(
      '/api/v2/user',
      method: 'PATCH',
      body: updates,
    );
    return response['success'] == true;
  }
}
```

### 4.2 错误处理策略

```dart
// API 异常定义
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? details;
  final String? requestId;
  
  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
    this.requestId,
  });
  
  @override
  String toString() => 'ApiException($statusCode): $message';
  
  // 常用异常工厂方法
  factory ApiException.networkError(String message) =>
      ApiException(statusCode: 0, message: 'Network error: $message');
      
  factory ApiException.unauthorized(String message) =>
      ApiException(statusCode: 401, message: 'Unauthorized: $message');
      
  factory ApiException.businessError(String message) =>
      ApiException(statusCode: 400, message: message);
}

// 统一错误处理函数
Future<T> handleApiResponse<T>(
  Future<Map<String, dynamic>> request,
  T Function(Map<String, dynamic>) parser,
) async {
  try {
    final response = await request;
    
    if (response['success'] == true) {
      return parser(response['data']);
    } else {
      throw ApiException(
        statusCode: response['statusCode'] ?? 400,
        message: response['message'] ?? 'Unknown error',
        details: response['details'],
        requestId: response['requestId'],
      );
    }
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException.networkError(e.toString());
  }
}
```

### 4.3 缓存管理策略

```dart
class V2CacheStrategy {
  static const Map<String, Duration> API_CACHE_TTL = {
    // 用户相关 - 中等缓存时间
    '/api/v2/user': Duration(minutes: 15),
    
    // 推荐相关 - 较长缓存时间
    '/api/v2/recommendation': Duration(minutes: 30),
    
    // 会话相关 - 短缓存时间
    '/api/v2/conversation': Duration(minutes: 5),
    
    // 动态相关 - 短缓存时间
    '/api/v2/feed': Duration(minutes: 5),
    
    // 心动列表 - 中等缓存时间
    '/api/v2/interactions/xindong': Duration(minutes: 10),
    
    // 默认缓存时间
    '_default': Duration(minutes: 10),
  };
  
  static Duration getCacheTTL(String endpoint) {
    return API_CACHE_TTL[endpoint] ?? API_CACHE_TTL['_default']!;
  }
  
  // 缓存键生成策略
  static String generateCacheKey(String endpoint, Map<String, String>? params) {
    final keyBuffer = StringBuffer(endpoint);
    if (params != null && params.isNotEmpty) {
      final sortedKeys = params.keys.toList()..sort();
      for (final key in sortedKeys) {
        keyBuffer.write('_${key}_${params[key]}');
      }
    }
    return keyBuffer.toString();
  }
}
```

### 4.4 网络层优化

```dart
class V2NetworkOptimizer {
  static final Map<String, Future<Map<String, dynamic>>> _pendingRequests = {};
  
  /// 请求去重
  static Future<Map<String, dynamic>> deduplicateRequest(
    String key,
    Future<Map<String, dynamic>> Function() requestFn,
  ) async {
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!;
    }
    
    final future = requestFn();
    _pendingRequests[key] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _pendingRequests.remove(key);
    }
  }
  
  /// 智能重试
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() requestFn, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    List<int> retryStatusCodes = const [500, 502, 503, 504, 408],
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await requestFn();
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        
        // 检查是否需要重试
        if (e is ApiException && !retryStatusCodes.contains(e.statusCode)) {
          rethrow;
        }
        
        // 指数退避
        final delay = baseDelay * math.pow(2, attempt - 1);
        await Future.delayed(Duration(milliseconds: delay.inMilliseconds.toInt()));
      }
    }
    throw Exception('Max retries exceeded');
  }
  
  /// 批量请求
  static Future<List<T>> batchRequests<T>(
    List<Future<T>> requests, {
    int concurrency = 3,
  }) async {
    final results = <T>[];
    for (int i = 0; i < requests.length; i += concurrency) {
      final batch = requests.skip(i).take(concurrency);
      final batchResults = await Future.wait(batch);
      results.addAll(batchResults);
    }
    return results;
  }
}
```

## 5. Mock 数据系统

### 5.1 Mock 数据管理器

```dart
class V2MockDataManager {
  static const bool _kUseMockData = kDebugMode;
  static Map<String, dynamic> _mockData = {};
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    if (!_kUseMockData || _initialized) return;
    
    try {
      // 从 assets 加载 Mock 数据
      final usersMock = await rootBundle.loadString('test/mock_data/v2/users.json');
      final recommendationsMock = await rootBundle.loadString('test/mock_data/v2/recommendations.json');
      final feedMock = await rootBundle.loadString('test/mock_data/v2/feed.json');
      final conversationsMock = await rootBundle.loadString('test/mock_data/v2/conversations.json');
      final xindongMock = await rootBundle.loadString('test/mock_data/v2/xindong.json');
      
      // 解析并合并所有 Mock 数据
      _mockData = {
        'GET /api/v2/user': json.decode(usersMock),
        'GET /api/v2/recommendation': json.decode(recommendationsMock),
        'GET /api/v2/feed': json.decode(feedMock),
        'GET /api/v2/conversation': json.decode(conversationsMock),
        'GET /api/v2/interactions/xindong': json.decode(xindongMock),
      };
      
      _initialized = true;
      print('🎭 V2 Mock Data initialized with ${_mockData.keys.length} endpoints');
    } catch (e) {
      print('❌ Failed to load V2 mock data: $e');
    }
  }
  
  static bool get useMockData => _kUseMockData && _initialized;
  
  static Map<String, dynamic>? getMockResponse(String endpoint, String method) {
    if (!useMockData) return null;
    
    final key = '$method $endpoint';
    final mockResponse = _mockData[key];
    
    if (mockResponse != null) {
      // 深拷贝避免修改原始数据
      return json.decode(json.encode(mockResponse));
    }
    
    return null;
  }
  
  /// 模拟网络延迟
  static Future<void> simulateNetworkDelay() async {
    if (!useMockData) return;
    
    final delayMs = 50 + Random().nextInt(200); // 50-250ms
    await Future.delayed(Duration(milliseconds: delayMs));
  }
}
```

### 5.2 Backend Manager 集成

```dart
class BackendManager {
  static const String _baseUrl = 'your-api-base-url';
  static bool useMockData = kDebugMode;
  
  Future<Map<String, dynamic>> request({
    required String endpoint,
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? params,
    Duration? cacheTTL,
    bool requireAuth = true,
  }) async {
    // 检查 Mock 数据
    if (useMockData) {
      final mockResponse = V2MockDataManager.getMockResponse(endpoint, method);
      if (mockResponse != null) {
        await V2MockDataManager.simulateNetworkDelay();
        print('🎭 Using mock data for $method $endpoint');
        return mockResponse;
      }
    }
    
    // 正常 API 请求
    return await _makeRealRequest(endpoint, method, body, params, requireAuth);
  }
  
  Future<Map<String, dynamic>> _makeRealRequest(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
    Map<String, String>? params,
    bool requireAuth,
  ) async {
    // 构建完整 URL
    String url = '$_baseUrl$endpoint';
    if (params != null && params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$queryString';
    }
    
    // 构建请求头
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Amoure-Flutter/${await _getAppVersion()}',
      'X-Request-ID': const Uuid().v4(),
      'X-Client-Version': await _getAppVersion(),
      'X-Platform': Platform.isIOS ? 'iOS' : 'Android',
    };
    
    // 添加认证头
    if (requireAuth) {
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    // 发送请求
    final response = await http.Request(method, Uri.parse(url))
      ..headers.addAll(headers);
      
    if (body != null) {
      response.body = json.encode(body);
    }
    
    final streamedResponse = await response.send();
    final responseBody = await streamedResponse.stream.bytesToString();
    
    return json.decode(responseBody);
  }
}
```

## 6. 性能监控与日志

### 6.1 性能监控

```dart
class V2PerformanceMonitor {
  /// 记录 API 调用性能
  static void trackApiCall({
    required String endpoint,
    required String method,
    required Duration duration,
    required bool success,
    String? errorMessage,
    String? requestId,
  }) {
    final event = {
      'type': 'api_call_v2',
      'endpoint': endpoint,
      'method': method,
      'duration_ms': duration.inMilliseconds,
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
      'version': 'v2.0',
      'request_id': requestId,
      if (errorMessage != null) 'error': errorMessage,
    };
    
    // 发送到 Firebase Analytics
    FirebaseAnalytics.instance.logEvent(
      name: 'api_performance_v2',
      parameters: event.map((k, v) => MapEntry(k, v.toString())),
    );
    
    // 本地日志
    print('📊 API Performance: $event');
  }
  
  /// 记录用户行为
  static void trackUserAction({
    required String action,
    required String screen,
    Map<String, dynamic>? properties,
  }) {
    final event = {
      'action': action,
      'screen': screen,
      'version': 'v2.0',
      'timestamp': DateTime.now().toIso8601String(),
      ...?properties,
    };
    
    FirebaseAnalytics.instance.logEvent(
      name: 'user_action_v2',
      parameters: event.map((k, v) => MapEntry(k, v.toString())),
    );
  }
  
  /// 记录页面加载时间
  static void trackPageLoad({
    required String pageName,
    required Duration loadTime,
  }) {
    FirebaseAnalytics.instance.logEvent(
      name: 'page_load_time_v2',
      parameters: {
        'page_name': pageName,
        'load_time_ms': loadTime.inMilliseconds.toString(),
        'version': 'v2.0',
      },
    );
  }
}
```

### 6.2 日志记录

```dart
class V2Logger {
  static const String _tag = 'AmoureV2';
  
  static void info(String message, [Object? error]) {
    print('ℹ️ [$_tag] $message');
    if (error != null) {
      print('   Error: $error');
    }
  }
  
  static void warning(String message, [Object? error]) {
    print('⚠️ [$_tag] WARNING: $message');
    if (error != null) {
      print('   Error: $error');
    }
  }
  
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('❌ [$_tag] ERROR: $message');
    if (error != null) {
      print('   Error: $error');
    }
    if (stackTrace != null) {
      print('   StackTrace: $stackTrace');
    }
    
    // 发送错误到 Crashlytics
    if (error != null) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }
  
  static void debug(String message) {
    if (kDebugMode) {
      print('🐛 [$_tag] DEBUG: $message');
    }
  }
}
```

## 7. 总结与最佳实践

### 7.1 V2 版本核心改进

1. **统一的响应格式**: 所有 API 使用标准化的 `Result<T>` 格式
2. **RESTful 设计**: 遵循 REST 最佳实践，语义化 URL 设计
3. **类型安全**: 强类型 DTO/VO 定义，减少字段不一致问题
4. **Clean Architecture**: 基于领域驱动设计的分层架构
5. **Mock 数据支持**: 内置完整的 Mock 数据系统，支持离线开发
6. **性能优化**: 请求去重、智能重试、多级缓存
7. **安全加强**: Token 自动刷新、输入验证、权限控制
8. **监控完善**: 全链路性能监控、错误追踪、用户行为分析

### 7.2 Flutter 开发最佳实践

1. **Service 层设计**: 统一的 Service 基类，标准化 API 调用
2. **错误处理**: 完善的异常处理机制和用户友好提示
3. **缓存策略**: 智能缓存管理，提升用户体验
4. **Mock 驱动开发**: 支持离线开发，提高开发效率
5. **性能监控**: 全面的性能监控和日志记录
6. **代码组织**: 清晰的文件结构和命名规范

### 7.3 API 调用示例总结

每个 API 接口都提供了完整的：
- 接口基本信息（URL、描述、认证、缓存）
- 请求参数详细说明
- Flutter 调用示例代码
- 完整的响应格式
- 错误处理方式

这确保了前端开发者能够：
- 快速理解每个 API 的用途和使用方式
- 直接复制代码进行开发
- 了解所有可能的响应字段
- 正确处理各种异常情况

---

**文档维护说明**

本文档是 Amoure V2 版本 Flutter 前端开发的核心参考文档，提供了：
- 完整的 API 接口规范
- 详细的调用示例
- 最佳实践指导
- Mock 数据支持
- 性能优化建议

**更新频率**: 每次 API 变更后同步更新
**维护团队**: Amoure V2 开发团队
*最后更新时间: 2025-08-30*