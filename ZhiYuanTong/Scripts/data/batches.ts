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
      rule('earlyCollege', '专科提前批', 3, 64, 'parallel', 'major', {
        allowAdjust: false,
        verified: true,
        note: '定向培养军士、公安、司法等，64 个专业+院校平行志愿，各类不得兼报',
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
      rule('earlyUG', '提前批 A 类', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、公安政法、消防救援、综合评价、高水平运动队等；第 1 次填 1 个学校志愿，第 2 次可填 4 个顺序学校志愿，每校 6 个专业 + 调剂',
      }),
      major('earlyUG', '提前批 B 类', 2, 60, {
        verified: true,
        note: '公费师范生、省属公费生、定向培养军士生等本专科计划，分 4 个招生类型只能选一类，60 个专业+学校',
      }),
      major('undergrad', '常规批（第 1 次·本科）', 3, 96, {
        verified: true,
        note: '一段线及以上考生填报本科志愿；含高校专项计划（2026 年起不再单独设特殊类型批）',
      }),
      major('college', '常规批（第 2、3 次·本专科）', 4, 96, {
        verified: true,
        note: '二段线及以上考生（含一段线未录取）填报本专科志愿',
      }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '山东提前批 A、B 两类不得兼报。',
  },
  {
    provId: 'hebei',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '顺序志愿：军队、公安、飞行、司法、航海、综合评价等，每次 1 所学校 + 6 个专业 + 专业服从调剂',
      }),
      major('earlyUG', '本科提前批 B 段', 2, 96, {
        verified: true,
        note: '国家专项、高校专项、公费师范生（含优师专项）、免费医学定向生，专业（类）+学校平行',
      }),
      rule('earlyUG', '本科提前批 C 段', 3, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '高水平运动队、定向就业招生，1 所学校 + 6 个专业 + 调剂，不征集',
      }),
      major('undergrad', '本科批', 4, 96, {
        verified: true,
        note: '专业（类）+学校，无专业调剂，每个志愿都必须能接受；含地方专项、预科班',
      }),
      rule('earlyCollege', '专科提前批', 5, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士、公安、司法等，1 所学校 + 6 个专业 + 调剂',
      }),
      major('college', '专科批', 6, 96, { verified: true, note: '1 次集中填报 + 3 次征集志愿，每次最多 96 个' }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'sichuan',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '本科提前批 · 国家专项', 1, 6, { verified: true, note: '2026 年由 2 个扩容至 6 个院校专业组平行志愿' }),
      rule('earlyUG', '本科提前批 A 段', 2, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、公安、综合评价等，顺序志愿：1 个第一志愿 + 2 个平行的第二志愿，第一志愿没录上会大幅掉档，必须放在「稳」',
      }),
      group('earlyUG', '本科提前批 · 高校专项', 3, 6, { verified: true, note: '2026 年由 2 个扩容至 6 个院校专业组平行志愿' }),
      group('earlyUG', '本科提前批 B 段', 4, 30, {
        verified: true,
        note: '公费师范生、定向医学生等，30 个院校专业组平行志愿',
      }),
      group('undergrad', '本科批 A 段 · 国家专项', 5, 20, { verified: true, note: '须先通过国家专项资格审核' }),
      group('undergrad', '本科批 A 段 · 地方专项', 6, 20, { verified: true, note: '须先通过地方专项资格审核' }),
      group('undergrad', '本科批 B 段', 7, 45, { verified: true }),
      rule('earlyCollege', '专科提前批', 8, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士、公安、司法、航海等，1 个第一志愿 + 2 个平行的第二志愿',
      }),
      group('college', '专科批', 9, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'guangdong',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      group('earlyUG', '提前批', 1, 20, {
        verified: true,
        note: '军事、公安、师范、医学定向等，20 个院校专业组平行志愿；民航招飞等单志愿另设',
      }),
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
      group('earlyUG', '本科提前批', 1, 20, { verified: true, note: '军事、公安、公费师范、定向医学生等' }),
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
      group('earlyUG', '本科提前批', 1, 20, { verified: true, note: '军事、公安、司法、公费师范等，20 个院校专业组平行志愿' }),
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
      rule('earlyUG', '普通类提前录取', 1, 5, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '传统志愿（顺序志愿）：5 个院校志愿，每校 6 个专业 + 专业服从调剂；军事、公安、定向等需体检政审',
      }),
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
      rule('earlyUG', '本科提前批', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '常规志愿：1 个第一志愿 + 3 个平行且有顺序的参考志愿；征求志愿 1 次设 8 个',
      }),
      group('undergrad', '本科批', 2, 40, {
        verified: true,
        note: '40 个院校专业组平行志愿，不得重复填报同一院校专业组；2 次征求志愿各 20 个',
      }),
      major('earlyCollege', '高职专科提前批', 3, 40, {
        verified: true,
        note: '专业志愿（专业+院校），本科批全部录取结束后进行',
      }),
      major('college', '高职专科批', 4, 40, { verified: true, note: '专业志愿（专业+院校）' }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '福建本科批 2 次征求志愿各 20 个，高职专科批 2 次征求各 20 个，本科提前批征求 1 次 8 个。',
  },
  {
    provId: 'jiangxi',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '提前本科 · 军事类单志愿', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '空军、海军飞行员，不征集',
      }),
      group('earlyUG', '提前本科 · 军警类平行志愿', 2, 45, {
        verified: true,
        note: '军事、警察、中央司法、消防救援院校；征集志愿时设 20 个',
      }),
      rule('earlyUG', '提前本科 · 非军警类单志愿', 3, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '小语种、马列理论、综合评价等',
      }),
      group('earlyUG', '提前本科 · 定向招生平行志愿', 4, 45, {
        verified: true,
        note: '公费师范生、优师专项等定向计划；征集志愿时设 20 个',
      }),
      rule('undergrad', '本科批 · 特殊选拔单志愿', 5, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '仅取得高校专项、高水平运动队资格的考生填报，平行志愿投档前完成',
      }),
      group('undergrad', '本科批', 6, 45, {
        verified: true,
        note: '国家专项、地方专项、苏区专项及预科班仅限取得相应资格的考生填报',
      }),
      group('earlyCollege', '提前高职专科 · 定向培养军士', 7, 45, { verified: true }),
      rule('earlyCollege', '提前高职专科 · 单志愿', 8, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '公安、司法高校等有特殊要求的专科专业',
      }),
      group('college', '高职专科批', 9, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '江西各批次征集志愿一般设 20 个院校专业组平行志愿（单志愿栏设 1 个）。',
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
      major('earlyUG', '本科提前批 B 段', 2, 60, {
        verified: true,
        note: '公安院校公安类、国家公费师范生、航海类等艰苦专业、小语种、马理专业等，60 个专业+学校平行志愿',
      }),
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
      major('earlyUG', '本科提前批 A 段（公安类）', 1, 60, {
        verified: true,
        note: '公安院校公安类专业，60 个专业平行志愿；与 A 段其他类不能兼报',
      }),
      rule('earlyUG', '本科提前批 A 段（其他类）', 2, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、消防、综合评价等，1 个学校 + 6 个专业 + 调剂；与公安类不能兼报',
      }),
      major('earlyUG', '本科提前批 B 段', 3, 60, {
        verified: true,
        note: '国家专项、高校专项、农村订单定向医学生、公费师范生（含优师专项、全科教师）等',
      }),
      major('undergrad', '本科批', 4, 96, {
        verified: true,
        note: '专业（类）平行志愿，含地方专项、少数民族预科班、民族班、定向招生',
      }),
      rule('earlyCollege', '高职专科提前批', 5, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士等，1 个学校 + 6 个专业 + 调剂',
      }),
      major('college', '高职专科批', 6, 96, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '民航飞行技术安排在本科提前批之前设 2 个平行志愿，高水平运动队在高校普通计划所在批次之前设 1 个院校志愿。',
  },
  {
    provId: 'guizhou',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军队、公安、司法等需政审面试体检的院校，1 个院校志愿 + 6 个专业',
      }),
      rule('earlyUG', '本科提前批 B 段', 2, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '高水平运动队、高校专项计划等特殊类型，1 个院校志愿 + 6 个专业',
      }),
      major('earlyUG', '本科提前批 C 段', 3, 60, {
        verified: true,
        note: '国家公费师范生、优师计划、免费医学生等定向培养，专业（类）+院校平行',
      }),
      major('undergrad', '本科批', 4, 96, { verified: true, note: '含预科、民族班、国家专项与地方专项计划' }),
      rule('earlyCollege', '高职专科提前批', 5, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士等有特殊要求的专业，1 个院校志愿 + 6 个专业',
      }),
      major('college', '高职专科批', 6, 96, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'shanxi',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军队院校军事类专业、高校综合评价、参加我省统一录取的香港高校',
      }),
      group('earlyUG', '本科提前批 B 段', 2, 45, {
        verified: true,
        note: '公安司法及专项计划、消防救援、公费师范生、优师专项、小语种、马理专业、提前批定向等',
      }),
      rule('earlyUG', '本科提前批 C 段', 3, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '地方优师专项、农村订单定向免费医学生、公费农科生、航海类',
      }),
      group('undergrad', '本科批', 4, 45, {
        verified: true,
        note: '2026 年首年新高考；高校专项自 2026 年起并入本批平行志愿栏',
      }),
      group('undergrad', '本科批 · 预科班', 5, 7, {
        verified: true,
        note: '仅具备预科班资格的考生填报，平行志愿',
      }),
      rule('special', '本科批 · 高水平运动队', 6, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '仅具备相应资格的考生填报',
      }),
      rule('earlyCollege', '专科提前批', 7, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士生、公安司法类、航海类等',
      }),
      group('college', '专科批', 8, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'shaanxi',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 · 军队院校招飞', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '空军航空大学、海军航空大学等',
      }),
      group('earlyUG', '本科提前批 · 军队院校（非招飞）', 2, 6, {
        verified: true,
        note: '6 个院校专业组平行志愿',
      }),
      group('earlyUG', '本科提前批 · 公安院校公安专业', 3, 6, { verified: true }),
      group('earlyUG', '本科提前批 · 公费师范生及优师专项', 4, 6, { verified: true }),
      group('earlyUG', '本科提前批 · 免费医学定向生', 5, 6, { verified: true }),
      rule('earlyUG', '本科提前批 · 其他特殊要求院校', 6, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '综合评价招生、民航招飞、航海类等',
      }),
      group('undergrad', '本科批', 7, 45, { verified: true }),
      group('college', '专科批', 8, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE + '陕西本科提前批各类别之间不得兼报。',
  },
  {
    provId: 'gansu',
    year: 2026,
    earlyGroups: EARLY_GROUPS,
    batches: [
      rule('earlyUG', '本科提前批 A 段（顺序）', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '顺序志愿部分（军警等需体检政审的院校）：1 个院校专业组 + 6 个专业 + 调剂，第一志愿要稳',
      }),
      group('earlyUG', '本科提前批 A 段（平行）', 2, 30, {
        verified: true,
        note: '2025 年起 A 段增加平行志愿投档，30 个院校专业组；同一院校属哪一类以招生计划为准',
      }),
      group('undergrad', '本科批 B 段', 3, 1, { verified: true, note: '高校专项等特殊类型，1 个院校专业组' }),
      group('undergrad', '本科批 C 段', 4, 45, { verified: true }),
      rule('earlyCollege', '专科提前批 D 段', 5, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士等，2 个顺序院校专业组',
      }),
      group('earlyCollege', '专科提前批 E 段', 6, 45, { verified: true }),
      group('college', '专科批 F 段', 7, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'ningxia',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、司法、消防、招收飞行员、航海类、免费医学生、综合评价等',
      }),
      group('earlyUG', '本科提前批 B 段', 2, 20, {
        verified: true,
        note: '公安、公费师范生、优师专项、小语种、马克思主义理论专业等',
      }),
      rule('undergrad', '本科批 A 段', 3, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '高水平运动队、高校专项计划',
      }),
      group('undergrad', '本科批 B 段', 4, 45, {
        verified: true,
        note: '普通类本科及国家/地方专项、民族班、预科班、定向招生等',
      }),
      rule('earlyCollege', '高职专科提前批 A 段', 5, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '普通类公安专业',
      }),
      group('earlyCollege', '高职专科提前批 B 段', 6, 20, { verified: true, note: '定向培养军士' }),
      group('college', '高职专科批', 7, 45, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'jilin',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、公安、公费师范、优师专项、综合评价等，1 个院校专业组 + 6 个专业 + 调剂',
      }),
      rule('earlyUG', '本科提前批 B 段', 2, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '高校专项、高水平运动队等特殊类型',
      }),
      group('undergrad', '本科批', 3, 40, { verified: true }),
      rule('earlyCollege', '专科提前批', 4, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        note: '顺序志愿，志愿个数待核对',
      }),
      group('college', '专科批', 5, 40, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'heilongjiang',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 · 招收飞行学员院校', 1, 3, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '梯度志愿：1 个空飞 + 1 个海飞 + 1 个民飞院校专业组',
      }),
      rule('earlyUG', '本科提前批 · 综合评价及特殊要求院校', 2, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '北京电子科技学院、中央司法警官学院、香港中文大学等',
      }),
      rule('earlyUG', '本科提前批 · 军队院校', 3, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
      }),
      group('earlyUG', '本科提前批 · 提前录取普通院校', 4, 20, {
        verified: true,
        note: '公安消防院校、航海类、国家公费师范生、优师专项、地方公费师范生、免费医学生等',
      }),
      group('earlyUG', '本科提前批 · 省内公安院校', 5, 5, {
        verified: true,
        note: '黑龙江公安警官职业学院',
      }),
      rule('special', '本科批 · 特殊类型招生', 6, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '高水平运动队',
      }),
      group('undergrad', '本科批', 7, 45, { verified: true }),
      group('earlyCollege', '高职专科提前批 A 段', 8, 10, {
        verified: true,
        note: '高本贯通培养、航海类、地方免费医学生、公安司法等',
      }),
      rule('earlyCollege', '高职专科提前批 B 段', 9, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士',
      }),
      group('college', '高职专科批', 10, 40, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'neimenggu',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '综合评价、高水平运动队、艺术类校考及戏曲类省际联考等，一般不征集志愿',
      }),
      group('earlyUG', '本科提前批 B 段', 2, 60, {
        verified: true,
        majorsPerVol: 12,
        note: '军事、公安、公费师范生、优师计划、农村订单定向免费医学生等',
      }),
      group('undergrad', '本科批', 3, 60, {
        verified: true,
        majorsPerVol: 12,
        note: '2026 年由 45 个扩容至 60 个院校专业组，每个志愿 12 个专业 + 调剂',
      }),
      rule('earlyCollege', '高职专科提前批', 4, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        note: '定向培养军士等，志愿个数待核对',
      }),
      group('college', '专科批', 5, 60, { verified: true, majorsPerVol: 12 }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'guangxi',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 · 空军招飞类', 1, 1, 'sequential', 'group', {
        majorsPerVol: 20,
        verified: true,
      }),
      group('earlyUG', '本科提前批 · 其他一类', 2, 20, {
        verified: true,
        majorsPerVol: 20,
        note: '航海类、公费师范生等',
      }),
      group('earlyUG', '本科提前批 · 其他二类', 3, 20, {
        verified: true,
        majorsPerVol: 20,
        note: '军事、公安等',
      }),
      rule('earlyUG', '本科提前批 · 其他三类', 4, 1, 'sequential', 'group', {
        majorsPerVol: 20,
        verified: true,
      }),
      group('undergrad', '本科普通批', 5, 40, {
        verified: true,
        majorsPerVol: 20,
        note: '高校专项计划 2026 年起并入本批，不再单设特殊类型批',
      }),
      rule('special', '其他预科批', 6, 1, 'sequential', 'group', {
        majorsPerVol: 20,
        verified: true,
        note: '边防军人子女预科班、免费少数民族预科班等',
      }),
      rule('earlyCollege', '高职高专提前批 · 定向类', 7, 1, 'sequential', 'group', {
        majorsPerVol: 20,
        verified: true,
        note: '免费医学生等',
      }),
      group('earlyCollege', '高职高专提前批 · 其他类', 8, 20, { verified: true, majorsPerVol: 20 }),
      group('college', '高职高专普通批', 9, 40, { verified: true, majorsPerVol: 20 }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'yunnan',
    year: 2026,
    batches: [
      group('earlyUG', '提前本科批 B 段', 1, 10, {
        verified: true,
        majorsPerVol: 10,
        note: '每个院校专业组设 10 个专业志愿 + 1 个「专业服从院校调剂」',
      }),
      group('earlyUG', '提前本科批 C 段', 2, 1, { verified: true, majorsPerVol: 10 }),
      group('earlyUG', '提前本科批 D 段', 3, 10, { verified: true, majorsPerVol: 10 }),
      group('undergrad', '本科批 A 段', 4, 1, {
        verified: true,
        majorsPerVol: 10,
        note: '高校专项等特殊类型，1 个院校专业组',
      }),
      group('undergrad', '本科批 B 段', 5, 40, {
        verified: true,
        majorsPerVol: 10,
        note: '符合国家/地方专项或少数民族预科条件的考生可各增加 10 个志愿',
      }),
      group('earlyCollege', '提前高职专科批 B 段', 6, 1, { verified: true, majorsPerVol: 10 }),
      group('college', '高职专科批', 7, 20, { verified: true, majorsPerVol: 10 }),
      group('special', '高本贯通批', 8, 20, { verified: true, majorsPerVol: 1 }),
    ],
    supplementNote:
      SUPPLEMENT_NOTE +
      '提前本科批 A 段（优师专项、免费定向）与提前高职专科批 A 段按县（市、区）定向填报，每个县区志愿含 1 个专业志愿 + 若干院校志愿，本 App 不生成，请按考试院定向计划填。',
  },
  {
    provId: 'tianjin',
    year: 2026,
    batches: [
      rule('earlyUG', '提前本科 · 军队招飞', 1, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '顺序志愿，仅限军队招飞定选合格考生',
      }),
      group('earlyUG', '提前本科 · 民航招飞', 2, 2, {
        verified: true,
        majorsPerVol: 6,
        note: '平行志愿，仅限民航招飞体检合格考生',
      }),
      rule('earlyUG', '提前本科 A 阶段', 3, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、消防、公安、司法、综合评价、航海类、非通用语种、马理专业、公费师范生等',
      }),
      group('earlyUG', '提前本科 B 阶段', 4, 5, {
        verified: true,
        majorsPerVol: 6,
        note: '地方农村专项计划，仅限宁河、武清、静海、宝坻、蓟州 5 区符合条件的考生',
      }),
      group('undergrad', '本科批 A 段', 5, 50, { verified: true }),
      group('undergrad', '本科批 B 段', 6, 25, { verified: true }),
      rule('earlyCollege', '提前高职专科批', 7, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '定向培养军士院校，须与提前本科批次同时填报',
      }),
      group('college', '专科批', 8, 20, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'beijing',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 A 段', 1, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、公安、公费师范等，2 个顺序志愿',
      }),
      group('earlyUG', '本科提前批 B 段', 2, 20, {
        verified: true,
        note: '双培计划、外培计划、农村专项等，20 个院校专业组平行志愿，无征集志愿',
      }),
      rule('special', '特殊类型招生', 3, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '高水平运动队等，在提前批之后、本科普通批之前录取',
      }),
      group('undergrad', '本科普通批', 4, 30, { verified: true }),
      rule('earlyCollege', '专科提前批', 5, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '普通类 2 个顺序志愿（艺术类另设 20 个平行志愿）',
      }),
      group('college', '专科普通批', 6, 20, { verified: true }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'shanghai',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批次', 1, 4, 'sequential', 'group', {
        majorsPerVol: 4,
        verified: true,
        note: '含地方农村专项计划批次，4 个顺序志愿',
      }),
      group('undergrad', '本科普通批次', 2, 24, { verified: true, majorsPerVol: 4 }),
      rule('earlyCollege', '专科提前批次', 3, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
      }),
      group('college', '专科普通批次', 4, 8, {
        verified: true,
        majorsPerVol: 6,
        note: '2026 年专科批次志愿数由 10 个调整为 8 个院校志愿',
      }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'hainan',
    year: 2026,
    batches: [
      group('earlyUG', '本科提前部分 · 普通类', 1, 6, {
        verified: true,
        majorsPerVol: 6,
        note: '军事、公安、司法、定向培养等',
      }),
      group('undergrad', '本科普通批', 2, 30, {
        verified: true,
        majorsPerVol: 6,
        note: '含本科少数民族班；海南总分 900 分制，批次线与投档线均为标准分',
      }),
      group('undergrad', '本科预科班', 3, 6, { verified: true, majorsPerVol: 6 }),
      group('undergrad', '本科批 · 国家专项计划', 4, 10, { verified: true, majorsPerVol: 6 }),
      group('undergrad', '本科批 · 地方专项计划', 5, 10, { verified: true, majorsPerVol: 6 }),
      group('college', '专科批', 6, 10, { verified: true, majorsPerVol: 6 }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'qinghai',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批次 ①段', 1, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '军事、航海类等艰苦专业、未组织体检面试的公安类专业，国际关系学院、上海海关学院及港澳院校等',
      }),
      major('earlyUG', '本科提前批次 ②段', 2, 60, {
        verified: true,
        note: '需政审面试体检的公安司法消防公共安全类、本研衔接国家公费师范生、国家优师专项、马理专业',
      }),
      major('earlyUG', '本科提前批次 ③段', 3, 60, {
        verified: true,
        note: '定向就业（清华定向、非西藏生源定向西藏、青苗计划等）与省级公费师范生（地方优师专项）',
      }),
      major('special', '本科提前批次 ④段 · 专项计划', 4, 60, {
        verified: true,
        note: '国家专项、地方专项、高校专项',
      }),
      major('special', '本科提前批次 ⑤段 · 省内专项', 5, 60, {
        verified: true,
        note: '省内生态专项、乡村振兴专项、民族地区教育高质量发展专项（A、B 类）',
      }),
      major('earlyCollege', '专科提前批次 ⑥段', 6, 60, {
        verified: true,
        note: '专科层次公安、司法、定向培养军士',
      }),
      major('undergrad', '本科批次 ⑦段', 7, 96, { verified: true, note: '不设专业调剂' }),
      rule('earlyCollege', '专科提前批次 ⑧段', 8, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '航海类、石家庄邮电/西安电力/山东电力订单培养',
      }),
      major('college', '高职专科批次 ⑩段', 9, 96, { verified: true, note: '不设专业调剂' }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'xinjiang',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批 · 军队公安政法消防类', 1, 4, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '梯度志愿 4 个，每个志愿 6 个专业；可与「其他提前单独录取」兼报，与体育类不能兼报',
      }),
      rule('earlyUG', '本科提前批 · 其他提前单独录取', 2, 4, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
      }),
      group('special', '国家及地方专项 · 本科一批', 3, 6, {
        verified: true,
        majorsPerVol: 6,
        note: '含南疆单列、对口援疆计划',
      }),
      rule('special', '高水平运动队 · 本科一批', 4, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
      }),
      group('undergrad', '本科一批', 5, 18, {
        verified: true,
        majorsPerVol: 6,
        note: '平行志愿，含高校专项计划（2026 年起不再单设批次）',
      }),
      group('special', '国家及地方专项 · 本科二批', 6, 6, { verified: true, majorsPerVol: 6 }),
      rule('special', '高水平运动队 · 本科二批', 7, 1, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
      }),
      group('undergrad', '本科二批', 8, 18, { verified: true, majorsPerVol: 6 }),
      rule('earlyCollege', '高职专科提前批', 9, 2, 'sequential', 'group', {
        majorsPerVol: 6,
        verified: true,
        note: '公安政法、定向培养军士生、南疆单列计划等',
      }),
      group('college', '高职专科批', 10, 18, {
        majorsPerVol: 6,
        verified: false,
        note: '志愿数量以当年《在疆招生计划专业目录》为准，待核对',
      }),
    ],
    supplementNote: SUPPLEMENT_NOTE,
  },
  {
    provId: 'xizang',
    year: 2026,
    batches: [
      rule('earlyUG', '本科提前批', 1, 10, 'sequential', 'group', {
        majorsPerVol: 6,
        note: '军警、司法类等提前批为顺序志愿，第一志愿尤其关键；志愿数待核对',
      }),
      group('undergrad', '本科批', 2, 30, {
        note: '2026 年为西藏传统高考最后一年（2027 年起新高考），志愿数以考试院当年公布为准',
      }),
      group('college', '专科批', 3, 30, { note: '志愿数以考试院当年公布为准' }),
    ],
    supplementNote:
      SUPPLEMENT_NOTE + '西藏各批次志愿数未获取到 2026 年官方文件，请务必以西藏自治区教育考试院当年公布为准。',
  },
]
