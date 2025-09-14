-- ===============================================
-- AMOURE BACKEND SCHEMA V2 - COMPLETE
-- ===============================================
-- Generated from: Amoure_Backend_Data_Schema_V2.md
-- Creation date: 2025-01-07
-- Database: PostgreSQL
-- Version: V2.0 (Complete Implementation)
-- ===============================================

-- ===============================================
-- 1. 用户基础信息表
-- ===============================================

-- 1.1 用户基本信息表
CREATE TABLE user_info (
    id BIGSERIAL PRIMARY KEY,
    location_code VARCHAR(32),
    location_name VARCHAR(64),
    last_login_time TIMESTAMP,
    machine_review_status VARCHAR(32) NOT NULL DEFAULT 'UNVERIFIED',
    reject_reasons TEXT,
    account_status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    activefootprints TEXT,
    ideal_partner_avatar VARCHAR(256),
    admin_score INTEGER DEFAULT 0,
    admin_score_updated_at TIMESTAMP,
    admin_score_updated_by BIGINT,
    create_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE user_info IS '用户基本信息表';
COMMENT ON COLUMN user_info.id IS '用户ID，主键';
COMMENT ON COLUMN user_info.location_code IS '地区编码';
COMMENT ON COLUMN user_info.location_name IS '地区名称';
COMMENT ON COLUMN user_info.last_login_time IS '最后登录时间';
COMMENT ON COLUMN user_info.machine_review_status IS '机审状态(UNVERIFIED/APPROVED/REJECTED)';
COMMENT ON COLUMN user_info.reject_reasons IS '机审驳回原因';
COMMENT ON COLUMN user_info.account_status IS '账号状态(ACTIVE/BLOCKED/DELETED)';
COMMENT ON COLUMN user_info.activefootprints IS '活跃足迹';
COMMENT ON COLUMN user_info.ideal_partner_avatar IS '理想伴侣头像URL';
COMMENT ON COLUMN user_info.admin_score IS '管理员评分（0-100分）';
COMMENT ON COLUMN user_info.admin_score_updated_at IS '管理员评分更新时间';
COMMENT ON COLUMN user_info.admin_score_updated_by IS '管理员评分更新者ID';

-- 1.2 用户档案信息表
CREATE TABLE user_profile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    username VARCHAR(50),
    password VARCHAR(100),
    height INTEGER,
    weight INTEGER,
    age INTEGER,
    degree VARCHAR(50),
    occupation VARCHAR(64),
    income_range VARCHAR(32),
    relationship_status JSON,
    has_children SMALLINT DEFAULT 0,
    want_children SMALLINT DEFAULT 0,
    smoking_habit VARCHAR(32),
    drinking_habit VARCHAR(32),
    religion VARCHAR(32),
    hobbies JSON,
    self_introduction TEXT,
    qa_answers JSON,
    location_code VARCHAR(64),
    location_name VARCHAR(128),
    hometown VARCHAR(128),
    location_flexibility JSON,
    birth_date DATE,
    gender VARCHAR(16),
    interests TEXT,
    tags JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_profile_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE user_profile IS '用户档案信息表';
COMMENT ON COLUMN user_profile.user_id IS '用户ID，外键关联user_info.id';
COMMENT ON COLUMN user_profile.relationship_status IS '关系状态（JSON格式）';
COMMENT ON COLUMN user_profile.has_children IS '是否有孩子：0-无，1-有';
COMMENT ON COLUMN user_profile.want_children IS '是否想要孩子：0-不要，1-想要';
COMMENT ON COLUMN user_profile.qa_answers IS '问答答案（JSON格式）';
COMMENT ON COLUMN user_profile.location_flexibility IS '位置灵活性（JSON格式）';
COMMENT ON COLUMN user_profile.tags IS '用户标签（JSON格式）';

-- 1.3 用户照片表
CREATE TABLE user_photos (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    photo_url VARCHAR(200) NOT NULL,
    photo_type VARCHAR(32) DEFAULT 'ALBUM',
    post_id BIGINT,
    sort_order INTEGER DEFAULT 0,
    status INTEGER DEFAULT 1,
    review_status VARCHAR(32) DEFAULT 'IN_REVIEW',
    reject_reason TEXT,
    retry_count INTEGER DEFAULT 0,
    last_retry_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_photos_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_photos_post_id FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE SET NULL
);

COMMENT ON TABLE user_photos IS '用户照片表';
COMMENT ON COLUMN user_photos.photo_type IS '照片类型：ALBUM-相册照片，AVATAR-头像，POST-动态照片，IDEAL_PARTNER-理想伴侣照片';
COMMENT ON COLUMN user_photos.review_status IS '审核状态：IN_REVIEW, APPROVED, REJECTED';
COMMENT ON COLUMN user_photos.retry_count IS 'AI审核失败重试次数';

-- ===============================================
-- 2. 认证与绑定表
-- ===============================================

-- 2.1 用户第三方绑定表
CREATE TABLE user_binding (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    binding_type VARCHAR(32) NOT NULL,
    third_party_id VARCHAR(100) NOT NULL,
    third_party_nickname VARCHAR(100),
    access_token TEXT,
    refresh_token TEXT,
    expires_at TIMESTAMP,
    bind_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status INTEGER DEFAULT 1,
    
    CONSTRAINT fk_user_binding_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT uk_user_binding_type_id UNIQUE(binding_type, third_party_id)
);

COMMENT ON TABLE user_binding IS '用户第三方绑定表';
COMMENT ON COLUMN user_binding.binding_type IS '绑定类型：WECHAT/APPLE/GOOGLE/EMAIL/PHONE';
COMMENT ON COLUMN user_binding.third_party_id IS '第三方平台用户ID或邮箱/手机号';
COMMENT ON COLUMN user_binding.status IS '绑定状态：1-正常，0-解绑';

-- 2.2 用户验证表
CREATE TABLE user_verification (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    verification_type VARCHAR(32) NOT NULL,
    verification_data TEXT,
    verification_description VARCHAR(255),
    review_status VARCHAR(32) DEFAULT 'IN_REVIEW',
    trust_score INTEGER DEFAULT 0,
    reviewer_id BIGINT,
    review_comment TEXT,
    submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP,
    
    CONSTRAINT fk_user_verification_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE user_verification IS '用户验证表';
COMMENT ON COLUMN user_verification.verification_type IS '验证类型：IDENTITY/REALPERSON/SCHOOL/COMPANY/INCOME';
COMMENT ON COLUMN user_verification.verification_description IS '公司或者学校名称';
COMMENT ON COLUMN user_verification.review_status IS '验证状态：IN_REVIEW/APPROVED/REJECTED';
COMMENT ON COLUMN user_verification.trust_score IS '信任分数，认证通过后的信任值';

-- ===============================================
-- 3. 推荐与匹配表
-- ===============================================

-- 3.1 用户偏好设置表
CREATE TABLE user_preferences (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    preferred_gender INTEGER,
    age_min INTEGER DEFAULT 18,
    age_max INTEGER DEFAULT 60,
    distance_max INTEGER DEFAULT 50,
    education_min INTEGER,
    income_min VARCHAR(50),
    height_min INTEGER,
    height_max INTEGER,
    interests_preference TEXT,
    relocation_preference VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_preferences_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE user_preferences IS '用户偏好设置表';
COMMENT ON COLUMN user_preferences.preferred_gender IS '偏好性别：1-男，2-女，3-不限';
COMMENT ON COLUMN user_preferences.distance_max IS '最大距离偏好（公里）';

-- 3.2 推荐记录表
CREATE TABLE recommendations (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    recommended_user_id BIGINT NOT NULL,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_recommendations_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_recommendations_recommended_user_id FOREIGN KEY (recommended_user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE recommendations IS '推荐记录表';
COMMENT ON COLUMN recommendations.status IS '推荐状态：1-活跃，0-失效';

-- ===============================================
-- 4. 互动与匹配表
-- ===============================================

-- 4.1 用户点赞表
CREATE TABLE user_likes (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    target_user_id BIGINT NOT NULL,
    like_type INTEGER DEFAULT 1,
    is_mutual BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_likes_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_likes_target_user_id FOREIGN KEY (target_user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT uk_user_likes_user_target UNIQUE(user_id, target_user_id)
);

COMMENT ON TABLE user_likes IS '用户点赞表';
COMMENT ON COLUMN user_likes.like_type IS '点赞类型：1-喜欢，2-超级喜欢';
COMMENT ON COLUMN user_likes.is_mutual IS '是否相互喜欢';

-- 4.2 用户匹配表
CREATE TABLE user_matches (
    id BIGSERIAL PRIMARY KEY,
    user1_id BIGINT NOT NULL,
    user2_id BIGINT NOT NULL,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_matches_user1_id FOREIGN KEY (user1_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_matches_user2_id FOREIGN KEY (user2_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT uk_user_matches_users UNIQUE(user1_id, user2_id)
);

COMMENT ON TABLE user_matches IS '用户匹配表';
COMMENT ON COLUMN user_matches.status IS '匹配状态：1-匹配成功，2-聊天中，3-已结束';

-- 4.3 用户屏蔽表
CREATE TABLE user_blocks (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    blocked_user_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_blocks_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_blocks_blocked_user_id FOREIGN KEY (blocked_user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT uk_user_blocks_user_blocked UNIQUE(user_id, blocked_user_id)
);

COMMENT ON TABLE user_blocks IS '用户屏蔽表';

-- ===============================================
-- 5. 消息与IM表
-- ===============================================

-- 5.1 IM用户配置表
CREATE TABLE im_user_profile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    im_user_id VARCHAR(100) NOT NULL,
    im_nickname VARCHAR(100),
    im_avatar VARCHAR(200),
    im_signature VARCHAR(200),
    online_status INTEGER DEFAULT 1,
    last_seen TIMESTAMP,
    push_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_im_user_profile_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT uk_im_user_profile_im_user_id UNIQUE(im_user_id)
);

COMMENT ON TABLE im_user_profile IS 'IM用户配置表';
COMMENT ON COLUMN im_user_profile.online_status IS '在线状态：1-在线，2-离线，3-忙碌';

-- 5.2 会话表
CREATE TABLE message_conversations (
    id BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL UNIQUE,
    user1_id BIGINT NOT NULL,
    user2_id BIGINT NOT NULL,
    conversation_type INTEGER DEFAULT 1,
    last_message_id BIGINT,
    last_message_time TIMESTAMP,
    unread_count_user1 INTEGER DEFAULT 0,
    unread_count_user2 INTEGER DEFAULT 0,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_message_conversations_user1_id FOREIGN KEY (user1_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_conversations_user2_id FOREIGN KEY (user2_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE message_conversations IS '会话表';
COMMENT ON COLUMN message_conversations.conversation_type IS '会话类型：1-普通会话，2-群聊';
COMMENT ON COLUMN message_conversations.status IS '会话状态：1-正常，2-已删除';

-- 5.3 消息表
CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    sender_id BIGINT NOT NULL,
    receiver_id BIGINT NOT NULL,
    message_type INTEGER DEFAULT 1,
    content TEXT,
    media_url VARCHAR(200),
    message_status INTEGER DEFAULT 1,
    is_recalled BOOLEAN DEFAULT false,
    send_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_time TIMESTAMP,
    read_time TIMESTAMP,
    
    CONSTRAINT fk_messages_sender_id FOREIGN KEY (sender_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_messages_receiver_id FOREIGN KEY (receiver_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE messages IS '消息表';
COMMENT ON COLUMN messages.message_type IS '消息类型：1-文本，2-图片，3-语音，4-视频，5-表情包';
COMMENT ON COLUMN messages.message_status IS '消息状态：1-已发送，2-已送达，3-已读';
COMMENT ON COLUMN messages.is_recalled IS '是否已撤回';

-- ===============================================
-- 6. 动态内容表
-- ===============================================

-- 6.1 动态帖子表
CREATE TABLE posts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    content TEXT,
    media_urls TEXT,
    post_type INTEGER DEFAULT 1,
    visibility INTEGER DEFAULT 1,
    location VARCHAR(100),
    tags TEXT,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    status VARCHAR(32) DEFAULT 'ACTIVE',
    review_status VARCHAR(32) DEFAULT 'IN_REVIEW',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_posts_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE posts IS '动态帖子表';
COMMENT ON COLUMN posts.post_type IS '帖子类型：1-普通动态，2-图片动态，3-视频动态';
COMMENT ON COLUMN posts.visibility IS '可见性：1-公开，2-仅匹配用户，3-私密';
COMMENT ON COLUMN posts.status IS '帖子状态：ACTIVE-正常，DELETED-已删除，HIDDEN-已隐藏';
COMMENT ON COLUMN posts.review_status IS '审核状态：IN_REVIEW/APPROVED/REJECTED';

-- 6.2 帖子点赞表
CREATE TABLE post_likes (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    like_type INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_post_likes_post_id FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    CONSTRAINT fk_post_likes_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT uk_post_likes_post_user UNIQUE(post_id, user_id)
);

COMMENT ON TABLE post_likes IS '帖子点赞表';
COMMENT ON COLUMN post_likes.like_type IS '点赞类型：1-普通点赞';

-- 6.3 帖子评论表
CREATE TABLE post_comments (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    content TEXT NOT NULL,
    parent_id BIGINT,
    like_count INTEGER DEFAULT 0,
    review_status VARCHAR(32) DEFAULT 'IN_REVIEW',
    deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_post_comments_post_id FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    CONSTRAINT fk_post_comments_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_post_comments_parent_id FOREIGN KEY (parent_id) REFERENCES post_comments(id) ON DELETE CASCADE
);

COMMENT ON TABLE post_comments IS '帖子评论表';
COMMENT ON COLUMN post_comments.parent_id IS '父评论ID，支持回复功能';
COMMENT ON COLUMN post_comments.review_status IS '审核状态：IN_REVIEW/APPROVED/REJECTED';

-- ===============================================
-- 7. VIP与订单表
-- ===============================================

-- 7.1 VIP套餐表
CREATE TABLE vip_packages (
    id BIGSERIAL PRIMARY KEY,
    package_name VARCHAR(50) NOT NULL,
    package_type INTEGER NOT NULL,
    duration_days INTEGER NOT NULL,
    original_price DECIMAL(10,2) NOT NULL,
    sale_price DECIMAL(10,2) NOT NULL,
    features TEXT,
    description TEXT,
    is_popular BOOLEAN DEFAULT false,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE vip_packages IS 'VIP套餐表';
COMMENT ON COLUMN vip_packages.package_type IS '套餐类型：1-基础版，2-标准版，3-高级版';
COMMENT ON COLUMN vip_packages.features IS '套餐功能列表（JSON格式）';
COMMENT ON COLUMN vip_packages.is_popular IS '是否为热门套餐';
COMMENT ON COLUMN vip_packages.status IS '套餐状态：1-有效，0-停用';

-- 7.2 用户VIP信息表
CREATE TABLE user_vip (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    vip_level INTEGER DEFAULT 0,
    package_id BIGINT,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    remaining_features TEXT,
    auto_renew BOOLEAN DEFAULT false,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_vip_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_vip_package_id FOREIGN KEY (package_id) REFERENCES vip_packages(id) ON DELETE SET NULL
);

COMMENT ON TABLE user_vip IS '用户VIP信息表';
COMMENT ON COLUMN user_vip.vip_level IS 'VIP等级：0-普通用户，1-基础VIP，2-标准VIP，3-高级VIP';
COMMENT ON COLUMN user_vip.remaining_features IS '剩余功能使用次数（JSON格式）';
COMMENT ON COLUMN user_vip.auto_renew IS '是否自动续费';

-- 7.3 订单表
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    order_no VARCHAR(32) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    package_id BIGINT NOT NULL,
    order_type INTEGER DEFAULT 1,
    original_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    final_amount DECIMAL(10,2) NOT NULL,
    payment_method INTEGER,
    payment_status INTEGER DEFAULT 0,
    transaction_id VARCHAR(100),
    order_status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP,
    completed_at TIMESTAMP,
    
    CONSTRAINT fk_orders_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_orders_package_id FOREIGN KEY (package_id) REFERENCES vip_packages(id) ON DELETE RESTRICT
);

COMMENT ON TABLE orders IS '订单表';
COMMENT ON COLUMN orders.order_type IS '订单类型：1-VIP购买，2-功能购买';
COMMENT ON COLUMN orders.payment_method IS '支付方式：1-微信，2-支付宝，3-Apple Pay';
COMMENT ON COLUMN orders.payment_status IS '支付状态：0-待支付，1-已支付，2-支付失败，3-已退款';
COMMENT ON COLUMN orders.order_status IS '订单状态：1-待支付，2-已完成，3-已取消，4-已退款';

-- 7.4 支付记录表
CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    payment_method INTEGER NOT NULL,
    payment_channel VARCHAR(32) NOT NULL,
    transaction_id VARCHAR(100),
    third_party_transaction_id VARCHAR(100),
    payment_amount DECIMAL(10,2) NOT NULL,
    payment_status INTEGER DEFAULT 0,
    payment_time TIMESTAMP,
    callback_data TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_payments_order_id FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

COMMENT ON TABLE payments IS '支付记录表';
COMMENT ON COLUMN payments.payment_channel IS '支付渠道：WECHAT/ALIPAY/APPLE_PAY';
COMMENT ON COLUMN payments.payment_status IS '支付状态：0-待支付，1-支付成功，2-支付失败';
COMMENT ON COLUMN payments.callback_data IS '第三方支付回调数据';

-- ===============================================
-- 8. 客服与工单表
-- ===============================================

-- 8.1 工单表
CREATE TABLE work_orders (
    id BIGSERIAL PRIMARY KEY,
    order_number VARCHAR(32) NOT NULL UNIQUE,
    order_type VARCHAR(32) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(32) DEFAULT 'OPEN',
    priority VARCHAR(16) DEFAULT 'NORMAL',
    creator_id BIGINT NOT NULL,
    assignee_id BIGINT,
    related_business_id BIGINT,
    related_business_type VARCHAR(32),
    metadata TEXT,
    resolution TEXT,
    due_date TIMESTAMP,
    started_at TIMESTAMP,
    resolved_at TIMESTAMP,
    reporter_ip VARCHAR(45),
    deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_work_orders_creator_id FOREIGN KEY (creator_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE work_orders IS '工单表';
COMMENT ON COLUMN work_orders.order_type IS '工单类型：REPORT/VERIFICATION/SUGGESTION/APP_ISSUE/USAGE_HELP/COMPLAINT/SYSTEM_ERROR/APPEAL/OTHER';
COMMENT ON COLUMN work_orders.status IS '工单状态：OPEN/IN_PROGRESS/PENDING_INFO/RESOLVED/CLOSED/CANCELLED';
COMMENT ON COLUMN work_orders.priority IS '优先级：NORMAL/URGENT/CRITICAL';
COMMENT ON COLUMN work_orders.related_business_type IS '关联业务类型：REPORT/VERIFICATION/USER_CREATED';

-- 8.2 帮助分类表
CREATE TABLE help_categories (
    id BIGSERIAL PRIMARY KEY,
    parent_id BIGINT,
    category_name VARCHAR(100) NOT NULL,
    category_icon VARCHAR(200),
    sort_order INTEGER DEFAULT 0,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_help_categories_parent_id FOREIGN KEY (parent_id) REFERENCES help_categories(id) ON DELETE SET NULL
);

COMMENT ON TABLE help_categories IS '帮助分类表';
COMMENT ON COLUMN help_categories.status IS '分类状态：1-有效，0-停用';

-- 8.3 帮助文章表
CREATE TABLE help_articles (
    id BIGSERIAL PRIMARY KEY,
    category_id BIGINT NOT NULL,
    title VARCHAR(200) NOT NULL,
    summary VARCHAR(500),
    content TEXT NOT NULL,
    author_id BIGINT,
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    is_featured BOOLEAN DEFAULT false,
    status INTEGER DEFAULT 1,
    published_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_help_articles_category_id FOREIGN KEY (category_id) REFERENCES help_categories(id) ON DELETE CASCADE
);

COMMENT ON TABLE help_articles IS '帮助文章表';
COMMENT ON COLUMN help_articles.status IS '文章状态：1-发布，2-草稿，3-下线';

-- ===============================================
-- 9. 举报与审核表
-- ===============================================

-- 9.1 举报表
CREATE TABLE reports (
    id BIGSERIAL PRIMARY KEY,
    reporter_id BIGINT NOT NULL,
    reported_user_id BIGINT,
    report_type VARCHAR(20) DEFAULT 'USER',
    target_id BIGINT NOT NULL,
    reason VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'PENDING',
    reviewer_id BIGINT,
    review_note TEXT,
    reviewed_at TIMESTAMP,
    reporter_ip VARCHAR(45),
    deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_reports_reporter_id FOREIGN KEY (reporter_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_reports_reported_user_id FOREIGN KEY (reported_user_id) REFERENCES user_info(id) ON DELETE SET NULL,
    CONSTRAINT fk_reports_target_id FOREIGN KEY (target_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE reports IS '举报表';
COMMENT ON COLUMN reports.report_type IS '举报类型：USER-用户举报，POST-帖子举报';
COMMENT ON COLUMN reports.target_id IS '目标ID (用户ID或帖子ID，根据report_type确定)';
COMMENT ON COLUMN reports.reason IS '举报原因枚举值';
COMMENT ON COLUMN reports.status IS '举报状态：PENDING-待处理，APPROVED-已通过，REJECTED-已驳回';

-- ===============================================
-- 10. 问题选项表
-- ===============================================

-- 10.1 问题选项表
CREATE TABLE question_options (
    id BIGSERIAL PRIMARY KEY,
    question_key VARCHAR(64) NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    options_data JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uk_question_options_key_version UNIQUE(question_key, version)
);

COMMENT ON TABLE question_options IS '问题选项表';
COMMENT ON COLUMN question_options.question_key IS '问题键值，用于标识不同问题';
COMMENT ON COLUMN question_options.version IS '版本号，支持选项更新';
COMMENT ON COLUMN question_options.options_data IS '选项数据（多语言JSON格式）';

-- ===============================================
-- 11. 系统配置表
-- ===============================================

-- 11.1 系统配置表
CREATE TABLE system_config (
    id BIGSERIAL PRIMARY KEY,
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    config_type VARCHAR(50) DEFAULT 'string',
    description VARCHAR(500),
    is_encrypted BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_config IS '系统配置表';
COMMENT ON COLUMN system_config.config_type IS '配置类型：string/integer/boolean/json';
COMMENT ON COLUMN system_config.is_encrypted IS '是否加密存储';

-- 11.2 管理员用户表
CREATE TABLE admin_users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    real_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    role_id BIGINT NOT NULL,
    status INTEGER DEFAULT 1,
    last_login_time TIMESTAMP,
    last_login_ip VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_admin_users_role_id FOREIGN KEY (role_id) REFERENCES admin_roles(id) ON DELETE RESTRICT
);

COMMENT ON TABLE admin_users IS '管理员用户表';
COMMENT ON COLUMN admin_users.status IS '管理员状态：1-正常，0-停用';

-- 11.3 管理员角色表
CREATE TABLE admin_roles (
    id BIGSERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL,
    role_code VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(200),
    permissions TEXT,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE admin_roles IS '管理员角色表';
COMMENT ON COLUMN admin_roles.permissions IS '权限列表（JSON格式）';

-- ===============================================
-- 12. 统计与日志表
-- ===============================================

-- 12.1 用户访问记录表
CREATE TABLE user_views (
    id BIGSERIAL PRIMARY KEY,
    viewer_id BIGINT NOT NULL,
    viewed_user_id BIGINT NOT NULL,
    view_type INTEGER DEFAULT 1,
    view_source VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_user_views_viewer_id FOREIGN KEY (viewer_id) REFERENCES user_info(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_views_viewed_user_id FOREIGN KEY (viewed_user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE user_views IS '用户访问记录表';
COMMENT ON COLUMN user_views.view_type IS '访问类型：1-普通查看，2-推荐页查看';
COMMENT ON COLUMN user_views.view_source IS '访问来源：推荐页/搜索/动态等';

-- 12.2 登录日志表
CREATE TABLE login_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    login_type INTEGER NOT NULL,
    login_ip VARCHAR(45),
    login_device VARCHAR(100),
    login_location VARCHAR(100),
    login_status INTEGER DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_login_logs_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE login_logs IS '用户登录日志表';
COMMENT ON COLUMN login_logs.login_type IS '登录类型：1-密码，2-短信，3-微信，4-Apple';
COMMENT ON COLUMN login_logs.login_status IS '登录状态：1-成功，2-失败';

-- 12.3 系统通知表
CREATE TABLE system_notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    notification_type VARCHAR(32) NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    related_id BIGINT,
    related_type VARCHAR(32),
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_system_notifications_user_id FOREIGN KEY (user_id) REFERENCES user_info(id) ON DELETE CASCADE
);

COMMENT ON TABLE system_notifications IS '系统通知表';
COMMENT ON COLUMN system_notifications.notification_type IS '通知类型：AUDIT/MATCH/MESSAGE/SYSTEM';
COMMENT ON COLUMN system_notifications.related_type IS '关联对象类型：USER/POST/ORDER等';

-- ===============================================
-- 13. 内容审核表
-- ===============================================

-- 13.1 内容过滤规则表
CREATE TABLE im_content_filter_rules (
    id BIGSERIAL PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    rule_type INTEGER NOT NULL,
    keywords TEXT,
    pattern_regex TEXT,
    action_type INTEGER DEFAULT 1,
    severity_level INTEGER DEFAULT 1,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE im_content_filter_rules IS '内容过滤规则表';
COMMENT ON COLUMN im_content_filter_rules.rule_type IS '规则类型：1-关键词，2-正则表达式';
COMMENT ON COLUMN im_content_filter_rules.action_type IS '处理动作：1-警告，2-拦截，3-审核';

-- ===============================================
-- 索引创建
-- ===============================================

-- 用户基础信息索引
CREATE INDEX idx_user_info_account_status ON user_info(account_status);
CREATE INDEX idx_user_info_machine_review_status ON user_info(machine_review_status);
CREATE INDEX idx_user_info_admin_score ON user_info(admin_score);
CREATE INDEX idx_user_info_last_login_time ON user_info(last_login_time);

-- 用户档案索引
CREATE INDEX idx_user_profile_user_id ON user_profile(user_id);
CREATE INDEX idx_user_profile_gender_age ON user_profile(gender, age);
CREATE INDEX idx_user_profile_location ON user_profile(location_code);

-- 第三方绑定索引
CREATE INDEX idx_user_binding_user_id ON user_binding(user_id);
CREATE INDEX idx_user_binding_type_id ON user_binding(binding_type, third_party_id);
CREATE INDEX idx_user_binding_third_party_id ON user_binding(third_party_id);

-- 用户照片索引
CREATE INDEX idx_user_photos_user_id ON user_photos(user_id);
CREATE INDEX idx_user_photos_review_status ON user_photos(review_status);
CREATE INDEX idx_user_photos_type ON user_photos(photo_type);

-- 认证系统索引
CREATE INDEX idx_user_verification_user_id ON user_verification(user_id);
CREATE INDEX idx_user_verification_type_status ON user_verification(verification_type, review_status);

-- 推荐系统索引
CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX idx_recommendations_user_id ON recommendations(user_id, status);
CREATE INDEX idx_user_likes_user_target ON user_likes(user_id, target_user_id);
CREATE INDEX idx_user_likes_target_user ON user_likes(target_user_id, user_id);
CREATE INDEX idx_user_matches_users ON user_matches(user1_id, user2_id, status);
CREATE INDEX idx_user_blocks_user_blocked ON user_blocks(user_id, blocked_user_id);

-- 消息系统索引
CREATE INDEX idx_im_user_profile_user_id ON im_user_profile(user_id);
CREATE INDEX idx_im_user_profile_im_user_id ON im_user_profile(im_user_id);
CREATE INDEX idx_message_conversations_users ON message_conversations(user1_id, user2_id);
CREATE INDEX idx_message_conversations_id ON message_conversations(conversation_id);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, send_time);
CREATE INDEX idx_messages_sender_receiver ON messages(sender_id, receiver_id);

-- 动态内容索引
CREATE INDEX idx_posts_user_time ON posts(user_id, created_at);
CREATE INDEX idx_posts_review_status ON posts(review_status, created_at);
CREATE INDEX idx_posts_status ON posts(status, created_at);
CREATE INDEX idx_post_likes_post_user ON post_likes(post_id, user_id);
CREATE INDEX idx_post_comments_post_id ON post_comments(post_id, created_at);
CREATE INDEX idx_post_comments_user_id ON post_comments(user_id);
CREATE INDEX idx_post_comments_parent_id ON post_comments(parent_id);

-- VIP和订单索引
CREATE INDEX idx_vip_packages_status ON vip_packages(status, package_type);
CREATE INDEX idx_user_vip_user_id ON user_vip(user_id, status, end_time);
CREATE INDEX idx_orders_user_status ON orders(user_id, order_status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status, created_at);
CREATE INDEX idx_orders_order_no ON orders(order_no);
CREATE INDEX idx_payments_order_id ON payments(order_id, payment_status);
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);

-- 工单系统索引
CREATE INDEX idx_work_orders_status_priority ON work_orders(status, priority, created_at);
CREATE INDEX idx_work_orders_assignee ON work_orders(assignee_id, status);
CREATE INDEX idx_work_orders_creator ON work_orders(creator_id, created_at);
CREATE INDEX idx_work_orders_business ON work_orders(related_business_type, related_business_id);
CREATE INDEX idx_work_orders_due_date ON work_orders(due_date, status);
CREATE INDEX idx_help_categories_parent ON help_categories(parent_id, sort_order);
CREATE INDEX idx_help_articles_category ON help_articles(category_id, status, sort_order);

-- 举报系统索引
CREATE INDEX idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX idx_reports_target ON reports(report_type, target_id);
CREATE INDEX idx_reports_status ON reports(status, created_at);

-- 问题选项索引
CREATE INDEX idx_question_options_key_version ON question_options(question_key, version);
CREATE INDEX idx_question_options_key ON question_options(question_key);

-- 系统配置索引
CREATE INDEX idx_system_config_key ON system_config(config_key);
CREATE INDEX idx_admin_users_username ON admin_users(username);
CREATE INDEX idx_admin_roles_code ON admin_roles(role_code);

-- 日志和统计索引
CREATE INDEX idx_user_views_viewer ON user_views(viewer_id, created_at);
CREATE INDEX idx_user_views_viewed ON user_views(viewed_user_id, created_at);
CREATE INDEX idx_login_logs_user_time ON login_logs(user_id, created_at);
CREATE INDEX idx_system_notifications_user ON system_notifications(user_id, is_read, created_at);

-- ===============================================
-- 触发器：自动更新时间戳
-- ===============================================

-- 创建通用的更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表添加更新时间戳触发器
CREATE TRIGGER update_user_info_updated_at BEFORE UPDATE ON user_info 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profile_updated_at BEFORE UPDATE ON user_profile 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_photos_updated_at BEFORE UPDATE ON user_photos 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_im_user_profile_updated_at BEFORE UPDATE ON im_user_profile 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_message_conversations_updated_at BEFORE UPDATE ON message_conversations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_post_comments_updated_at BEFORE UPDATE ON post_comments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_post_likes_updated_at BEFORE UPDATE ON post_likes 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vip_packages_updated_at BEFORE UPDATE ON vip_packages 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_vip_updated_at BEFORE UPDATE ON user_vip 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_work_orders_updated_at BEFORE UPDATE ON work_orders 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_help_categories_updated_at BEFORE UPDATE ON help_categories 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_help_articles_updated_at BEFORE UPDATE ON help_articles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_users_updated_at BEFORE UPDATE ON admin_users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_roles_updated_at BEFORE UPDATE ON admin_roles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_question_options_updated_at BEFORE UPDATE ON question_options 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===============================================
-- 初始数据插入
-- ===============================================

-- 管理员角色初始数据
INSERT INTO admin_roles (role_name, role_code, description, permissions, status) VALUES
('超级管理员', 'SUPER_ADMIN', '拥有所有权限的超级管理员', '["*"]', 1),
('系统管理员', 'SYSTEM_ADMIN', '系统管理和配置权限', '["system.*", "user.view", "report.handle"]', 1),
('用户管理员', 'USER_ADMIN', '用户管理和审核权限', '["user.*", "verification.*", "report.handle"]', 1),
('内容管理员', 'CONTENT_ADMIN', '内容审核和管理权限', '["post.*", "photo.*", "content.*"]', 1),
('客服', 'CUSTOMER_SERVICE', '客服和工单处理权限', '["workorder.*", "help.*", "user.view"]', 1);

-- 系统配置初始数据
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES
('app.name', 'Amoure', 'string', '应用名称'),
('app.version', '2.0.0', 'string', '应用版本'),
('registration.enabled', 'true', 'boolean', '是否允许新用户注册'),
('verification.auto_approve.education', 'true', 'boolean', '教育认证是否自动审核'),
('recommendation.batch_size', '15', 'integer', '推荐批次大小'),
('vip.trial_period_days', '7', 'integer', 'VIP试用期天数'),
('payment.timeout_minutes', '30', 'integer', '支付超时时间（分钟）');

-- 帮助分类初始数据
INSERT INTO help_categories (category_name, category_icon, sort_order, status) VALUES
('账号问题', 'account_circle', 1, 1),
('认证问题', 'verified_user', 2, 1),
('推荐匹配', 'favorite', 3, 1),
('聊天消息', 'chat', 4, 1),
('VIP服务', 'star', 5, 1),
('支付订单', 'payment', 6, 1),
('举报申诉', 'report', 7, 1),
('其他问题', 'help', 99, 1);

-- VIP套餐初始数据
INSERT INTO vip_packages (package_name, package_type, duration_days, original_price, sale_price, features, description, is_popular, status) VALUES
('基础VIP', 1, 30, 29.90, 19.90, '["无限点赞", "查看谁赞了我", "优先推荐"]', '一个月基础VIP服务', false, 1),
('标准VIP', 2, 90, 79.90, 59.90, '["无限点赞", "查看谁赞了我", "优先推荐", "超级点赞", "聊天特权"]', '三个月标准VIP服务', true, 1),
('高级VIP', 3, 365, 299.90, 199.90, '["无限点赞", "查看谁赞了我", "优先推荐", "超级点赞", "聊天特权", "专属客服", "高级筛选"]', '一年高级VIP服务', false, 1);

-- ===============================================
-- 数据完整性检查
-- ===============================================

-- 检查表是否创建成功
DO $$
BEGIN
    RAISE NOTICE 'Schema creation completed successfully!';
    RAISE NOTICE 'Total tables created: %', (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE');
    RAISE NOTICE 'Total indexes created: %', (SELECT count(*) FROM pg_indexes WHERE schemaname = 'public');
    RAISE NOTICE 'Total triggers created: %', (SELECT count(*) FROM information_schema.triggers WHERE trigger_schema = 'public');
END $$;