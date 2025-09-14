# Amoure Flutter 前端 GraphQL 测试计划

**版本**: v1.0 – 2025-08-02

---

## 1. 目标

1. 确认新建的 **GraphQL → BackendManager → CacheManager** 全链路在各种情形下均能正确工作。
2. 在 **UI 集成前** 即捕获核心逻辑错误；在 **UI 集成后** 通过端到端体验验证业务正确性。
3. 自动化测试结果进入 CI，阻断回归缺陷。

---

## 2. 测试分层策略

| 层级 | 工具/框架 | 数据来源 | 目的 |
|------|-----------|----------|------|
| 单元 (Unit) | `ferry_test`, `mocktail`, `build_runner` | **静态生成的假响应** | 验证 GraphQLConfig、BackendManagerLink、Service 方法逻辑 (不触网) |
| 合成 (Service Integration) | `mock_web_server` (Android) / `dart_frog` (desktop) | **动态 Fake Server** | 确认 Ferry 请求格式、Header、缓存键、TTL 等与后端契约一致 |
| UI 集成 (Widget) | `flutter_test`, `GetX TestUtils` | Stub Service (Dependency Injection) | 验证 Controller ↔ Widget 数据流、状态呈现 |
| 端到端 (E2E) | `flutter_driver` / `integration_test` + Staging 后端 | 真实后端或局部 Fake | 回归测试，验证真实交互 & 性能 |

---

## 3. 假数据方案对比

| 方案 | 描述 | 优点 | 缺点 | 适用阶段 |
|------|------|------|------|-----------|
| A. **纯 Mock (离线)** | 使用 `ferry_test` 的 `MockClient`，对每个 `*.req.gql.dart` 提供 `MockResponse` | 速度快、无需网络、可精确控制场景 | 需要手写大量 JSON，易与 Schema 偏离 | Unit / Widget |
| B. **本地 Fake GraphQL Server** | 利用 `dart_frog` 或 `mock_web_server` 启动本地 http server，返回 GraphQL JSON | 请求链路完全一致，能测试 Header & Cache | 维护 Fake Server 昂贵；启动慢 | Service Integration |
| C. **Staging 后端 + 工具种子数据** | 后端提供种子脚本 / Playground 批量插入测试数据 | 与真实环境一致 | 依赖后端、数据可变 | E2E |

> 建议：先 A → B → C 递进，以保障覆盖度与效率。

---

## 4. 具体测试用例

### 4.1 核心链路 (BackendManagerLink)

| 用例ID | 场景 | 断言 |
|--------|------|------|
| BM-01 | 查询命中 **短期缓存** | 第一次命中网络 / 第二次命中 `_shortTermCache` (<5s) |
| BM-02 | 查询命中 **持久化缓存** | 重启后首次查询读取 `CacheManager`，不访问网络 |
| BM-03 | 缓存过期重取 | 超过 TTL 后返回网络数据并刷新缓存 |
| BM-04 | Token 过期 | 第一次 401 → 自动刷新 token → 重试成功 |
| BM-05 | 离线排队 | 断网下触发查询 → 队列 → 网络恢复后自动发送 |

### 4.2 Service 层

以 `HomeGraphQLService` 为例：

| 用例ID | 场景 | Mock 行为 | 断言 |
| HG-01 | 正常获取推荐 | Mock 返回 `users.length=5` | Stream 首个 data 匹配 & 无 error |
| HG-02 | `forceRefresh`=true | Mock 服务统计访问次数=1 | FetchPolicy 已变为 NetworkOnly |
| HG-03 | GraphQL Error | Mock 返回 `errors` 数组 | 抛出 `GraphQLServiceException` |

### 4.3 Controller + Widget

| 用例ID | 场景 | 断言 |
|--------|------|------|
| UI-01 | 首屏加载 | `isLoadingRecommendation=true` → 假数据渲染完成 → `recommendationUsers.length==5` |
| UI-02 | 下拉刷新 | 状态切换 Loading→Done，无异常 |
| UI-03 | 分页加载 | 调 `loadMoreHomeFeed()` 后列表长度增长 |

...（其余 Service/Controller 类推）

---

## 5. 自动化执行

1. **脚本位置**：`muer_dating_app/test/graphql/`。
2. **CI**：在 GitHub Actions `flutter-test.yml` 中增加 step：
   ```yaml
   - name: Run GraphQL tests
     run: flutter test --coverage test/graphql
   ```
3. **本地 Fake Server**：脚本 `scripts/start_fake_graphql_server.dart`，CI 启动时 `dart run` 后再执行测试。

---

## 6. 数据生成工具

1. `graphql-codegen` + `json-schema-faker`：根据 `schema.graphql` 自动产出随机一致性 JSON。
2. 手写 fixture：`test/fixtures/home_recommendation_feed.json`。
3. 后端种子脚本：`Amoure-server/scripts/seed_test_data.sql`。

---

## 7. 进度里程碑

| 阶段 | 负责人 | 完成时间 | 交付物 |
|------|--------|----------|--------|
| Unit / Service Mock 架构 | FE Team | 08-05 | 测试运行通过 (覆盖率≥60%) |
| Fake Server & Cache cases | FE Team | 08-10 | BM-01~05, HG-01~03 全通过 |
| Widget & Controller Tests | FE Team | 08-14 | UI-01~03 通过，golden screenshot |
| E2E 与真后端 | QA Team | 08-20 | Android+iOS 报告，主要流程通过 |

---

## 8. 结语

通过分层递进测试，可在 UI 集成前发现逻辑缺陷，又能在集成后用真实交互回归性能与体验。若资源有限，也可跳过 Fake Server 阶段，直接在 Staging 后端 + 真机上调试；但建议仍保留最小 Unit & Service 测试作为回归防线。 