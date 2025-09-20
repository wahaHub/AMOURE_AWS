# muer 前台接入 V2 后台方案（UI 无改动）

本文档说明如何在保持现有 UI 不变的前提下，让前台 `muer_dating_app` 对接后端 V2 接口（代码位置：`Amoure-server/amoure-app/src/main/java/com/amoure/api/v2`）。核心思路：仅在网络层 / Repository 层做适配（Adapter），不改动 UI 层组件与交互。

---

## 1. 总览与原则

- 接口前缀：V1 为 `/api/app/*`，V2 为 `/api/v2/*`。
- 认证体系：V2 使用 Sa-Token 独立空间与独立 Header 名称（`satoken-v2`），支持 `Bearer` 前缀。
- 返回体：仍使用统一 `Result<T>` 包装，字段更清晰，新增部分结构化字段（如 `statusInfo`）。
- 兼容策略：
  - 在 App 的网络层新增 V2 客户端与“V1→V2 请求/响应映射”适配器。
  - 引入版本开关，不动 UI 调用点（Repository 接口保持不变）。

---

## 2. 快速接入步骤

1) 新增配置与开关（App 内）
- `API_BASE_URL_V2 = {your-base}/api/v2`
- `USE_V2_API = true`（灰度时可动态开关）
- 独立存储 V2 Token：键名如 `v2_token_value`，避免与 V1 冲突。

2) 新增 V2 Token 拦截器
- Header 名称：`satoken-v2`
- 值：`Bearer ${tokenValue}`（后端已配置支持 Bearer 前缀）

3) 登录改造（仅网络层转换，不改 UI）
- 仍调用原有 `AuthRepository.login(params)`；在实现中：
  - 将原 V1 `LoginRequest` 字段映射到 V2：
    - `loginType: Integer` → `String.valueOf(loginType)`
    - `smsCode` → `verifyCode`
    - `wxCode` → `wechatCode`
    - `appleParams.identityToken` → `identityToken`
  - 调用 `POST /api/v2/auth/login`，从响应 `data.tokenInfo.tokenValue` 取 Token，保存为 `v2_token_value`。

4) 统一请求头注入
- 登录之后，所有需要鉴权的 V2 请求在拦截器里带上：
  - `satoken-v2: Bearer ${v2_token_value}`

5) 按清单替换接口（见第 4 节）
- 为每个原 Repository 方法加一层“V1→V2 参数/响应映射”。
- 方法签名与返回类型对 UI 保持不变。

6) 联调自测
- 使用文末自测清单、`design_docs/API_Testing_Guide_V1_V2.md`、Postman 环境进行快速验收。

---

## 3. 认证与 Token 细节

- V2 Token 工具类：`StpUserV2Util`（独立 token 逻辑空间）。
- V2 Token 配置：`V2TokenConfig` 指定 `token-name = satoken-v2` 且支持 `Bearer` 格式读取。
- 后端登录响应（`/api/v2/auth/login`）结构关键点：
  - `data.tokenInfo` 为 Sa-Token 信息对象（包含 `tokenValue`, `tokenName`, `loginId` 等）。
  - `data.isNewUser` 标识新用户；新用户需调用 `/api/v2/user/onboard` 完成资料首填。

拦截器示例（Kotlin + OkHttp）：
```kotlin
class V2AuthInterceptor(private val tokenProvider: () -> String?) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = tokenProvider()
        val request = if (!token.isNullOrBlank()) {
            chain.request().newBuilder()
                .addHeader("satoken-v2", "Bearer $token")
                .build()
        } else chain.request()
        return chain.proceed(request)
    }
}
```

---

## 4. 接口映射清单（V1 → V2）

说明：本节仅列前台常用接口。若 UI 仍调用原 Repository 方法，请在方法内部做参数与响应的转换，方法签名保持不变。

1) 认证 Auth
- 登录：
  - V1: `POST /api/app/auth/login`（`loginType`, `smsCode`/`wxCode`/`appleParams`）
  - V2: `POST /api/v2/auth/login`
    - 字段映射：
      - `loginType: int` → `loginType: string`（示例：1→"1"）
      - `smsCode` → `verifyCode`
      - `wxCode` → `wechatCode`
      - `appleParams.identityToken` → `identityToken`
    - 响应：`data.tokenInfo.tokenValue` → 保存到 `v2_token_value`
- 登出：
  - V1: `POST /api/app/auth/logout`
  - V2: `POST /api/v2/auth/logout`
- 注销账号：
  - V1: `POST /api/app/auth/deactivate`
  - V2: `POST /api/v2/auth/deactivate`
- Web 注册（如 H5/Web）：
  - V2: `POST /api/v2/auth/register`
- 活跃心跳：
  - V2: `POST /api/v2/auth/activity`

2) 用户 User
- 获取当前/指定用户详情：
  - V1: `POST /api/app/user/getUserDetail`（body 可空或含 `userId`）
  - V2: `GET /api/v2/user?userId={id}`（空则取当前登录用户）
- 新用户入驻（资料首填）：
  - V1: `saveBasicInfo`/`saveProfile`
  - V2: `POST /api/v2/user/onboard`
    - 请求体：`nickname`, `birthday(YYYY-MM-DD)`, `gender("1"/"2")`, `profileImageUrl`, `location` ...
- 更新用户档案：
  - V1: `POST /api/app/user/saveProfile`
  - V2: `PATCH /api/v2/user/profile`
- 彻底删除账户：
  - V2: `DELETE /api/v2/user/complete`
- 好友详情（用于推荐/匹配卡片跳转）：
  - V2: `GET /api/v2/user/friend/{friendUserId}`

3) 用户互动/心动 Interactions
- 点赞/操作：
  - V1: `POST /api/app/interaction/markLike`（body: `{targetUserId, type}`；type 取值：`LIKE|SUPER_LIKE|DISLIKE|BLOCK`）
  - V2: `POST /api/v2/interactions`（body: `{targetUserId, interactionType}`）
    - 类型映射：
      - `LIKE` → `like`
      - `SUPER_LIKE` → `super_like`
      - `DISLIKE` → `pass`
      - `BLOCK` → `block`
- 心动列表：
  - V1: `POST /api/app/interaction/likeUserList`（body: `{type, pageNum, pageSize}`；type：`LIKE_ME|I_LIKE|MUTUAL`）
  - V2: `GET /api/v2/interactions/likes?type={t}&cursor={page}&limit={size}`
    - 类型映射：
      - `LIKE_ME` → `like_me`
      - `I_LIKE` → `i_like`
      - `MUTUAL` → `mutual`
- 拉黑列表：
  - V2: `GET /api/v2/interactions/blocks?page={1}&size={20}`

4) 推荐 Recommendation
- V2: `GET /api/v2/recommendation`（返回 `users` map，key 为用户ID字符串，value 为用户详情 map）

5) 第三方绑定 Account Binding
- 微信：
  - 绑定：`POST /api/v2/account/binding/wechat`
  - 解绑：`DELETE /api/v2/account/binding/wechat`
- 手机：
  - 绑定：`POST /api/v2/account/binding/phone`
  - 更换：`PUT  /api/v2/account/binding/phone`
  - 解绑：`DELETE /api/v2/account/binding/phone`
- 邮箱：
  - 绑定：`POST /api/v2/account/binding/email`
  - 更换：`PUT  /api/v2/account/binding/email`
  - 解绑：`DELETE /api/v2/account/binding/email`
- Apple：
  - 绑定：`POST /api/v2/account/binding/apple`
  - 解绑：`DELETE /api/v2/account/binding/apple`
- 查询当前用户所有绑定：`GET /api/v2/account/binding`

6) 认证 Verification（如 UI 有认证模块）
- 提交认证：`POST /api/v2/verification/submit?userId={uid}`（body: 认证请求）
- 批量状态：`POST /api/v2/verification/status/batch`（body: `[userId...]`）
- 管理端审核/待审核：`/review/{verificationId}`, `/pending`（需要 ADMIN 权限）

7) 动态 Feed（如 UI 有动态流/发布）
- 获取动态：`GET /api/v2/feed?type=all|user&userId=&cursor=&limit=`
- 发布动态：`POST /api/v2/feed`
- 点赞/取消点赞：`POST /api/v2/feed/{postId}/like`，`DELETE /api/v2/feed/{postId}/like`
- 删除动态：`DELETE /api/v2/feed/{postId}`

8) 问题选项（问答/筛选项）
- 最新版本一次性获取：`GET /api/v2/question-options/batchGetLatestAllOptions`
- 指定版本：`GET /api/v2/question-options/batchGetAllOptionsForVersion?version=2`

---

## 5. 请求/响应字段适配建议

- 登录请求：
  - 适配器将 `loginType(Int)` 转成字符串；`smsCode→verifyCode`、`wxCode→wechatCode`、Apple 取 `identityToken`；
  - 登录响应读取 `data.tokenInfo.tokenValue` 存到 `v2_token_value`；保持 Repository 返回对象与 UI 一致（必要时 copy 字段）。

- 互动请求：
  - 适配器将 V1 `type`（大写枚举）映射为 V2 `interactionType`（小写下划线）。
  - 心动列表类型同理（`LIKE_ME|I_LIKE|MUTUAL` → `like_me|i_like|mutual`）。

- 用户详情/档案：
  - V2 `UserDetailResponse` 包含 `photos`、`verificationStatus`、`bindingInfo`、`statusInfo` 等，适配到 UI 需要的字段即可，多余字段可忽略。

- 错误处理：
  - 依然是 `Result<T>`；检查 `code/ok`（项目内约定）并统一在网络层转换成 App 内部的错误类型。

---

## 6. 示例：Repository 适配（伪代码）

```ts
// 假设保持原接口不变
async function loginV1Style(params: V1LoginParams): Promise<Session> {
  if (!USE_V2_API) return loginViaV1(params)

  const v2Body = {
    loginType: String(params.loginType),
    mobile: params.mobile,
    verifyCode: params.smsCode,
    wechatCode: params.wxCode,
    identityToken: params.appleParams?.identityToken,
  }
  const resp = await http.post(`${API_BASE_URL_V2}/auth/login`, v2Body)
  const token = resp.data?.data?.tokenInfo?.tokenValue
  save('v2_token_value', token)
  return mapV2LoginResponseToSession(resp.data)
}

async function markLikeV1Style(req: { targetUserId: number; type: 'LIKE'|'SUPER_LIKE'|'DISLIKE'|'BLOCK' }) {
  if (!USE_V2_API) return http.post(`${API_BASE_URL_V1}/interaction/markLike`, req)
  const mapType = { LIKE: 'like', SUPER_LIKE: 'super_like', DISLIKE: 'pass', BLOCK: 'block' }[req.type]
  return http.post(`${API_BASE_URL_V2}/interactions`, { targetUserId: req.targetUserId, interactionType: mapType })
}

async function likeUserListV1Style({ type, pageNum, pageSize }) {
  if (!USE_V2_API) return http.post(`${API_BASE_URL_V1}/interaction/likeUserList`, { type, pageNum, pageSize })
  const t = { LIKE_ME: 'like_me', I_LIKE: 'i_like', MUTUAL: 'mutual' }[type]
  return http.get(`${API_BASE_URL_V2}/interactions/likes`, { params: { type: t, cursor: String(pageNum), limit: pageSize } })
}
```

---

## 7. 自测清单（最小路径）

- 登录（短信/微信/Apple 任一）→ 保存 `v2_token_value` 成功。
- 获取当前用户详情 `GET /api/v2/user` 正常。
- 新用户入驻 `POST /api/v2/user/onboard` 正常（老用户跳过）。
- 推荐列表 `GET /api/v2/recommendation` 能返回用户集合。
- 点赞 `POST /api/v2/interactions`，心动列表 `GET /api/v2/interactions/likes` 正常。
- 第三方绑定（任一）`POST /api/v2/account/binding/*` 成功。
- 问题选项 `GET /api/v2/question-options/batchGetLatestAllOptions` 正常。

---

## 8. 回滚与灰度

- 保持 `USE_V2_API` 开关，支持用户/渠道/灰度包按比例切换。
- V2 Token 与 V1 Token 独立存储与头部，互不影响；任意时刻可回退至 V1。

---

## 9. 参考代码位置（后端）

- 认证：`amoure-app/src/main/java/com/amoure/api/v2/controller/AuthV2Controller.java`
- 用户：`amoure-app/src/main/java/com/amoure/api/v2/controller/UserV2Controller.java`
- 互动：`amoure-app/src/main/java/com/amoure/api/v2/controller/InteractionV2Controller.java`
- 推荐：`amoure-app/src/main/java/com/amoure/api/v2/controller/RecommendationV2Controller.java`
- 绑定：`amoure-app/src/main/java/com/amoure/api/v2/controller/ThirdPartyBindV2Controller.java`
- 认证：`amoure-app/src/main/java/com/amoure/api/v2/controller/UserVerificationV2Controller.java`
- 动态：`amoure-app/src/main/java/com/amoure/api/v2/controller/FeedV2Controller.java`
- Token 配置：`amoure-app/src/main/java/com/amoure/api/v2/config/V2TokenConfig.java`

---

如需，我可以基于现有前台项目目录直接提交一版网络层适配代码（含开关、拦截器与主要 Repository 适配）。

