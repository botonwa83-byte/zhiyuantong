/**
 * 由内置官方数据生成院校库增量。
 *
 * - 院校清单：`Resources/Data/official/universities.csv`（数据管道按规范化名称聚合后的院校主数据）
 * - base / baseHis：用该院校在已内置省份的投档线反推「分数 - 当年特殊类型线」的线差中位数，
 *   比内置手工标注更贴合真实录取水平；没有投档线的院校按办学层次取保守估计。
 *
 * 目的：凡是内置了投档线的院校都能参与测算，而不是只有手工标注的那几百所。
 */
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { resolve } from 'node:path'
import { provinces } from './provinces'
import type { UniversitySeed } from '../types'

const OFFICIAL_DIR = resolve(
  process.cwd(),
  'ZhiYuanTong/ZhiYuanTong/Resources/Data/official',
)

/** 办学层次 -> 就业 / 深造的中位数（用于没有官方就业报告的院校，UI 会标注为模型估算） */
const LEVEL_DEFAULT: Record<string, { baoyan: number; further: number; employRate: number; salary: number; base: number }> = {
  顶尖985: { baoyan: 60, further: 82, employRate: 97, salary: 13000, base: 150 },
  985: { baoyan: 45, further: 70, employRate: 96, salary: 11000, base: 95 },
  211: { baoyan: 30, further: 52, employRate: 94, salary: 9500, base: 60 },
  双一流: { baoyan: 25, further: 45, employRate: 93, salary: 9000, base: 55 },
  省重点: { baoyan: 12, further: 30, employRate: 92, salary: 8000, base: 25 },
  普通本科: { baoyan: 5, further: 20, employRate: 90, salary: 7000, base: 5 },
  民办独立学院: { baoyan: 2, further: 10, employRate: 88, salary: 6200, base: -35 },
}

/** 极简 CSV 解析：院校名等字段不含分隔符，但仍按 RFC4180 处理引号 */
function parseCsv(text: string): Record<string, string>[] {
  const rows: string[][] = []
  let row: string[] = []
  let cell = ''
  let quoted = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') { cell += '"'; i++ } else { quoted = false }
      } else cell += ch
      continue
    }
    if (ch === '"') { quoted = true; continue }
    if (ch === ',') { row.push(cell); cell = ''; continue }
    if (ch === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; continue }
    if (ch !== '\r') cell += ch
  }
  if (cell.length || row.length) { row.push(cell); rows.push(row) }
  const head = rows.shift() ?? []
  return rows
    .filter((r) => r.some((c) => c.trim() !== ''))
    .map((r) => {
      const o: Record<string, string> = {}
      head.forEach((h, i) => { o[h.trim()] = (r[i] ?? '').trim() })
      return o
    })
}

function median(list: number[]): number {
  if (!list.length) return 0
  const s = [...list].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

/**
 * 批次归类优先级（与 App 侧 BatchKind 一致）：本科批 > 专科批 > 本科提前批 > 专项 > 专科提前批 > 其他。
 * 院校线只取主批次：本专科都招的院校若混算，会拿专科线当院校线（差 100+ 分）。
 */
function batchPriority(label: string): number {
  if (/专科|高职|二段/.test(label)) return label.includes('提前') ? 4 : 1
  if (/专项|预科|综合评价|特殊类型|南疆|援疆/.test(label)) return 3
  if (/提前|零志愿/.test(label)) return 2
  if (/本科|一段|一批|二批/.test(label)) return 0
  return 5
}

/**
 * 主批次样本：只用普通本科批 / 专科批（含一段、二段）。
 * 军校、综评、专项批的分数口径和普通批差太多（国防科大提前批样本能比普通批低 100 分），
 * 只有在完全没有普通批样本时才退回这些批次。
 */
function mainBatchSample(byBatch?: Map<string, { phy: number[]; his: number[] }>) {
  if (!byBatch || !byBatch.size) return null
  const pick = (maxPri: number) => {
    let best: { pri: number; bucket: { phy: number[]; his: number[] } } | null = null
    for (const [label, bucket] of byBatch) {
      const pri = batchPriority(label)
      if (pri > maxPri) continue
      if (!best || pri < best.pri) best = { pri, bucket }
    }
    return best
  }
  return (pick(1) ?? pick(5))?.bucket ?? null
}

/** 主批次没有文科样本时，退而取其它批次里优先级最高的文科样本 */
function fallbackHis(byBatch?: Map<string, { phy: number[]; his: number[] }>) {
  if (!byBatch) return null
  let best: { pri: number; his: number[] } | null = null
  for (const [label, bucket] of byBatch) {
    if (!bucket.his.length) continue
    const pri = batchPriority(label)
    if (!best || pri < best.pri) best = { pri, his: bucket.his }
  }
  return best ? best.his : null
}

/** 科类列名 -> 物理类 / 历史类（文理分科省份：理科对应 phy，文科对应 his） */
function trackOf(label: string): 'phy' | 'his' | null {
  if (/物理|理科|综合/.test(label)) return 'phy'
  if (/历史|文科/.test(label)) return 'his'
  return null
}

const provIdByName = new Map(provinces.map((p) => [p.name, p.id]))

/** 非 750 分制省份：分数与批次线口径不同，不能与其余省份的线差混算 */
const NON_750_PROVINCES = new Set(['hainan'])

function specialLine(provId: string, track: 'phy' | 'his', year: number): number | null {
  const p = provinces.find((x) => x.id === provId)
  const l = p?.lines[year]?.[track]
  return typeof l?.special === 'number' ? l.special : null
}

/**
 * 读取内置官方数据，生成院校库增量（与内置手工标注同名时以内置为准，由 universities.ts 合并）
 */
export function officialUniversitySeeds(): UniversitySeed[] {
  if (!existsSync(OFFICIAL_DIR)) return []
  const uniFile = resolve(OFFICIAL_DIR, 'universities.csv')
  if (!existsSync(uniFile)) return []

  // 1) 每所院校的线差样本（按批次 + 科类分开：本科批与专科批不能混算）
  const samples = new Map<string, Map<string, { phy: number[]; his: number[] }>>()
  const admissionFiles = readdirSync(OFFICIAL_DIR).filter((f) => f.endsWith('_admission.csv'))
  for (const file of admissionFiles) {
    const provId = file.replace(/_admission\.csv$/, '')
    // 非 750 分制省份（海南为 900 分制标准分）的分数与批次线口径不同，线差不可比，跳过
    if (NON_750_PROVINCES.has(provId)) continue
    for (const row of parseCsv(readFileSync(resolve(OFFICIAL_DIR, file), 'utf8'))) {
      const name = (row['院校名称'] ?? '').trim()
      const score = Number(row['最低分'])
      const year = Number(row['年份'] ?? '2025') || 2025
      const track = trackOf(row['科类'] ?? '')
      if (!name || !Number.isFinite(score) || !track) continue
      const special = specialLine(provId, track, year)
      if (special == null) continue
      let byBatch = samples.get(name)
      if (!byBatch) {
        byBatch = new Map()
        samples.set(name, byBatch)
      }
      const label = (row['批次'] ?? '').trim()
      const bucket = byBatch.get(label) ?? { phy: [], his: [] }
      bucket[track].push(score - special)
      byBatch.set(label, bucket)
    }
  }

  // 2) 院校主数据 -> seed
  const seeds: UniversitySeed[] = []
  for (const row of parseCsv(readFileSync(uniFile, 'utf8'))) {
    const name = (row['name'] ?? '').trim()
    if (!name) continue
    const level = (row['level'] ?? '普通本科').trim() || '普通本科'
    const def = LEVEL_DEFAULT[level] ?? LEVEL_DEFAULT['普通本科']
    const byBatch = samples.get(name)
    const main = mainBatchSample(byBatch)
    const base = main && main.phy.length ? median(main.phy) : def.base
    const his = main && main.his.length ? main.his : fallbackHis(byBatch)
    const baseHis = his && his.length ? median(his) : undefined
    seeds.push({
      name,
      prov: provIdByName.get((row['prov'] ?? '').trim()) ?? '',
      city: (row['city'] ?? '').trim(),
      level,
      kind: (row['kind'] ?? '').trim(),
      base: Math.round(base * 10) / 10,
      baseHis: baseHis == null ? undefined : Math.round(baseHis * 10) / 10,
      strengths: [],
      majors: [],
      baoyan: def.baoyan,
      further: def.further,
      employRate: def.employRate,
      salary: def.salary,
      industries: [],
      employers: [],
    })
  }
  return seeds
}
