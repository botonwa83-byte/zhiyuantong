/**
 * 各省录取批次规则（志愿设置）：批次顺序、志愿数上限、平行/顺序志愿、志愿单位。
 *
 * 来源：2026 年各省教育考试院文件与教育在线（eol.cn）/高考 100 的全省汇总（docs/BATCH_DESIGN.md 第五节）。
 * 规则只用于「按批次生成志愿表」的裁剪与梯度分配，**正式填报必须以考生当年官方文件为准**：
 * 未逐条核对官方文件的批次标 verified: false，UI 要提示「规则待核对」。
 *
 * 志愿单位：
 * - group：院校专业组（每个志愿 = 一所院校的一个专业组，组内若干专业 + 是否服从调剂）
 * - major：专业（类）+学校（一个志愿 = 一个具体专业，没有专业调剂）
 */
import type { BatchRule, ProvinceBatches } from '../types'

/** 提前批常见的类别：各省基本都规定各类别之间不得兼报 */
const EARLY_GROUPS = ['军事', '公安', '司法', '师范（公费/优师）', '医学（定向）', '飞行/航海', '其他']

/** 征集志愿（补充批）统一提示：投档线数据里没有征集志愿，只能提示考生盯官方公告 */
const SUPPLEMENT_NOTE =
  '征集志愿（补录）在每批次录取结束后由省考试院公布缺额计划，数据不在本 App 内。' +
  '留意省考试院公告，往年征集志愿降分幅度多在 5~20 分，个别冷门院校/专业可降更多。'

function rule(
  kind: BatchRule['kind'],
  name: string,
  order: number,
  max: number,
  mode: BatchRule['mode'],
  unit: BatchRule['unit'],
  extra: Partial<BatchRule> = {},
): BatchRule {
  return { kind, name, order, max, mode, unit, allowAdjust: unit === 'group', verified: false, ...extra }
}

/** 院校专业组模式的通用配置（每组 6 个专业 + 1 个调剂选项） */
function group(
  kind: BatchRule['kind'],
  name: string,
  order: number,
  max: number,
  extra: Partial<BatchRule> = {},
): BatchRule {
  return rule(kind, name, order, max, 'parallel', 'group', { majorsPerVol: 6, ...extra })
}

/** 专业（类）+学校模式（无专业调剂） */
function major(
  kind: BatchRule['kind'],
  name: string,
  order: number,
  max: number,
  extra: Partial<BatchRule> = {},
): BatchRule {
  return rule(kind, name, order, max, 'parallel', 'major', { allowAdjust: false, ...extra })
}

export const provinceBatches: ProvinceBatches[] = [
  {
    provId: 'henan',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批', 1, 64, 'parallel', 'major', {
        allowAdjust: false,
        verified: true,
        note: '军事、公安、司法、师范、医学等各类别不得兼报，多数需体检/政审/面试',
      }),
      group('undergrad', '本科批', 2, 48, { verified: true }),
      rule('earlyCollege', '专科提前批', 3, 32, 'sequential', 'major', {
        allowAdjust: false,
        note: '定向培养军士等，顺序志愿，第一志愿要稳',
      }),
      group('college', '专科批', 4, 48, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '河南本科批、专科批录取后各安排征集志愿。',
  },
  {
    provId: 'shandong',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      major('earlyUG', '提前批 A 类', 1, 96, {
        verified: false,
        note: '与提前批 B 类不得兼报；含军事、公安、综合评价等需体检政审的类别',
      }),
      major('earlyUG', '提前批 B 类', 2, 96, { verified: false, note: '与 A 类不得兼报' }),
      rule('special', '特殊类型批', 3, 1, 'sequential', 'major', {
        allowAdjust: false,
        note: '高校专项计划等，需先通过资格审核',
      }),
      major('undergrad', '常规批（一段）', 4, 96, { verified: true }),
      major('college', '常规批（二段）', 5, 96, { verified: true, note: '一段录取结束后的剩余计划与专科计划' }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'hebei',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      major('earlyUG', '本科提前批 A 段', 1, 96, { verified: false, note: '军事、公安、飞行等需体检政审面试' }),
      major('earlyUG', '本科提前批 B 段', 2, 96, { verified: false, note: '国家专项、公费师范生等' }),
      major('earlyUG', '本科提前批 C 段', 3, 96, { verified: false, note: '高水平运动队、艺术类等特殊类型' }),
      major('undergrad', '本科批', 4, 96, {
        verified: true,
        note: '专业（类）+学校，无专业调剂，每个志愿都必须能接受',
      }),
      major('earlyCollege', '专科提前批', 5, 96, { verified: false }),
      major('college', '专科批', 6, 96, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'sichuan',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '顺序志愿：1 个第一志愿 + 2 个平行的第二志愿，第一志愿没录上会大幅掉档，必须放在「稳」',
      }),
      group('earlyUG', '本科提前批 B 段', 2, 45, { verified: false, note: '国家专项、公费师范生等（顺序志愿）' }),
      group('undergrad', '本科批 A 段', 3, 20, { verified: true, note: '国家专项、高校专项等特殊计划' }),
      group('undergrad', '本科批 B 段', 4, 45, { verified: true }),
      group('college', '专科批', 5, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'guangdong',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '提前批', 1, 20, { verified: false, note: '军事、公安、师范、医学定向等' }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'jiangsu',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: true }),
      group('undergrad', '本科批', 2, 40, { verified: true }),
      group('college', '专科批', 3, 40, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'anhui',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'hunan',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 45, {
        verified: true,
        note: '45 个院校专业组平行志愿 + 1 个单志愿（民航飞行、农村订单定向医学生）',
      }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 30, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'hubei',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 30, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'zhejiang',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '普通类提前批', 1, 5, { verified: false, note: '军事、公安、定向等，需体检政审' }),
      major('undergrad', '普通类一段', 2, 80, { verified: true, note: '专业平行志愿，无调剂' }),
      major('college', '普通类二段', 3, 80, { verified: true, note: '一段录取后的剩余计划与专科计划' }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'fujian',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 50, {
        verified: true,
        note: '常规志愿 50 个院校专业组，录取后另有 2 次征求志愿',
      }),
      group('college', '专科批', 3, 30, { verified: false }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '福建本科批、专科批各安排 2 次征求志愿。',
  },
  {
    provId: 'jiangxi',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'liaoning',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 2, 'sequential', 'group', {
        majorsPerVol: 4,
        verified: true,
        note: '有序志愿：2 个有序院校志愿，每个院校 4 个专业 + 专业服从',
      }),
      group('earlyUG', '本科提前批 B 段', 2, 60, { verified: false }),
      major('undergrad', '本科批', 3, 112, { verified: true, note: '专业+学校，志愿数全国最多，无调剂' }),
      rule('earlyCollege', '专科提前批', 4, 2, 'sequential', 'group', {
        majorsPerVol: 4,
        verified: true,
        note: '有序志愿：2 个有序院校志愿',
      }),
      major('college', '专科批', 5, 60, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'chongqing',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      major('undergrad', '本科批', 2, 96, { verified: true, note: '专业（类）平行志愿' }),
      major('college', '专科批', 3, 96, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'guizhou',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      major('undergrad', '本科批', 2, 96, { verified: true }),
      major('college', '专科批', 3, 96, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'shanxi',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true, note: '2026 年首年新高考，院校专业组平行志愿' }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'shaanxi',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'gansu',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'ningxia',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'jilin',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 40, { verified: true }),
      group('college', '专科批', 3, 40, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'heilongjiang',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 45, { verified: true }),
      group('college', '专科批', 3, 40, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'neimenggu',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 60, { verified: true, majorsPerVol: 12, note: '每个志愿可填 12 个专业' }),
      group('college', '专科批', 3, 60, { verified: true, majorsPerVol: 12 }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'guangxi',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 40, { verified: true }),
      group('college', '专科批', 3, 40, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'yunnan',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批 B 段', 2, 40, { verified: true }),
      group('college', '专科批', 3, 20, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'tianjin',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批 A 段', 2, 50, { verified: true }),
      group('undergrad', '本科批 B 段', 3, 25, { verified: true }),
      group('college', '专科批', 4, 20, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'beijing',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 30, { verified: true }),
      group('college', '专科批', 3, 20, { verified: false }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'shanghai',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 24, { verified: true, majorsPerVol: 4 }),
      group('college', '专科批', 3, 20, { verified: false }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'hainan',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科批', 2, 30, { verified: true, note: '海南总分 900 分制，批次线与投档线均为标准分' }),
      group('college', '专科批', 3, 10, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'qinghai',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      major('undergrad', '本科批', 2, 96, { verified: true }),
      major('college', '专科批', 3, 96, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'xinjiang',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 20, { verified: false }),
      group('undergrad', '本科一批', 2, 18, {
        verified: true,
        mode: 'sequential',
        note: '老高考梯度志愿：1 个第一志愿 + 若干平行参考志愿，第一志愿优先',
      }),
      group('undergrad', '本科二批', 3, 18, { verified: true, mode: 'sequential' }),
      group('college', '专科批', 4, 18, { verified: true, mode: 'sequential' }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'xizang',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前批', 1, 10, { verified: false }),
      group('undergrad', '本科批', 2, 30, { verified: false }),
      group('college', '专科批', 3, 30, { verified: false }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
]
