### Amoure Postman Collections vs Controllers Param Mismatch Report

Scope
- Compare Postman collections:
  - V1: `api-testing/postman/Amoure-V1-Accurate-Final.postman_collection.json`
  - V2: `api-testing/postman/Amoure-V2-Accurate-Final.postman_collection.json`
- Against actual controllers and DTOs in `Amoure-server/amoure-app`.

---

### V1 mismatches (api/app/*)

- Auth Login `POST /api/app/auth/login`
  - Postman body uses: `{"loginType": 1, "phone": "...", "verifyCode": "..."}`
  - Controller expects: `LoginRequest` with fields
    - `loginType` Integer
    - `mobile` String (NOT `phone`)
    - `smsCode` String (NOT `verifyCode`)
  - Fix example:
    - `{ "loginType": 1, "mobile": "13800138000", "smsCode": "888888" }`

- Interactions Like User List `POST /api/app/interaction/likeUserList`
  - Postman body: `{ "page": 1, "size": 10 }`
  - Controller expects: `LikeUserListReq extends BasePageReq`
    - `current` Integer (NOT `page`)
    - `pageSize` Integer (NOT `size`)
    - Optional: `type` String: `LIKE_ME | I_LIKE | MUTUAL`
  - Fix example:
    - `{ "current": 1, "pageSize": 10, "type": "LIKE_ME" }`

- Interactions Mark Like `POST /api/app/interaction/markLike`
  - Postman body (current): `{ "targetUserId": 2, "type": "like" }`
  - Controller expects: `UserLikeReq`
    - `targetUserId` Long
    - `type` String using UPPERCASE enum names: `LIKE | SUPER_LIKE | DISLIKE | BLOCK`
  - Fix example:
    - `{ "targetUserId": 2, "type": "LIKE" }`

- Posts Publish `POST /api/app/post/publishPost`
  - Postman body: `{ "content": "...", "mediaUrls": ["..."] }`
  - Controller expects: `PostPublishRequest`
    - `content` String
    - `imageUrls` List<String> (NOT `mediaUrls`)
    - `visibility` String required: `PUBLIC | PRIVATE`
  - Fix example:
    - `{ "content": "Hello", "imageUrls": ["https://..."], "visibility": "PUBLIC" }`

- Posts Query List `POST /api/app/post/queryPostList`
  - Postman body: `{ "current": 1, "size": 10, "userId": null }`
  - Controller expects: `PostQueryRequest extends BasePageReq`
    - `current` Integer
    - `pageSize` Integer (NOT `size`)
    - Optional: `userId` Long
  - Fix example:
    - `{ "current": 1, "pageSize": 10, "userId": null }`

- Recommendation Users `POST /api/app/recommend/users`
  - Postman body: `{ "ageMin": 18, "ageMax": 35, "location": "", "page": 1, "size": 10 }`
  - Controller expects: `RecommendUserFilterDTO`
    - `minAge` (NOT `ageMin`)
    - `maxAge` (NOT `ageMax`)
    - `locationCode` (NOT `location`)
    - (No pagination in DTO; extra `page/size` ignored)
  - Fix example:
    - `{ "minAge": 18, "maxAge": 35, "locationCode": "310000" }`

---

### V2 mismatches (api/v2/*)

- Auth Login `POST /api/v2/auth/login`
  - Postman body: `{ "loginType": 1, "phone": "...", "verifyCode": "..." }`
  - Controller expects: `com.amoure.api.v2.dto.request.LoginRequest`
    - `loginType` String (NOT Integer)
    - `mobile` String (NOT `phone`)
    - `verifyCode` String
  - Fix example:
    - `{ "loginType": "1", "mobile": "13800138000", "verifyCode": "888888" }`

- User Detail `GET /api/v2/user?userId=&fields=`
  - Postman defines this endpoint.
  - Controller does NOT provide this endpoint. Available endpoints under `/api/v2/user`:
    - `POST /api/v2/user/onboard`
    - `GET /api/v2/user/friend/{friendUserId}`
  - Action: remove or implement missing endpoint; or switch tests to existing ones.

- User Update Profile `PATCH /api/v2/user/profile`
  - Postman defines this endpoint.
  - Controller does NOT provide this endpoint.
  - Action: remove from collection or implement in controller.

- Delete User `DELETE /api/v2/auth/user`
  - Postman defines this endpoint.
  - Controller does NOT provide this endpoint.

- Delete User Completely `DELETE /api/v2/user/complete`
  - Postman defines this endpoint.
  - Controller does NOT provide this endpoint.

- Interactions Likes `GET /api/v2/interactions/likes`
  - Postman includes required query `type` (`liked_by_me | i_liked | mutual_liked`) – OK.
  - Note: missing `type` will trigger server error; ensure always present.

- Feed Create `POST /api/v2/feed`
  - Postman body: `{ "content": "...", "mediaUrls": ["..."], "location": "...", "tags": "..." }`
  - Controller expects: `CreatePostRequest`
    - `mediaUrls` String (comma-separated), NOT array
    - `visibility` Integer required by service (and may be validated later)
    - Optional: `postType` Integer
  - Fix example:
    - `{ "content": "...", "mediaUrls": "https://a.com/x.jpg,https://a.com/y.jpg", "visibility": 1, "location": "Shanghai", "tags": "lifestyle,dating" }`

- Conversation List `GET /api/v2/conversation`
  - Postman defines this endpoint with `cursor`/`limit`.
  - Controller provides only `GET /api/v2/conversation/im` (IM conversations). No base list endpoint.
  - Action: adjust to `/api/v2/conversation/im` or implement base endpoint.

---

Notes
- Many V1 endpoints expect pagination fields `current` and `pageSize` from `BasePageReq`.
- Enum-like fields in V1 often expect UPPERCASE textual values (e.g., `LIKE`, `PUBLIC`).
- V2 login uses string `loginType` and `verifyCode` naming.


