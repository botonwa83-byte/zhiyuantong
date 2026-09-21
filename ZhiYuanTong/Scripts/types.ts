/** 全局类型定义 */

export type Track = 'phy' | 'his'
/**
 * 省份高考模式：
 * - 3+1+2：首选科目物理/历史，一分一段与投档线分「物理类 / 历史类」公布
 * - 3+3：不分科类，只有一个综合位次（UI 不提供科类选择）
 * - 文理分科：老高考，分「理科 / 文科」（新疆、西藏 2027 年才首考新高考）
 */
export type ExamMode = '3+1+2' | '3+3' | '文理分科'

export interface YearLines {
  /** 特殊类型招生控制线（近似“一本 / 强基线”） */
  special: number
  /** 本科批控制线 */
  undergrad: number
  /** 专科批控制线 */
  college: number
  /** 报考人数（万人） */
  candidates: number
  /** 本科招生计划（万人），用于估算录取率 */
  ugPlan: number
}

export interface Province {
  id: string
  name: string
  mode: ExamMode
  /** 年份 -> 科类 -> 批次线 */
  lines: Record<number, Record<Track, YearLines>>
}

export type UniLevel = '顶尖985' | '985' | '211' | '双一流' | '省重点' | '普通本科' | '民办/独立学院'
export type UniKind =
  | '综合'
  | '理工'
  | '师范'
  | '财经'
  | '政法'
  | '医药'
  | '农林'
  | '语言'
  | '艺术'
  | '军工'

/** 智能生成志愿表的梯度策略：冲 / 稳 / 保 的分配倾向 */
export type GenStrategy = '冲刺' | '均衡' | '保守'

/**
 * 院校库条目。
 * 除 name 外全部可选：官方数据集（dist/universities_full.csv）不提供 city / kind / base / 就业类字段，
 * 缺失字段必须走降级逻辑（展示「暂无官方数据」或用同层次推算），严禁编造数值。
 */
export interface UniversitySeed {
  name: string
  /** 官方院校代码（数据管道产物） */
  uniCode?: string
  /** 学校所在省份 id */
  prov?: string
  city?: string
  level?: UniLevel
  kind?: UniKind
  /** 物理类：相对特殊类型线的基准线差 */
  base?: number
  /** 历史类基准线差（缺省按 base-6 处理） */
  baseHis?: number
  /** 优势学科 */
  strengths?: string[]
  /** 王牌专业 */
  majors?: string[]
  /** 保研率 % */
  baoyan?: number
  /** 深造率 % */
  further?: number
  /** 就业率 % */
  employRate?: number
  /** 应届平均月薪（元） */
  salary?: number
  /** 主要就业行业 */
  industries?: string[]
  /** 代表雇主 */
  employers?: string[]
  /** 办学性质：公办 / 民办 / 独立学院（官方数据集提供） */
  nature?: string
  /** 来自官方数据集导入（非内置手工标注） */
  imported?: boolean
}

/** 单年录取数据（由基准线差 + 省份 + 年份确定性推导） */
export interface YearAdmission {
  year: number
  /** 最低录取分 */
  score: number
  /** 最低录取位次 */
  rank: number
  /** 相对当年特殊类型线的线差 */
  diff: number
  /** 该省投放计划数 */
  plan: number
  /** 投档人数（估算） */
  applicants: number
  /** 录取率（估算） */
  admitRate: number
  /** 是否来自官方导入的投档线 */
  official?: boolean
}

export interface UniversityRecord {
  seed: UniversitySeed
  provId: string
  track: Track
  years: YearAdmission[]
  /** 近三年平均分 */
  avgScore: number
  /** 近三年平均线差 */
  avgDiff: number
  /** 近三年平均位次 */
  avgRank: number
  /** 三年线差波动（标准差） */
  volatility: number
  /** 三年线差变化（2024 - 2022） */
  delta3: number
  /** 热度指数 0-100 */
  heat: number
  /** 今年等效分（按今年批次线换算往年位次） */
  equivScore: number
  /** 该省是否为本省院校 */
  inProvince: boolean
  /** 三年中来自官方导入数据的年份数 */
  officialYears: number
}

export interface StudentProfile {
  id: string
  phone: string
  name: string
  provId: string
  track: Track
  score: number
  /** 手动位次（可为空，自动估算） */
  rank?: number
  subjects: string[]
  /** 意向城市 */
  cities: string[]
  /** 意向门类 */
  majors: string[]
  obeyAdjust: boolean
  /** 智能生成志愿表时的梯度策略 */
  strategy?: GenStrategy
  /** 智能生成志愿表时是否优先省内院校 */
  preferProvince?: boolean
  /** 智能生成志愿表时选中的热门专业（细分方向，区别于 majors 的学科门类） */
  hotMajors?: string[]
  /** 当年批次线校准（考生按官方公布数据填写） */
  linesOverride?: { special?: number; undergrad?: number; college?: number }
  createdAt: number
}

export interface VolunteerItem {
  uniName: string
  tier: '冲' | '稳' | '保'
  prob: number
  note?: string
}

/** 学科门类就业数据 */
export interface MajorCareer {
  name: string
  directions: string[]
  industries: string[]
  /** 就业率 % */
  employRate: number
  /** 深造率 % */
  furtherRate: number
  /** 应届起薪区间 */
  salaryRange: [number, number]
  /** 工作 5 年月薪中位数 */
  midSalary: number
  trend: '上升' | '平稳' | '承压'
  trendNote: string
  advice: string
}

export interface HotMajor extends MajorCareer {
  /** 代表性院校 */
  schools: string[]
  /** 建议选科 */
  subjects: string
}

/**
 * 录取批次归类（与 App 侧 BatchKind 一一对应）。
 * - earlyUG 本科提前批 / undergrad 本科批 / special 专项与特殊类型
 * - earlyCollege 专科提前批 / college 专科批 / supplement 征集志愿（补录）
 */
export type BatchKindId =
  | 'earlyUG'
  | 'undergrad'
  | 'special'
  | 'earlyCollege'
  | 'college'
  | 'supplement'

/** 志愿单位：group 院校专业组（有专业调剂），major 专业（类）+学校（无调剂） */
export type VolunteerUnit = 'group' | 'major'
/** 投档模式：parallel 平行志愿，sequential 顺序/有序/梯度志愿（第一志愿优先） */
export type VolunteerMode = 'parallel' | 'sequential'

export interface BatchRule {
  kind: BatchKindId
  /** 省里的官方批次名，如「本科提前批」「普通类一段」 */
  name: string
  /** 录取顺序，数字越小越先录（前一批次录取后，后续批次志愿作废） */
  order: number
  /** 志愿数上限 */
  max: number
  mode: VolunteerMode
  unit: VolunteerUnit
  /** 是否可以服从专业调剂（专业+学校模式没有调剂） */
  allowAdjust: boolean
  /** 每个志愿可填的专业数（院校专业组模式，默认 6） */
  majorsPerVol?: number
  note?: string
  /** 是否已按当年官方文件逐条核对（false 时 UI 提示「规则待核对」） */
  verified?: boolean
}

export interface ProvinceBatches {
  provId: string
  year: number
  /** 提前批类别（军事/公安/…）：各省多规定各类别之间不得兼报 */
  earlyGroups?: string[]
  batches: BatchRule[]
  /** 征集志愿（补录）提示：投档线数据里没有征集志愿，只能提示考生盯公告 */
  supplementNote?: string
}

export interface CityCareer {
  name: string
  industries: string[]
  /** 平均招聘月薪 */
  salary: number
  /** 生活成本指数（100 = 全国均值） */
  cost: number
  settle: '容易' | '中等' | '较难'
  /** 就业景气指数 0-100 */
  prosperity: number
  policy: string
  note: string
}
