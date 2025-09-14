# InteractionService V2 与 InteractionV2Controller 对齐分析文档

## 文档概述

本文档详细分析了新的 V2 InteractionService（基于 Clean Architecture）与现有的 InteractionV2Controller 之间的职责分配问题，并提供具体的重构和对齐建议。

### 分析时间
- **日期**: 2025-08-30
- **分析对象**: 
  - `com.amoure.api.v2.service.InteractionService`
  - `com.amoure.api.controller.v2.InteractionV2Controller`

---

## 1. 当前问题分析

### 1.1 职责分配问题

#### 当前状态
```
InteractionV2Controller (控制器层)
    ├── 参数验证 ❌ (应该在Service层)
    ├── 业务逻辑处理 ❌ (混在Controller中)
    ├── 数据转换 ❌ (大量转换逻辑)
    ├── 批量数据查询 ❌ (不属于Controller职责)
    ├── 缓存处理 ❌ (应该在Service层)
    └── 响应构建 ✅ (Controller职责)

InteractionService (服务层)
    ├── 纯净的领域逻辑 ✅
    ├── 简洁的方法签名 ✅
    ├── 事务管理 ✅
    └── 但缺少复杂业务场景 ❌
```

#### 理想状态
```
InteractionV2Controller (控制器层)
    ├── 请求参数接收 ✅
    ├── 简单参数验证 ✅
    ├── 调用Service方法 ✅
    └── 响应格式化 ✅

InteractionService (服务层)
    ├── 业务参数验证 ✅
    ├── 复杂业务逻辑 ✅
    ├── 数据查询和转换 ✅
    ├── 缓存管理 ✅
    └── 事务控制 ✅
```

### 1.2 具体问题分析

#### 问题一：Controller 承担过多业务逻辑
**现状**：InteractionV2Controller 中有大量业务处理代码
```java
// ❌ 问题代码：Controller中的复杂业务逻辑
@GetMapping("/likes")
public Result<Map<String, Object>> getXindongList(...) {
    // 大量的类型映射逻辑
    String serviceType;
    switch (type) {
        case "liked_by_me": serviceType = LikeListTypeEnum.I_LIKE.getType(); break;
        // ... 更多映射逻辑
    }
    
    // 复杂的数据批量查询和转换
    List<Long> userIds = result.getRecords().stream()...
    Map<Long, AppUser> userMap = appUserService.batchGetUsers(userIds)...
    Map<Long, UserProfile> profileMap = userProfileService.listByUserIds(userIds)...
    
    // 复杂的响应构建逻辑
    for (LikeUserVO user : result.getRecords()) {
        // 50+ 行的数据转换逻辑
    }
}
```

#### 问题二：Service 层功能不完整
**现状**：InteractionService 过于简化，缺少实际业务场景
```java
// ❌ 问题：V2 InteractionService 缺少心动列表功能
public class InteractionService {
    // 只有基础的点赞功能
    public LikeResult likeUser(Long userId, Long targetUserId, Integer likeType) { ... }
    
    // 缺少心动列表查询
    // 缺少复杂筛选逻辑
    // 缺少数据转换逻辑
}
```

#### 问题三：重复的业务逻辑
- Controller 中重复实现了用户数据查询和转换
- 缺少统一的用户信息获取服务
- 没有复用现有的 UserInteractionService 优势

---

## 2. 对齐方案分析

### 方案一：重构 Controller，增强 Service（推荐）

#### 2.1 重构 InteractionV2Controller
```java
@RestController
@RequestMapping("/api/v2/interactions")
@RequiredArgsConstructor
@Slf4j
public class InteractionV2Controller {

    private final InteractionService interactionService; // 使用增强后的V2服务
    
    /**
     * 用户交互操作 - 简化后的Controller
     */
    @PostMapping
    public Result<InteractionResult> interactUser(@RequestBody @Valid InteractUserRequest request) {
        Long userId = StpUtil.getLoginIdAsLong();
        
        // 简单参数验证
        if (userId.equals(request.getTargetUserId())) {
            return Result.failure("不能与自己互动");
        }
        
        // 调用领域服务
        InteractionResult result = interactionService.interactWithUser(
            userId, request.getTargetUserId(), request.getType());
            
        return Result.success(result);
    }
    
    /**
     * 获取心动列表 - 简化后的Controller
     */
    @GetMapping("/xindong")
    public Result<XindongResponse> getXindongList(
            @RequestParam String type,
            @RequestParam(required = false) String filter,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") Integer limit) {
        
        Long userId = StpUtil.getLoginIdAsLong();
        
        // 参数转换和调用服务
        XindongType xindongType = XindongType.fromString(type);
        XindongFilter xindongFilter = XindongFilter.fromString(filter);
        
        XindongResponse response = interactionService.getXindongList(
            userId, xindongType, xindongFilter, cursor, limit);
            
        return Result.success(response);
    }
}
```

#### 2.2 增强 InteractionService
```java
@Service
@Transactional
@RequiredArgsConstructor
@Slf4j
public class InteractionService {
    
    // 基础依赖
    private final UserLikeRepository userLikeRepository;
    private final UserMatchRepository userMatchRepository;
    private final ApplicationEventPublisher eventPublisher;
    
    // 新增依赖（整合现有服务）
    private final UserService userService;                    // V2用户服务
    private final UserInteractionService legacyUserInteractionService; // 现有交互服务
    private final AppUserService appUserService;             // 用户基础服务
    private final UserProfileService userProfileService;     // 用户档案服务
    private final UserPhotoService userPhotoService;         // 用户照片服务
    private final UserVerificationService userVerificationService; // 认证服务
    
    /**
     * 用户互动操作（整合现有逻辑）
     */
    public InteractionResult interactWithUser(Long userId, Long targetUserId, InteractionType type) {
        log.debug("用户互动: userId={}, targetUserId={}, type={}", userId, targetUserId, type);
        
        // 1. 业务验证
        validateInteraction(userId, targetUserId, type);
        
        // 2. 执行互动操作
        boolean isMatched = false;
        switch (type) {
            case LIKE:
                isMatched = executelike(userId, targetUserId, 1);
                break;
            case SUPER_LIKE:
                isMatched = executeLike(userId, targetUserId, 2);
                break;
            case PASS:
                executePass(userId, targetUserId);
                break;
            case BLOCK:
                executeBlock(userId, targetUserId);
                break;
        }
        
        return InteractionResult.builder()
                .targetUserId(targetUserId)
                .type(type)
                .isMatched(isMatched)
                .build();
    }
    
    /**
     * 获取心动列表（整合Controller中的复杂逻辑）
     */
    public XindongResponse getXindongList(
            Long userId, 
            XindongType type, 
            XindongFilter filter, 
            String cursor, 
            Integer limit) {
        
        log.debug("获取心动列表: userId={}, type={}, filter={}", userId, type, filter);
        
        // 1. 参数转换（移植自Controller）
        String legacyType = convertToLegacyType(type);
        String legacyFilter = convertToLegacyFilter(filter);
        int currentPage = parseCursor(cursor);
        
        // 2. 查询数据（复用现有服务）
        LikeUserListReq request = LikeUserListReq.builder()
                .current(currentPage)
                .pageSize(limit)
                .type(legacyType)
                .filter(legacyFilter)
                .build();
                
        IPage<LikeUserVO> result = legacyUserInteractionService.getLikeUserList(
                new Page<>(currentPage, limit), userId, legacyType, legacyFilter);
        
        // 3. 批量获取用户详细信息（移植自Controller）
        List<XindongUser> users = buildXindongUsers(result.getRecords());
        
        // 4. 构建分页信息
        XindongPagination pagination = XindongPagination.builder()
                .hasMore(result.getCurrent() < result.getPages())
                .nextCursor(result.getCurrent() < result.getPages() ? 
                    String.valueOf(result.getCurrent() + 1) : null)
                .total(result.getTotal())
                .currentPage((int) result.getCurrent())
                .pageSize(limit)
                .build();
        
        // 5. 构建统计信息
        XindongStats stats = XindongStats.builder()
                .totalCount(result.getTotal())
                .newCount(calculateNewCount(userId, type))
                .mutualCount(type == XindongType.I_LIKED ? calculateMutualCount(userId) : null)
                .build();
        
        return XindongResponse.builder()
                .type(type.toString())
                .filter(filter.toString())
                .users(users)
                .pagination(pagination)
                .stats(stats)
                .build();
    }
    
    /**
     * 批量构建心动用户信息（移植自Controller）
     */
    private List<XindongUser> buildXindongUsers(List<LikeUserVO> likeUsers) {
        if (likeUsers.isEmpty()) {
            return new ArrayList<>();
        }
        
        // 1. 提取用户ID
        List<Long> userIds = likeUsers.stream()
                .map(LikeUserVO::getUserId)
                .collect(Collectors.toList());
        
        // 2. 批量查询用户信息
        Map<Long, AppUser> userMap = appUserService.batchGetUsers(userIds)
                .stream()
                .collect(Collectors.toMap(AppUser::getId, user -> user));
                
        Map<Long, UserProfile> profileMap = userProfileService.listByUserIds(userIds)
                .stream()
                .collect(Collectors.toMap(UserProfile::getUserId, profile -> profile));
                
        Map<Long, List<String>> photosMap = batchGetUserPhotos(userIds);
        
        // 3. 转换为响应对象
        return likeUsers.stream()
                .map(likeUser -> buildXindongUser(likeUser, userMap, profileMap, photosMap))
                .collect(Collectors.toList());
    }
    
    /**
     * 构建单个心动用户信息
     */
    private XindongUser buildXindongUser(
            LikeUserVO likeUser,
            Map<Long, AppUser> userMap,
            Map<Long, UserProfile> profileMap,
            Map<Long, List<String>> photosMap) {
        
        Long userId = likeUser.getUserId();
        AppUser appUser = userMap.get(userId);
        UserProfile profile = profileMap.get(userId);
        List<String> photos = photosMap.getOrDefault(userId, new ArrayList<>());
        
        return XindongUser.builder()
                .userId(userId.toString())
                .nickname(likeUser.getNickname())
                .avatar(likeUser.getAvatarUrl())
                .age(likeUser.getAge())
                .height(likeUser.getHeight())
                .gender(appUser != null ? appUser.getGender() : "")
                .location(appUser != null ? appUser.getLocationName() : "")
                .education(likeUser.getSchool())
                .occupation(likeUser.getCompany())
                .school(likeUser.getSchool())
                .work(likeUser.getCompany())
                .hometown(profile != null ? profile.getHometown() : "")
                .religion(profile != null ? profile.getReligion() : "")
                .marriageStatus(profile != null ? profile.getMarriageStatus() : "")
                .selfIntroduction(profile != null ? profile.getSelfIntroduction() : "")
                .qaAnswers(V2DataConverter.convertQAAnswersToObject(
                    profile != null ? profile.getQaAnswers() : null))
                .locationFlexibilityAnswers(V2DataConverter.convertLocationFlexibilityToObject(
                    profile != null ? profile.getLocationFlexibility() : null))
                .interactionTime(likeUser.getLastActiveTime())
                .interactionType(likeUser.getLikeType())
                .isMutual(likeUser.getIsMutual())
                .activeDays(calculateActiveDays(appUser))
                .isOnline(false) // 简化处理
                .lastActiveTime(appUser != null ? appUser.getLastLoginTime() : null)
                .verificationStatus(buildVerificationStatus(likeUser))
                .photos(photos.stream()
                    .map(url -> XindongUserPhoto.builder()
                        .photoId(generatePhotoId(url))
                        .url(url)
                        .photoType(2)
                        .sortOrder(1)
                        .build())
                    .collect(Collectors.toList()))
                .distance(likeUser.getDistance())
                .build();
    }
    
    // ... 其他业务方法
}
```

### 1.2 架构不一致问题

#### V2 InteractionService 设计理念
- **领域驱动**: 使用 Domain Entity (UserLike, UserMatch)
- **Repository 模式**: 直接操作领域仓储
- **纯净业务逻辑**: 专注核心业务规则
- **强类型响应**: 使用 DTO/Response 对象

#### 现有 InteractionV2Controller 实现方式
- **传统分层**: 直接调用多个 Service 类
- **Map 响应**: 使用 HashMap 构建响应
- **混合职责**: Controller 承担业务逻辑
- **性能优化**: 批量查询和缓存考虑

---

## 3. 对齐方案

### 方案一：重构分离职责（强烈推荐）

#### 3.1 增强 InteractionService
```java
@Service
@Transactional
@RequiredArgsConstructor
@Slf4j
public class InteractionService {
    
    // V2 Domain 层依赖
    private final UserLikeRepository userLikeRepository;
    private final UserMatchRepository userMatchRepository;
    private final ApplicationEventPublisher eventPublisher;
    
    // 整合现有服务依赖
    private final UserInteractionService legacyUserInteractionService;
    private final AppUserService appUserService;
    private final UserProfileService userProfileService;
    private final UserPhotoService userPhotoService;
    private final UserVerificationService userVerificationService;
    private final UserService userService;
    
    /**
     * 用户互动操作（简化，专注核心逻辑）
     */
    public InteractionResult interactWithUser(Long userId, Long targetUserId, InteractionType type) {
        // 1. 业务验证
        validateInteraction(userId, targetUserId, type);
        
        // 2. 调用现有的成熟实现（避免重复造轮子）
        boolean isMatched = legacyUserInteractionService.markLike(
            userId, targetUserId, convertToLegacyType(type));
            
        // 3. 如果需要，同步到 V2 Domain 层
        if (type == InteractionType.LIKE || type == InteractionType.SUPER_LIKE) {
            syncToV2Domain(userId, targetUserId, type, isMatched);
        }
        
        return InteractionResult.builder()
                .targetUserId(targetUserId)
                .type(type)
                .isMatched(isMatched)
                .build();
    }
    
    /**
     * 获取心动列表（移植Controller逻辑）
     */
    public XindongResponse getXindongList(
            Long userId, 
            XindongType type, 
            XindongFilter filter, 
            String cursor, 
            Integer limit) {
        
        log.debug("获取心动列表: userId={}, type={}, filter={}", userId, type, filter);
        
        // 1. 参数转换
        String legacyType = convertXindongTypeToLegacy(type);
        String legacyFilter = convertXindongFilterToLegacy(filter);
        int currentPage = parseCursor(cursor);
        
        // 2. 调用现有服务获取数据
        Page<UserInteraction> page = new Page<>(currentPage, limit);
        IPage<LikeUserVO> result = legacyUserInteractionService.getLikeUserList(
                page, userId, legacyType, legacyFilter);
        
        // 3. 构建完整的用户信息（批量优化）
        List<XindongUser> users = buildXindongUsersWithFullInfo(result.getRecords());
        
        // 4. 构建响应
        return XindongResponse.builder()
                .type(type.getDisplayName())
                .filter(filter.getDisplayName())
                .users(users)
                .pagination(buildPagination(result, cursor))
                .stats(buildStats(userId, type, result))
                .build();
    }
    
    /**
     * 构建完整的心动用户信息（移植并优化Controller逻辑）
     */
    private List<XindongUser> buildXindongUsersWithFullInfo(List<LikeUserVO> likeUsers) {
        if (likeUsers.isEmpty()) {
            return new ArrayList<>();
        }
        
        // 1. 批量获取用户基础信息
        List<Long> userIds = likeUsers.stream()
                .map(LikeUserVO::getUserId)
                .collect(Collectors.toList());
                
        BatchUserInfoResult batchInfo = getBatchUserInfo(userIds);
        
        // 2. 转换为响应对象
        return likeUsers.stream()
                .map(likeUser -> convertToXindongUser(likeUser, batchInfo))
                .collect(Collectors.toList());
    }
    
    /**
     * 批量获取用户信息（性能优化）
     */
    private BatchUserInfoResult getBatchUserInfo(List<Long> userIds) {
        // 并行查询多个数据源
        CompletableFuture<Map<Long, AppUser>> usersFuture = CompletableFuture
                .supplyAsync(() -> appUserService.batchGetUsers(userIds)
                    .stream().collect(Collectors.toMap(AppUser::getId, u -> u)));
                    
        CompletableFuture<Map<Long, UserProfile>> profilesFuture = CompletableFuture
                .supplyAsync(() -> userProfileService.listByUserIds(userIds)
                    .stream().collect(Collectors.toMap(UserProfile::getUserId, p -> p)));
                    
        CompletableFuture<Map<Long, List<String>>> photosFuture = CompletableFuture
                .supplyAsync(() -> batchGetUserPhotos(userIds));
                
        CompletableFuture<Map<Long, VerificationStatus>> verificationsFuture = CompletableFuture
                .supplyAsync(() -> batchGetVerificationStatus(userIds));
        
        // 等待所有查询完成
        try {
            return BatchUserInfoResult.builder()
                    .userMap(usersFuture.get())
                    .profileMap(profilesFuture.get())
                    .photosMap(photosFuture.get())
                    .verificationMap(verificationsFuture.get())
                    .build();
        } catch (Exception e) {
            log.error("批量获取用户信息失败", e);
            throw new ServiceException("获取用户信息失败");
        }
    }
    
    private String convertXindongTypeToLegacy(XindongType type) {
        switch (type) {
            case LIKED_BY_ME:
                return LikeListTypeEnum.I_LIKE.getType();
            case I_LIKED:
                return LikeListTypeEnum.LIKE_ME.getType();
            case MUTUAL_LIKED:
                return LikeListTypeEnum.MUTUAL.getType();
            default:
                return LikeListTypeEnum.I_LIKE.getType();
        }
    }
    
    // ... 其他辅助方法
}
```

#### 3.2 定义新的响应对象
```java
// 统一的响应对象
@Data
@Builder
public class XindongResponse {
    private String type;
    private String filter;
    private List<XindongUser> users;
    private XindongPagination pagination;
    private XindongStats stats;
}

@Data
@Builder
public class XindongUser {
    // 基础信息
    private String userId;
    private String nickname;
    private String avatar;
    private Integer age;
    private String gender;
    private Integer height;
    private String location;
    
    // 教育职业
    private String education;
    private String occupation;
    private String school;
    private String work;
    
    // 详细信息
    private String hometown;
    private String religion;
    private String marriageStatus;
    private String selfIntroduction;
    private Map<String, Object> qaAnswers;
    private Map<String, Object> locationFlexibilityAnswers;
    
    // 互动信息
    private LocalDateTime interactionTime;
    private Integer interactionType;
    private Boolean isMutual;
    
    // 活跃状态
    private Integer activeDays;
    private Boolean isOnline;
    private LocalDateTime lastActiveTime;
    
    // 认证状态
    private Map<String, Object> verificationStatus;
    
    // 照片
    private List<XindongUserPhoto> photos;
    
    // 其他
    private Double distance;
}
```

### 方案二：适配器模式整合

#### 2.1 创建交互服务适配器
```java
@Component
public class InteractionServiceAdapter {
    
    private final InteractionService v2InteractionService;
    private final UserInteractionService legacyUserInteractionService;
    
    @Value("${amoure.v2.interaction.enabled:false}")
    private boolean useV2Service;
    
    /**
     * 统一的用户互动接口
     */
    public InteractionResult interactUser(Long userId, Long targetUserId, InteractionType type) {
        if (useV2Service) {
            return v2InteractionService.interactWithUser(userId, targetUserId, type);
        } else {
            // 调用现有实现并转换结果
            boolean isMatched = legacyUserInteractionService.markLike(
                userId, targetUserId, convertTypeToLegacy(type));
            return InteractionResult.builder()
                    .targetUserId(targetUserId)
                    .type(type)
                    .isMatched(isMatched)
                    .build();
        }
    }
    
    /**
     * 统一的心动列表接口
     */
    public XindongResponse getXindongList(XindongRequest request) {
        if (useV2Service) {
            return v2InteractionService.getXindongList(
                request.getUserId(), request.getType(), request.getFilter(), 
                request.getCursor(), request.getLimit());
        } else {
            // 使用现有Controller的逻辑构建响应
            return buildXindongResponseFromLegacy(request);
        }
    }
}
```

---

## 4. 实施建议

### 4.1 推荐方案：方案一（重构分离职责）

**理由**：
1. **职责清晰**: Controller 专注 API 层，Service 专注业务逻辑
2. **代码质量**: 消除 Controller 中的复杂业务逻辑
3. **维护性**: 业务逻辑集中在 Service 层，便于测试和维护
4. **复用性**: Service 方法可以被其他 Controller 复用

### 4.2 实施步骤

#### 第一步：重构 InteractionService（2天）
1. 将 Controller 中的复杂业务逻辑移动到 Service
2. 创建统一的响应对象类
3. 实现批量查询优化
4. 添加必要的缓存支持

#### 第二步：简化 InteractionV2Controller（1天）
1. 移除业务逻辑，只保留 API 层职责
2. 更新为调用增强后的 InteractionService
3. 保持 API 接口不变，确保前端兼容

#### 第三步：测试验证（1天）
1. 单元测试：测试 Service 层业务逻辑
2. 集成测试：测试 Controller + Service 集成
3. 性能测试：确保性能不退化

#### 第四步：灰度上线（0.5天）
1. 通过配置控制新旧实现切换
2. 小流量验证
3. 全量上线

### 4.3 风险控制

#### 风险点
1. **数据一致性**: V2 Domain Entity 与现有 PO 的映射
2. **性能影响**: 重构可能影响查询性能
3. **功能回归**: 可能遗漏某些边缘场景

#### 缓解措施
1. **详细测试**: 覆盖所有现有功能场景
2. **性能基准**: 建立性能基准并持续监控
3. **功能对比**: 创建功能检查清单
4. **回滚机制**: 快速回滚到现有实现

---

## 5. 代码示例

### 5.1 重构后的 Controller
```java
@RestController
@RequestMapping("/api/v2/interactions")
@RequiredArgsConstructor
public class InteractionV2Controller {

    private final InteractionService interactionService;
    
    /**
     * 用户交互操作 - 重构后的简洁实现
     */
    @PostMapping
    public Result<InteractionResult> interactUser(@RequestBody @Valid InteractUserRequest request) {
        Long userId = StpUtil.getLoginIdAsLong();
        
        InteractionResult result = interactionService.interactWithUser(
            userId, request.getTargetUserId(), request.getType());
            
        return Result.success(result);
    }
    
    /**
     * 获取心动列表 - 重构后的简洁实现
     */
    @GetMapping("/xindong")
    public Result<XindongResponse> getXindongList(
            @RequestParam String type,
            @RequestParam(required = false, defaultValue = "all") String filter,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") Integer limit) {
        
        Long userId = StpUtil.getLoginIdAsLong();
        
        XindongResponse response = interactionService.getXindongList(
            userId, XindongType.fromString(type), XindongFilter.fromString(filter), 
            cursor, limit);
            
        return Result.success(response);
    }
}
```

### 5.2 完整的 Service 实现
```java
@Service
@Transactional
@RequiredArgsConstructor
@Slf4j
public class InteractionService {
    
    /**
     * 获取心动列表的完整实现（移植所有Controller逻辑）
     */
    public XindongResponse getXindongList(
            Long userId, 
            XindongType type, 
            XindongFilter filter, 
            String cursor, 
            Integer limit) {
        
        // 1. 参数处理
        String legacyType = convertXindongTypeToLegacy(type);
        String legacyFilter = convertXindongFilterToLegacy(filter);
        int currentPage = StringUtils.isBlank(cursor) ? 1 : Integer.parseInt(cursor);
        
        // 2. 查询数据
        LikeUserListReq request = LikeUserListReq.builder()
                .current(currentPage)
                .pageSize(limit)
                .type(legacyType)
                .filter(legacyFilter)
                .build();
                
        Page<UserInteraction> page = new Page<>(currentPage, limit);
        IPage<LikeUserVO> result = legacyUserInteractionService.getLikeUserList(
                page, userId, legacyType, legacyFilter);
        
        // 3. 批量构建用户信息
        List<XindongUser> users = buildCompleteXindongUsers(result.getRecords());
        
        // 4. 构建分页和统计信息
        XindongPagination pagination = XindongPagination.builder()
                .hasMore(result.getCurrent() < result.getPages())
                .nextCursor(result.getCurrent() < result.getPages() ? 
                    String.valueOf(result.getCurrent() + 1) : null)
                .total(result.getTotal())
                .currentPage((int) result.getCurrent())
                .pageSize(limit)
                .build();
                
        XindongStats stats = XindongStats.builder()
                .totalCount(result.getTotal())
                .newCount(calculateNewXindongCount(userId, type))
                .mutualCount(type == XindongType.I_LIKED ? 
                    calculateMutualXindongCount(userId) : null)
                .build();
        
        return XindongResponse.builder()
                .type(type.getDisplayName())
                .filter(filter.getDisplayName())
                .users(users)
                .pagination(pagination)
                .stats(stats)
                .availableFilters(getAvailableFilters())
                .build();
    }
    
    /**
     * 批量构建完整的心动用户信息
     */
    private List<XindongUser> buildCompleteXindongUsers(List<LikeUserVO> likeUsers) {
        if (likeUsers.isEmpty()) {
            return new ArrayList<>();
        }
        
        // 1. 提取用户ID
        List<Long> userIds = likeUsers.stream()
                .map(LikeUserVO::getUserId)
                .collect(Collectors.toList());
        
        // 2. 并行批量查询（性能优化）
        CompletableFuture<Map<Long, AppUser>> usersFuture = CompletableFuture
                .supplyAsync(() -> appUserService.batchGetUsers(userIds)
                    .stream().collect(Collectors.toMap(AppUser::getId, u -> u)));
                    
        CompletableFuture<Map<Long, UserProfile>> profilesFuture = CompletableFuture
                .supplyAsync(() -> userProfileService.listByUserIds(userIds)
                    .stream().collect(Collectors.toMap(UserProfile::getUserId, p -> p)));
                    
        CompletableFuture<Map<Long, List<UserPhoto>>> photosFuture = CompletableFuture
                .supplyAsync(() -> batchGetUserPhotos(userIds));
                
        CompletableFuture<Map<Long, VerificationStatus>> verificationsFuture = CompletableFuture
                .supplyAsync(() -> batchGetVerificationStatus(userIds));
        
        try {
            BatchUserData batchData = BatchUserData.builder()
                    .userMap(usersFuture.get())
                    .profileMap(profilesFuture.get())
                    .photosMap(photosFuture.get())
                    .verificationMap(verificationsFuture.get())
                    .build();
                    
            // 3. 转换每个用户
            return likeUsers.stream()
                    .map(likeUser -> convertToCompleteXindongUser(likeUser, batchData))
                    .collect(Collectors.toList());
                    
        } catch (Exception e) {
            log.error("批量获取用户信息失败", e);
            throw new ServiceException("获取用户信息失败: " + e.getMessage());
        }
    }
}
```

---

## 6. 总结

### 6.1 对齐的核心目标

1. **职责分离**: Controller 只负责 API 层，Service 负责业务逻辑
2. **功能完整**: V2 Service 应该包含所有现有功能
3. **性能保证**: 新实现不能有性能回归
4. **代码质量**: 提高代码的可读性、可测试性和可维护性

### 6.2 实施优先级

1. **高优先级**: 重构 InteractionV2Controller，分离职责
2. **中优先级**: 增强 InteractionService，补全功能
3. **低优先级**: 性能优化和监控完善

### 6.3 成功指标

- Controller 代码行数减少 60% 以上
- Service 层测试覆盖率达到 90% 以上
- API 响应时间不超过现有实现的 110%
- 所有现有功能保持兼容

通过这个重构方案，可以实现 Clean Architecture 的设计目标，同时保持系统的稳定性和性能。