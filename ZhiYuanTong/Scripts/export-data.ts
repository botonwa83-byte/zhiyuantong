/**
 * 把本目录下的 TS 数据集导出成 iOS/macOS 端可直接 Codable 解码的 bundle.json。
 * 数据集是原生 App 的唯一数据来源，保存在 ZhiYuanTong/Scripts/data/。
 * 用法（项目根目录执行）：bash ZhiYuanTong/Scripts/sync-data.sh
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { provinces, CURRENT_YEAR, HISTORY_YEARS } from './data/provinces'
import { universitySeeds, cityHeat, setImportedUniversities } from './data/universities'
import { officialUniversitySeeds } from './data/universitiesFromOfficial'
import { majorProfiles } from './data/majors'
import { majorCareers, hotMajors, cityCareers } from './data/employment'
import { provinceBatches } from './data/batches'
import type {
  BatchRule,
  HotMajor,
  MajorCareer,
  MajorProfile,
  Province,
  Track,
  UniversitySeed,
} from './types'

// 输出路径以调用方的工作目录为准（sync-data.sh 已 cd 到项目根）
const OUT = resolve(
  process.cwd(),
  'ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json',
)

/** 省份：年份 × 科类的嵌套表 -> 扁平记录（Swift 侧 ProvinceDTO.lines） */
function toProvinceDTO(p: Province) {
  const lines = Object.entries(p.lines).flatMap(([year, byTrack]) =>
    (Object.keys(byTrack) as Track[]).map((track) => ({
      year: Number(year),
      track,
      ...byTrack[track],
    })),
  )
  return { id: p.id, name: p.name, mode: p.mode, lines }
}

/** 院校：原样透传（baseHis 缺省时省略该键，Swift 侧为 optional） */
function toUniversityDTO(s: UniversitySeed) {
  return {
    name: s.name,
    prov: s.prov,
    city: s.city,
    level: s.level,
    kind: s.kind,
    base: s.base,
    baseHis: s.baseHis,
    strengths: s.strengths,
    majors: s.majors,
    baoyan: s.baoyan,
    further: s.further,
    employRate: s.employRate,
    salary: s.salary,
    industries: s.industries,
    employers: s.employers,
  }
}

/** 学科门类 / 热门专业：起薪区间拆成 salaryMin / salaryMax */
function toCareerDTO(c: MajorCareer | HotMajor) {
  return {
    name: c.name,
    directions: c.directions,
    industries: c.industries,
    employRate: c.employRate,
    furtherRate: c.furtherRate,
    salaryMin: c.salaryRange[0],
    salaryMax: c.salaryRange[1],
    midSalary: c.midSalary,
    trend: c.trend,
    trendNote: c.trendNote,
    advice: c.advice,
    ...('schools' in c ? { schools: c.schools, subjects: c.subjects } : {}),
  }
}

/** 专业画像：salary 元组同样拆开，缺失风险项输出 null */
function toMajorProfileDTO(p: MajorProfile) {
  return {
    name: p.name,
    discipline: p.discipline,
    employRate: p.employRate,
    furtherRate: p.furtherRate,
    salaryMin: p.salary[0],
    salaryMax: p.salary[1],
    mid5y: p.mid5y,
    trend: p.trend,
    jobs: p.jobs,
    industries: p.industries,
    cities: p.cities,
    subjects: p.subjects,
    barrier: p.barrier,
    risk: p.risk ?? null,
  }
}

/** 内置官方数据里的院校（投档线覆盖到的院校）补进院校库，手工标注的条目仍以内置为准 */
setImportedUniversities(officialUniversitySeeds())

/** 批次规则：缺省字段补齐，Swift 侧全为非可选字段，避免解码失败 */
function toBatchRuleDTO(r: BatchRule) {
  return {
    kind: r.kind,
    name: r.name,
    order: r.order,
    max: r.max,
    mode: r.mode,
    unit: r.unit,
    allowAdjust: r.allowAdjust,
    majorsPerVol: r.majorsPerVol ?? null,
    note: r.note ?? null,
    verified: r.verified ?? false,
  }
}

const bundle = {
  currentYear: CURRENT_YEAR,
  historyYears: [...HISTORY_YEARS],
  provinces: provinces.map(toProvinceDTO),
  batchRules: provinceBatches.map((p) => ({
    provId: p.provId,
    year: p.year,
    earlyGroups: p.earlyGroups ?? [],
    batches: p.batches.map(toBatchRuleDTO),
    supplementNote: p.supplementNote ?? null,
  })),
  universities: universitySeeds().map(toUniversityDTO),
  cityHeat,
  majorProfiles: majorProfiles.map(toMajorProfileDTO),
  majorCareers: majorCareers.map(toCareerDTO),
  hotMajors: hotMajors.map(toCareerDTO),
  cityCareers: cityCareers.map((c) => ({ ...c })),
}

// 导出前校验：模式白名单 + 3+3 省份两轨必须一致（防止把物理/历史两套线误塞给不分科类的省份）
const MODES = new Set<Province['mode']>(['3+1+2', '3+3', '文理分科'])
for (const p of bundle.provinces) {
  if (!MODES.has(p.mode)) throw new Error(`未知考试模式：${p.name}(${p.id}) = ${p.mode}`)
  if (p.mode === '3+3') {
    const bad = p.lines
      .filter((l) => l.track === 'phy')
      .filter((l) => !p.lines.some((o) => o.year === l.year && o.track === 'his'
        && o.special === l.special && o.undergrad === l.undergrad && o.college === l.college))
    if (bad.length) throw new Error(`${p.name}(${p.id}) 为 3+3，物理/历史两轨必须一致，异常年份：${bad.map((b) => b.year).join(', ')}`)
  }
}

// 批次规则校验：省份必须存在、每个省必须有本科批与专科批、order 不重复、志愿数为正
const KINDS = new Set(['earlyUG', 'undergrad', 'special', 'earlyCollege', 'college', 'supplement'])
const provIds = new Set(bundle.provinces.map((p) => p.id))
for (const b of bundle.batchRules) {
  if (!provIds.has(b.provId)) throw new Error(`批次规则里的省份不存在：${b.provId}`)
  if (!b.batches.length) throw new Error(`${b.provId} 没有配置任何批次`)
  if (!b.batches.some((r) => r.kind === 'undergrad')) throw new Error(`${b.provId} 缺少本科批`)
  if (!b.batches.some((r) => r.kind === 'college' || r.kind === 'earlyCollege')) {
    throw new Error(`${b.provId} 缺少专科批`)
  }
  const orders = new Set<number>()
  for (const r of b.batches) {
    if (!KINDS.has(r.kind)) throw new Error(`${b.provId} 未知批次类型：${r.kind}`)
    if (r.max <= 0) throw new Error(`${b.provId}/${r.name} 志愿数必须为正：${r.max}`)
    if (orders.has(r.order)) throw new Error(`${b.provId}/${r.name} 录取顺序重复：${r.order}`)
    orders.add(r.order)
  }
}

mkdirSync(dirname(OUT), { recursive: true })
writeFileSync(OUT, JSON.stringify(bundle), 'utf8')

console.log(
  `bundle.json 已生成：${OUT}\n` +
    `省份 ${bundle.provinces.length} · 院校 ${bundle.universities.length} · ` +
    `专业 ${bundle.majorProfiles.length} · 门类 ${bundle.majorCareers.length} · ` +
    `热门专业 ${bundle.hotMajors.length} · 城市 ${bundle.cityCareers.length} · ` +
    `城市热度 ${Object.keys(bundle.cityHeat).length} · ` +
    `批次规则 ${bundle.batchRules.length} 省`,
)
