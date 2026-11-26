# 维拓校务管理平台

培训机构教务管理后台，管理校区、学期、班级、课次、学员报名与考勤，并提供班级经营报表。

技术栈：Rails 8.1 / Ruby 3.3.14 / MySQL / Hotwire（Turbo + Stimulus）/ Tailwind CSS v4 + daisyUI / importmap（无 JS 打包步骤）。后台作业、缓存、Action Cable 均基于生产数据库（solid_queue / solid_cache / solid_cable）。

给 AI 助手的完整架构与约定见 [AGENTS.md](AGENTS.md)；面向教务人员的日常操作说明见 [docs/user_guide.md](docs/user_guide.md)。

## 快速开始

```bash
bin/setup                 # 安装依赖、准备数据库（默认随后启动 bin/dev）
bin/setup --skip-server   # 只准备环境，不启动服务
bin/dev                   # Rails + Tailwind watcher（改样式必须开着）
bin/rails test            # 全量测试
bin/rails test test/models/semester_test.rb:18   # 单个用例
bin/ci                    # 全套本地检查：rubocop / bundler-audit / importmap audit / brakeman / 测试 / seeds
bin/rails data:integrity  # 约束迁移前检查重复/孤儿数据
```

单独检查：`bin/rubocop`、`bin/bundler-audit`、`bin/importmap audit`、`bin/brakeman`、`bin/rails tailwindcss:build`。

本地 MySQL 通过 `/tmp/mysql.sock` 以 root 免密连接，库为 `weituo_development` / `weituo_test`；`db/seeds.rb` 会先清空业务数据，再生成覆盖学校/校区/学期、班级、课次、考勤与授权账号的演示数据（2 个校区、4 个学期、180 名学员）。测试用 `fixtures :all`，认证用 `sign_in_as(users(:one))`。

演示账号密码均为 `password`：`admin`（超级管理员，两个校区）、`user1`（城东校区管理员，七/八年级）、`user2`（城西校区管理员，全部年级）、`user3`（城东校区管理员，仅九年级）、`pending`（未分配校区）。

## 角色与权限

| 角色 | `UserCampuse.role` | 可见范围 |
| --- | --- | --- |
| 超级管理员 | `admin` | 全部菜单，含用户管理、学校管理、年级科目管理 |
| 管理员 | `manager` | 按 `grade_ids` 限定的年级与科目 |

用户通过 `UserCampuse` 关联到校区，一个用户可有多个校区授权，每个授权带一份 JSON `grade_ids`。`Current.user.grades_by_campuse` / `subjects_by_campuse` 决定筛选与表单里可选的年级、科目。

**当前上下文**：登录后 `AdminController#set_current_context` 把当前校区、学校、学期写入 `Current` 并记在 session 里；顶栏可切换校区/学期。所有列表与详情都按这三个上下文过滤，切换后看到的是另一套数据。学期默认取覆盖今天的学期，取不到则回退到 `seq` 最大的学期。

账号以用户名 + 密码登录（`users` 表无邮箱字段），不提供自助邮件重置密码；需要重置时由管理员在「用户管理」中修改。

## 术语与数据模型

| 业务名词 | 模型 / 表 | 说明 |
| --- | --- | --- |
| 学校 | `School` / `schools` | 顶层组织 |
| 校区 | `Campuse` / `campuses` | 模型名是刻意的单数拼写，勿改 |
| 学期 | `Semester` / `semesters` | 按 `seq` 排序，带 `start_date` / `end_date` |
| 年级、科目 | `Grade` / `Subject` / `GradeSubject` | 学校可开设的年级科目组合 |
| 日校 | `DaySchool` | 学员就读的全日制学校 |
| 教师 | `Teacher` | 属于校区，带科目 |
| 学员、监护人 | `Student` / `Guardian` | 属于校区，可带年级、日校、家庭住址；监护人可带关系与职业 |
| 推荐关系 | `StudentReferral` / `student_referrals` | 学员之间的推荐入学关系，被推荐学员唯一 |
| 班级 | `SemesterKlass` / `semester_klasses` | 学期 + 阶段（一阶段 / 二阶段）+ 校区 + 年级 + 科目 + 班型 + 序号 |
| 课次 | `Course` / `courses` | 班级下按 `seq` 排列的一节课，有 `start_date` 表示已开课 |
| 报名 | `KlassStudent` / `klass_students` | 学员与班级的关系，状态 `in` / `out` / `transfer` |
| 考勤 | `Attendance` / `attendances` | 每个「课次 × 报名」一条记录 |
| 用户、授权、会话 | `User` / `UserCampuse` / `Session` | 登录与权限 |

`klasses` 表仍存在于 schema，但没有对应模型，也不参与现有流程。

```mermaid
flowchart LR
  School[学校] --> Campuse[校区]
  Campuse --> Semester[学期]
  Semester --> SK[班级]
  SK --> Course[课次]
  SK --> KS[报名]
  Student[学员] --> KS
  Course --> Att[考勤]
  KS --> Att
```

## 核心业务流程

### 1. 开班

入口：`班级管理 → 开班`，或 `POST /admin/semester_klasses`。

- 必填：学期、阶段（一阶段 / 二阶段）、年级、教师、校区、班型（`TG` 提高 / `JY` 精英 / `XZ` 创新 / `XQ` 兴趣 / `CC` 超常）、序号、`times`（课次数）
- **科目由教师带出**，不由表单单独指定
- 唯一性：`学期 + 阶段 + 校区 + 年级 + 科目 + 班型 + 序号` 不可重复；同一学期的一阶段、二阶段可以重复使用班型与序号
- 创建后 `after_create` 自动生成 `times` 门课次（`seq` 从 1 开始，均无 `start_date`）
- 班级名规则：`期次 + 年级 level + 科目首字 + 班型中文首字 + 序号`，例如 `一期7数提1`、`二期7数提1`；自动序号按阶段独立计算

### 2. 学员报名与批量导入

`Student#join_klass(semester_klass, course_seq: 1)` 要求学员的年级、校区与班级一致；不匹配直接跳过。

- 从第 1 课入班：仅为**已开课**的课次生成考勤
- 插班（从第 N 课入班）：第 N 课之前的课次补记为 `absent`，第 N 课及之后已开课的课次生成 `normal` 考勤
- 班级表单的学员名单改为搜索勾选同年级学员，并选择入班课次（默认第 1 课）
- 班级页「添加学员」抽屉（`insert_students`）列出同年级且未入班的学员，可搜索勾选，也可切换为粘贴「姓名,入班课次」名单批量加入（没有档案的姓名会自动按本班年级建档）；提交后按各自入班课次插班，之前课次补记 `absent`

学员页「批量导入」抽屉支持下载导入模板（`StudentImportTemplate`）、上传 `.xlsx`（`Student.add_by_xlsx`，首行表头可有可无）或按 CSV 文本批量建档（`Student.add_by_text`）：`姓名,性别,生日,年级level,层级,入学日期,日校[,家庭住址][,监护人姓名,监护人电话,监护关系,监护人职业]…`（监护人按 4 列一组可重复，写多名）；家庭住址与监护人各列可选，填写电话即建档（姓名、关系、职业可留空）；年级、日校不匹配或不在授权范围的行会跳过，只建学员档不自动入班。教师、日校、监护人也有各自的 `add_by_text` 文本导入。学员档案可记录推荐人（`StudentReferral`，`referrer_id` / `referred_id` 均指向学员），新增/编辑时按姓名搜索本校区学员；被推荐学员只能有一位推荐人。侧栏「推荐统计」汇总推荐总数、推荐人排行、被推荐学员年级分布与推荐明细，可按推荐人年级筛选。同名学员按校区和姓名自动编号（`students.name_seq`，从 1 累加；改名时原序号未被占用则保持不变），选择器与考勤/报表展示会带「序号 N」；学员列表默认 30 条/页，可在底部切换 20 / 30 / 50 / 100；可按姓名、年级筛选，并按「在班 / 未入班 / 有退课」分栏；支持勾选学员批量升年级（仅更新年级，不调整班级报名）。

### 3. 开课与考勤生成

`PUT /admin/semester_klasses/:id/courses/:id/start` → `Course#start!`：

- 写入 `start_date`（默认今天），已开课则直接返回（幂等）
- 为该班级**所有报名学员**生成 `Attendance`，初始状态 `normal`
- 班级所有课次都有 `start_date` 时，`SemesterKlass#ended?` 为 true（结课）

班级详情页以「学员 × 课次」矩阵展示考勤，未开课的课次显示「未开课」。

### 4. 考勤状态流转

状态：`normal` 正常、`absent` 缺课、`filled` 补课销假、`personal_leave` 事假、`sick_leave` 病假、`quit` 退课、`transfer` 转出。最后打标人和时间看 `marked_by_id` 与 `updated_at`；转出目标班记录在 `transfer_target_klass_id` 外键上。

| 事件 | 允许从 | 到 | 额外副作用 |
| --- | --- | --- | --- |
| `mark_absent` | `normal` / `filled` | `absent` | 记 `absent_at` |
| `mark_personal_leave` | `absent` / `normal` / `filled` | `personal_leave` | 记 `personal_leave_at`，**要求课次已开课** |
| `mark_sick_leave` | `absent` / `normal` / `filled` | `sick_leave` | 记 `sick_leave_at` |
| `mark_filled` | `absent` / `personal_leave` / `sick_leave` / `quit` / `transfer` | `filled` | 清空各类请假/退课时间戳 |
| `mark_quit` | `absent` / `normal` / `personal_leave` / `sick_leave` / `filled` / `transfer` | `quit` | 级联后续课次 + 报名转 `out` |
| `mark_transfer` | `absent` / `normal` / `personal_leave` / `sick_leave` / `quit` / `filled` | `transfer` | 级联后续课次 + 报名转 `transfer` |
| `mark_rejoin` | `quit` / `transfer` | `normal` | 当前及后续课次恢复 `normal` |

打标入口是 `PUT /admin/semester_klasses/:sk_id/courses/:course_id/attendances/:id/mark?status=...`，控制器按白名单分派 `mark_*!`，未知 status 会被忽略。

```mermaid
stateDiagram-v2
    [*] --> normal
    normal --> absent: mark_absent
    normal --> personal_leave: mark_personal_leave
    normal --> sick_leave: mark_sick_leave
    normal --> quit: mark_quit
    normal --> transfer: mark_transfer
    absent --> filled: mark_filled
    personal_leave --> filled: mark_filled
    sick_leave --> filled: mark_filled
    quit --> filled: mark_filled
    transfer --> filled: mark_filled
    quit --> normal: mark_rejoin
    transfer --> normal: mark_rejoin
```

### 5. 退课 / 转出的级联

在某课次标记 `quit` 或 `transfer` 时，不只是改这一条考勤：

- **后续所有课次**（`seq > 当前课次`）自动生成/更新考勤为 `quit` 或 `transfer`
- 对应的 `KlassStudent` 转为 `out`（退班）或 `transfer`（转出）
- 之后对该学员执行 `mark_rejoin`，当前及后续课次恢复 `normal`

`KlassStudent` 自身状态机：`in`（初始）→ `out` / `transfer`，`transfer` 与 `out` 之间可互相转换。

### 6. 班级报表

入口：`班级报表`（`GET /admin/semester_klasses/statement`），可按学期、年级、科目、教师、班型筛选，展示班级人数与三个比率。分母均为**当前在班学员数**。

| 指标 | 口径（以代码为准） |
| --- | --- |
| 新增率 `new_rate` | 当前在班学员中，未出现在**历史学期**（`seq` 更小）任何班级的占比 |
| 拓科率 `expand_rate` | 当前在班学员中，**上学期读过其他科目但未读过本科目**的占比 |
| 预留率 `reserve_rate` | 当前在班学员中，**下学期同科目班级**仍就读的占比 |

页面顶部还有 4 个汇总卡：统计班级数、在班学员人次、平均新增率、平均预留率。

### 7. 复制班级

入口：`复制班级`（`/admin/semester_klasses/copy`）。目标学期可选当前学期及其之后的学期（`seq >= current.seq`）；候选班级为 `seq < target.seq`，因此：

- 目标为当前学期时，来源是历史学期（原有能力）。
- 目标为未来学期时，来源包含历史学期和当前学期，可把本学期班级复制到新学期。

复制时按新表单重新生成班级：**归属目标学期与当前校区**、科目由所选教师带出、按 `times` 重建课次。学员改为搜索多选：默认勾选源班的在班学员，退课/转出默认不选；可搜索并勾选同年级其他学员一起带入，只加入与目标年级一致的学员。**不会**把源班级的报名关系直接带过来。

复制到未来学期后，会回到复制页并保留目标学期；班级详情仍需先把顶栏学期切换到目标学期才能查看。

### 8. 学期 / 校区切换

顶栏下拉切换后写入 session 与 `Current`；班级列表、班级详情、报表等都随之切换作用域。切换学期时若目标学期的班级不在当前上下文中，详情会打不开——先切换学期再进入对应班级。

## 页面入口

| 路径 | 用途 |
| --- | --- |
| `/` | 首页概览（学员 / 班级 / 课次 / 快捷入口） |
| `/admin/semester_klasses` | 班级管理 |
| `/admin/semester_klasses/statement` | 班级报表 |
| `/admin/semester_klasses/copy` | 复制班级（可选目标学期） |
| `/admin/teachers` | 教师管理 |
| `/admin/users` | 用户管理 |
| `/admin/schools` | 学校管理（校区、学期；年级科目已独立） |
| `/admin/grade_subjects` | 年级科目管理（按学期启用/取消组合并设置课次） |
| `/admin/day_schools` | 日校管理（按校区维护日校名单） |
| `/session/new` | 登录 |

除登录、密码相关页面与 `/up` 健康检查外，所有页面都要求登录。

## 测试

- `test/models/`：模型与状态机、报表口径、批量导入
- `test/controllers/`：各控制器 action 的功能测试（含鉴权、失败路径、副作用断言）
- `test/integration/`：重点业务场景端到端流程——班级全生命周期、跨学期报表、学期/校区切换与权限作用域

`bin/ci` 会跑完 rubocop、bundler-audit、importmap audit、brakeman、测试与 test 环境 `db:seed:replant`，与 CI 一致。

## 部署

Kamal，配置见 `config/deploy.yml`；生产使用 4 个 MySQL 库（主库 + cache / queue / cable），连接串由 `*_DATABASE_URL` secrets 提供，后三者通过 `config/database.yml` 的 `migrations_paths` 各自管理迁移（这些目录当前尚未在仓库中创建）。Solid Queue 跑在 Puma 进程内（`SOLID_QUEUE_IN_PUMA`）。

CI/CD：`.github/workflows/ci.yml` 在 PR 和 push `main` 时跑 `bin/ci`；`.github/workflows/cd.yml` 由 **CI 在 main 上成功完成后**触发 `kamal redeploy`，并固定签出 CI 验证过的那个 commit。推送 `main` 会触发部署，请谨慎。

镜像仓库为阿里云 ACR 个人版，不接受 OCI attestation manifest，因此 `config/deploy.yml` 关闭了 buildx 的 `provenance` / `sbom`。
