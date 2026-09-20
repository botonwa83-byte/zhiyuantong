# SDD ledger — plan: docs/superpowers/plans/2026-09-18-official-data-pipeline.md

Spec（binding authority）: docs/superpowers/specs/2026-09-18-official-data-pipeline-design.md

## Pre-flight rulings

- **Ruling: 仓库不在 git 版本控制下（`fatal: not a git repository`）。** 所有 `git add/commit` 步骤跳过；`sdd-workspace` / `task-brief` / `review-package` 脚本依赖 git，全部不可用，改用手写 brief 与文件快照评审。代价：无提交历史可回滚，靠 `raw/` 存档与 staging 覆盖式产物保证幂等。未擅自 `git init`。
- **Ruling: 本环境仅提供只读的 `code-explorer` 子代理，无可写代码能力的 general-purpose 子代理。** 实施改由控制器内联执行，每阶段末派只读子代理做评审门禁。代价：控制器上下文承担实现细节，评审仍有独立门禁。
- **Ruling: Python 依赖装进 `data-pipeline/.venv`，不污染系统 Python。** 命令里的 python 一律用 `.venv/bin/python`。代价：npm 脚本需指向 venv 解释器。

## Pre-flight scan（任务间接口冲突）

| 任务对 | 生产 / 消费 | 结论 |
| --- | --- | --- |
| T1 `YearContext` → T7 `run.py` | T1 出 `target_year/history_years/current_year`；T7 消费 | 一致，无冲突 |
| T2 契约表 → T6/T9/T11/T12 | T2 出 `TABLES`/`write_table`/`read_table`；其余消费 | 列名在各任务中逐字一致（`min_score`/`min_rank`/`prov_id`…），无冲突 |
| T3 `fetch_source` → T4 `parse_source` | T3 出 `Path`；T4 消费 `Path`+`options` | 一致 |
| T5 `normalize_rows` → T7 | T5 出 DataFrame；T7 写表 | 一致 |
| T11 vs T12 | 两端产物形状各自独立（Web `OfficialDataset` / iOS `bundle.json`） | 无共享文件冲突 |
| T8 山东「零核心代码改动」vs T7 | T8 要求仅加配置 | 与 T7 的 `run_province` 接口一致，可行 |

## Progress
