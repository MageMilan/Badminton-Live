# 羽球比赛记录 - 实时分享集成文档 (Integration)

本文档旨在描述 Android 客户端与 Supabase 后端及 Web 预览端之间的数据同步与集成逻辑。

## 1. Supabase 数据库结构

实时分享功能依赖于 Supabase 的 PostgreSQL 数据库。需在控制台中执行以下 SQL 脚本以创建核心表：

```sql
-- 1. 创建实时分享表
create table live_tournaments (
  id uuid primary key,               -- 分享唯一标识 (shareId)
  payload jsonb not null,            -- 赛事完整数据快照 (包含名称、场次、比分、排行榜)
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. 启用实时广播 (Realtime)
-- 允许 Web 端订阅该表的变更，实现比分即时跳动
alter publication supabase_realtime add table live_tournaments;

-- 3. 配置行级安全策略 (RLS)
alter table live_tournaments enable row level security;

-- 允许任何人通过 ID 查询 (预览链接持有者)
create policy "Allow public read by id" on live_tournaments
  for select using (true);

-- 允许匿名客户端通过 upsert 更新 (Android 端推送)
create policy "Allow public upsert" on live_tournaments
  for insert with check (true);

create policy "Allow public update" on live_tournaments
  for update using (true);
```

---

## 2. 数据上传逻辑 (Android -> Supabase)

### 2.1 触发时机
Android 客户端在 `MatchViewModel` 中使用 `combine` 算子监听本地数据库。一旦**开启了分享功能**，以下任何变动都会自动触发向云端同步：
- 任意场次的比分保存（Score A/B 修改）。
- 场次状态变更（从待赛变为计分中，或变为已完成）。
- 比赛完成结算（排行榜最终锁定）。

### 2.2 上传方式 (Upsert)
客户端采用 **全量快照推送** 策略。每次同步都会构造一个 `LiveShareData` 对象并调用 Supabase 的 `upsert` 接口。
- **幂等性**: 根据 `shareId` (UUID) 进行覆盖更新，如果记录不存在则插入，存在则更新。
- **静默处理**: 为了不影响离线记分的流畅度，上传过程在 `viewModelScope` 的后台 IO 线程异步执行，失败时仅记录日志而不中断用户操作。

---

## 3. 分享链接的生成

分享链接在“比赛大厅”点击开启实时分享时生成：

1.  **生成 UUID**: 调用 `UUID.randomUUID().toString()` 生成一个 128 位的随机字符串作为 `shareId`。
2.  **持久化**: 该 ID 会存储在本地 `tournaments` 表的 `shareId` 字段中。
3.  **构造链接**: 将 `shareId` 拼接到预设的 GitHub Pages Web 应用地址中。
    - **格式**: `https://<your-username>.github.io/Badminton-Live/#/?id=<shareId>`
    - **安全性**: 链接不包含任何用户账号信息，仅包含该赛事的随机 UUID。

---

## 4. 数据检索与实时订阅 (Web 端)

Web 预览端通过以下逻辑获取并展示数据：

1.  **解析 ID**: 从 URL 的 query 参数中提取 `id`。
2.  **初始读取**:
    ```javascript
    const { data, error } = await supabase
      .from('live_tournaments')
      .select('payload')
      .eq('id', shareId)
      .single();
    ```
3.  **实时监听**:
    Web 端使用 Supabase JS SDK 订阅对应行的更新事件，当 `payload` 发生变化时，UI 会即时响应：
    ```javascript
    supabase
      .channel('schema-db-changes')
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'live_tournaments', filter: `id=eq.${shareId}` },
        (payload) => {
          // 这里的 payload.new.payload 即为最新的赛事数据快照
          updateUI(payload.new.payload);
        }
      )
      .subscribe();
    ```

### 数据契约说明
Web 端接收到的 `payload` 结构请参考根目录下的 `sample_live_share.json`。该文件包含了完整的场次对阵信息、比分状态以及动态生成的排行榜数据。
