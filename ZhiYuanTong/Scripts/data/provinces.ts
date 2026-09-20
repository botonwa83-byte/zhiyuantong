import type { Province, Track, YearLines } from '../types'
import { extraProvinces } from './provincesExtra'

/** 用于趋势分析与等效分换算的历史年份（近三年） */
export const HISTORY_YEARS = [2022, 2023, 2024] as const
/** 当前填报年份（其批次线默认继承上一年，可在档案页校准） */
export const CURRENT_YEAR = 2025

function pair(phy: YearLines, his: YearLines): Record<Track, YearLines> {
  return { phy, his }
}

function both(y: YearLines): Record<Track, YearLines> {
  return { phy: y, his: { ...y } }
}

/**
 * 批次线数据（物理类 / 历史类）。
 * 说明：此处为基于各省教育考试院公开信息整理的近似值，仅用于演示；
 * 生产环境应替换为官方《一分一段表》与招生计划数据接口。
 */
const coreProvinces: Province[] = [
  {
    id: 'henan',
    name: '河南',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 509, undergrad: 405, college: 190, candidates: 125, ugPlan: 41 },
        { special: 527, undergrad: 445, college: 190, candidates: 125, ugPlan: 41 },
      ),
      2023: pair(
        { special: 514, undergrad: 409, college: 190, candidates: 131, ugPlan: 44 },
        { special: 547, undergrad: 465, college: 190, candidates: 131, ugPlan: 44 },
      ),
      2024: pair(
        { special: 511, undergrad: 396, college: 185, candidates: 136, ugPlan: 47 },
        { special: 521, undergrad: 428, college: 185, candidates: 136, ugPlan: 47 },
      ),
      2025: pair(
        { special: 512, undergrad: 398, college: 185, candidates: 138, ugPlan: 48 },
        { special: 522, undergrad: 430, college: 185, candidates: 138, ugPlan: 48 },
      ),
    },
  },
  {
    id: 'shandong',
    name: '山东',
    mode: '3+3',
    lines: {
      2022: both({ special: 513, undergrad: 437, college: 150, candidates: 87, ugPlan: 30 }),
      2023: both({ special: 520, undergrad: 443, college: 150, candidates: 98, ugPlan: 31 }),
      2024: both({ special: 521, undergrad: 444, college: 150, candidates: 100, ugPlan: 32 }),
      2025: both({ special: 522, undergrad: 445, college: 150, candidates: 102, ugPlan: 33 }),
    },
  },
  {
    id: 'guangdong',
    name: '广东',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 538, undergrad: 445, college: 180, candidates: 70, ugPlan: 32 },
        { special: 532, undergrad: 437, college: 180, candidates: 70, ugPlan: 32 },
      ),
      2023: pair(
        { special: 539, undergrad: 439, college: 180, candidates: 73, ugPlan: 33 },
        { special: 540, undergrad: 433, college: 180, candidates: 73, ugPlan: 33 },
      ),
      2024: pair(
        { special: 532, undergrad: 442, college: 200, candidates: 76, ugPlan: 34 },
        { special: 539, undergrad: 428, college: 200, candidates: 76, ugPlan: 34 },
      ),
      2025: pair(
        { special: 534, undergrad: 442, college: 200, candidates: 78, ugPlan: 35 },
        { special: 538, undergrad: 430, college: 200, candidates: 78, ugPlan: 35 },
      ),
    },
  },
  {
    id: 'sichuan',
    name: '四川',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 515, undergrad: 426, college: 150, candidates: 77, ugPlan: 28 },
        { special: 538, undergrad: 466, college: 150, candidates: 77, ugPlan: 28 },
      ),
      2023: pair(
        { special: 520, undergrad: 433, college: 150, candidates: 80, ugPlan: 29 },
        { special: 527, undergrad: 458, college: 150, candidates: 80, ugPlan: 29 },
      ),
      2024: pair(
        { special: 539, undergrad: 459, college: 150, candidates: 83, ugPlan: 30 },
        { special: 529, undergrad: 457, college: 150, candidates: 83, ugPlan: 30 },
      ),
      2025: pair(
        { special: 540, undergrad: 460, college: 150, candidates: 85, ugPlan: 31 },
        { special: 530, undergrad: 458, college: 150, candidates: 85, ugPlan: 31 },
      ),
    },
  },
  {
    id: 'hebei',
    name: '河北',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 487, undergrad: 430, college: 200, candidates: 75, ugPlan: 27 },
        { special: 506, undergrad: 443, college: 200, candidates: 75, ugPlan: 27 },
      ),
      2023: pair(
        { special: 492, undergrad: 439, college: 200, candidates: 86, ugPlan: 29 },
        { special: 495, undergrad: 430, college: 200, candidates: 86, ugPlan: 29 },
      ),
      2024: pair(
        { special: 484, undergrad: 448, college: 200, candidates: 88, ugPlan: 30 },
        { special: 506, undergrad: 449, college: 200, candidates: 88, ugPlan: 30 },
      ),
      2025: pair(
        { special: 486, undergrad: 448, college: 200, candidates: 90, ugPlan: 31 },
        { special: 505, undergrad: 449, college: 200, candidates: 90, ugPlan: 31 },
      ),
    },
  },
  {
    id: 'hunan',
    name: '湖南',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 475, undergrad: 414, college: 200, candidates: 65, ugPlan: 25 },
        { special: 499, undergrad: 451, college: 200, candidates: 65, ugPlan: 25 },
      ),
      2023: pair(
        { special: 477, undergrad: 415, college: 200, candidates: 68, ugPlan: 26 },
        { special: 482, undergrad: 428, college: 200, candidates: 68, ugPlan: 26 },
      ),
      2024: pair(
        { special: 481, undergrad: 422, college: 200, candidates: 73, ugPlan: 27 },
        { special: 496, undergrad: 438, college: 200, candidates: 73, ugPlan: 27 },
      ),
      2025: pair(
        { special: 482, undergrad: 424, college: 200, candidates: 75, ugPlan: 28 },
        { special: 497, undergrad: 440, college: 200, candidates: 75, ugPlan: 28 },
      ),
    },
  },
  {
    id: 'jiangsu',
    name: '江苏',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 516, undergrad: 429, college: 220, candidates: 40, ugPlan: 23 },
        { special: 525, undergrad: 471, college: 220, candidates: 40, ugPlan: 23 },
      ),
      2023: pair(
        { special: 512, undergrad: 448, college: 220, candidates: 45, ugPlan: 24 },
        { special: 527, undergrad: 474, college: 220, candidates: 45, ugPlan: 24 },
      ),
      2024: pair(
        { special: 516, undergrad: 462, college: 220, candidates: 48, ugPlan: 25 },
        { special: 530, undergrad: 478, college: 220, candidates: 48, ugPlan: 25 },
      ),
      2025: pair(
        { special: 518, undergrad: 463, college: 220, candidates: 49, ugPlan: 26 },
        { special: 531, undergrad: 479, college: 220, candidates: 49, ugPlan: 26 },
      ),
    },
  },
  {
    id: 'anhui',
    name: '安徽',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 491, undergrad: 435, college: 200, candidates: 60, ugPlan: 22 },
        { special: 523, undergrad: 480, college: 200, candidates: 60, ugPlan: 22 },
      ),
      2023: pair(
        { special: 482, undergrad: 427, college: 200, candidates: 64, ugPlan: 23 },
        { special: 495, undergrad: 440, college: 200, candidates: 64, ugPlan: 23 },
      ),
      2024: pair(
        { special: 496, undergrad: 465, college: 200, candidates: 65, ugPlan: 24 },
        { special: 512, undergrad: 462, college: 200, candidates: 65, ugPlan: 24 },
      ),
      2025: pair(
        { special: 498, undergrad: 466, college: 200, candidates: 67, ugPlan: 25 },
        { special: 513, undergrad: 463, college: 200, candidates: 67, ugPlan: 25 },
      ),
    },
  },
  {
    id: 'hubei',
    name: '湖北',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 504, undergrad: 409, college: 200, candidates: 46, ugPlan: 20 },
        { special: 527, undergrad: 435, college: 200, candidates: 46, ugPlan: 20 },
      ),
      2023: pair(
        { special: 525, undergrad: 424, college: 200, candidates: 50, ugPlan: 21 },
        { special: 527, undergrad: 426, college: 200, candidates: 50, ugPlan: 21 },
      ),
      2024: pair(
        { special: 525, undergrad: 437, college: 200, candidates: 52, ugPlan: 22 },
        { special: 530, undergrad: 432, college: 200, candidates: 52, ugPlan: 22 },
      ),
      2025: pair(
        { special: 526, undergrad: 438, college: 200, candidates: 53, ugPlan: 23 },
        { special: 531, undergrad: 434, college: 200, candidates: 53, ugPlan: 23 },
      ),
    },
  },
  {
    id: 'fujian',
    name: '福建',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 520, undergrad: 428, college: 220, candidates: 22, ugPlan: 11 },
        { special: 542, undergrad: 468, college: 220, candidates: 22, ugPlan: 11 },
      ),
      2023: pair(
        { special: 518, undergrad: 431, college: 220, candidates: 23, ugPlan: 12 },
        { special: 531, undergrad: 453, college: 220, candidates: 23, ugPlan: 12 },
      ),
      2024: pair(
        { special: 538, undergrad: 449, college: 220, candidates: 25, ugPlan: 12 },
        { special: 519, undergrad: 431, college: 220, candidates: 25, ugPlan: 12 },
      ),
      2025: pair(
        { special: 538, undergrad: 450, college: 220, candidates: 26, ugPlan: 13 },
        { special: 520, undergrad: 433, college: 220, candidates: 26, ugPlan: 13 },
      ),
    },
  },
  {
    id: 'zhejiang',
    name: '浙江',
    mode: '3+3',
    lines: {
      2022: both({ special: 592, undergrad: 497, college: 280, candidates: 36, ugPlan: 14 }),
      2023: both({ special: 594, undergrad: 488, college: 274, candidates: 39, ugPlan: 15 }),
      2024: both({ special: 595, undergrad: 492, college: 269, candidates: 40, ugPlan: 15.4 }),
      2025: both({ special: 596, undergrad: 490, college: 270, candidates: 41, ugPlan: 16 }),
    },
  },
  {
    id: 'beijing',
    name: '北京',
    mode: '3+3',
    lines: {
      2022: both({ special: 518, undergrad: 425, college: 120, candidates: 6.0, ugPlan: 4.2 }),
      2023: both({ special: 527, undergrad: 448, college: 120, candidates: 6.5, ugPlan: 4.4 }),
      2024: both({ special: 523, undergrad: 434, college: 120, candidates: 6.7, ugPlan: 4.5 }),
      2025: both({ special: 524, undergrad: 436, college: 120, candidates: 6.8, ugPlan: 4.6 }),
    },
  },
  {
    id: 'liaoning',
    name: '辽宁',
    mode: '3+1+2',
    lines: {
      2022: pair(
        { special: 502, undergrad: 362, college: 150, candidates: 24, ugPlan: 12 },
        { special: 504, undergrad: 404, college: 150, candidates: 24, ugPlan: 12 },
      ),
      2023: pair(
        { special: 494, undergrad: 360, college: 150, candidates: 24.5, ugPlan: 12.5 },
        { special: 495, undergrad: 404, college: 150, candidates: 24.5, ugPlan: 12.5 },
      ),
      2024: pair(
        { special: 510, undergrad: 368, college: 150, candidates: 25, ugPlan: 13 },
        { special: 510, undergrad: 400, college: 150, candidates: 25, ugPlan: 13 },
      ),
      2025: pair(
        { special: 510, undergrad: 370, college: 150, candidates: 25.5, ugPlan: 13.4 },
        { special: 510, undergrad: 402, college: 150, candidates: 25.5, ugPlan: 13.4 },
      ),
    },
  },
]

/** 全部省份（核心 + 扩充） */
export const provinces: Province[] = [...coreProvinces, ...extraProvinces]

export const provinceMap = new Map(provinces.map((p) => [p.id, p]))

export function getProvince(id: string): Province {
  return provinceMap.get(id) ?? provinces[0]
}

export function trackLabel(p: Province, t: Track): string {
  if (p.mode === '3+3') return '综合'
  return t === 'phy' ? '物理类' : '历史类'
}
