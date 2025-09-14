# Amoure V2 后端实现文档 - 其他核心模块（Additional Core Modules）

## 模块概述

除了前面详细介绍的核心模块外，Amoure V2 系统还包含多个重要的支撑模块，包括用户认证模块、举报管理模块、作业调度系统、以及各种工具类和配置模块。这些模块虽然不是主要业务逻辑，但对系统的完整性和稳定性至关重要。

## 用户认证模块 (User Verification Module)

### 1. 控制器层设计
**文件位置**: `com.amoure.api.v2.controller.UserVerificationV2Controller`

#### 主要功能
- 身份认证申请和管理
- 学校认证、公司认证、收入认证
- 真人认证和实名认证
- 认证状态查询和管理

#### API设计特点
```java
@RestController
@RequestMapping("/api/v2/verification")
public class UserVerificationV2Controller {
    
    // 获取认证状态
    @GetMapping("/status")
    public Result<VerificationStatusResponse> getVerificationStatus();
    
    // 申请认证
    @PostMapping("/{type}")
    public Result<Boolean> applyVerification(@PathVariable String type, @RequestBody VerificationRequest request);
    
    // 认证审核（管理员）
    @PostMapping("/{verificationId}/review") 
    public Result<Boolean> reviewVerification(@PathVariable Long verificationId, @RequestBody ReviewRequest request);
}
```

### 2. 服务层设计
**文件位置**: `com.amoure.api.v2.service.VerificationService`

#### 认证类型支持
```java
public enum VerificationType {
    IDENTITY("身份认证"),        // 实名认证
    REAL_PERSON("真人认证"),     // 真人验证  
    SCHOOL("学校认证"),         // 学历认证
    COMPANY("公司认证"),        // 工作认证
    INCOME("收入认证");         // 收入证明
}
```

#### 核心业务逻辑
```java
@Service
public class VerificationService {
    
    // 获取用户完整认证状态
    public VerificationStatusResponse getAllVerificationStatus(Long userId);
    
    // 获取已通过的认证状态
    public VerificationStatusResponse getApprovedVerificationStatus(Long userId);
    
    // 批量获取认证状态
    public Map<Long, VerificationStatusResponse> batchGetApprovedVerificationStatus(List<Long> userIds);
    
    // 申请认证
    public void applyVerification(Long userId, VerificationType type, VerificationRequest request);
    
    // 审核认证
    public void reviewVerification(Long verificationId, boolean approved, String reason);
}
```

#### 认证状态管理
**策略模式实现**:
```java
@Component
public class BaseVerificationStrategy {
    
    // 不同认证类型的验证策略
    public abstract boolean validate(VerificationRequest request);
    public abstract boolean supports(VerificationType type);
}

// 具体实现类
@Component
public class IdentityVerificationStrategy extends BaseVerificationStrategy;

@Component  
public class SchoolVerificationStrategy extends BaseVerificationStrategy;
```

## 举报管理模块 (Report Management Module)

### 1. 控制器层设计
**文件位置**: `com.amoure.api.v2.controller.ReportV2Controller`

#### 主要功能
- 用户举报提交
- 举报类型管理
- 举报处理流程
- 举报统计和分析

#### API接口
```java
@RestController
@RequestMapping("/api/v2/report")
public class ReportV2Controller {
    
    // 提交举报
    @PostMapping
    public Result<ReportResponse> submitReport(@RequestBody @Valid ReportRequest request);
    
    // 获取举报列表（管理员）
    @GetMapping("/list")
    public Result<PageResponse<ReportResponse>> getReports(
        @RequestParam(defaultValue = "0") Integer page,
        @RequestParam(defaultValue = "20") Integer size,
        @RequestParam(required = false) String status
    );
    
    // 处理举报（管理员）
    @PostMapping("/{reportId}/handle")
    public Result<Boolean> handleReport(@PathVariable Long reportId, @RequestBody HandleReportRequest request);
}
```

### 2. 数据模型设计

#### UserReport 实体
**文件位置**: `com.amoure.api.v2.domain.entity.UserReport`

```java
@Data
@Builder
@TableName("reports")
public class UserReport {
    @TableId(type = IdType.AUTO)
    private Long id;                    // 举报ID
    
    @TableField("reporter_id")
    private Long reporterId;            // 举报人ID
    
    @TableField("reported_user_id")
    private Long reportedUserId;        // 被举报用户ID (向后兼容)
    
    @TableField("report_type")
    private ReportType reportType;      // 举报类型
    
    @TableField("target_id")
    private Long targetId;              // 目标ID (用户ID或帖子ID)
    
    @TableField("reason")
    private ReportReason reason;        // 举报原因
    
    @TableField("description")
    private String description;         // 举报描述
    
    @TableField("status")
    private ReportStatus status;        // 举报状态
    
    @TableField("reviewer_id")
    private Long reviewerId;            // 审核人ID
    
    @TableField("review_note")
    private String reviewNote;          // 审核备注
    
    @TableField("reviewed_at")
    private LocalDateTime reviewedAt;   // 审核时间
    
    @TableField("reporter_ip")
    private String reporterIp;          // 举报人IP
    
    @TableLogic
    @TableField("deleted")
    private Boolean deleted;            // 逻辑删除
    
    private LocalDateTime createdAt;    // 创建时间
    private LocalDateTime updatedAt;    // 更新时间
}
```

### 3. 枚举类型定义

#### ReportType - 举报类型
```java
public enum ReportType {
    USER("用户举报"),
    POST("帖子举报");
}
```

#### ReportReason - 举报原因
```java
public enum ReportReason {
    INAPPROPRIATE_CONTENT("不当内容"),
    FAKE_PROFILE("虚假档案"),
    HARASSMENT("骚扰行为"),
    SPAM("垃圾信息"),
    NUDITY("色情内容"),
    VIOLENCE("暴力内容"),
    FRAUD("欺诈行为"),
    COPYRIGHT("版权侵犯"),
    OTHER("其他");
}
```

#### ReportStatus - 举报状态
```java
public enum ReportStatus {
    PENDING("待处理"),
    APPROVED("已通过"),
    REJECTED("已驳回");
}
```

## 工单管理系统 (Work Order Management System)

### 1. 工单系统概述
**文件位置**: `com.amoure.api.v2.service.WorkOrderService`

#### 设计理念
工单系统是 Amoure V2 的核心业务支撑系统，负责处理所有需要人工干预的业务流程，包括：
- **举报处理**: 自动为所有举报创建工单
- **认证审核**: 为无自动化处理的认证类型创建工单  
- **申诉处理**: 用户申诉和争议处理
- **系统问题**: 技术问题和bug处理

### 2. 数据模型设计

#### WorkOrder 实体
**文件位置**: `com.amoure.api.v2.domain.entity.WorkOrder`

```java
@Data
@Builder
@TableName("work_orders")
public class WorkOrder {
    @TableId(type = IdType.AUTO)
    private Long id;                        // 工单ID
    
    @TableField("order_number")
    private String orderNumber;             // 工单编号 (WO202501020001)
    
    @TableField("order_type")
    private WorkOrderType orderType;        // 工单类型
    
    @TableField("title")
    private String title;                   // 工单标题
    
    @TableField("description")
    private String description;             // 工单描述
    
    @TableField("status")
    private WorkOrderStatus status;         // 工单状态
    
    @TableField("priority")
    private WorkOrderPriority priority;     // 优先级
    
    @TableField("creator_id")
    private Long creatorId;                 // 创建人ID
    
    @TableField("assignee_id")
    private Long assigneeId;                // 分配给的处理人ID
    
    @TableField("related_business_id")
    private Long relatedBusinessId;         // 关联业务ID
    
    @TableField("related_business_type")
    private String relatedBusinessType;     // 关联业务类型
    
    @TableField("metadata")
    private String metadata;                // 扩展数据 (JSON)
    
    @TableField("resolution")
    private String resolution;              // 处理结果
    
    @TableField("due_date")
    private LocalDateTime dueDate;          // 预计处理时间
    
    @TableField("started_at")
    private LocalDateTime startedAt;        // 开始处理时间
    
    @TableField("resolved_at")
    private LocalDateTime resolvedAt;       // 解决时间
    
    private LocalDateTime createdAt;        // 创建时间
    private LocalDateTime updatedAt;        // 更新时间
    
    @TableLogic
    private Boolean deleted;                // 逻辑删除
}
```

### 3. 枚举类型设计

#### WorkOrderType - 工单类型
```java
public enum WorkOrderType {
    REPORT("举报处理"),         // 举报相关工单
    VERIFICATION("认证审核"),   // 认证审核工单
    APPEAL("申诉处理"),         // 申诉处理工单
    SYSTEM_ISSUE("系统问题"),   // 系统问题工单
    OTHER("其他");             // 其他类型工单
    
    // 自动生成工单编号
    public static String generateOrderNumber(WorkOrderType orderType);
}
```

#### WorkOrderStatus - 工单状态
```java
public enum WorkOrderStatus {
    OPEN("待处理"),            // 新建工单，等待分配
    IN_PROGRESS("处理中"),     // 已分配，正在处理
    PENDING_INFO("等待补充信息"), // 等待用户补充信息
    RESOLVED("已解决"),        // 处理完成，等待关闭
    CLOSED("已关闭"),          // 正常关闭
    CANCELLED("已取消");       // 取消处理
    
    public boolean isOpen();       // 是否为开放状态
    public boolean isCompleted();  // 是否已完成
    public boolean canReopen();    // 是否可以重新打开
}
```

#### WorkOrderPriority - 工单优先级
```java
public enum WorkOrderPriority {
    LOW(1, "低"),
    MEDIUM(2, "中"),
    HIGH(3, "高"),
    URGENT(4, "紧急");
    
    // 根据工单类型自动确定优先级
    public static WorkOrderPriority getDefaultPriority(WorkOrderType orderType) {
        switch (orderType) {
            case REPORT: return MEDIUM;        // 举报工单中等优先级
            case VERIFICATION: return LOW;     // 认证工单低优先级
            case APPEAL: return HIGH;          // 申诉工单高优先级
            case SYSTEM_ISSUE: return URGENT;  // 系统问题紧急
            default: return MEDIUM;
        }
    }
}
```

### 4. 核心业务逻辑

#### 举报工单自动创建
**触发时机**: 用户提交举报后立即创建工单

```java
public WorkOrder createReportWorkOrder(UserReport report) {
    // 1. 检查重复工单
    WorkOrder existingOrder = workOrderMapper.findByBusinessIdAndType(
        report.getId(), "REPORT");
    if (existingOrder != null && existingOrder.isOpen()) {
        return existingOrder; // 避免重复创建
    }
    
    // 2. 构建工单信息
    String title = buildReportWorkOrderTitle(report);
    String description = buildReportWorkOrderDescription(report);
    Map<String, Object> metadata = buildReportMetadata(report);
    
    // 3. 创建工单
    WorkOrder workOrder = WorkOrder.builder()
        .orderNumber(WorkOrder.generateOrderNumber(WorkOrderType.REPORT))
        .orderType(WorkOrderType.REPORT)
        .title(title)
        .description(description)
        .status(WorkOrderStatus.OPEN)
        .priority(WorkOrderPriority.MEDIUM)
        .relatedBusinessId(report.getId())
        .relatedBusinessType("REPORT")
        .metadata(serializeMetadata(metadata))
        .dueDate(calculateDueDate(WorkOrderType.REPORT, WorkOrderPriority.MEDIUM))
        .build();
        
    workOrderMapper.insert(workOrder);
    return workOrder;
}
```

#### 认证工单条件创建  
**触发时机**: 认证类型不支持自动处理时创建工单

```java
public boolean shouldCreateVerificationWorkOrder(VerificationType verificationType) {
    switch (verificationType) {
        case REALPERSON:
            return false; // 真人认证有AI自动处理
        case SCHOOL:
            return true;  // 学历认证可能需要人工审核
        case CAREER:
        case IDENTITY:
        case INCOME:
            return true;  // 这些认证需要人工审核
        default:
            return true;
    }
}

public WorkOrder createVerificationWorkOrder(UserVerification verification) {
    // 创建认证审核工单的逻辑
    // 包含认证类型、用户信息、认证材料等元数据
}
```

### 5. 工单处理流程

#### 工单生命周期管理
```java
// 工单状态流转
OPEN → IN_PROGRESS → RESOLVED → CLOSED
  ↓         ↓           ↓
CANCELLED  PENDING_INFO  ↑ (可重新打开)

// 核心状态操作方法
public void assignWorkOrder(Long orderId, Long assigneeId);     // 分配工单
public void startProcessing(Long orderId, Long assigneeId);     // 开始处理
public void markPendingInfo(Long orderId, String note);         // 标记等待信息
public void resolveWorkOrder(Long orderId, String resolution);  // 解决工单
public void closeWorkOrder(Long orderId);                       // 关闭工单
public void reopenWorkOrder(Long orderId);                      // 重新打开
```

#### 工单分配策略
```java
// 批量分配工单
public void batchAssignOrders(List<Long> orderIds, Long assigneeId);

// 自动分配策略（可扩展）
public void autoAssignOrders() {
    // 根据工单类型、优先级、处理人负载等因素自动分配
}
```

### 6. 查询和统计功能

#### 工单查询接口
```java
// 分页查询工单
public PageResponse<WorkOrder> getPendingWorkOrders(int page, int size);
public PageResponse<WorkOrder> getAssigneeWorkOrders(Long assigneeId, int page, int size);
public PageResponse<WorkOrder> getWorkOrdersByType(WorkOrderType type, int page, int size);

// 超期工单查询
public List<WorkOrder> getOverdueOrders();
```

#### 统计分析功能
```java
// 工单统计
public Map<WorkOrderStatus, Long> getOrderCountByStatus();
public Map<WorkOrderType, Long> getOrderCountByType(LocalDateTime start, LocalDateTime end);
public Map<Long, Long> getOrderCountByAssignee(LocalDateTime start, LocalDateTime end);

// 性能指标
public double getAverageResolutionTime(WorkOrderType type);
public int getOverdueOrderCount();
```

### 7. 集成设计模式

#### 举报系统集成
**在ReportService中的集成**:
```java
@Transactional(rollbackFor = Exception.class)
public ReportDetailResponse createReport(Long reporterUserId, CreateReportRequest request, String clientIp) {
    // 1. 创建举报记录
    UserReport report = createReportRecord(reporterUserId, request, clientIp);
    
    // 2. 自动创建工单
    try {
        WorkOrder workOrder = workOrderService.createReportWorkOrder(report);
        log.info("举报工单创建成功: reportId={}, orderId={}", report.getId(), workOrder.getId());
    } catch (Exception e) {
        log.error("创建举报工单失败: reportId={}", report.getId(), e);
        // 不中断主流程，工单创建失败不影响举报记录创建
    }
    
    // 3. 发布事件通知
    publishReportCreatedEvent(report);
    
    return buildReportDetailResponse(report);
}
```

#### 认证系统集成
**在BaseVerificationStrategy中的集成**:
```java
private UserVerification createVerification(Long userId, Map<String, Object> verificationData, 
                                          List<String> documentUrls, String description) {
    // 1. 创建认证记录
    UserVerification verification = buildVerificationRecord(userId, verificationData, description);
    verificationMapper.insert(verification);
    
    // 2. 检查是否需要创建工单
    if (workOrderService.shouldCreateVerificationWorkOrder(getVerificationType())) {
        try {
            WorkOrder workOrder = workOrderService.createVerificationWorkOrder(verification);
            log.info("认证工单创建成功: verificationId={}, orderId={}", 
                    verification.getId(), workOrder.getId());
        } catch (Exception e) {
            log.error("创建认证工单失败: verificationId={}", verification.getId(), e);
        }
    } else {
        log.debug("认证类型支持自动处理，无需创建工单: type={}", getVerificationType());
    }
    
    return verification;
}
```

### 8. 数据访问层设计

#### WorkOrderMapper 核心功能
```java
// 业务查询
WorkOrder findByBusinessIdAndType(Long businessId, String businessType);
WorkOrder findSimilarOpenOrder(WorkOrderType orderType, Long businessId, String businessType);

// 状态查询
IPage<WorkOrder> findPendingOrders(Page<WorkOrder> page);
IPage<WorkOrder> findByAssigneeId(Page<WorkOrder> page, Long assigneeId);
List<WorkOrder> findOverdueOrders(LocalDateTime now);

// 统计查询
List<WorkOrderStatusCount> countByStatus();
List<WorkOrderTypeCount> countByTypeInDateRange(LocalDateTime start, LocalDateTime end);
List<WorkOrderAssigneeCount> countByAssigneeInDateRange(LocalDateTime start, LocalDateTime end);

// 批量操作
int batchAssignOrders(List<Long> orderIds, Long assigneeId, LocalDateTime now);
```

### 9. 性能优化设计

#### 批量处理优化
```java
// 批量分配工单
@Update("UPDATE work_orders SET assignee_id = #{assigneeId}, " +
        "status = CASE WHEN status = 'OPEN' THEN 'IN_PROGRESS' ELSE status END, " +
        "updated_at = #{now} " +
        "WHERE id IN (...) AND deleted = 0")
int batchAssignOrders(@Param("orderIds") List<Long> orderIds, 
                     @Param("assigneeId") Long assigneeId);
```

#### 索引优化策略
```sql
-- 工单查询优化
INDEX idx_work_order_status_priority (status, priority, created_at)
INDEX idx_work_order_assignee (assignee_id, status)
INDEX idx_work_order_business (related_business_type, related_business_id)
INDEX idx_work_order_due_date (due_date, status)
```

### 10. 监控和运维

#### 关键监控指标
- **工单创建率**: 每日新建工单数量
- **处理效率**: 平均处理时间和完成率
- **超期率**: 超过预计处理时间的工单比例
- **处理人负载**: 每个处理人的工单分配和完成情况
- **业务分布**: 各类业务产生的工单数量分布

#### 重要日志记录
```java
log.info("举报工单创建成功: reportId={}, orderId={}, orderNumber={}", 
        report.getId(), workOrder.getId(), workOrder.getOrderNumber());
log.info("认证工单创建成功: verificationId={}, orderId={}, orderNumber={}", 
        verification.getId(), workOrder.getId(), workOrder.getOrderNumber());
log.info("工单分配成功: orderId={}, assigneeId={}", orderId, assigneeId);
log.info("工单解决成功: orderId={}, resolution={}", orderId, resolution);
```

### 11. 业务规则设计

#### 工单创建规则
```java
// 举报工单：所有举报都创建工单
UserReport report = createReportRecord(...);
WorkOrder workOrder = workOrderService.createReportWorkOrder(report);

// 认证工单：仅无自动处理的认证类型创建工单
if (workOrderService.shouldCreateVerificationWorkOrder(verificationType)) {
    WorkOrder workOrder = workOrderService.createVerificationWorkOrder(verification);
}
```

#### 工单编号生成规则
```java
// 工单编号格式：WO + 类型码 + 时间戳后10位
public static String generateOrderNumber(WorkOrderType orderType) {
    String prefix = "WO";
    String typeCode = getTypeCode(orderType); // R/V/A/S/O
    String timestamp = String.valueOf(System.currentTimeMillis()).substring(4);
    return prefix + typeCode + timestamp;
}

// 示例编号：
// WOR1234567890 - 举报工单
// WOV1234567890 - 认证工单  
// WOA1234567890 - 申诉工单
```

#### 优先级和截止时间规则
```java
private LocalDateTime calculateDueDate(WorkOrderType orderType, WorkOrderPriority priority) {
    switch (priority) {
        case URGENT:  return now.plusHours(4);   // 紧急：4小时
        case HIGH:    return now.plusHours(24);  // 高：24小时
        case MEDIUM:  return now.plusDays(3);    // 中：3天
        case LOW:     return now.plusDays(7);    // 低：7天
    }
}
```

### 12. 扩展功能设计

#### 工单模板系统
```java
// 不同类型工单的标题和描述模板
private String buildReportWorkOrderTitle(UserReport report) {
    String targetType = report.isUserReport() ? "用户" : "帖子";
    return String.format("处理%s举报 - %s", targetType, report.getReason().getDescription());
}

private String buildVerificationWorkOrderTitle(UserVerification verification) {
    return String.format("审核%s认证申请", verification.getVerificationType().getDescription());
}
```

#### 元数据管理
```java
// 举报工单元数据
Map<String, Object> metadata = new HashMap<>();
metadata.put("reportId", report.getId());
metadata.put("reportType", report.getReportType());
metadata.put("reportReason", report.getReason());
metadata.put("reporterId", report.getReporterId());
metadata.put("targetId", report.getActualTargetId());

// 认证工单元数据
Map<String, Object> metadata = new HashMap<>();
metadata.put("verificationId", verification.getId());
metadata.put("verificationType", verification.getVerificationType());
metadata.put("userId", verification.getUserId());
metadata.put("description", verification.getDescription());
```

## 作业调度系统 (Job Scheduling System)

### 1. 推荐作业系统
**文件位置**: `com.amoure.api.v2.job.UserRecommendJobV2`

#### 核心功能
```java
@Component
public class UserRecommendJobV2 {
    
    // 手动触发用户推荐
    public List<Long> manualTriggerRecommendationForUser(Long userId) {
        // 1. 获取用户偏好和历史行为
        UserPreference preference = getUserPreference(userId);
        
        // 2. 执行推荐算法
        List<Long> candidates = runRecommendationAlgorithm(userId, preference);
        
        // 3. 过滤已交互用户
        List<Long> filtered = filterInteractedUsers(userId, candidates);
        
        // 4. 缓存推荐结果
        cacheRecommendations(userId, filtered);
        
        return filtered;
    }
    
    // 批量生成推荐（定时任务）
    @Scheduled(cron = "0 0 2 * * ?") // 每天凌晨2点执行
    public void generateRecommendationsBatch() {
        List<Long> activeUsers = getActiveUsers();
        
        for (Long userId : activeUsers) {
            try {
                manualTriggerRecommendationForUser(userId);
            } catch (Exception e) {
                log.error("生成推荐失败: userId={}", userId, e);
            }
        }
    }
}
```

### 2. 推荐算法设计
#### 多因子算法
```java
public class RecommendationAlgorithm {
    
    public List<Long> recommend(Long userId, UserPreference preference) {
        List<UserCandidate> candidates = new ArrayList<>();
        
        // 1. 地理位置因子
        List<UserCandidate> locationMatches = findByLocation(userId, preference.getLocation());
        applyLocationWeight(locationMatches, 0.3);
        candidates.addAll(locationMatches);
        
        // 2. 年龄匹配因子
        List<UserCandidate> ageMatches = findByAgeRange(userId, preference.getAgeRange());
        applyAgeWeight(ageMatches, 0.2);
        candidates.addAll(ageMatches);
        
        // 3. 兴趣标签因子
        List<UserCandidate> interestMatches = findByInterests(userId, preference.getInterests());
        applyInterestWeight(interestMatches, 0.25);
        candidates.addAll(interestMatches);
        
        // 4. 教育背景因子
        List<UserCandidate> educationMatches = findByEducation(userId, preference.getEducation());
        applyEducationWeight(educationMatches, 0.15);
        candidates.addAll(educationMatches);
        
        // 5. 活跃度因子
        applyActivityWeight(candidates, 0.1);
        
        // 6. 排序和去重
        return candidates.stream()
            .collect(Collectors.groupingBy(UserCandidate::getUserId))
            .entrySet().stream()
            .map(entry -> {
                double totalScore = entry.getValue().stream()
                    .mapToDouble(UserCandidate::getScore)
                    .sum();
                return new UserCandidate(entry.getKey(), totalScore);
            })
            .sorted((a, b) -> Double.compare(b.getScore(), a.getScore()))
            .map(UserCandidate::getUserId)
            .limit(50) // 限制推荐数量
            .collect(Collectors.toList());
    }
}
```

## 工具类和常量模块

### 1. 用户状态工具类
**文件位置**: `com.amoure.api.v2.util.UserStatusUtil`

#### 核心功能
```java
public class UserStatusUtil {
    
    // 判断用户是否最近活跃
    public static boolean isUserRecentlyActive(UserInfoMapper mapper, Long userId) {
        UserInfo userInfo = mapper.selectById(userId);
        if (userInfo == null) return false;
        
        LocalDateTime lastLogin = userInfo.getLastLoginTime();
        return lastLogin != null && 
               lastLogin.isAfter(LocalDateTime.now().minusDays(7));
    }
    
    // 判断用户是否在线
    public static boolean isUserRecentlyOnline(UserInfoMapper mapper, Long userId) {
        UserInfo userInfo = mapper.selectById(userId);
        if (userInfo == null) return false;
        
        LocalDateTime lastLogin = userInfo.getLastLoginTime();
        return lastLogin != null && 
               lastLogin.isAfter(LocalDateTime.now().minusHours(1));
    }
    
    // 计算用户资料完整度
    public static int calculateProfileCompleteness(UserInfoMapper userMapper, UserProfileMapper profileMapper, Long userId) {
        UserInfo userInfo = userMapper.selectById(userId);
        UserProfile userProfile = profileMapper.findByUserId(userId);
        
        if (userInfo == null || userProfile == null) return 0;
        
        int totalFields = 20; // 总字段数
        int completedFields = 0;
        
        // 检查各个字段是否完整
        if (StringUtils.isNotBlank(userProfile.getUsername())) completedFields++;
        if (userProfile.getAge() != null && userProfile.getAge() > 0) completedFields++;
        if (StringUtils.isNotBlank(userProfile.getGender())) completedFields++;
        if (userProfile.getHeight() != null && userProfile.getHeight() > 0) completedFields++;
        // ... 更多字段检查
        
        return (completedFields * 100) / totalFields;
    }
    
    // 从活跃足迹计算活跃天数
    public static Integer calculateActiveDaysFromFootprints(UserInfo userInfo) {
        String footprints = userInfo.getActivefootprints();
        if (StringUtils.isBlank(footprints)) return 0;
        
        try {
            String[] days = footprints.split(",");
            return days.length;
        } catch (Exception e) {
            log.error("解析活跃足迹失败: userId={}, footprints={}", userInfo.getId(), footprints, e);
            return 0;
        }
    }
}
```

### 2. 活跃天数工具类
**文件位置**: `com.amoure.api.util.ActiveDaysUtil`

#### 核心功能
```java
public class ActiveDaysUtil {
    
    // 更新活跃足迹
    public static String updateActivefootprints(String currentFootprints, long todayTimestamp) {
        Set<Long> timestamps = new HashSet<>();
        
        // 解析现有足迹
        if (StringUtils.isNotBlank(currentFootprints)) {
            String[] parts = currentFootprints.split(",");
            for (String part : parts) {
                try {
                    timestamps.add(Long.parseLong(part.trim()));
                } catch (NumberFormatException e) {
                    log.warn("无效的时间戳格式: {}", part);
                }
            }
        }
        
        // 添加今天的时间戳
        timestamps.add(todayTimestamp);
        
        // 保持最近30天的记录
        LocalDateTime thirtyDaysAgo = LocalDateTime.now().minusDays(30);
        long thirtyDaysAgoTimestamp = thirtyDaysAgo.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
        
        timestamps = timestamps.stream()
            .filter(ts -> ts >= thirtyDaysAgoTimestamp)
            .collect(Collectors.toSet());
        
        // 转换为字符串
        return timestamps.stream()
            .sorted()
            .map(String::valueOf)
            .collect(Collectors.joining(","));
    }
}
```

### 3. 用户交互常量
**文件位置**: `com.amoure.api.v2.constants.UserInteractionConstants`

```java
public class UserInteractionConstants {
    
    // 点赞类型常量
    public static final Integer LIKE_TYPE_REGULAR = 1;
    public static final Integer LIKE_TYPE_SUPER = 2;
    
    // 匹配状态常量
    public static final String MATCH_STATUS_SUCCESS = "matched";
    
    // 心动列表类型
    public static final String TYPE_LIKE_ME = "i_liked";
    public static final String TYPE_I_LIKE = "liked_by_me";
    public static final String TYPE_MUTUAL = "mutual_liked";
    
    // 过滤条件
    public static final String FILTER_ALL_XINDONG = "all";
    public static final String FILTER_RECENT_ONLINE_OLD = "recent_online";
    public static final String FILTER_RECENT_ACTIVE_OLD = "recent_active";
    public static final String FILTER_PROFILE_COMPLETE_OLD = "profile_complete";
    public static final String FILTER_MULTIPLE_VERIFICATION = "verified";
    
    // 分页常量
    public static final int DEFAULT_PAGE = 1;
    public static final int MIN_PAGE = 1;
    public static final int DEFAULT_SIZE = 20;
    public static final int MAX_SIZE = 100;
    
    // 字段名常量
    public static final String FIELD_USER_ID = "userId";
    public static final String FIELD_NICKNAME = "nickname";
    public static final String FIELD_AVATAR_URL = "avatarUrl";
    public static final String FIELD_AGE = "age";
    public static final String FIELD_HEIGHT = "height";
    public static final String FIELD_DEGREE = "degree";
    public static final String FIELD_OCCUPATION = "occupation";
    
    // 日志模板
    public static final String LOG_USER_INTERACTION = "用户交互操作: userId={}, targetUserId={}, type={}";
    public static final String LOG_USER_MATCHED = "用户匹配成功: userId={}, targetUserId={}, matchId={}";
    public static final String LOG_GET_LIKE_USER_LIST = "获取心动用户列表: userId={}, type={}, filter={}, page={}, size={}";
    
    // 错误消息
    public static final String ERROR_SELF_INTERACTION = "不能与自己进行交互";
    public static final String ERROR_TARGET_USER_NOT_FOUND = "目标用户不存在: ";
    public static final String ERROR_TARGET_USER_INACTIVE = "目标用户状态异常";
    public static final String ERROR_USER_BLOCKED = "用户已被拉黑";
}
```

## 配置模块

### 1. Sa-Token配置
```java
@Configuration
public class SaTokenConfig implements WebMvcConfigurer {
    
    // 注册Sa-Token拦截器
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new SaInterceptor(handle -> StpUtil.checkLogin()))
                .addPathPatterns("/api/v2/**")
                .excludePathPatterns("/api/v2/auth/login", "/api/v2/auth/register");
    }
    
    // Sa-Token配置
    @Bean
    @Primary
    public StpInterface getStpInterface() {
        return new StpInterfaceImpl();
    }
}
```

### 2. 缓存配置
```java
@Configuration
@EnableCaching
public class CacheConfig {
    
    @Bean
    public CacheManager cacheManager() {
        RedisCacheManager.Builder builder = RedisCacheManager
                .RedisCacheManagerBuilder
                .fromConnectionFactory(redisConnectionFactory)
                .cacheDefaults(cacheConfiguration());
        
        return builder.build();
    }
    
    private RedisCacheConfiguration cacheConfiguration() {
        return RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(Duration.ofHours(1))
                .disableCachingNullValues()
                .serializeKeysWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(new StringRedisSerializer()))
                .serializeValuesWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(new GenericJackson2JsonRedisSerializer()));
    }
}
```

### 3. 缓存键常量
**文件位置**: `com.amoure.api.constant.CacheKeyConstants`

```java
public class CacheKeyConstants {
    
    // 推荐系统缓存键
    public static final String RECOMMEND_USERS_KEY = "recommend:users:";
    
    // 用户信息缓存键
    public static final String USER_PROFILE_KEY = "user:profile:";
    public static final String USER_PHOTOS_KEY = "user:photos:";
    public static final String USER_VERIFICATION_KEY = "user:verification:";
    
    // 交互数据缓存键
    public static final String USER_LIKES_KEY = "user:likes:";
    public static final String USER_MATCHES_KEY = "user:matches:";
    public static final String USER_BLOCKS_KEY = "user:blocks:";
    
    // 动态内容缓存键
    public static final String USER_POSTS_KEY = "posts:user:";
    public static final String RECOMMEND_POSTS_KEY = "posts:recommend:";
    public static final String POST_DETAIL_KEY = "post:detail:";
    
    // 对话缓存键
    public static final String CONVERSATIONS_KEY = "conversations:user:";
    public static final String CONVERSATION_DETAIL_KEY = "conversation:detail:";
    
    // 验证码缓存键
    public static final String VERIFY_CODE_KEY = "verify:code:";
    public static final String LOGIN_ATTEMPT_KEY = "login:attempt:";
    
    // 系统配置缓存键
    public static final String SYSTEM_CONFIG_KEY = "system:config:";
    public static final String FEATURE_FLAGS_KEY = "system:features:";
}
```

## 监控和健康检查

### 1. 健康检查端点
```java
@RestController
@RequestMapping("/api/v2/health")
public class HealthController {
    
    @Autowired
    private DataSource dataSource;
    
    @Autowired
    private StringRedisTemplate redisTemplate;
    
    @GetMapping
    public Result<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        
        // 数据库健康检查
        health.put("database", checkDatabase());
        
        // Redis健康检查
        health.put("redis", checkRedis());
        
        // 系统信息
        health.put("system", getSystemInfo());
        
        return Result.success(health);
    }
    
    private Map<String, Object> checkDatabase() {
        try {
            Connection connection = dataSource.getConnection();
            boolean valid = connection.isValid(5);
            connection.close();
            
            Map<String, Object> db = new HashMap<>();
            db.put("status", valid ? "UP" : "DOWN");
            db.put("responseTime", System.currentTimeMillis());
            return db;
        } catch (Exception e) {
            Map<String, Object> db = new HashMap<>();
            db.put("status", "DOWN");
            db.put("error", e.getMessage());
            return db;
        }
    }
    
    private Map<String, Object> checkRedis() {
        try {
            String pong = redisTemplate.getConnectionFactory()
                    .getConnection().ping();
            
            Map<String, Object> redis = new HashMap<>();
            redis.put("status", "PONG".equals(pong) ? "UP" : "DOWN");
            redis.put("response", pong);
            return redis;
        } catch (Exception e) {
            Map<String, Object> redis = new HashMap<>();
            redis.put("status", "DOWN");
            redis.put("error", e.getMessage());
            return redis;
        }
    }
}
```

### 2. 系统监控指标
```java
@Component
public class SystemMetrics {
    
    private final MeterRegistry meterRegistry;
    
    // 用户注册指标
    public void recordUserRegistration() {
        Counter.builder("user.registration.total")
                .description("Total user registrations")
                .register(meterRegistry)
                .increment();
    }
    
    // 用户交互指标
    public void recordUserInteraction(String type) {
        Counter.builder("user.interaction.total")
                .description("Total user interactions")
                .tag("type", type)
                .register(meterRegistry)
                .increment();
    }
    
    // 推荐系统指标
    public void recordRecommendationGenerated(int count) {
        Gauge.builder("recommendation.count")
                .description("Number of recommendations generated")
                .register(meterRegistry, count);
    }
}
```

## 最佳实践总结

### 1. 代码组织原则
- **模块化设计**: 按业务功能拆分模块
- **层次分明**: Controller、Service、Mapper分层清晰
- **职责单一**: 每个类和方法职责明确
- **依赖注入**: 使用Spring的依赖注入管理对象

### 2. 性能优化策略
- **批量操作**: 优先使用批量接口
- **缓存使用**: 合理使用多级缓存
- **异步处理**: 非关键路径异步处理
- **数据库优化**: 合理使用索引和查询优化

### 3. 安全和可靠性
- **权限控制**: 严格的API权限验证
- **数据校验**: 完整的输入数据校验
- **异常处理**: 完善的异常处理机制
- **监控告警**: 全面的系统监控和告警

### 4. 扩展性考虑
- **配置化**: 关键参数配置化管理
- **插件化**: 支持功能插件化扩展
- **版本控制**: API版本管理和兼容性
- **微服务准备**: 为微服务拆分预留接口边界