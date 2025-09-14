# Amoure Backend Database Schema - Refactored

## 概述

本文档详细描述了重构后的Amoure约会应用后台的数据库表结构。数据库使用PostgreSQL，包含用户管理、认证、推荐、互动、消息、动态内容等核心功能模块的数据表。

## 数据库信息
- **数据库名称**: muer
- **数据库类型**: PostgreSQL
- **字符集**: UTF-8

---

## 核心数据表

### 1. 用户基础信息表

#### 1.1 user_info (用户基本信息表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | AUTO_INCREMENT | NOT NULL | PK | 用户ID，主键，自增 |
| location_code | varchar | 32 | - | YES | - | 地区编码 |
| location_name | varchar | 64 | - | YES | - | 地区名称 |
| last_login_time | timestamp | - | - | YES | - | 最后登录时间 |
| machine_review_status | enum | - | 'UNVERIFIED' | NOT NULL | - | 机审状态枚举(UNVERIFIED/APPROVED/REJECTED) |
| reject_reasons | text | - | - | YES | - | 机审驳回原因（记录审核不通过的具体原因） |
| account_status | enum | - | 'ACTIVE' | NOT NULL | - | 账号状态枚举(ACTIVE/BLOCKED/DELETED) |
| activefootprints | text | - | - | YES | - | 活跃足迹 |
| ideal_partner_avatar | varchar | 256 | - | YES | - | 理想伴侣头像URL |
| admin_score | integer | - | 0 | YES | - | 管理员评分（0-100分，用于推荐算法） |
| admin_score_updated_at | timestamp | - | - | YES | - | 管理员评分更新时间 |
| admin_score_updated_by | bigint | - | - | YES | - | 管理员评分更新者ID |
| create_time | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| update_time | timestamp | - | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | YES | - | 更新时间 |

**枚举定义**:
- `machine_review_status`: UNVERIFIED("未验证"), APPROVED("已通过"), REJECTED("已拒绝")
- `account_status`: ACTIVE("正常"), BLOCKED("已封禁"), DELETED("已删除")

#### 1.2 user_profile (用户档案信息表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 档案ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| username | varchar | 50 | - | YES | - | 用户名 |
| password | varchar | 100 | - | YES | - | 密码（加密存储） |
| height | integer | - | - | YES | - | 身高（厘米） |
| weight | integer | - | - | YES | - | 体重（公斤） |
| age | integer | - | - | YES | - | 年龄 |
| degree | varchar | 50 | - | YES | - | 教育程度 |
| occupation | varchar | 64 | - | YES | - | 职业 |
| income_range | varchar | 32 | - | YES | - | 收入范围 |
| relationship_status | json | - | - | YES | - | 关系状态（JSON格式） |
| has_children | smallint | - | 0 | YES | - | 是否有孩子：0-无，1-有 |
| want_children | smallint | - | 0 | YES | - | 是否想要孩子：0-不要，1-想要 |
| smoking_habit | varchar | 32 | - | YES | - | 吸烟习惯 |
| drinking_habit | varchar | 32 | - | YES | - | 饮酒习惯 |
| religion | varchar | 32 | - | YES | - | 宗教信仰 |
| hobbies | json | - | - | YES | - | 兴趣爱好（JSON格式） |
| self_introduction | text | - | - | YES | - | 个人简介 |
| qa_answers | json | - | - | YES | - | 问答答案（JSON格式） |
| location_code | varchar | 64 | - | YES | - | 地区编码 |
| location_name | varchar | 128 | - | YES | - | 地区名称 |
| hometown | varchar | 128 | - | YES | - | 家乡 |
| location_flexibility | json | - | - | YES | - | 位置灵活性（JSON格式） |
| birth_date | date | - | - | YES | - | 出生日期 |
| gender | varchar | 16 | - | YES | - | 性别(MALE/FEMALE) |
| interests | text | - | - | YES | - | 兴趣爱好（JSON格式） |
| tags | jsonb | - | - | YES | - | 用户标签（JSON格式） |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 1.3 user_photos (用户照片表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 照片ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| photo_url | varchar | 200 | - | NOT NULL | - | 照片URL |
| photo_type | varchar | 32 | 'ALBUM' | YES | - | 照片类型：ALBUM-相册照片，AVATAR-头像，POST-动态照片，IDEAL_PARTNER-理想伴侣照片 |
| post_id | bigint | - | - | YES | FK | 关联的动态ID（仅POST类型照片使用） |
| sort_order | integer | - | 0 | YES | - | 排序顺序 |
| status | integer | - | 1 | YES | - | 照片状态：1-正常，0-隐藏，-1-已删除 |
| review_status | varchar | 32 | - | YES | - | 审核状态：IN_REVIEW, APPROVED, REJECTED |
| reject_reason | text | - | - | YES | - | 驳回原因（审核不通过时记录具体原因） |
| retry_count | integer | - | 0 | YES | - | 重试次数（记录AI审核失败的重试次数） |
| last_retry_at | timestamp | - | - | YES | - | 最后重试时间 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

### 2. 认证与绑定表

#### 2.1 user_binding (用户第三方绑定表)
**注意**: 在当前实现中，第三方绑定信息（wechat_open_id、apple_id、google_id）以及邮箱(email)和手机号(phone)都存储在此表中，而不是分散在user_info或user_profile表中。

| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 绑定ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| binding_type | varchar | 32 | - | NOT NULL | - | 绑定类型：WECHAT/APPLE/GOOGLE/EMAIL/PHONE |
| third_party_id | varchar | 100 | - | NOT NULL | - | 第三方平台用户ID或邮箱/手机号 |
| third_party_nickname | varchar | 100 | - | YES | - | 第三方平台昵称 |
| access_token | text | - | - | YES | - | 访问令牌 |
| refresh_token | text | - | - | YES | - | 刷新令牌 |
| expires_at | timestamp | - | - | YES | - | 令牌过期时间 |
| bind_time | timestamp | - | CURRENT_TIMESTAMP | YES | - | 绑定时间 |
| status | integer | - | 1 | YES | - | 绑定状态：1-正常，0-解绑 |

**绑定类型说明**:
- WECHAT: 微信绑定，third_party_id存储wechat_open_id
- APPLE: Apple账号绑定，third_party_id存储apple_id  
- GOOGLE: Google账号绑定，third_party_id存储google_id
- EMAIL: 邮箱绑定，third_party_id存储邮箱地址
- PHONE: 手机号绑定，third_party_id存储手机号

#### 2.2 user_verification (用户验证表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 验证ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| verification_type | integer | - | - | NOT NULL | - | 验证类型：1-实名认证，2-学历认证，3-职业认证，4-收入认证 |
| verification_data | text | - | - | YES | - | 验证数据（JSON格式） |
| verification_description | varchar | 255 | - | YES | - | 公司或者学校名称 |
| review_status | integer | - | 0 | YES | - | 验证状态：0-待审核，1-通过，2-拒绝 |
| trust_score | integer | - | 0 | YES | - | 信任分数，认证通过后的信任值 |
| reviewer_id | bigint | - | - | YES | - | 审核员ID |
| review_comment | text | - | - | YES | - | 审核备注 |
| submitted_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 提交时间 |
| reviewed_at | timestamp | - | - | YES | - | 审核时间 |

### 3. 推荐与匹配表

#### 3.1 user_preferences (用户偏好设置表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 偏好ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| preferred_gender | integer | - | - | YES | - | 偏好性别：1-男，2-女，3-不限 |
| age_min | integer | - | 18 | YES | - | 最小年龄偏好 |
| age_max | integer | - | 60 | YES | - | 最大年龄偏好 |
| distance_max | integer | - | 50 | YES | - | 最大距离偏好（公里） |
| education_min | integer | - | - | YES | - | 最低教育程度要求 |
| income_min | varchar | 50 | - | YES | - | 最低收入要求 |
| height_min | integer | - | - | YES | - | 最低身高要求 |
| height_max | integer | - | - | YES | - | 最高身高要求 |
| interests_preference | text | - | - | YES | - | 兴趣偏好（JSON格式） |
| relocation_preference | varchar | 100 | - | YES | - | 搬迁偏好 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 3.2 recommendations (推荐记录表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 推荐ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| recommended_user_id | bigint | - | - | NOT NULL | FK | 被推荐用户ID |
| status | integer | - | 1 | YES | - | 推荐状态：1-活跃，0-失效 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |

### 4. 互动与匹配表

#### 4.1 user_likes (用户点赞表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 点赞ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 点赞用户ID |
| target_user_id | bigint | - | - | NOT NULL | FK | 被点赞用户ID |
| like_type | integer | - | 1 | YES | - | 点赞类型：1-喜欢，2-超级喜欢 |
| is_mutual | boolean | - | false | YES | - | 是否相互喜欢 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |

#### 4.2 user_matches (用户匹配表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 匹配ID，主键 |
| user1_id | bigint | - | - | NOT NULL | FK | 用户1ID |
| user2_id | bigint | - | - | NOT NULL | FK | 用户2ID |
| status | integer | - | 1 | YES | - | 匹配状态：1-匹配成功，2-聊天中，3-已结束 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 匹配时间 |

#### 4.3 user_blocks (用户屏蔽表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 屏蔽ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 屏蔽用户ID |
| blocked_user_id | bigint | - | - | NOT NULL | FK | 被屏蔽用户ID |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 屏蔽时间 |

### 5. 消息与IM表

#### 5.1 im_user_profile (IM用户配置表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 配置ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID，外键关联user_info.id |
| im_user_id | varchar | 100 | - | NOT NULL | - | IM系统用户ID |
| im_nickname | varchar | 100 | - | YES | - | IM昵称 |
| im_avatar | varchar | 200 | - | YES | - | IM头像 |
| im_signature | varchar | 200 | - | YES | - | IM个性签名 |
| online_status | integer | - | 1 | YES | - | 在线状态：1-在线，2-离线，3-忙碌 |
| last_seen | timestamp | - | - | YES | - | 最后在线时间 |
| push_enabled | boolean | - | true | YES | - | 是否开启推送 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 5.2 message_conversations (会话表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 会话ID，主键 |
| conversation_id | varchar | 100 | - | NOT NULL | - | 会话唯一标识 |
| user1_id | bigint | - | - | NOT NULL | FK | 用户1ID |
| user2_id | bigint | - | - | NOT NULL | FK | 用户2ID |
| conversation_type | integer | - | 1 | YES | - | 会话类型：1-私聊，2-群聊 |
| last_message_id | bigint | - | - | YES | - | 最后一条消息ID |
| last_message_time | timestamp | - | - | YES | - | 最后消息时间 |
| unread_count_user1 | integer | - | 0 | YES | - | 用户1未读消息数 |
| unread_count_user2 | integer | - | 0 | YES | - | 用户2未读消息数 |
| status | integer | - | 1 | YES | - | 会话状态：1-正常，0-删除 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 5.3 messages (消息表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 消息ID，主键 |
| conversation_id | varchar | 100 | - | NOT NULL | FK | 会话ID |
| sender_id | bigint | - | - | NOT NULL | FK | 发送者ID |
| receiver_id | bigint | - | - | NOT NULL | FK | 接收者ID |
| message_type | integer | - | 1 | YES | - | 消息类型：1-文本，2-图片，3-语音，4-视频，5-表情包 |
| content | text | - | - | YES | - | 消息内容 |
| media_url | varchar | 200 | - | YES | - | 媒体文件URL |
| message_status | integer | - | 1 | YES | - | 消息状态：1-已发送，2-已送达，3-已读 |
| is_recalled | boolean | - | false | YES | - | 是否已撤回 |
| send_time | timestamp | - | CURRENT_TIMESTAMP | YES | - | 发送时间 |
| delivered_time | timestamp | - | - | YES | - | 送达时间 |
| read_time | timestamp | - | - | YES | - | 已读时间 |

### 6. 动态内容表

#### 6.1 posts (动态帖子表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 帖子ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 发布者用户ID |
| content | text | - | - | YES | - | 帖子内容 |
| media_urls | text | - | - | YES | - | 媒体文件URLs（JSON格式） |
| post_type | integer | - | 1 | YES | - | 帖子类型：1-普通动态，2-图片动态，3-视频动态 |
| visibility | integer | - | 1 | YES | - | 可见性：1-公开，2-仅匹配用户，3-私密 |
| location | varchar | 100 | - | YES | - | 位置信息 |
| tags | text | - | - | YES | - | 标签（JSON格式） |
| like_count | integer | - | 0 | YES | - | 点赞数 |
| comment_count | integer | - | 0 | YES | - | 评论数 |
| share_count | integer | - | 0 | YES | - | 分享数 |
| status | integer | - | 1 | YES | - | 帖子状态：1-正常，2-隐藏，3-删除 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 6.2 post_likes (帖子点赞表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 点赞ID，主键 |
| post_id | bigint | - | - | NOT NULL | FK | 帖子ID |
| user_id | bigint | - | - | NOT NULL | FK | 点赞用户ID |
| like_type | integer | - | 1 | YES | - | 点赞类型：1-点赞，2-喜欢，3-超赞 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 点赞时间 |

#### 6.3 post_comments (帖子评论表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 评论ID，主键 |
| post_id | bigint | - | - | NOT NULL | FK | 帖子ID |
| user_id | bigint | - | - | NOT NULL | FK | 评论用户ID |
| content | text | - | - | NOT NULL | - | 评论内容 |
| review_status | varchar | 32 | - | YES | - | 审核状态 |
| status | integer | - | 1 | YES | - | 评论状态：1-正常，2-隐藏，3-删除 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 评论时间 |

### 7. VIP与订单表

#### 7.1 vip_packages (VIP套餐表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 套餐ID，主键 |
| package_name | varchar | 50 | - | NOT NULL | - | 套餐名称 |
| package_type | integer | - | - | NOT NULL | - | 套餐类型：1-月会员，2-季度会员，3-年会员 |
| duration_days | integer | - | - | NOT NULL | - | 有效期天数 |
| original_price | decimal | 10,2 | - | NOT NULL | - | 原价 |
| sale_price | decimal | 10,2 | - | NOT NULL | - | 售价 |
| features | text | - | - | YES | - | 功能特权（JSON格式） |
| description | text | - | - | YES | - | 套餐描述 |
| is_popular | boolean | - | false | YES | - | 是否热门推荐 |
| status | integer | - | 1 | YES | - | 套餐状态：1-上架，0-下架 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 7.2 user_vip (用户VIP信息表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | VIP记录ID，主键 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID |
| vip_level | integer | - | 0 | YES | - | VIP等级：0-普通用户，1-VIP1，2-VIP2 |
| package_id | bigint | - | - | YES | FK | VIP套餐ID |
| start_time | timestamp | - | - | YES | - | VIP开始时间 |
| end_time | timestamp | - | - | YES | - | VIP结束时间 |
| remaining_features | text | - | - | YES | - | 剩余特权次数（JSON格式） |
| auto_renew | boolean | - | false | YES | - | 是否自动续费 |
| status | integer | - | 1 | YES | - | VIP状态：1-正常，2-过期，3-取消 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 7.3 orders (订单表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 订单ID，主键 |
| order_no | varchar | 32 | - | NOT NULL | UK | 订单号 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID |
| package_id | bigint | - | - | NOT NULL | FK | 套餐ID |
| order_type | integer | - | 1 | YES | - | 订单类型：1-VIP购买，2-特权购买 |
| original_amount | decimal | 10,2 | - | NOT NULL | - | 原价金额 |
| discount_amount | decimal | 10,2 | 0.00 | YES | - | 优惠金额 |
| final_amount | decimal | 10,2 | - | NOT NULL | - | 实付金额 |
| payment_method | integer | - | - | YES | - | 支付方式：1-微信支付，2-支付宝，3-Apple Pay |
| payment_status | integer | - | 0 | YES | - | 支付状态：0-待支付，1-已支付，2-支付失败，3-已退款 |
| transaction_id | varchar | 100 | - | YES | - | 支付交易号 |
| order_status | integer | - | 1 | YES | - | 订单状态：1-待支付，2-已完成，3-已取消，4-已退款 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| paid_at | timestamp | - | - | YES | - | 支付时间 |
| completed_at | timestamp | - | - | YES | - | 完成时间 |

### 8. 客服与工单表

#### 8.1 work_orders (工单表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 工单ID，主键 |
| work_order_no | varchar | 32 | - | NOT NULL | UK | 工单号 |
| user_id | bigint | - | - | NOT NULL | FK | 用户ID |
| category | integer | - | - | NOT NULL | - | 工单分类：1-账号问题，2-支付问题，3-技术问题，4-投诉建议 |
| title | varchar | 200 | - | NOT NULL | - | 工单标题 |
| description | text | - | - | NOT NULL | - | 问题描述 |
| attachments | text | - | - | YES | - | 附件URLs（JSON格式） |
| priority | integer | - | 2 | YES | - | 优先级：1-高，2-中，3-低 |
| status | integer | - | 1 | YES | - | 工单状态：1-待处理，2-处理中，3-已解决，4-已关闭 |
| handler_id | bigint | - | - | YES | FK | 处理人员ID |
| handler_notes | text | - | - | YES | - | 处理备注 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |
| resolved_at | timestamp | - | - | YES | - | 解决时间 |

#### 8.2 help_categories (帮助分类表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 分类ID，主键 |
| parent_id | bigint | - | - | YES | FK | 父分类ID |
| category_name | varchar | 100 | - | NOT NULL | - | 分类名称 |
| category_icon | varchar | 200 | - | YES | - | 分类图标 |
| sort_order | integer | - | 0 | YES | - | 排序顺序 |
| status | integer | - | 1 | YES | - | 分类状态：1-启用，0-禁用 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 8.3 help_articles (帮助文章表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 文章ID，主键 |
| category_id | bigint | - | - | NOT NULL | FK | 分类ID |
| title | varchar | 200 | - | NOT NULL | - | 文章标题 |
| summary | varchar | 500 | - | YES | - | 文章摘要 |
| content | text | - | - | NOT NULL | - | 文章内容 |
| author_id | bigint | - | - | YES | FK | 作者ID |
| view_count | integer | - | 0 | YES | - | 阅读次数 |
| like_count | integer | - | 0 | YES | - | 点赞次数 |
| sort_order | integer | - | 0 | YES | - | 排序顺序 |
| is_featured | boolean | - | false | YES | - | 是否推荐 |
| status | integer | - | 1 | YES | - | 文章状态：1-发布，2-草稿，3-下线 |
| published_at | timestamp | - | - | YES | - | 发布时间 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

### 9. 举报与审核表

#### 9.1 reports (举报表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 举报ID，主键 |
| reporter_id | bigint | - | - | NOT NULL | FK | 举报人ID |
| reported_user_id | bigint | - | - | YES | FK | 被举报用户ID (仅用户举报时使用) |
| report_type | varchar | 20 | 'USER' | NOT NULL | - | 举报类型：USER-用户举报，POST-帖子举报 |
| target_id | bigint | - | - | NOT NULL | FK | 目标ID (用户ID或帖子ID，根据report_type确定) |
| reason | varchar | 50 | - | NOT NULL | - | 举报原因枚举值 |
| description | text | - | - | YES | - | 举报详细描述 |
| status | varchar | 20 | 'PENDING' | NOT NULL | - | 举报状态：PENDING-待处理，APPROVED-已通过，REJECTED-已驳回 |
| reviewer_id | bigint | - | - | YES | FK | 审核人员ID |
| review_note | text | - | - | YES | - | 审核备注 |
| reviewed_at | timestamp | - | - | YES | - | 审核时间 |
| reporter_ip | varchar | 45 | - | YES | - | 举报人IP地址 |
| deleted | boolean | - | false | NOT NULL | - | 逻辑删除标记 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | NOT NULL | - | 举报时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | NOT NULL | - | 更新时间 |

### 10. 问题选项表

#### 10.1 question_options (问题选项表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 选项ID，主键 |
| question_key | varchar | 64 | - | NOT NULL | - | 问题键值 |
| version | integer | - | 1 | NOT NULL | - | 版本号 |
| options_data | json | - | - | NOT NULL | - | 选项数据（多语言JSON格式） |
| created_at | timestamp | - | CURRENT_TIMESTAMP | NOT NULL | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | NOT NULL | - | 更新时间 |

#### 约束条件
- UNIQUE KEY: (question_key, version)
- INDEX: question_key, version

### 11. 系统配置表

#### 11.1 system_config (系统配置表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 配置ID，主键 |
| config_key | varchar | 100 | - | NOT NULL | UK | 配置键 |
| config_value | text | - | - | YES | - | 配置值 |
| config_type | varchar | 50 | 'string' | YES | - | 配置类型：string, number, boolean, json |
| description | varchar | 500 | - | YES | - | 配置描述 |
| is_encrypted | boolean | - | false | YES | - | 是否加密存储 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 11.2 admin_users (管理员用户表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 管理员ID，主键 |
| username | varchar | 50 | - | NOT NULL | UK | 管理员用户名 |
| password | varchar | 100 | - | NOT NULL | - | 密码（加密存储） |
| real_name | varchar | 50 | - | YES | - | 真实姓名 |
| email | varchar | 100 | - | YES | - | 邮箱 |
| phone | varchar | 20 | - | YES | - | 手机号 |
| role_id | bigint | - | - | NOT NULL | FK | 角色ID |
| status | integer | - | 1 | YES | - | 状态：1-正常，0-禁用 |
| last_login_time | timestamp | - | - | YES | - | 最后登录时间 |
| last_login_ip | varchar | 50 | - | YES | - | 最后登录IP |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

#### 11.3 admin_roles (管理员角色表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 角色ID，主键 |
| role_name | varchar | 50 | - | NOT NULL | - | 角色名称 |
| role_code | varchar | 50 | - | NOT NULL | UK | 角色编码 |
| description | varchar | 200 | - | YES | - | 角色描述 |
| permissions | text | - | - | YES | - | 权限列表（JSON格式） |
| status | integer | - | 1 | YES | - | 角色状态：1-启用，0-禁用 |
| created_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | YES | - | 更新时间 |

---

## 数据表关系

### 主要外键关系

1. **用户相关表**
   - `user_profile.user_id` → `user_info.id`
   - `user_photos.user_id` → `user_info.id`
   - `user_binding.user_id` → `user_info.id` (统一管理第三方绑定、邮箱、手机号)
   - `user_verification.user_id` → `user_info.id`

2. **推荐与匹配**
   - `user_preferences.user_id` → `user_info.id`
   - `recommendations.user_id` → `user_info.id`
   - `recommendations.recommended_user_id` → `user_info.id`
   - `user_likes.user_id` → `user_info.id`
   - `user_likes.target_user_id` → `user_info.id`
   - `user_matches.user1_id` → `user_info.id`
   - `user_matches.user2_id` → `user_info.id`

3. **消息系统**
   - `im_user_profile.user_id` → `user_info.id`
   - `message_conversations.user1_id` → `user_info.id`
   - `message_conversations.user2_id` → `user_info.id`
   - `messages.sender_id` → `user_info.id`
   - `messages.receiver_id` → `user_info.id`

4. **动态内容**
   - `posts.user_id` → `user_info.id`
   - `post_likes.post_id` → `posts.id`
   - `post_likes.user_id` → `user_info.id`
   - `post_comments.post_id` → `posts.id`
   - `post_comments.user_id` → `user_info.id`

5. **VIP与订单**
   - `user_vip.user_id` → `user_info.id`
   - `user_vip.package_id` → `vip_packages.id`
   - `orders.user_id` → `user_info.id`
   - `orders.package_id` → `vip_packages.id`

---

## 索引建议

### 高频查询索引

```sql
-- 用户查询索引
CREATE INDEX idx_user_info_account_status ON user_info(account_status);
CREATE INDEX idx_user_info_machine_review_status ON user_info(machine_review_status);
CREATE INDEX idx_user_info_ideal_partner_avatar ON user_info(ideal_partner_avatar);

-- 第三方绑定索引
CREATE INDEX idx_user_binding_user_id ON user_binding(user_id);
CREATE INDEX idx_user_binding_type_id ON user_binding(binding_type, third_party_id);
CREATE INDEX idx_user_binding_third_party_id ON user_binding(third_party_id);

-- 用户档案索引
CREATE INDEX idx_user_profile_user_id ON user_profile(user_id);
CREATE INDEX idx_user_profile_gender_age ON user_profile(gender, age);
CREATE INDEX idx_user_profile_location ON user_profile(location_province, location_city);

-- 推荐系统索引
CREATE INDEX idx_recommendations_user_id ON recommendations(user_id, status);
CREATE INDEX idx_user_likes_user_target ON user_likes(user_id, target_user_id);
CREATE INDEX idx_user_matches_users ON user_matches(user1_id, user2_id, status);

-- 消息系统索引
CREATE INDEX idx_messages_conversation ON messages(conversation_id, send_time);
CREATE INDEX idx_messages_sender_receiver ON messages(sender_id, receiver_id);

-- 动态内容索引
CREATE INDEX idx_posts_user_time ON posts(user_id, created_at);
CREATE INDEX idx_posts_status_time ON posts(status, created_at);
CREATE INDEX idx_post_likes_post_user ON post_likes(post_id, user_id);

-- 订单索引
CREATE INDEX idx_orders_user_status ON orders(user_id, order_status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status, created_at);
```

---

## 数据库设计原则

### 1. 命名规范
- 表名使用下划线分隔的小写英文
- 字段名使用下划线分隔的小写英文
- 主键统一命名为 `id`
- 外键字段统一以 `_id` 结尾
- 时间字段统一以 `_at` 或 `_time` 结尾

### 2. 数据类型规范
- 主键使用 `bigint` 类型
- 字符串类型优先使用 `varchar`，长文本使用 `text`
- 金额使用 `decimal(10,2)` 类型
- 时间使用 `timestamp` 类型
- 布尔值使用 `boolean` 类型

### 3. 字段设计原则
- 每个表都包含 `created_at` 和 `updated_at` 字段
- 重要业务表包含 `status` 状态字段
- 计数类字段默认值设为 0
- 布尔类字段明确默认值

### 4. 扩展性考虑
- 预留 JSON 类型字段存储扩展属性
- 使用枚举值时预留扩展空间
- 重要配置信息使用配置表而非硬编码

---

## 重构说明

### 主要变更

1. **用户表重构**
   - 将 `app_user` 表重构为 `user_info` 表
   - 简化字段，保留核心用户信息
   - 添加 `location_code`、`location_name`、`last_login_time`、`machine_review_status`、`account_status`、`activefootprints` 字段

2. **用户档案表优化**
   - 保留现有所有字段
   - `education` → `degree`
   - `income` → `income_range`
   - `relationship_status` 从 `integer` 改为 `varchar`
   - 移除 `avatar_url`、`registration_ip`、`looking_for`
   - 新增 `birth_date`、`gender`、`update_time`、`location_province`、`location_city`、`interests`

3. **数据一致性**
   - 所有外键关联更新为 `user_info.id`
   - 保持其他表结构不变，确保系统兼容性

---

## 总结

本重构后的数据库schema设计保持了Amoure约会应用的所有核心功能，同时简化了用户信息表结构，优化了用户档案表字段。设计遵循了数据库设计的最佳实践，具备良好的扩展性和维护性，能够支撑应用的长期发展需求。