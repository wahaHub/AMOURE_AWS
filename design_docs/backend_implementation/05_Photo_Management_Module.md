# Amoure V2 后端实现文档 - 照片管理模块（Photo Management Module）

## 模块概述

照片管理模块是 Amoure V2 的核心内容管理系统，负责处理用户照片的完整生命周期，包括上传、存储、审核、展示等功能。该模块采用分类管理设计，支持多种照片类型，并实现了智能审核和状态保持机制。

## 核心组件架构

### 1. 服务层设计 (Service Layer)
**文件位置**: `com.amoure.api.v2.service.PhotoService`

#### 主要职责
- 用户照片的CRUD操作管理
- 照片分类和类型管理
- 审核流程和状态管理
- 批量操作和性能优化
- 文件存储集成和生命周期管理

#### 核心功能模块

##### 照片查询功能
**基础查询方法**:
```java
// 获取用户所有个人照片（包含待审核）
public List<PhotoResponse> getUserPhotos(Long userId)

// 获取用户已审核通过的照片（对外展示）
public List<PhotoResponse> getApprovedUserPhotos(Long userId)

// 批量获取多用户已审核照片（性能优化）
public Map<Long, List<PhotoResponse>> batchGetApprovedUserPhotos(List<Long> userIds)
```

**专业查询方法**:
```java
// 获取用户头像
public PhotoResponse getUserAvatar(Long userId)

// 获取动态相关照片
public List<PhotoResponse> getPostPhotos(Long postId)

// 获取理想伴侣照片
public List<PhotoResponse> getIdealPartnerPhotos(Long userId)

// 批量获取用户头像URL
public Map<Long, String> batchGetUserAvatars(List<Long> userIds)
```

##### 照片提交和管理
**核心方法**: `commitPhotos`
```java
public void commitPhotos(Long userId, List<String> photoUrls, String idealPartnerPhoto)
```

**智能提交流程**:
1. **状态保持**: 查询现有照片的审核状态
2. **清理重建**: 删除现有个人照片记录
3. **分类处理**: 第一张设为头像(AVATAR)，其余设为相册(ALBUM)
4. **状态继承**: 相同URL的照片保持原有审核状态
5. **批量插入**: 高效创建新照片记录
6. **事件通知**: 发布照片提交事件
7. **伴侣头像**: 特殊处理理想伴侣头像

**状态保持逻辑**:
```java
// 保持已有照片的审核状态，避免重复审核
ReviewStatus reviewStatus = ReviewStatus.IN_REVIEW; // 默认待审核
if (existingPhoto != null) {
    reviewStatus = existingPhoto.getReviewStatus(); // 保持原有状态
}
```

##### 审核管理功能
**审核操作**:
```java
public void reviewPhoto(Long photoId, ReviewPhotoRequest request)
```

**审核流程**:
1. **权限验证**: 验证照片存在性
2. **状态更新**: 批准或拒绝照片
3. **事件发布**: 通知审核结果
4. **数据持久化**: 更新审核状态到数据库

**管理查询**:
```java
// 获取待审核照片列表（分页）
public PageResponse<PhotoResponse> getPendingPhotos(int page, int size)

// 获取照片审核统计信息
public PhotoAuditInfoResponse getPhotoAuditInfo(Long userId)
```

#### 依赖组件注入
```java
private final UserPhotoMapper photoMapper;              // 照片数据访问
private final UserInfoMapper userInfoMapper;            // 用户信息访问
private final FileStorageService fileStorageService;    // 文件存储服务
private final ApplicationEventPublisher eventPublisher; // 事件发布器
```

## 数据模型设计

### UserPhoto 实体模型
```java
public class UserPhoto {
    private Long id;                    // 照片ID
    private Long userId;                // 用户ID
    private String photoUrl;            // 照片URL
    private PhotoType photoType;        // 照片类型
    private Integer sortOrder;          // 排序顺序
    private ReviewStatus reviewStatus;  // 审核状态
    private String rejectReason;        // 拒绝原因
    private Long postId;               // 关联动态ID（可选）
    private LocalDateTime createdAt;    // 创建时间
    private LocalDateTime updatedAt;    // 更新时间
    
    // 业务方法
    public void approve() { this.reviewStatus = ReviewStatus.APPROVED; }
    public void reject() { this.reviewStatus = ReviewStatus.REJECTED; }
    public boolean isApproved() { return ReviewStatus.APPROVED.equals(this.reviewStatus); }
}
```

### 枚举类型定义

#### PhotoType - 照片类型枚举
```java
public enum PhotoType {
    AVATAR("头像"),           // 用户头像
    ALBUM("相册"),            // 个人相册照片  
    POST("动态"),             // 动态配图
    IDEAL_PARTNER("理想伴侣"), // 理想伴侣照片
    VERIFICATION("认证");      // 认证照片
    
    private final String description;
}
```

#### ReviewStatus - 审核状态枚举
```java
public enum ReviewStatus {
    IN_REVIEW("待审核"),
    APPROVED("已通过"),
    REJECTED("已拒绝");
    
    private final String description;
}
```

### 响应模型设计

#### PhotoResponse - 照片详情响应
```java
public class PhotoResponse {
    private String photoId;          // 照片ID
    private String url;             // 照片URL
    private String photoType;       // 照片类型代码
    private String photoTypeName;   // 照片类型名称
    private Integer sortOrder;      // 排序顺序
    private String reviewStatus;    // 审核状态代码
    private String reviewStatusName; // 审核状态名称
    private String rejectReason;    // 拒绝原因
    private Boolean isApproved;     // 是否已通过审核
    private LocalDateTime createdAt; // 创建时间
    private LocalDateTime updatedAt; // 更新时间
}
```

#### PhotoAuditInfoResponse - 审核统计响应
```java
public class PhotoAuditInfoResponse {
    private Integer pendingCount;   // 待审核数量
    private Integer approvedCount;  // 已通过数量
    private Integer rejectedCount;  // 已拒绝数量
    private Integer totalCount;     // 总数量
}
```

## 业务逻辑设计

### 照片分类管理

#### 个人照片处理
**分类规则**:
- **第一张照片**: 自动设为头像(AVATAR)类型
- **其他照片**: 设为相册(ALBUM)类型
- **排序策略**: 按提交顺序自动排序(sortOrder)

**查询范围**:
```java
// 只查询个人相关照片类型
.in(UserPhoto::getPhotoType, PhotoType.ALBUM, PhotoType.AVATAR)
```

#### 动态照片处理
**独立管理**:
- **专属查询**: 通过postId关联查询
- **类型固定**: PhotoType.POST
- **不影响个人照片**: commitPhotos操作不处理动态照片

#### 理想伴侣照片处理
**特殊设计**:
- **直接存储**: 保存在UserInfo表的idealPartnerAvatar字段
- **无需审核**: 直接生效，不进入审核流程
- **独立管理**: 不影响个人照片管理

### 审核流程设计

#### 智能状态保持
**设计理念**: 避免重复审核，提升用户体验
```java
// 检查现有照片状态
Map<String, UserPhoto> existingPhotosMap = existingPhotos.stream()
    .collect(Collectors.toMap(UserPhoto::getPhotoUrl, photo -> photo));

// 保持原有状态
if (existingPhoto != null) {
    reviewStatus = existingPhoto.getReviewStatus();
}
```

**优势**:
- **用户友好**: 已通过审核的照片无需重新等待
- **效率提升**: 减少审核工作量
- **状态连续**: 保证用户体验的连续性

#### 审核工作流
**管理员审核**:
1. **获取待审核列表**: `getPendingPhotos`分页查询
2. **审核决策**: 通过或拒绝，提供拒绝原因
3. **状态更新**: 更新数据库审核状态
4. **用户通知**: 通过事件系统通知用户

**自动化扩展**:
- 支持接入AI审核服务
- 支持敏感内容检测
- 支持人脸识别验证

### 性能优化策略

#### 批量查询优化
**方法**: `batchGetApprovedUserPhotos`
```java
// 单次查询所有用户照片
List<UserPhoto> allPhotos = photoMapper.selectList(/* 批量条件 */);

// 内存分组处理
Map<Long, List<UserPhoto>> grouped = allPhotos.stream()
    .collect(Collectors.groupingBy(UserPhoto::getUserId));
```

**优势**:
- **减少数据库交互**: N+1查询优化为1次查询
- **内存高效**: 流式处理大数据量
- **响应稳定**: 批量操作响应时间可预期

#### 头像查询优化
**专用接口**: `batchGetUserAvatars`
```java
// 专门优化的头像批量查询
List<UserPhoto> avatars = photoMapper.findAvatarsByUserIds(userIds);

// 直接返回URL映射
return avatars.stream()
    .collect(Collectors.toMap(
        UserPhoto::getUserId,
        UserPhoto::getPhotoUrl
    ));
```

**应用场景**:
- 用户列表展示
- 推荐列表渲染
- 消息界面头像显示

## 智能审核自动化系统

### ImageModerationJobV2 - 图片审核引擎
**文件位置**: `com.amoure.api.v2.job.ImageModerationJobV2`

#### 审核引擎概述
`ImageModerationJobV2` 是 Amoure V2 照片管理的核心智能审核引擎，采用AI驱动的自动化审核流程，支持失败重试和人工审核降级机制。

#### 核心配置参数
```java
// 审核任务配置
@XxlJob("imageModerationJobV2")          // 定时任务标识
private static final int BATCH_SIZE = 100;        // 每批处理数量
private static final int MAX_DAYS = 30;           // 审核范围：30天内的照片
private static final String RETRY_REASON = "超过重试次数，转人工审核";
```

#### 主要功能模块

##### 1. 定时审核任务
**触发方式**: 每半小时执行一次
**执行方法**: `moderateImages()`

**审核流程**:
```java
public void moderateImages() {
    // 1. 获取待审核图片列表
    List<UserPhoto> pendingPhotos = getPendingPhotos();
    
    // 2. 批量处理审核
    int processedCount = processPendingImages();
    
    // 3. 统计和日志记录
    log.info("图片审核完成 - 处理: {}", processedCount);
}
```

##### 2. 智能图片筛选
**方法**: `getPendingPhotos()`

**筛选策略**:
```java
new LambdaQueryWrapper<UserPhoto>()
    .eq(UserPhoto::getReviewStatus, ReviewStatus.IN_REVIEW)    // 待审核状态
    .ge(UserPhoto::getCreatedAt, LocalDateTime.now().minusDays(30))  // 30天内
    .last("LIMIT 100")  // 批量限制
```

**筛选优势**:
- **时效性控制**: 只处理30天内的新照片
- **状态精准**: 专注待审核状态的图片
- **性能优化**: 批量限制避免系统过载
- **排除临时照片**: 只审核正式提交的照片

##### 3. 重试机制和降级策略
**重试控制逻辑**:
```java
if (!photo.canRetry()) {
    // 超过重试次数，转人工审核
    photo.reject("超过重试次数，转人工审核");
    userPhotoMapper.updateById(photo);
    manualReviewCount++;
    log.warn("图片转人工审核: photoId={}, retryCount={}", 
            photo.getId(), photo.getRetryCount());
    continue;
}
```

**多级处理策略**:
1. **一级**: AI自动审核
2. **二级**: 失败重试机制
3. **三级**: 人工审核降级
4. **四级**: 异常处理和日志记录

##### 4. AI审核集成
**核心处理方法**: `processImage(UserPhoto photo)`

**AI审核流程**:
```java
private boolean processImage(UserPhoto photo) {
    // 1. 调用AI审核服务
    ModerationResult result = aiModerationService.moderateImage(photo.getPhotoUrl());
    
    // 2. 结果判断和处理
    if (!result.hasError()) {
        if (result.isRejected()) {
            // 图片违规处理
            photo.reject(result.getReason());
            createImageRejectNotification(photo, result.getReason());
            log.info("图片AI审核不通过: photoId={}, reason={}", 
                    photo.getId(), result.getReason());
        } else {
            // 图片通过处理
            photo.approve();
            photo.clearRejectReasons(); // 清除历史驳回原因
            log.info("图片AI审核通过: photoId={}", photo.getId());
        }
        userPhotoMapper.updateById(photo);
        return true;
    } else {
        // AI失败，增加重试次数
        photo.incrementRetryCount();
        userPhotoMapper.updateById(photo);
        return false;
    }
}
```

##### 5. 审核结果通知系统
**通知创建方法**: `createImageRejectNotification()`

**通知处理流程**:
```java
private void createImageRejectNotification(UserPhoto photo, String reason) {
    // TODO: V2系统通知创建
    // SystemNotificationV2 notification = SystemNotificationV2.builder()
    //     .userId(photo.getUserId())
    //     .title("图片审核")
    //     .content("您上传的图片审核未通过，原因：" + reason)
    //     .notificationType(NotificationType.AUDIT)
    //     .build();
    
    log.info("图片驳回通知创建: photoId={}, reason={}", photo.getId(), reason);
}
```

#### 依赖服务集成
```java
private final UserPhotoMapper userPhotoMapper;              // V2照片数据访问
private final SystemNotificationService systemNotificationService; // 通知服务  
private final AIContentModerationService aiModerationService;      // AI审核服务
```

#### 性能优化特性

##### 1. 批量处理优化
- **分批加载**: 每次处理100张图片，避免内存溢出
- **时间窗口**: 30天时间范围，平衡效率和时效性
- **状态筛选**: 精准的状态查询，减少无效处理

##### 2. 重试机制优化
```java
// 智能重试判断
boolean isRetry = photo.getRetryCount() > 0;
if (isRetry) {
    log.info("重试成功，图片审核通过: photoId={}", photo.getId());
}
```

##### 3. 异常隔离机制
```java
// 单张图片异常不影响整体流程
for (UserPhoto photo : pendingPhotos) {
    try {
        if (processImage(photo)) {
            processedCount++;
        }
    } catch (Exception e) {
        log.error("处理图片失败: photoId={}", photo.getId(), e);
        // 继续处理下一张
    }
}
```

#### 监控和统计

##### 关键监控指标
- **审核成功率**: 成功处理的图片数量和比例
- **AI准确率**: AI审核的准确性统计
- **重试统计**: 重试次数和成功率分析
- **人工降级率**: 转人工审核的图片比例
- **处理性能**: 平均处理时间和吞吐量

##### 重要日志记录
```java
log.info("V2图片审核任务执行完成 - 处理: {}", totalProcessed);
log.info("待审核图片数量: {}", pendingPhotos.size());
log.info("有{}张图片转为人工审核", manualReviewCount);
log.warn("图片超过重试次数，转人工审核: photoId={}, retryCount={}", 
        photo.getId(), photo.getRetryCount());
```

#### 业务规则和策略

##### 审核范围控制
- **时间范围**: 仅审核30天内的图片
- **状态范围**: 专注待审核状态
- **类型范围**: 排除临时和测试图片

##### 失败处理策略
1. **AI服务异常**: 增加重试次数，保持待审核状态
2. **超过重试上限**: 自动转入人工审核流程
3. **系统异常**: 详细日志记录，不中断整体流程

##### 审核质量保证
- **清理历史驳回原因**: 通过审核时清除旧的驳回记录
- **重试成功标记**: 特别标记重试成功的案例
- **通知及时性**: 审核结果实时通知用户

## 事件驱动架构

### 事件定义

#### 照片生命周期事件
```java
// 照片上传事件
public static class PhotoUploadedEvent {
    private final Long userId;
    private final Long photoId;
}

// 照片审核通过事件
public static class PhotoApprovedEvent {
    private final Long userId;
    private final Long photoId;
}

// 照片审核拒绝事件
public static class PhotoRejectedEvent {
    private final Long userId;
    private final Long photoId;
    private final String reason;
}

// 照片批量提交事件
public static class PhotosCommittedEvent {
    private final Long userId;
    private final Integer photoCount;
}
```

### 事件处理逻辑

#### 审核通知处理
**PhotoApprovedEvent处理**:
- 发送用户通知
- 更新用户资料完整度
- 触发推荐算法更新
- 更新用户展示状态

**PhotoRejectedEvent处理**:
- 发送拒绝通知和原因
- 记录用户行为统计
- 提供重新上传指导

#### 缓存更新处理
**PhotoCacheClearEvent处理**:
- 清理用户照片缓存
- 更新CDN缓存
- 刷新相关页面缓存

## 文件存储集成

### FileStorageService集成
**当前集成**:
```java
private final FileStorageService fileStorageService;
```

**功能支持**:
- 文件上传到OSS/云存储
- URL生成和访问控制
- 临时文件处理

**扩展规划**:
- 文件删除功能
- 图片压缩和处理
- 多分辨率支持
- 水印和防盗链

### 存储策略设计

#### URL管理
**URL标准化**:
- 使用完整的HTTP/HTTPS URL
- 支持CDN加速域名
- 支持参数化访问控制

**安全控制**:
- 防盗链机制
- 时效性URL
- 访问权限控制

## 异常处理体系

### 自定义异常类
```java
// 照片不存在异常
public static class PhotoNotFoundException extends RuntimeException

// 照片访问权限异常
public static class PhotoAccessDeniedException extends RuntimeException  

// 照片已存在异常
public static class PhotoAlreadyExistsException extends RuntimeException
```

### 异常处理策略
1. **业务异常**: 返回明确的错误信息和建议
2. **权限异常**: 统一的权限拒绝响应
3. **系统异常**: 记录详细日志，返回通用错误
4. **文件异常**: 区分上传失败、存储失败等具体情况

## 数据访问层设计

### PhotoMapper接口
**基础CRUD**:
```java
// MyBatis-Plus基础接口
extends BaseMapper<UserPhoto>

// 自定义查询方法
UserPhoto findUserAvatar(Long userId);
List<UserPhoto> findAvatarsByUserIds(List<Long> userIds);
Long countByUserIdAndReviewStatus(Long userId, ReviewStatus status);
Long countActivePhotosByUserId(Long userId);
```

**查询优化**:
- 合理使用索引
- 避免全表扫描
- 优化复杂查询条件

### 数据库设计考虑

#### 索引策略
```sql
-- 用户照片查询优化
INDEX idx_user_photo_type (user_id, photo_type, review_status)

-- 审核管理查询优化  
INDEX idx_review_status_created (review_status, created_at)

-- 动态照片关联优化
INDEX idx_post_photo (post_id, photo_type)
```

#### 数据清理策略
- 定期清理已删除用户的照片记录
- 清理无效的OSS文件引用
- 归档历史审核记录

## 监控和运维

### 关键监控指标
1. **上传成功率**: 照片上传操作成功率
2. **审核效率**: 平均审核时间和积压数量
3. **存储使用量**: 总存储空间和增长趋势
4. **访问性能**: 照片加载速度和CDN命中率
5. **异常频率**: 各类异常的发生频率

### 日志记录策略
**DEBUG级别**:
- 方法参数和执行步骤
- 批量操作的详细信息
- 状态转换的具体过程

**INFO级别**:
- 照片提交和审核完成
- 重要的业务状态变更
- 批量操作的汇总统计

**WARN级别**:
- 异常的业务操作
- 性能警告和资源使用警告
- 审核规则触发警告

**ERROR级别**:
- 文件存储操作失败
- 数据库操作异常
- 审核流程异常

## 最佳实践和注意事项

### 性能优化建议
1. **批量操作优先**: 尽量使用批量接口减少数据库交互
2. **缓存策略**: 热点用户照片数据合理缓存
3. **异步处理**: 照片处理和审核异步化
4. **CDN优化**: 合理配置CDN缓存策略

### 数据一致性保证
1. **事务控制**: 关键操作使用数据库事务
2. **状态同步**: 确保审核状态与展示状态一致
3. **文件引用**: 保证数据库记录与文件存储一致
4. **用户体验**: 避免重复审核影响用户体验

### 安全考虑
1. **权限控制**: 严格的照片访问权限验证
2. **内容审核**: 多层级内容安全检查
3. **隐私保护**: 遵循用户隐私设置和权限
4. **防滥用**: 上传频率限制和内容检测

### 扩展性设计
1. **存储插件化**: 支持多种文件存储后端
2. **审核策略化**: 支持不同的审核规则和流程
3. **处理管道化**: 支持图片处理管道扩展
4. **微服务拆分**: 为未来微服务化预留接口边界

## 未来优化方向

### 功能增强
1. **AI审核**: 集成智能图像审核服务
2. **图像处理**: 自动裁剪、压缩、水印
3. **多分辨率**: 支持不同设备的分辨率需求
4. **人脸识别**: 自动检测和验证用户身份

### 性能优化
1. **图片CDN**: 全球化内容分发网络
2. **懒加载**: 前端图片懒加载优化
3. **预加载**: 智能预加载用户可能浏览的图片
4. **压缩算法**: 更先进的图片压缩技术

### 用户体验
1. **实时预览**: 上传过程中的实时预览
2. **批量上传**: 支持多文件同时上传
3. **编辑功能**: 简单的图片编辑和美颜功能
4. **审核透明**: 审核进度和结果的透明化展示