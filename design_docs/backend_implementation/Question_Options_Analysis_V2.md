# Amoure Question Options 分析与设计

## 概述

基于现有数据库表结构分析，整理出需要通过 question_options 表统一管理的所有选项类型。这些选项将支持多语言，并通过数据库视图提供便捷的访问方式。

**新增 QA 问答相关选项**：根据 user_profile.qa_answers 字段的实际使用情况，新增了问答问题类型和地域灵活性相关的选项配置。

---

## 建议的 Question Options 表结构

### question_options (问题选项表)
| 字段名 | 类型 | 长度 | 默认值 | 是否非空 | 主键 | 备注 |
|--------|------|------|--------|----------|------|------|
| id | bigint | - | - | NOT NULL | PK | 选项ID，主键 |
| question_key | varchar | 64 | - | NOT NULL | - | 问题键值 |
| version | integer | - | 1 | NOT NULL | - | 版本号 |
| options_data | json | - | - | NOT NULL | - | 选项数据（多语言JSON格式） |
| created_at | timestamp | - | CURRENT_TIMESTAMP | NOT NULL | - | 创建时间 |
| updated_at | timestamp | - | CURRENT_TIMESTAMP | NOT NULL | - | 更新时间 |

### 约束条件
- UNIQUE KEY: (question_key, version)
- INDEX: question_key, version

---

## JSON 数据格式

```json
{
  "options": [
    {
      "value": "option_key",
      "labels": {
        "zh": "中文标签",
        "en": "English Label",
        "ja": "日本語ラベル",
        "ko": "한국어 라벨"
      }
    }
  ]
}
```

---

## 重要的 Question Options 列表

**共计16种选项类型**，涵盖用户基本信息、偏好设置、系统功能和问答系统等各个方面。其中location_flexibility为特殊的复合问题组结构。

### 1. 个人标签 (my_tags)
**用途**: 用户自我标签选择
**表关联**: user_profile.qa_answers, user_profile.interests, user_profile.tags

```json
{
  "options": [
    {"value": "humorous", "labels": {"zh": "幽默风趣", "en": "Humorous", "ja": "ユーモアのある", "ko": "유머러스한"}},
    {"value": "gentle", "labels": {"zh": "温柔体贴", "en": "Gentle", "ja": "優しい", "ko": "따뜻한"}},
    {"value": "independent", "labels": {"zh": "独立自主", "en": "Independent", "ja": "独立した", "ko": "독립적인"}},
    {"value": "sports_lover", "labels": {"zh": "热爱运动", "en": "Sports Lover", "ja": "スポーツ好き", "ko": "운동을 좋아하는"}},
    {"value": "artistic", "labels": {"zh": "文艺青年", "en": "Artistic", "ja": "芸術的", "ko": "예술적인"}},
    {"value": "tech_savvy", "labels": {"zh": "技术达人", "en": "Tech Savvy", "ja": "技術に精通", "ko": "기술에 능숙한"}},
    {"value": "foodie", "labels": {"zh": "美食爱好者", "en": "Foodie", "ja": "グルメ", "ko": "미식가"}},
    {"value": "travel_enthusiast", "labels": {"zh": "旅行达人", "en": "Travel Enthusiast", "ja": "旅行愛好家", "ko": "여행 애호가"}},
    {"value": "music_lover", "labels": {"zh": "音乐发烧友", "en": "Music Lover", "ja": "音楽愛好家", "ko": "음악 애호가"}},
    {"value": "bookworm", "labels": {"zh": "读书控", "en": "Bookworm", "ja": "読書家", "ko": "독서광"}},
    {"value": "sunny", "labels": {"zh": "阳光开朗", "en": "Sunny", "ja": "明るい", "ko": "밝고 명랑한"}},
    {"value": "mature", "labels": {"zh": "成熟稳重", "en": "Mature", "ja": "成熟", "ko": "성숙한"}},
    {"value": "romantic", "labels": {"zh": "浪漫主义", "en": "Romantic", "ja": "ロマンチック", "ko": "로맨틱한"}},
    {"value": "realistic", "labels": {"zh": "现实主义", "en": "Realistic", "ja": "現実的", "ko": "현실적인"}},
    {"value": "responsible", "labels": {"zh": "有责任心", "en": "Responsible", "ja": "責任感がある", "ko": "책임감 있는"}}
  ]
}
```

### 2. 教育程度 (education_level)
**用途**: 学历选择
**表关联**: user_profile.degree, user_preferences.education_min

```json
{
  "options": [
    {"value": "high_school", "labels": {"zh": "高中及以下", "en": "High School or Below", "ja": "高校以下", "ko": "고등학교 이하"}},
    {"value": "associate", "labels": {"zh": "专科", "en": "Associate Degree", "ja": "短大・専門学校", "ko": "전문대학"}},
    {"value": "bachelor", "labels": {"zh": "本科", "en": "Bachelor's Degree", "ja": "大学卒業", "ko": "학사"}},
    {"value": "master", "labels": {"zh": "硕士", "en": "Master's Degree", "ja": "修士", "ko": "석사"}},
    {"value": "doctorate", "labels": {"zh": "博士", "en": "Doctorate", "ja": "博士", "ko": "박사"}},
    {"value": "other", "labels": {"zh": "其他", "en": "Other", "ja": "その他", "ko": "기타"}}
  ]
}
```

### 3. 职业类型 (occupation_type)
**用途**: 职业选择
**表关联**: user_profile.occupation

```json
{
  "options": [
    {"value": "it_tech", "labels": {"zh": "IT/技术", "en": "IT/Technology", "ja": "IT/技術", "ko": "IT/기술"}},
    {"value": "software_engineer", "labels": {"zh": "软件工程师", "en": "Software Engineer", "ja": "ソフトウェアエンジニア", "ko": "소프트웨어 엔지니어"}},
    {"value": "product_manager", "labels": {"zh": "产品经理", "en": "Product Manager", "ja": "プロダクトマネージャー", "ko": "제품 매니저"}},
    {"value": "finance", "labels": {"zh": "金融", "en": "Finance", "ja": "金融", "ko": "금융"}},
    {"value": "investment_banking", "labels": {"zh": "投行", "en": "Investment Banking", "ja": "投資銀行", "ko": "투자은행"}},
    {"value": "consultant", "labels": {"zh": "咨询师", "en": "Consultant", "ja": "コンサルタント", "ko": "컸설턴트"}},
    {"value": "lawyer", "labels": {"zh": "律师", "en": "Lawyer", "ja": "弁護士", "ko": "변호사"}},
    {"value": "doctor", "labels": {"zh": "医生", "en": "Doctor", "ja": "医師", "ko": "의사"}},
    {"value": "education", "labels": {"zh": "教育", "en": "Education", "ja": "教育", "ko": "교육"}},
    {"value": "teacher", "labels": {"zh": "教师", "en": "Teacher", "ja": "教師", "ko": "교사"}},
    {"value": "researcher", "labels": {"zh": "研究员", "en": "Researcher", "ja": "研究者", "ko": "연구원"}},
    {"value": "healthcare", "labels": {"zh": "医疗健康", "en": "Healthcare", "ja": "医療", "ko": "의료"}},
    {"value": "nurse", "labels": {"zh": "护士", "en": "Nurse", "ja": "看護師", "ko": "간호사"}},
    {"value": "media", "labels": {"zh": "传媒/艺术", "en": "Media/Arts", "ja": "メディア/芸術", "ko": "미디어/예술"}},
    {"value": "designer", "labels": {"zh": "设计师", "en": "Designer", "ja": "デザイナー", "ko": "디자이너"}},
    {"value": "photographer", "labels": {"zh": "摄影师", "en": "Photographer", "ja": "写真家", "ko": "사진작가"}},
    {"value": "artist", "labels": {"zh": "艺术家", "en": "Artist", "ja": "アーティスト", "ko": "예술가"}},
    {"value": "business", "labels": {"zh": "商业/销售", "en": "Business/Sales", "ja": "ビジネス/営業", "ko": "비즈니스/영업"}},
    {"value": "marketing", "labels": {"zh": "市场营销", "en": "Marketing", "ja": "マーケティング", "ko": "마케팅"}},
    {"value": "sales", "labels": {"zh": "销售", "en": "Sales", "ja": "販売", "ko": "영업"}},
    {"value": "government", "labels": {"zh": "政府/公共服务", "en": "Government/Public Service", "ja": "政府/公共サービス", "ko": "정부/공공서비스"}},
    {"value": "civil_servant", "labels": {"zh": "公务员", "en": "Civil Servant", "ja": "公務員", "ko": "공무원"}},
    {"value": "entrepreneur", "labels": {"zh": "创业/自由职业", "en": "Entrepreneur/Freelancer", "ja": "起業/フリーランス", "ko": "창업/프리랜서"}},
    {"value": "startup_founder", "labels": {"zh": "创业者", "en": "Startup Founder", "ja": "スタートアップ创業者", "ko": "스타트업 창업자"}},
    {"value": "freelancer", "labels": {"zh": "自由职业者", "en": "Freelancer", "ja": "フリーランサー", "ko": "프리랜서"}},
    {"value": "real_estate", "labels": {"zh": "房地产", "en": "Real Estate", "ja": "不動産", "ko": "부동산"}},
    {"value": "architecture", "labels": {"zh": "建筑师", "en": "Architect", "ja": "建築家", "ko": "건축가"}},
    {"value": "student", "labels": {"zh": "学生", "en": "Student", "ja": "学生", "ko": "학생"}},
    {"value": "retired", "labels": {"zh": "退休", "en": "Retired", "ja": "定年退职", "ko": "은퇴"}},
    {"value": "unemployed", "labels": {"zh": "暂无工作", "en": "Unemployed", "ja": "無職", "ko": "무직"}},
    {"value": "other", "labels": {"zh": "其他", "en": "Other", "ja": "その他", "ko": "기타"}}
  ]
}
```

### 4. 收入范围 (income_range)
**用途**: 收入水平选择
**表关联**: user_profile.income_range, user_preferences.income_min

```json
{
  "options": [
    {"value": "below_100k", "labels": {"zh": "10万以下", "en": "Below ¥100K", "ja": "10万以下", "ko": "10만 이하"}},
    {"value": "100k_200k", "labels": {"zh": "10万-20万", "en": "¥100K-¥200K", "ja": "10万-20万", "ko": "10만-20만"}},
    {"value": "200k_300k", "labels": {"zh": "20万-30万", "en": "¥200K-¥300K", "ja": "20万-30万", "ko": "20만-30만"}},
    {"value": "300k_500k", "labels": {"zh": "30万-50万", "en": "¥300K-¥500K", "ja": "30万-50万", "ko": "30만-50만"}},
    {"value": "above_500k", "labels": {"zh": "50万以上", "en": "Above ¥500K", "ja": "50万以上", "ko": "50만 이상"}}
  ]
}
```

### 5. 关系状态 (relationship_status)
**用途**: 婚姻状况选择
**表关联**: user_profile.relationship_status

```json
{
  "options": [
    {"value": "single", "labels": {"zh": "单身", "en": "Single", "ja": "独身", "ko": "독신"}},
    {"value": "divorced_no_children", "labels": {"zh": "离异无娃", "en": "Divorced (No Children)", "ja": "離婚（子供なし）", "ko": "이혼 (자녀 없음)"}},
    {"value": "widowed", "labels": {"zh": "丧偶", "en": "Widowed", "ja": "未亡人", "ko": "사별"}},
    {"value": "divorced_with_children", "labels": {"zh": "离异带娃", "en": "Divorced (With Children)", "ja": "離婚（子供あり）", "ko": "이혼 (자녀 있음)"}}
  ]
}
```

### 6. 吸烟习惯 (smoking_habit)
**用途**: 吸烟情况选择
**表关联**: user_profile.smoking_habit

```json
{
  "options": [
    {"value": "never", "labels": {"zh": "从不吸烟", "en": "Never"}, "sort_order": 1},
    {"value": "occasionally", "labels": {"zh": "偶尔吸烟", "en": "Occasionally"}, "sort_order": 2},
    {"value": "regularly", "labels": {"zh": "经常吸烟", "en": "Regularly"}, "sort_order": 3},
    {"value": "quit", "labels": {"zh": "已戒烟", "en": "Quit"}, "sort_order": 4}
  ]
}
```

### 7. 饮酒习惯 (drinking_habit)
**用途**: 饮酒情况选择
**表关联**: user_profile.drinking_habit

```json
{
  "options": [
    {"value": "never", "labels": {"zh": "从不饮酒", "en": "Never"}, "sort_order": 1},
    {"value": "socially", "labels": {"zh": "社交饮酒", "en": "Socially"}, "sort_order": 2},
    {"value": "occasionally", "labels": {"zh": "偶尔饮酒", "en": "Occasionally"}, "sort_order": 3},
    {"value": "regularly", "labels": {"zh": "经常饮酒", "en": "Regularly"}, "sort_order": 4}
  ]
}
```

### 8. 宗教信仰 (religion)
**用途**: 宗教信仰选择
**表关联**: user_profile.religion

```json
{
  "options": [
    {"value": "none", "labels": {"zh": "无宗教信仰", "en": "None"}, "sort_order": 1},
    {"value": "christianity", "labels": {"zh": "基督教", "en": "Christianity"}, "sort_order": 2},
    {"value": "buddhism", "labels": {"zh": "佛教", "en": "Buddhism"}, "sort_order": 3},
    {"value": "islam", "labels": {"zh": "伊斯兰教", "en": "Islam"}, "sort_order": 4},
    {"value": "hinduism", "labels": {"zh": "印度教", "en": "Hinduism"}, "sort_order": 5},
    {"value": "judaism", "labels": {"zh": "犹太教", "en": "Judaism"}, "sort_order": 6},
    {"value": "other", "labels": {"zh": "其他", "en": "Other"}, "sort_order": 7},
    {"value": "prefer_not_say", "labels": {"zh": "不愿透露", "en": "Prefer Not to Say"}, "sort_order": 8}
  ]
}
```

### 9. 兴趣爱好 (hobbies)
**用途**: 兴趣爱好选择
**表关联**: user_profile.hobbies, user_profile.interests

```json
{
  "options": [
    {"value": "reading", "labels": {"zh": "阅读", "en": "Reading", "ja": "読書", "ko": "독서"}},
    {"value": "travel", "labels": {"zh": "旅行", "en": "Travel", "ja": "旅行", "ko": "여행"}},
    {"value": "sports", "labels": {"zh": "运动", "en": "Sports", "ja": "スポーツ", "ko": "스포츠"}},
    {"value": "fitness", "labels": {"zh": "健身", "en": "Fitness", "ja": "フィットネス", "ko": "피트니스"}},
    {"value": "gym", "labels": {"zh": "健身房", "en": "Gym", "ja": "ジム", "ko": "헬스장"}},
    {"value": "running", "labels": {"zh": "跑步", "en": "Running", "ja": "ランニング", "ko": "달리기"}},
    {"value": "yoga", "labels": {"zh": "瑕伽", "en": "Yoga", "ja": "ヨガ", "ko": "요가"}},
    {"value": "swimming", "labels": {"zh": "游泳", "en": "Swimming", "ja": "水泳", "ko": "수영"}},
    {"value": "basketball", "labels": {"zh": "篮球", "en": "Basketball", "ja": "バスケットボール", "ko": "농구"}},
    {"value": "football", "labels": {"zh": "足球", "en": "Football/Soccer", "ja": "サッカー", "ko": "축구"}},
    {"value": "tennis", "labels": {"zh": "网球", "en": "Tennis", "ja": "テニス", "ko": "테니스"}},
    {"value": "golf", "labels": {"zh": "高尔夫", "en": "Golf", "ja": "ゴルフ", "ko": "골프"}},
    {"value": "music", "labels": {"zh": "音乐", "en": "Music", "ja": "音楽", "ko": "음악"}},
    {"value": "singing", "labels": {"zh": "唱歌", "en": "Singing", "ja": "歌うこと", "ko": "노래"}},
    {"value": "piano", "labels": {"zh": "钢琴", "en": "Piano", "ja": "ピアノ", "ko": "피아노"}},
    {"value": "guitar", "labels": {"zh": "吉他", "en": "Guitar", "ja": "ギター", "ko": "기타"}},
    {"value": "movies", "labels": {"zh": "电影", "en": "Movies", "ja": "映画", "ko": "영화"}},
    {"value": "tv_shows", "labels": {"zh": "电视剧", "en": "TV Shows", "ja": "テレビ番組", "ko": "TV 쇼"}},
    {"value": "anime", "labels": {"zh": "动漫", "en": "Anime", "ja": "アニメ", "ko": "애니메이션"}},
    {"value": "cooking", "labels": {"zh": "烹饪", "en": "Cooking", "ja": "料理", "ko": "요리"}},
    {"value": "baking", "labels": {"zh": "烘焙", "en": "Baking", "ja": "ベーキング", "ko": "베이킹"}},
    {"value": "food_tasting", "labels": {"zh": "美食探店", "en": "Food Tasting", "ja": "食べ歩き", "ko": "맛집 탐방"}},
    {"value": "photography", "labels": {"zh": "摄影", "en": "Photography", "ja": "写真", "ko": "사진"}},
    {"value": "videography", "labels": {"zh": "摄像", "en": "Videography", "ja": "動画制作", "ko": "영상 촬영"}},
    {"value": "art", "labels": {"zh": "艺术", "en": "Art", "ja": "美術", "ko": "미술"}},
    {"value": "painting", "labels": {"zh": "绘画", "en": "Painting", "ja": "絵画", "ko": "그림"}},
    {"value": "drawing", "labels": {"zh": "素描", "en": "Drawing", "ja": "ドローイング", "ko": "드로잉"}},
    {"value": "crafts", "labels": {"zh": "手工制作", "en": "Crafts", "ja": "ハンドメイド", "ko": "수공예"}},
    {"value": "gaming", "labels": {"zh": "游戏", "en": "Gaming", "ja": "ゲーム", "ko": "게임"}},
    {"value": "board_games", "labels": {"zh": "桌游", "en": "Board Games", "ja": "ボードゲーム", "ko": "보드게임"}},
    {"value": "dancing", "labels": {"zh": "舞蹈", "en": "Dancing", "ja": "ダンス", "ko": "댄스"}},
    {"value": "writing", "labels": {"zh": "写作", "en": "Writing", "ja": "文章執筆", "ko": "글쓰기"}},
    {"value": "blogging", "labels": {"zh": "博客", "en": "Blogging", "ja": "ブログ", "ko": "블로그"}},
    {"value": "gardening", "labels": {"zh": "园艺", "en": "Gardening", "ja": "ガーデニング", "ko": "원예"}},
    {"value": "pets", "labels": {"zh": "养宠物", "en": "Pets", "ja": "ペット", "ko": "반려동물"}},
    {"value": "volunteering", "labels": {"zh": "志愿服务", "en": "Volunteering", "ja": "ボランティア", "ko": "자원봉사"}},
    {"value": "learning_languages", "labels": {"zh": "学习语言", "en": "Learning Languages", "ja": "語学習", "ko": "언어 학습"}},
    {"value": "wine_tasting", "labels": {"zh": "品酒", "en": "Wine Tasting", "ja": "ワインテイスティング", "ko": "와인 시음"}},
    {"value": "shopping", "labels": {"zh": "购物", "en": "Shopping", "ja": "ショッピング", "ko": "쇼핑"}},
    {"value": "fashion", "labels": {"zh": "时尚", "en": "Fashion", "ja": "ファッション", "ko": "패션"}},
    {"value": "investing", "labels": {"zh": "投资理财", "en": "Investing", "ja": "投資", "ko": "투자"}},
    {"value": "cryptocurrency", "labels": {"zh": "加密货币", "en": "Cryptocurrency", "ja": "暗号通貨", "ko": "암호화폐"}},
    {"value": "hiking", "labels": {"zh": "徒步/登山", "en": "Hiking", "ja": "ハイキング", "ko": "하이킹"}},
    {"value": "camping", "labels": {"zh": "露营", "en": "Camping", "ja": "キャンプ", "ko": "캐핑"}},
    {"value": "astronomy", "labels": {"zh": "天文", "en": "Astronomy", "ja": "天文学", "ko": "천문학"}},
    {"value": "karaoke", "labels": {"zh": "K歌", "en": "Karaoke", "ja": "カラオケ", "ko": "노래방"}}
  ]
}
```

### 10. 搬迁偏好 (relocation_preference)
**用途**: 搬迁意愿选择
**表关联**: user_preferences.relocation_preference

```json
{
  "options": [
    {"value": "never", "labels": {"zh": "不愿搬迁", "en": "Never"}, "sort_order": 1},
    {"value": "same_city", "labels": {"zh": "同城内可以", "en": "Within Same City"}, "sort_order": 2},
    {"value": "same_country", "labels": {"zh": "国内可以", "en": "Within Country"}, "sort_order": 3},
    {"value": "anywhere", "labels": {"zh": "任何地方", "en": "Anywhere"}, "sort_order": 4}
  ]
}
```

### 11. 性别偏好 (gender_preference)
**用途**: 性别偏好选择
**表关联**: user_preferences.preferred_gender

```json
{
  "options": [
    {"value": "male", "labels": {"zh": "男性", "en": "Male"}, "sort_order": 1},
    {"value": "female", "labels": {"zh": "女性", "en": "Female"}, "sort_order": 2},
    {"value": "any", "labels": {"zh": "不限", "en": "Any"}, "sort_order": 3}
  ]
}
```

### 12. 举报分类 (report_category)
**用途**: 举报原因分类
**表关联**: reports.report_category

```json
{
  "options": [
    {"value": "spam", "labels": {"zh": "垃圾信息", "en": "Spam"}, "sort_order": 1},
    {"value": "inappropriate", "labels": {"zh": "不当内容", "en": "Inappropriate Content"}, "sort_order": 2},
    {"value": "harassment", "labels": {"zh": "骚扰", "en": "Harassment"}, "sort_order": 3},
    {"value": "fake_info", "labels": {"zh": "虚假信息", "en": "Fake Information"}, "sort_order": 4},
    {"value": "violence", "labels": {"zh": "暴力内容", "en": "Violence"}, "sort_order": 5},
    {"value": "nudity", "labels": {"zh": "色情内容", "en": "Nudity/Sexual Content"}, "sort_order": 6},
    {"value": "other", "labels": {"zh": "其他", "en": "Other"}, "sort_order": 7}
  ]
}
```

### 13. 支付方式 (payment_method)
**用途**: 支付方式选择
**表关联**: orders.payment_method

```json
{
  "options": [
    {"value": "wechat", "labels": {"zh": "微信支付", "en": "WeChat Pay"}, "sort_order": 1},
    {"value": "alipay", "labels": {"zh": "支付宝", "en": "Alipay"}, "sort_order": 2},
    {"value": "apple_pay", "labels": {"zh": "Apple Pay", "en": "Apple Pay"}, "sort_order": 3},
    {"value": "google_pay", "labels": {"zh": "Google Pay", "en": "Google Pay"}, "sort_order": 4},
    {"value": "credit_card", "labels": {"zh": "信用卡", "en": "Credit Card"}, "sort_order": 5}
  ]
}
```

### 14. 工单分类 (work_order_category)
**用途**: 工单分类选择
**表关联**: work_orders.category

```json
{
  "options": [
    {"value": "account", "labels": {"zh": "账号问题", "en": "Account Issues", "ja": "アカウント問題", "ko": "계정 문제"}},
    {"value": "payment", "labels": {"zh": "支付问题", "en": "Payment Issues", "ja": "支払い問題", "ko": "결제 문제"}},
    {"value": "technical", "labels": {"zh": "技术问题", "en": "Technical Issues", "ja": "技術的問題", "ko": "기술적 문제"}},
    {"value": "feedback", "labels": {"zh": "投诉建议", "en": "Feedback & Suggestions", "ja": "フィードバック・提案", "ko": "피드백 및 제안"}},
    {"value": "verification", "labels": {"zh": "认证问题", "en": "Verification Issues", "ja": "認証問題", "ko": "인증 문제"}},
    {"value": "other", "labels": {"zh": "其他", "en": "Other", "ja": "その他", "ko": "기타"}}
  ]
}
```

### 15. 问答问题类型 (qa_questions)
**用途**: 用户档案问答问题
**表关联**: user_profile.qa_answers
**特殊说明**: 此选项为问题组，options_data包含9个开放式问题

```json
{
  "questions": [
    {"value": "self_intro", "labels": {"zh": "自我介绍", "en": "Self Introduction", "ja": "自己紹介", "ko": "자기소개"}},
    {"value": "my_tags", "labels": {"zh": "我的标签", "en": "My Tags", "ja": "私のタグ", "ko": "내 태그"}},
    {"value": "family_background", "labels": {"zh": "家庭背景", "en": "Family Background", "ja": "家族の背景", "ko": "가족 배경"}},
    {"value": "hobbies_interests", "labels": {"zh": "平时喜欢做什么", "en": "What do you like to do in your free time", "ja": "普段何をするのが好きですか", "ko": "평소에 무엇을 하는 것을 좋아하나요"}},
    {"value": "love_view", "labels": {"zh": "我的爱情观", "en": "My View on Love", "ja": "恋愛観", "ko": "나의 연애관"}},
    {"value": "why_single", "labels": {"zh": "我为什么单身", "en": "Why I am Single", "ja": "なぜ独身なのか", "ko": "내가 왜 싱글인지"}},
    {"value": "ideal_partner", "labels": {"zh": "理想的另一半", "en": "My Ideal Partner", "ja": "理想のパートナー", "ko": "이상적인 파트너"}},
    {"value": "bottom_line", "labels": {"zh": "我的底线/不能接受的点", "en": "My Bottom Line", "ja": "私の底線", "ko": "나의 바닥선"}},
    {"value": "lifestyle", "labels": {"zh": "我的生活方式", "en": "My Lifestyle", "ja": "私のライフスタイル", "ko": "나의 라이프스타일"}}
  ]
}
```

### 16. 地域灵活性 (location_flexibility)
**用途**: 地域灵活性相关的三个问题组合
**表关联**: user_profile.location_flexibility
**特殊说明**: 此选项为复合问题组，options_data为map结构而非数组

```json
{
  "questions": {
    "accept_long_distance": {
      "title": {"zh": "是否可以接受短暂异地关系", "en": "Accept Long Distance Relationship", "ja": "一時的な遠距離恋愛を受け入れられるか", "ko": "단기간의 원거리 연애를 받아들일 수 있는지"},
      "options": [
        {"value": "not_accept", "labels": {"zh": "不接受", "en": "Not Accept", "ja": "受け入れない", "ko": "받아들이지 않음"}},
        {"value": "1_month", "labels": {"zh": "1个月", "en": "1 Month", "ja": "1ヶ月", "ko": "1개월"}},
        {"value": "3_months", "labels": {"zh": "3个月", "en": "3 Months", "ja": "3ヶ月", "ko": "3개월"}},
        {"value": "6_months", "labels": {"zh": "半年", "en": "6 Months", "ja": "半年", "ko": "6개월"}},
        {"value": "1_year", "labels": {"zh": "1年", "en": "1 Year", "ja": "1年", "ko": "1년"}},
        {"value": "more_than_1_year", "labels": {"zh": "1年以上", "en": "More than 1 Year", "ja": "1年以上", "ko": "1년 이상"}}
      ]
    },
    "willing_to_relocate": {
      "title": {"zh": "是否愿意搬到对方城市", "en": "Willing to Relocate", "ja": "相手の都市に引っ越す意志があるか", "ko": "상대방의 도시로 이주할 의향이 있는지"},
      "options": [
        {"value": "very_willing", "labels": {"zh": "非常愿意为了爱情可以重新开始", "en": "Very willing to start over for love", "ja": "愛のために新たなスタートを切ることを非常に望んでいる", "ko": "사랑을 위해 새로운 시작을 할 의향이 매우 있음"}},
        {"value": "better_opportunity", "labels": {"zh": "如果对方城市发展机会更好", "en": "If partner's city has better opportunities", "ja": "相手の都市により良い発展機会があれば", "ko": "상대방 도시에 더 좋은 발전 기회가 있다면"}},
        {"value": "depends_situation", "labels": {"zh": "需要看具体情况和工作安排", "en": "Need to consider specific situation and work", "ja": "具体的な状況と仕事の手配を考慮する必要がある", "ko": "구체적인 상황과 업무 안배를 고려해야 함"}},
        {"value": "quite_difficult", "labels": {"zh": "比较困难有太多牵绊", "en": "Quite difficult with too many ties", "ja": "あまりにも多くのしがらみがあり困難", "ko": "너무 많은 연결고리가 있어 상당히 어려움"}}
      ]
    },
    "help_partner_relocate": {
      "title": {"zh": "是否愿意帮助对方搬过来", "en": "Help Partner Relocate", "ja": "パートナーの引っ越しを手伝う意志があるか", "ko": "상대방의 이주를 도울 의향이 있는지"},
      "options": [
        {"value": "fully_assist", "labels": {"zh": "当然愿意会全力协助安排", "en": "Of course willing to fully assist", "ja": "もちろん喜んで全面的に支援する", "ko": "당연히 기꺼이 전력으로 도와드리겠습니다"}},
        {"value": "some_help", "labels": {"zh": "可以提供一定帮助和支持", "en": "Can provide some help and support", "ja": "ある程度の助けとサポートを提供できる", "ko": "일정한 도움과 지원을 제공할 수 있음"}},
        {"value": "joint_effort", "labels": {"zh": "看情况需要双方共同努力", "en": "Depends on situation need joint effort", "ja": "状況によって双方の共同努力が必要", "ko": "상황에 따라 양측의 공동 노력이 필요"}},
        {"value": "solve_independently", "labels": {"zh": "希望对方能独立解决", "en": "Hope partner can solve independently", "ja": "相手が独立して解決できることを願う", "ko": "상대방이 독립적으로 해결하기를 희망"}}
      ]
    }
  }
}
```

---

## 建议的数据库视图

### question_options_view (基础视图)
```sql
CREATE VIEW question_options_view AS
SELECT 
    question_key,
    version,
    options_data,
    created_at,
    updated_at
FROM question_options
ORDER BY question_key, version DESC;
```

### question_options_latest (最新版本视图)
```sql
CRETE VIEW question_options_latest AS
SELECT DISTINCT ON (question_key)
    question_key,
    version,
    options_data,
    created_at,
    updated_at
FROM question_options
ORDER BY question_key, version DESC;
```

### question_options_i18n (多语言视图)
```sql
CREATE VIEW question_options_i18n AS
SELECT 
    q.question_key,
    q.version,
    jsonb_array_elements(q.options_data->'options') as option_data,
    q.created_at
FROM question_options q
ORDER BY q.question_key, q.version DESC;
```

### question_options_by_lang (按语言获取函数)
```sql
CREATE OR REPLACE FUNCTION get_question_options(
    p_question_key VARCHAR DEFAULT NULL,
    p_version INTEGER DEFAULT NULL,
    lang_code VARCHAR DEFAULT 'zh'
)
RETURNS TABLE (
    question_key VARCHAR,
    version INTEGER,
    option_value VARCHAR,
    option_label VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        q.question_key,
        q.version,
        (jsonb_array_elements(q.options_data->'options')->>'value')::VARCHAR as option_value,
        COALESCE(
            (jsonb_array_elements(q.options_data->'options')->'labels'->>lang_code)::VARCHAR,
            (jsonb_array_elements(q.options_data->'options')->'labels'->>'en')::VARCHAR
        ) as option_label
    FROM (
        SELECT DISTINCT ON (question_key) 
            question_key, version, options_data
        FROM question_options 
        WHERE (p_question_key IS NULL OR question_key = p_question_key)
        AND (p_version IS NULL OR version = p_version)
        ORDER BY question_key, version DESC
    ) q;
END;
$$ LANGUAGE plpgsql;
```

---

## 使用建议

1. **版本管理**: 通过 version 字段支持选项的版本升级，默认使用最新版本
2. **多语言支持**: options_data 中存储多语言标签，支持 zh/en/ja/ko 等语言
3. **缓存策略**: 建议在应用层缓存这些相对稳定的选项数据
4. **API 设计**: 提供按 question_key、版本和语言获取选项的 API
5. **默认语言**: 当指定语言不存在时，回退到英文 (en)
6. **JSON 索引**: 建议为 options_data 建立 GIN 索引以提高查询性能

---

## 总结

通过统一的 question_options 表管理所有选项数据，可以：
- 简化选项数据的维护
- 支持版本管理，便于选项更新和回滚
- 支持多语言国际化 (zh/en/ja/ko)
- 提高数据一致性
- 减少硬编码选项
- 通过 JSON 格式灵活存储多语言选项
- 保持历史版本，支持数据追溯
- **新增QA问答系统支持**：涵盖个人问题和地域灵活性相关的所有选项配置