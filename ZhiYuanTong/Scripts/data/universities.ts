import type { UniversitySeed } from '../types'
import { extraCityHeat, extraSeeds } from './universitiesExtra'

/**
 * 院校库（示例数据）。
 * base = 该校在「物理类」相对特殊类型招生控制线的基准线差，用于推导近三年录取分/位次；
 * 生产环境请替换为各省教育考试院公布的《投档线 + 一分一段表》原始数据。
 */
const coreSeeds: UniversitySeed[] = [
  // ================= 顶尖 985 =================
  { name: '清华大学', prov: 'beijing', city: '北京', level: '顶尖985', kind: '综合', base: 186, baseHis: 168, strengths: ['计算机科学与技术', '电气工程', '材料科学与工程', '核科学与技术'], majors: ['计算机科学与技术', '电子信息工程', '电气工程及其自动化', '经济与金融'], baoyan: 76, further: 88, employRate: 98.5, salary: 14500, industries: ['信息技术', '高端制造', '金融', '科研院所'], employers: ['华为', '中金公司', '国家电网', '航天科技集团'] },
  { name: '北京大学', prov: 'beijing', city: '北京', level: '顶尖985', kind: '综合', base: 184, baseHis: 172, strengths: ['数学', '物理学', '化学', '中国语言文学', '临床医学'], majors: ['数学与应用数学', '计算机科学与技术', '经济学', '临床医学', '法学'], baoyan: 74, further: 86, employRate: 98, salary: 14000, industries: ['信息技术', '金融', '教育科研', '医疗卫生'], employers: ['中金公司', '华为', '中信集团', '字节跳动'] },
  { name: '上海交通大学', prov: 'shanghai', city: '上海', level: '顶尖985', kind: '理工', base: 150, baseHis: 138, strengths: ['船舶与海洋工程', '机械工程', '临床医学', '计算机科学与技术'], majors: ['计算机科学与技术', '电子信息工程', '机械工程', '临床医学', '金融学'], baoyan: 66, further: 82, employRate: 98, salary: 13500, industries: ['高端制造', '信息技术', '医疗健康', '金融'], employers: ['华为', '上汽集团', '中国商飞', '瑞金医院'] },
  { name: '复旦大学', prov: 'shanghai', city: '上海', level: '顶尖985', kind: '综合', base: 148, baseHis: 145, strengths: ['数学', '理论经济学', '新闻传播学', '临床医学'], majors: ['经济学', '数学与应用数学', '新闻学', '临床医学', '计算机科学与技术'], baoyan: 65, further: 84, employRate: 97.6, salary: 13200, industries: ['金融', '信息技术', '医疗健康', '文化传媒'], employers: ['中金公司', '腾讯', '复旦大学附属医院', '上汽集团'] },
  { name: '浙江大学', prov: 'zhejiang', city: '杭州', level: '顶尖985', kind: '综合', base: 145, baseHis: 138, strengths: ['计算机科学与技术', '光学工程', '控制科学与工程', '农业工程'], majors: ['计算机科学与技术', '电子信息工程', '自动化', '人工智能', '临床医学'], baoyan: 62, further: 80, employRate: 97.5, salary: 12800, industries: ['信息技术', '高端制造', '数字经济', '医疗健康'], employers: ['阿里巴巴', '华为', '海康威视', '网易'] },
  { name: '中国科学技术大学', prov: 'anhui', city: '合肥', level: '顶尖985', kind: '理工', base: 143, strengths: ['物理学', '化学', '天文学', '核科学与技术'], majors: ['物理学', '计算机科学与技术', '化学', '人工智能', '少年班'], baoyan: 68, further: 88, employRate: 96, salary: 13000, industries: ['科研教育', '信息技术', '半导体', '新能源'], employers: ['中科院各所', '华为', '中科寒武纪', '比亚迪'] },
  { name: '南京大学', prov: 'jiangsu', city: '南京', level: '顶尖985', kind: '综合', base: 140, baseHis: 136, strengths: ['天文学', '地质学', '计算机科学与技术', '图书情报'], majors: ['计算机科学与技术', '天文学', '化学', '经济学', '汉语言文学'], baoyan: 62, further: 82, employRate: 97, salary: 12500, industries: ['信息技术', '金融', '科研教育', '软件服务'], employers: ['华为', '腾讯', '中金公司', '中国电科'] },
  { name: '中国人民大学', prov: 'beijing', city: '北京', level: '顶尖985', kind: '综合', base: 132, baseHis: 140, strengths: ['理论经济学', '法学', '新闻传播学', '工商管理'], majors: ['经济学', '法学', '金融学', '新闻学', '人力资源管理'], baoyan: 55, further: 76, employRate: 97, salary: 12500, industries: ['金融', '公共管理', '法律', '互联网'], employers: ['中金公司', '四大行总行', '国家部委', '字节跳动'] },

  // ================= 985 =================
  { name: '哈尔滨工业大学', prov: 'heilongjiang', city: '哈尔滨', level: '985', kind: '理工', base: 120, strengths: ['航空宇航科学与技术', '机械工程', '材料科学', '控制科学与工程'], majors: ['航天工程', '机械设计制造', '计算机科学与技术', '自动化', '材料科学与工程'], baoyan: 55, further: 75, employRate: 96, salary: 11800, industries: ['航天军工', '高端制造', '信息技术', '新能源'], employers: ['航天科技集团', '华为', '中国电科', '比亚迪'] },
  { name: '北京航空航天大学', prov: 'beijing', city: '北京', level: '985', kind: '军工', base: 118, strengths: ['航空宇航科学与技术', '计算机科学与技术', '材料科学与工程'], majors: ['飞行器设计与工程', '计算机科学与技术', '人工智能', '自动化'], baoyan: 57, further: 78, employRate: 97, salary: 12500, industries: ['航空航天', '信息技术', '军工', '科研院所'], employers: ['航天科技集团', '中国商飞', '华为', '航空工业集团'] },
  { name: '北京理工大学', prov: 'beijing', city: '北京', level: '985', kind: '军工', base: 110, strengths: ['兵器科学与技术', '机械工程', '信息与通信工程'], majors: ['弹药工程与爆炸技术', '车辆工程', '计算机科学与技术', '光电信息科学与工程'], baoyan: 52, further: 74, employRate: 96.5, salary: 11500, industries: ['军工', '汽车', '信息技术', '智能制造'], employers: ['兵器工业集团', '中国电科', '比亚迪', '百度'] },
  { name: '同济大学', prov: 'shanghai', city: '上海', level: '985', kind: '理工', base: 108, strengths: ['土木工程', '建筑学', '交通运输工程'], majors: ['土木工程', '建筑学', '城乡规划', '计算机科学与技术'], baoyan: 50, further: 72, employRate: 96.5, salary: 12000, industries: ['建筑设计', '土木工程', '汽车', '信息技术'], employers: ['中建集团', '上汽集团', '同济设计院', '华为'] },
  { name: '武汉大学', prov: 'hubei', city: '武汉', level: '985', kind: '综合', base: 100, baseHis: 104, strengths: ['测绘科学与技术', '法学', '马克思主义理论', '水利工程'], majors: ['测绘工程', '法学', '计算机科学与技术', '新闻传播', '口腔医学'], baoyan: 48, further: 70, employRate: 96, salary: 11200, industries: ['信息技术', '测绘地理信息', '法律', '医疗健康'], employers: ['华为', '腾讯', '中国电科', '武汉大学人民医院'] },
  { name: '华中科技大学', prov: 'hubei', city: '武汉', level: '985', kind: '理工', base: 98, strengths: ['机械工程', '光学工程', '电气工程', '公共卫生'], majors: ['机械设计制造', '电气工程', '计算机科学与技术', '临床医学', '光电信息'], baoyan: 48, further: 72, employRate: 96.5, salary: 11500, industries: ['高端制造', '光电信息', '医疗健康', '电力'], employers: ['华为', '国家电网', '联影医疗', '小米'] },
  { name: '西安交通大学', prov: 'shaanxi', city: '西安', level: '985', kind: '理工', base: 96, strengths: ['动力工程及工程热物理', '电气工程', '管理科学与工程'], majors: ['能源与动力工程', '电气工程', '机械工程', '工业工程'], baoyan: 50, further: 72, employRate: 96, salary: 11000, industries: ['能源电力', '高端制造', '信息技术', '军工'], employers: ['国家电网', '中国西电', '华为', '航天科技集团'] },
  { name: '东南大学', prov: 'jiangsu', city: '南京', level: '985', kind: '理工', base: 94, strengths: ['建筑学', '土木工程', '电子科学与技术'], majors: ['建筑学', '信息工程', '计算机科学与技术', '土木工程'], baoyan: 48, further: 70, employRate: 96, salary: 11500, industries: ['建筑设计', '电子信息', '通信', '交通'], employers: ['华为', '中国电科', '中建集团', '中兴通讯'] },
  { name: '中山大学', prov: 'guangdong', city: '广州', level: '985', kind: '综合', base: 92, baseHis: 96, strengths: ['工商管理', '临床医学', '生态学'], majors: ['临床医学', '计算机科学与技术', '经济学', '工商管理'], baoyan: 46, further: 70, employRate: 96, salary: 11500, industries: ['医疗健康', '信息技术', '金融', '生物医药'], employers: ['腾讯', '华为', '中山大学附属医院', '招商银行'] },
  { name: '南开大学', prov: 'tianjin', city: '天津', level: '985', kind: '综合', base: 90, baseHis: 94, strengths: ['数学', '化学', '应用经济学'], majors: ['数学与应用数学', '经济学', '化学', '历史学'], baoyan: 47, further: 70, employRate: 95.5, salary: 10800, industries: ['金融', '信息技术', '化学化工', '教育科研'], employers: ['中金公司', '华为', '渤海银行', '天津一汽'] },
  { name: '天津大学', prov: 'tianjin', city: '天津', level: '985', kind: '理工', base: 88, strengths: ['化学工程与技术', '建筑学', '仪器科学与技术'], majors: ['化学工程与工艺', '建筑学', '计算机科学与技术', '精密仪器'], baoyan: 46, further: 68, employRate: 96, salary: 11000, industries: ['化工能源', '建筑设计', '信息技术', '智能制造'], employers: ['中石化', '中国电科', '华为', '中建集团'] },
  { name: '北京师范大学', prov: 'beijing', city: '北京', level: '985', kind: '师范', base: 88, baseHis: 94, strengths: ['教育学', '心理学', '中国语言文学'], majors: ['心理学', '教育学', '汉语言文学', '数学与应用数学'], baoyan: 50, further: 66, employRate: 95.5, salary: 10000, industries: ['教育', '公共管理', '互联网', '文化传媒'], employers: ['各地教育局/重点中学', '字节跳动', '学而思', '人民出版社'] },
  { name: '厦门大学', prov: 'fujian', city: '厦门', level: '985', kind: '综合', base: 84, baseHis: 88, strengths: ['会计学', '工商管理', '海洋科学'], majors: ['会计学', '金融学', '计算机科学与技术', '海洋科学'], baoyan: 45, further: 66, employRate: 96, salary: 11000, industries: ['金融财会', '信息技术', '海洋经济', '外贸'], employers: ['四大会计师事务所', '华为', '厦门航空', '建发集团'] },
  { name: '电子科技大学', prov: 'sichuan', city: '成都', level: '985', kind: '理工', base: 86, strengths: ['电子科学与技术', '信息与通信工程', '计算机科学与技术'], majors: ['电子信息工程', '计算机科学与技术', '通信工程', '微电子科学与工程'], baoyan: 45, further: 70, employRate: 97, salary: 12500, industries: ['半导体', '通信', '信息技术', '军工电子'], employers: ['华为', '中兴通讯', '中国电科', '腾讯'] },
  { name: '华南理工大学', prov: 'guangdong', city: '广州', level: '985', kind: '理工', base: 80, strengths: ['轻工技术与工程', '材料科学与工程', '建筑学'], majors: ['计算机科学与技术', '材料科学与工程', '建筑学', '食品科学与工程'], baoyan: 42, further: 62, employRate: 96.5, salary: 11500, industries: ['先进制造', '信息技术', '新材料', '食品'], employers: ['华为', '腾讯', '美的集团', '南方电网'] },
  { name: '华东师范大学', prov: 'shanghai', city: '上海', level: '985', kind: '师范', base: 78, baseHis: 84, strengths: ['教育学', '软件工程', '地理学'], majors: ['软件工程', '教育学', '心理学', '统计学'], baoyan: 44, further: 62, employRate: 96, salary: 10400, industries: ['教育', '信息技术', '金融', '公共管理'], employers: ['上海重点中学', '字节跳动', '招商银行', '上海市公务员'] },
  { name: '西北工业大学', prov: 'shaanxi', city: '西安', level: '985', kind: '军工', base: 82, strengths: ['航空宇航科学与技术', '材料科学与工程', '计算机科学与技术'], majors: ['飞行器设计与工程', '计算机科学与技术', '材料科学与工程', '自动化'], baoyan: 48, further: 72, employRate: 96, salary: 11200, industries: ['航空航天', '军工', '信息技术', '新材料'], employers: ['航空工业集团', '航天科技集团', '华为', '中国船舶'] },
  { name: '四川大学', prov: 'sichuan', city: '成都', level: '985', kind: '综合', base: 70, baseHis: 74, strengths: ['口腔医学', '材料科学与工程', '化学工程'], majors: ['口腔医学', '临床医学', '计算机科学与技术', '高分子材料'], baoyan: 40, further: 60, employRate: 95.5, salary: 10500, industries: ['医疗健康', '信息技术', '新材料', '化工'], employers: ['华西医院', '华为', '通威集团', '腾讯'] },
  { name: '中南大学', prov: 'hunan', city: '长沙', level: '985', kind: '理工', base: 68, strengths: ['冶金工程', '矿业工程', '临床医学'], majors: ['计算机科学与技术', '冶金工程', '临床医学', '交通运输'], baoyan: 40, further: 60, employRate: 95.5, salary: 10500, industries: ['有色冶金', '轨道交通', '医疗健康', '信息技术'], employers: ['中国中车', '华为', '湘雅医院', '中国五矿'] },
  { name: '山东大学', prov: 'shandong', city: '济南', level: '985', kind: '综合', base: 66, baseHis: 70, strengths: ['数学', '材料科学与工程', '临床医学'], majors: ['数学与应用数学', '临床医学', '计算机科学与技术', '电气工程'], baoyan: 40, further: 60, employRate: 95, salary: 10200, industries: ['医疗健康', '信息技术', '电力', '教育科研'], employers: ['国家电网', '华为', '齐鲁医院', '海尔集团'] },
  { name: '吉林大学', prov: 'jilin', city: '长春', level: '985', kind: '综合', base: 60, strengths: ['化学', '车辆工程', '法学'], majors: ['车辆工程', '化学', '计算机科学与技术', '法学'], baoyan: 38, further: 58, employRate: 94.5, salary: 9800, industries: ['汽车', '化工', '信息技术', '法律'], employers: ['一汽集团', '华为', '比亚迪', '吉林大学第一医院'] },
  { name: '大连理工大学', prov: 'liaoning', city: '大连', level: '985', kind: '理工', base: 64, strengths: ['力学', '化学工程与技术', '机械工程'], majors: ['机械设计制造', '化学工程与工艺', '计算机科学与技术', '土木工程'], baoyan: 40, further: 60, employRate: 95, salary: 10200, industries: ['装备制造', '化工', '船舶', '信息技术'], employers: ['大连船舶重工', '华为', '中石化', '英特尔大连'] },
  { name: '湖南大学', prov: 'hunan', city: '长沙', level: '985', kind: '综合', base: 62, baseHis: 66, strengths: ['土木工程', '化学', '设计学'], majors: ['土木工程', '计算机科学与技术', '工业设计', '金融学'], baoyan: 38, further: 58, employRate: 95, salary: 10200, industries: ['建筑工程', '信息技术', '金融', '汽车'], employers: ['中建五局', '华为', '三一重工', '招商银行'] },
  { name: '重庆大学', prov: 'chongqing', city: '重庆', level: '985', kind: '理工', base: 62, strengths: ['电气工程', '机械工程', '建筑学'], majors: ['电气工程', '计算机科学与技术', '土木工程', '机械工程'], baoyan: 38, further: 58, employRate: 95, salary: 10000, industries: ['电力', '建筑', '汽车', '信息技术'], employers: ['国家电网', '长安汽车', '中建集团', '腾讯'] },
  { name: '中国农业大学', prov: 'beijing', city: '北京', level: '985', kind: '农林', base: 56, strengths: ['农学', '生物学', '食品科学与工程'], majors: ['农学', '食品科学与工程', '动物医学', '计算机科学与技术'], baoyan: 42, further: 62, employRate: 94, salary: 9500, industries: ['现代农业', '食品', '生物技术', '公共管理'], employers: ['中粮集团', '农业农村部系统', '伊利集团', '先正达'] },
  { name: '东北大学', prov: 'liaoning', city: '沈阳', level: '985', kind: '理工', base: 52, strengths: ['冶金工程', '控制科学与工程', '计算机科学与技术'], majors: ['计算机科学与技术', '自动化', '冶金工程', '机器人工程'], baoyan: 34, further: 54, employRate: 94, salary: 9600, industries: ['钢铁冶金', '工业自动化', '信息技术', '机器人'], employers: ['鞍钢集团', '华为', '东软集团', '新松机器人'] },
  { name: '兰州大学', prov: 'gansu', city: '兰州', level: '985', kind: '综合', base: 48, baseHis: 54, strengths: ['化学', '大气科学', '生态学'], majors: ['化学', '物理学', '草业科学', '计算机科学与技术'], baoyan: 40, further: 60, employRate: 93, salary: 9000, industries: ['科研教育', '化工', '气象环保', '信息技术'], employers: ['中科院各所', '兰州石化', '华为', '各地高校'] },
  { name: '中国海洋大学', prov: 'shandong', city: '青岛', level: '985', kind: '农林', base: 50, strengths: ['海洋科学', '水产'], majors: ['海洋科学', '水产养殖学', '计算机科学与技术', '环境科学'], baoyan: 36, further: 56, employRate: 94, salary: 9500, industries: ['海洋经济', '水产', '环保', '科研'], employers: ['自然资源部系统', '海尔集团', '中船集团', '青岛港'] },
  { name: '中央民族大学', prov: 'beijing', city: '北京', level: '985', kind: '综合', base: 48, baseHis: 54, strengths: ['民族学', '社会学', '中国语言文学'], majors: ['民族学', '法学', '新闻学', '计算机科学与技术'], baoyan: 34, further: 54, employRate: 93, salary: 9200, industries: ['公共管理', '文化传媒', '教育', '信息技术'], employers: ['各地公务员系统', '字节跳动', '民族出版社', '四大行'] },
  { name: '西北农林科技大学', prov: 'shaanxi', city: '咸阳', level: '985', kind: '农林', base: 38, strengths: ['农学', '林学', '葡萄酒工程'], majors: ['农学', '林学', '食品科学与工程', '动物医学'], baoyan: 36, further: 56, employRate: 92, salary: 8500, industries: ['现代农业', '食品', '林草', '科研'], employers: ['中粮集团', '农业农村部系统', '张裕集团', '各地农科院'] },
  { name: '国防科技大学', prov: 'hunan', city: '长沙', level: '985', kind: '军工', base: 112, strengths: ['计算机科学与技术', '航空宇航科学与技术', '大气科学'], majors: ['计算机科学与技术', '航天工程', '大气科学', '指挥信息系统工程'], baoyan: 50, further: 70, employRate: 99, salary: 11000, industries: ['国防科研', '信息技术', '航天'], employers: ['军队科研单位', '中国电科', '航天科技集团'] },

  // ================= 211 / 双一流 =================
  { name: '上海财经大学', prov: 'shanghai', city: '上海', level: '211', kind: '财经', base: 96, baseHis: 100, strengths: ['会计学', '财政学', '应用经济学'], majors: ['会计学', '金融学', '经济学', '统计学'], baoyan: 35, further: 55, employRate: 97, salary: 13000, industries: ['金融', '会计师事务所', '咨询', '互联网'], employers: ['四大会计师事务所', '中金公司', '招商银行', '字节跳动'] },
  { name: '中央财经大学', prov: 'beijing', city: '北京', level: '211', kind: '财经', base: 92, baseHis: 95, strengths: ['应用经济学', '保险学', '统计学'], majors: ['金融学', '会计学', '财政学', '精算学'], baoyan: 34, further: 54, employRate: 96.5, salary: 12500, industries: ['金融', '财税', '咨询', '央企财务'], employers: ['四大行总行', '中金公司', '财政部系统', '中国人寿'] },
  { name: '对外经济贸易大学', prov: 'beijing', city: '北京', level: '211', kind: '财经', base: 86, baseHis: 90, strengths: ['国际贸易学', '法学', '外国语言文学'], majors: ['国际经济与贸易', '金融学', '商务英语', '法学'], baoyan: 33, further: 52, employRate: 96.5, salary: 12200, industries: ['外贸', '金融', '法律', '跨境电商'], employers: ['中化集团', '四大会计师事务所', '商务部系统', '阿里巴巴国际站'] },
  { name: '中国政法大学', prov: 'beijing', city: '北京', level: '211', kind: '政法', base: 78, baseHis: 82, strengths: ['法学', '政治学', '社会学'], majors: ['法学', '政治学与行政学', '社会学', '侦查学'], baoyan: 30, further: 50, employRate: 94, salary: 10800, industries: ['法律', '公共管理', '金融合规', '企业法务'], employers: ['红圈所', '法院检察院系统', '四大行法务', '字节跳动'] },
  { name: '北京邮电大学', prov: 'beijing', city: '北京', level: '211', kind: '理工', base: 84, strengths: ['信息与通信工程', '计算机科学与技术'], majors: ['计算机科学与技术', '通信工程', '人工智能', '信息安全'], baoyan: 40, further: 62, employRate: 97, salary: 13500, industries: ['通信', '互联网', '半导体', '运营商'], employers: ['华为', '中国移动', '腾讯', '字节跳动'] },
  { name: '西安电子科技大学', prov: 'shaanxi', city: '西安', level: '211', kind: '理工', base: 76, strengths: ['电子科学与技术', '信息与通信工程'], majors: ['电子信息工程', '计算机科学与技术', '微电子科学与工程', '人工智能'], baoyan: 38, further: 60, employRate: 97, salary: 12500, industries: ['半导体', '通信', '军工电子', '互联网'], employers: ['华为', '中兴通讯', '中国电科', '比亚迪半导体'] },
  { name: '南京航空航天大学', prov: 'jiangsu', city: '南京', level: '211', kind: '理工', base: 70, strengths: ['航空宇航科学与技术', '机械工程'], majors: ['飞行器设计与工程', '机械工程', '计算机科学与技术', '自动化'], baoyan: 36, further: 58, employRate: 96, salary: 11200, industries: ['航空航天', '高端制造', '信息技术', '民航'], employers: ['航空工业集团', '中国商飞', '华为', '中国电科'] },
  { name: '南京理工大学', prov: 'jiangsu', city: '南京', level: '211', kind: '理工', base: 68, strengths: ['兵器科学与技术', '化学工程'], majors: ['武器系统与工程', '机械工程', '计算机科学与技术', '材料科学与工程'], baoyan: 35, further: 56, employRate: 95.5, salary: 10800, industries: ['军工', '智能制造', '化工', '信息技术'], employers: ['兵器工业集团', '中国电科', '华为', '徐工集团'] },
  { name: '哈尔滨工程大学', prov: 'heilongjiang', city: '哈尔滨', level: '211', kind: '理工', base: 60, strengths: ['船舶与海洋工程', '核科学与技术'], majors: ['船舶与海洋工程', '核工程与核技术', '计算机科学与技术', '自动化'], baoyan: 34, further: 56, employRate: 95, salary: 10200, industries: ['船舶海工', '核电', '军工', '信息技术'], employers: ['中国船舶集团', '中广核', '中国电科', '华为'] },
  { name: '北京交通大学', prov: 'beijing', city: '北京', level: '211', kind: '理工', base: 62, strengths: ['交通运输工程', '系统科学'], majors: ['计算机科学与技术', '交通运输', '通信工程', '土木工程'], baoyan: 34, further: 54, employRate: 96, salary: 11000, industries: ['轨道交通', '信息技术', '通信', '物流'], employers: ['中国国家铁路集团', '华为', '中国中铁', '京东物流'] },
  { name: '北京科技大学', prov: 'beijing', city: '北京', level: '211', kind: '理工', base: 60, strengths: ['冶金工程', '材料科学与工程'], majors: ['材料科学与工程', '计算机科学与技术', '机械工程', '冶金工程'], baoyan: 36, further: 56, employRate: 95.5, salary: 10800, industries: ['钢铁冶金', '新材料', '信息技术', '新能源'], employers: ['中国宝武', '比亚迪', '华为', '中国钢研'] },
  { name: '中国传媒大学', prov: 'beijing', city: '北京', level: '211', kind: '艺术', base: 60, baseHis: 68, strengths: ['新闻传播学', '戏剧与影视学'], majors: ['播音与主持艺术', '新闻学', '广告学', '数字媒体技术'], baoyan: 26, further: 46, employRate: 94, salary: 10500, industries: ['文化传媒', '互联网内容', '广告公关', '影视'], employers: ['央视/省级卫视', '字节跳动', '腾讯视频', '奥美'] },
  { name: '华北电力大学', prov: 'beijing', city: '北京', level: '211', kind: '理工', base: 58, strengths: ['电气工程', '动力工程'], majors: ['电气工程及其自动化', '能源与动力工程', '自动化', '计算机科学与技术'], baoyan: 30, further: 50, employRate: 96, salary: 11000, industries: ['电力能源', '电网', '新能源', '电力设备'], employers: ['国家电网', '南方电网', '国家电投', '中国电建'] },
  { name: '苏州大学', prov: 'jiangsu', city: '苏州', level: '211', kind: '综合', base: 56, baseHis: 60, strengths: ['材料科学与工程', '纺织科学与工程', '临床医学'], majors: ['材料科学与工程', '临床医学', '计算机科学与技术', '法学'], baoyan: 28, further: 48, employRate: 95, salary: 10200, industries: ['新材料', '医疗健康', '信息技术', '制造业'], employers: ['恒力集团', '苏州大学附属医院', '华为', '博世汽车'] },
  { name: '上海大学', prov: 'shanghai', city: '上海', level: '211', kind: '综合', base: 52, baseHis: 56, strengths: ['社会学', '机械工程', '美术学'], majors: ['计算机科学与技术', '社会学', '通信工程', '电影制作'], baoyan: 26, further: 46, employRate: 95, salary: 10500, industries: ['信息技术', '先进制造', '文化创意', '金融'], employers: ['上汽集团', '华为', '上海电气', '腾讯'] },
  { name: '暨南大学', prov: 'guangdong', city: '广州', level: '211', kind: '综合', base: 52, baseHis: 56, strengths: ['新闻传播学', '药学', '应用经济学'], majors: ['新闻学', '金融学', '药学', '计算机科学与技术'], baoyan: 27, further: 48, employRate: 95, salary: 10500, industries: ['传媒', '金融', '医药', '信息技术'], employers: ['南方报业', '腾讯', '广药集团', '招商银行'] },
  { name: '西南财经大学', prov: 'sichuan', city: '成都', level: '211', kind: '财经', base: 58, baseHis: 60, strengths: ['金融学', '会计学', '统计学'], majors: ['金融学', '会计学', '保险学', '统计学'], baoyan: 28, further: 48, employRate: 95.5, salary: 11200, industries: ['金融', '会计审计', '保险', '金融科技'], employers: ['四大会计师事务所', '建设银行', '中国人寿', '成都银行'] },
  { name: '中南财经政法大学', prov: 'hubei', city: '武汉', level: '211', kind: '财经', base: 50, baseHis: 54, strengths: ['法学', '财政学', '会计学'], majors: ['法学', '会计学', '金融学', '经济学'], baoyan: 25, further: 46, employRate: 94.5, salary: 10400, industries: ['法律', '金融', '财税', '企业法务'], employers: ['红圈所', '四大行', '湖北省财政系统', '四大会计师事务所'] },
  { name: '华中师范大学', prov: 'hubei', city: '武汉', level: '211', kind: '师范', base: 46, baseHis: 52, strengths: ['教育学', '政治学', '中国语言文学'], majors: ['教育学', '汉语言文学', '数学与应用数学', '心理学'], baoyan: 26, further: 48, employRate: 94, salary: 9200, industries: ['教育', '公共管理', '信息技术', '文化传媒'], employers: ['各地重点中学', '教育局', '字节跳动', '长江出版'] },
  { name: '南京师范大学', prov: 'jiangsu', city: '南京', level: '211', kind: '师范', base: 44, baseHis: 50, strengths: ['教育学', '地理学', '美术学'], majors: ['教育学', '汉语言文学', '地理科学', '计算机科学与技术'], baoyan: 25, further: 46, employRate: 94, salary: 9400, industries: ['教育', '信息技术', '公共管理', '文化传媒'], employers: ['江苏重点中学', '华为', '江苏广电', '学而思'] },
  { name: '陕西师范大学', prov: 'shaanxi', city: '西安', level: '211', kind: '师范', base: 40, baseHis: 46, strengths: ['教育学', '中国史', '化学'], majors: ['教育学', '汉语言文学', '数学与应用数学', '化学'], baoyan: 24, further: 44, employRate: 93, salary: 8800, industries: ['教育', '公共管理', '文化传媒', '科研'], employers: ['西北地区重点中学', '陕西教育局', '华为', '陕文投'] },
  { name: '西南大学', prov: 'chongqing', city: '重庆', level: '211', kind: '综合', base: 40, baseHis: 44, strengths: ['教育学', '心理学', '蚕学'], majors: ['教育学', '心理学', '计算机科学与技术', '农学'], baoyan: 24, further: 44, employRate: 93.5, salary: 9000, industries: ['教育', '农业', '信息技术', '公共管理'], employers: ['重庆重点中学', '中国农业科学院', '长安汽车', '腾讯'] },
  { name: '河海大学', prov: 'jiangsu', city: '南京', level: '211', kind: '理工', base: 40, strengths: ['水利工程', '土木工程', '环境科学与工程'], majors: ['水利水电工程', '土木工程', '计算机科学与技术', '环境工程'], baoyan: 26, further: 46, employRate: 95, salary: 10000, industries: ['水利水电', '建筑工程', '环保', '信息技术'], employers: ['中国电建', '中国能建', '中交集团', '华为'] },
  { name: '中国矿业大学', prov: 'jiangsu', city: '徐州', level: '211', kind: '理工', base: 34, strengths: ['矿业工程', '安全科学与工程'], majors: ['采矿工程', '安全工程', '计算机科学与技术', '土木工程'], baoyan: 24, further: 44, employRate: 94, salary: 9500, industries: ['能源矿业', '安全工程', '建筑工程', '信息技术'], employers: ['国家能源集团', '中煤集团', '中国电科', '徐工集团'] },
  { name: '江南大学', prov: 'jiangsu', city: '无锡', level: '211', kind: '理工', base: 38, strengths: ['食品科学与工程', '轻工技术与工程', '设计学'], majors: ['食品科学与工程', '设计学', '生物工程', '计算机科学与技术'], baoyan: 22, further: 42, employRate: 94, salary: 9600, industries: ['食品', '消费品', '工业设计', '生物制造'], employers: ['雀巢', '伊利集团', '海尔集团', '中粮集团'] },
  { name: '合肥工业大学', prov: 'anhui', city: '合肥', level: '211', kind: '理工', base: 38, strengths: ['管理科学与工程', '机械工程', '车辆工程'], majors: ['机械设计制造', '车辆工程', '计算机科学与技术', '土木工程'], baoyan: 22, further: 42, employRate: 94, salary: 9600, industries: ['汽车', '装备制造', '信息技术', '家电'], employers: ['江淮汽车', '蔚来汽车', '京东方', '华为'] },
  { name: '福州大学', prov: 'fujian', city: '福州', level: '211', kind: '理工', base: 30, strengths: ['化学', '土木工程', '管理科学与工程'], majors: ['化学', '土木工程', '计算机科学与技术', '电气工程'], baoyan: 18, further: 38, employRate: 94, salary: 9200, industries: ['化工新材料', '建筑', '信息技术', '电力'], employers: ['福建炼化', '宁德时代', '华为', '国家电网福建'] },
  { name: '南昌大学', prov: 'jiangxi', city: '南昌', level: '211', kind: '综合', base: 28, strengths: ['材料科学与工程', '食品科学与工程'], majors: ['材料科学与工程', '临床医学', '计算机科学与技术', '食品科学'], baoyan: 18, further: 38, employRate: 93.5, salary: 9000, industries: ['新材料', '医疗健康', '食品', '信息技术'], employers: ['江中集团', '南昌大学附属医院', '华为', '晶科能源'] },
  { name: '河北工业大学', prov: 'hebei', city: '天津', level: '211', kind: '理工', base: 26, strengths: ['电气工程', '材料科学与工程'], majors: ['电气工程', '材料科学与工程', '机械工程', '计算机科学与技术'], baoyan: 18, further: 36, employRate: 93.5, salary: 9000, industries: ['电力', '新材料', '钢铁', '信息技术'], employers: ['国家电网', '中国宝武', '长城汽车', '中兴通讯'] },
  { name: '太原理工大学', prov: 'shanxi', city: '太原', level: '211', kind: '理工', base: 22, strengths: ['煤炭科学与技术', '化学工程'], majors: ['采矿工程', '化学工程与工艺', '机械工程', '计算机科学与技术'], baoyan: 16, further: 34, employRate: 93, salary: 8600, industries: ['能源矿业', '化工', '装备制造', '信息技术'], employers: ['晋能控股', '山西焦煤', '华为', '太重集团'] },
  { name: '深圳大学', prov: 'guangdong', city: '深圳', level: '双一流', kind: '综合', base: 60, baseHis: 58, strengths: ['光学工程', '计算机科学与技术', '建筑学'], majors: ['计算机科学与技术', '电子信息工程', '建筑学', '金融学'], baoyan: 18, further: 40, employRate: 96, salary: 12500, industries: ['信息技术', '金融科技', '智能制造', '文化创意'], employers: ['腾讯', '华为', '招商银行', '大疆创新'] },
  { name: '南方科技大学', prov: 'guangdong', city: '深圳', level: '双一流', kind: '理工', base: 92, strengths: ['物理学', '材料科学', '生物学'], majors: ['物理学', '计算机科学与技术', '生物科学', '材料科学与工程'], baoyan: 45, further: 78, employRate: 96, salary: 13000, industries: ['科研', '信息技术', '半导体', '生物医药'], employers: ['华为', '腾讯', '深圳先进院', '大疆创新'] },
  { name: '上海科技大学', prov: 'shanghai', city: '上海', level: '双一流', kind: '理工', base: 88, strengths: ['物质科学', '信息科学', '生命科学'], majors: ['计算机科学与技术', '生物科学', '材料科学与工程', '物理学'], baoyan: 40, further: 76, employRate: 95, salary: 12500, industries: ['科研', '半导体', '生物医药', '信息技术'], employers: ['上海微技术工业研究院', '华为', '药明康德', '中芯国际'] },

  // ================= 省重点 / 特色院校 =================
  { name: '东北财经大学', prov: 'liaoning', city: '大连', level: '省重点', kind: '财经', base: 34, baseHis: 38, strengths: ['财政学', '会计学', '产业经济学'], majors: ['会计学', '金融学', '财政学', '统计学'], baoyan: 15, further: 32, employRate: 94, salary: 10000, industries: ['金融', '财会', '咨询', '互联网'], employers: ['四大会计师事务所', '大连银行', '招商银行', '京东'] },
  { name: '江西财经大学', prov: 'jiangxi', city: '南昌', level: '省重点', kind: '财经', base: 20, baseHis: 26, strengths: ['财政学', '统计学', '会计学'], majors: ['会计学', '金融学', '统计学', '法学'], baoyan: 12, further: 28, employRate: 93, salary: 9000, industries: ['金融', '财会', '财税', '信息技术'], employers: ['江西省财政系统', '四大会计师事务所', '江西银行', '华为'] },
  { name: '首都经济贸易大学', prov: 'beijing', city: '北京', level: '省重点', kind: '财经', base: 30, baseHis: 34, strengths: ['劳动经济学', '会计学', '统计学'], majors: ['会计学', '金融学', '人力资源管理', '统计学'], baoyan: 12, further: 30, employRate: 95, salary: 10800, industries: ['金融', '人力资源', '财会', '公共管理'], employers: ['北京市国企', '四大会计师事务所', '中国人保', '京东'] },
  { name: '天津财经大学', prov: 'tianjin', city: '天津', level: '省重点', kind: '财经', base: 24, baseHis: 28, strengths: ['统计学', '会计学', '金融学'], majors: ['会计学', '金融学', '统计学', '工商管理'], baoyan: 10, further: 26, employRate: 93.5, salary: 9200, industries: ['金融', '财会', '保险', '贸易'], employers: ['渤海银行', '四大会计师事务所', '天津港', '中国人寿'] },
  { name: '浙江工商大学', prov: 'zhejiang', city: '杭州', level: '省重点', kind: '财经', base: 20, baseHis: 24, strengths: ['工商管理', '统计学', '食品科学'], majors: ['会计学', '统计学', '计算机科学与技术', '食品科学'], baoyan: 10, further: 26, employRate: 94, salary: 9800, industries: ['数字经济', '财会', '零售', '信息技术'], employers: ['阿里巴巴', '四大会计师事务所', '物产中大', '浙商银行'] },
  { name: '广东外语外贸大学', prov: 'guangdong', city: '广州', level: '省重点', kind: '语言', base: 22, baseHis: 28, strengths: ['外国语言文学', '国际贸易学'], majors: ['英语', '国际经济与贸易', '翻译', '法学'], baoyan: 10, further: 26, employRate: 94, salary: 10000, industries: ['外贸', '跨境电商', '教育', '法律'], employers: ['SHEIN', '华为', '广交会', '四大会计师事务所'] },
  { name: '北京工商大学', prov: 'beijing', city: '北京', level: '省重点', kind: '财经', base: 16, strengths: ['食品科学与工程', '应用经济学'], majors: ['会计学', '食品科学与工程', '计算机科学与技术', '经济学'], baoyan: 10, further: 26, employRate: 94, salary: 10000, industries: ['食品', '财会', '信息技术', '零售'], employers: ['中粮集团', '四大会计师事务所', '京东', '北京市属国企'] },
  { name: '南京工业大学', prov: 'jiangsu', city: '南京', level: '省重点', kind: '理工', base: 22, strengths: ['化学工程与技术', '材料科学与工程'], majors: ['化学工程与工艺', '材料科学与工程', '计算机科学与技术', '土木工程'], baoyan: 12, further: 28, employRate: 94, salary: 9500, industries: ['化工新材料', '建筑工程', '信息技术', '环保'], employers: ['中石化', '中国化学工程', '华为', '徐工集团'] },
  { name: '浙江工业大学', prov: 'zhejiang', city: '杭州', level: '省重点', kind: '理工', base: 24, strengths: ['化学工程与技术', '机械工程', '药学'], majors: ['化学工程与工艺', '机械工程', '计算机科学与技术', '药学'], baoyan: 12, further: 28, employRate: 94.5, salary: 10000, industries: ['化工', '制药', '智能制造', '信息技术'], employers: ['巨化集团', '海康威视', '阿里巴巴', '华东医药'] },
  { name: '广东工业大学', prov: 'guangdong', city: '广州', level: '省重点', kind: '理工', base: 20, strengths: ['控制科学与工程', '机械工程'], majors: ['自动化', '计算机科学与技术', '机械设计制造', '材料科学与工程'], baoyan: 8, further: 22, employRate: 94.5, salary: 10200, industries: ['智能制造', '信息技术', '机器人', '新能源'], employers: ['华为', '美的集团', '广汽集团', '大疆创新'] },
  { name: '深圳技术大学', prov: 'guangdong', city: '深圳', level: '省重点', kind: '理工', base: 26, strengths: ['智能制造', '新材料', '物联网'], majors: ['计算机科学与技术', '机械设计制造', '物联网工程', '新材料'], baoyan: 5, further: 18, employRate: 94, salary: 10800, industries: ['智能制造', '信息技术', '新能源', '半导体'], employers: ['比亚迪', '华为', '大族激光', '中芯国际'] },
  { name: '河南大学', prov: 'henan', city: '开封', level: '省重点', kind: '综合', base: 10, baseHis: 16, strengths: ['地理学', '生物学', '教育学'], majors: ['地理科学', '生物科学', '汉语言文学', '计算机科学与技术'], baoyan: 12, further: 30, employRate: 92, salary: 8200, industries: ['教育', '科研', '信息技术', '公共管理'], employers: ['河南省重点中学', '各地教育局', '华为', '河南投资集团'] },
  { name: '山西大学', prov: 'shanxi', city: '太原', level: '省重点', kind: '综合', base: 4, baseHis: 10, strengths: ['物理学', '哲学', '计算机科学'], majors: ['物理学', '哲学', '计算机科学与技术', '历史学'], baoyan: 12, further: 30, employRate: 91, salary: 8000, industries: ['科研教育', '信息技术', '公共管理', '能源'], employers: ['山西重点中学', '华为', '晋能控股', '山西省公务员'] },
  { name: '燕山大学', prov: 'hebei', city: '秦皇岛', level: '省重点', kind: '理工', base: 8, strengths: ['机械工程', '材料科学与工程'], majors: ['机械设计制造', '材料科学与工程', '计算机科学与技术', '自动化'], baoyan: 10, further: 26, employRate: 93, salary: 8800, industries: ['装备制造', '汽车', '钢铁', '信息技术'], employers: ['中信重工', '长城汽车', '中国一重', '华为'] },
  { name: '扬州大学', prov: 'jiangsu', city: '扬州', level: '省重点', kind: '综合', base: 6, baseHis: 10, strengths: ['兽医学', '农学', '中国语言文学'], majors: ['动物医学', '汉语言文学', '计算机科学与技术', '土木工程'], baoyan: 10, further: 26, employRate: 92, salary: 8500, industries: ['现代农业', '教育', '建筑工程', '信息技术'], employers: ['江苏牧羊集团', '江苏重点中学', '中建集团', '华为'] },
  { name: '长沙理工大学', prov: 'hunan', city: '长沙', level: '省重点', kind: '理工', base: 4, strengths: ['电力工程', '交通运输工程'], majors: ['电气工程及其自动化', '道路桥梁与渡河工程', '计算机科学与技术', '会计学'], baoyan: 8, further: 22, employRate: 93, salary: 9000, industries: ['电力', '交通基建', '信息技术', '财会'], employers: ['国家电网湖南', '湖南路桥', '中国电建', '三一重工'] },
  { name: '上海理工大学', prov: 'shanghai', city: '上海', level: '省重点', kind: '理工', base: 18, strengths: ['光学工程', '动力工程', '医疗器械'], majors: ['光电信息科学与工程', '机械设计制造', '计算机科学与技术', '工商管理'], baoyan: 10, further: 26, employRate: 94, salary: 10200, industries: ['光电信息', '医疗器械', '智能制造', '信息技术'], employers: ['上海电气', '联影医疗', '华为', '上汽集团'] },
  { name: '哈尔滨理工大学', prov: 'heilongjiang', city: '哈尔滨', level: '省重点', kind: '理工', base: -6, strengths: ['电气工程', '机械工程', '材料科学'], majors: ['电气工程及其自动化', '材料科学与工程', '机械设计制造', '计算机科学与技术'], baoyan: 6, further: 18, employRate: 92, salary: 8200, industries: ['电力设备', '装备制造', '信息技术', '新材料'], employers: ['哈电集团', '国家电网黑龙江', '中国一重', '华为'] },
  { name: '西安理工大学', prov: 'shaanxi', city: '西安', level: '省重点', kind: '理工', base: 0, strengths: ['水利工程', '机械工程', '印刷工程'], majors: ['水利水电工程', '机械设计制造', '自动化', '计算机科学与技术'], baoyan: 8, further: 22, employRate: 92, salary: 8500, industries: ['水利电力', '装备制造', '军工配套', '信息技术'], employers: ['中国电建', '陕鼓集团', '华为', '中国西电'] },
  { name: '昆明理工大学', prov: 'yunnan', city: '昆明', level: '省重点', kind: '理工', base: -4, strengths: ['冶金工程', '矿业工程', '环境工程'], majors: ['冶金工程', '机械设计制造', '计算机科学与技术', '建筑学'], baoyan: 7, further: 20, employRate: 91, salary: 8000, industries: ['有色冶金', '矿业', '环保', '建筑工程'], employers: ['云铜集团', '云南建投', '中国铝业', '华为'] },
  { name: '山东师范大学', prov: 'shandong', city: '济南', level: '省重点', kind: '师范', base: 2, baseHis: 10, strengths: ['教育学', '化学', '中国语言文学'], majors: ['汉语言文学', '数学与应用数学', '化学', '教育学'], baoyan: 10, further: 28, employRate: 92, salary: 8300, industries: ['教育', '公共管理', '化工', '文化传媒'], employers: ['山东重点中学', '各地教育局', '万华化学', '齐鲁晚报'] },
  { name: '郑州大学', prov: 'henan', city: '郑州', level: '211', kind: '综合', base: 55, baseHis: 56, strengths: ['临床医学', '材料科学与工程', '化学'], majors: ['临床医学', '计算机科学与技术', '材料科学与工程', '法学'], baoyan: 26, further: 46, employRate: 94.5, salary: 9500, industries: ['医疗健康', '信息技术', '新材料', '公共管理'], employers: ['郑州大学第一附属医院', '华为', '宇通客车', '河南投资集团'] },
  { name: '杭州电子科技大学', prov: 'zhejiang', city: '杭州', level: '省重点', kind: '理工', base: 34, strengths: ['电子科学与技术', '计算机科学与技术', '控制科学'], majors: ['计算机科学与技术', '电子信息工程', '自动化', '信息安全'], baoyan: 14, further: 30, employRate: 95.5, salary: 11500, industries: ['信息技术', '半导体', '通信', '金融科技'], employers: ['阿里巴巴', '海康威视', '华为', '中电海康'] },
  { name: '首都医科大学', prov: 'beijing', city: '北京', level: '省重点', kind: '医药', base: 62, strengths: ['临床医学', '口腔医学', '护理学'], majors: ['临床医学', '口腔医学', '预防医学', '护理学'], baoyan: 20, further: 55, employRate: 96, salary: 11000, industries: ['医疗卫生', '生物医药', '医疗器械'], employers: ['北京友谊医院', '北京朝阳医院', '同仁堂', '药明康德'] },
  { name: '华东政法大学', prov: 'shanghai', city: '上海', level: '省重点', kind: '政法', base: 45, baseHis: 50, strengths: ['法学', '知识产权'], majors: ['法学', '知识产权', '侦查学', '国际经济法'], baoyan: 16, further: 38, employRate: 93, salary: 11000, industries: ['法律', '金融合规', '知识产权', '公共管理'], employers: ['上海红圈所分所', '上海法院系统', '四大会计师事务所', '字节跳动'] },
  { name: '西南政法大学', prov: 'chongqing', city: '重庆', level: '省重点', kind: '政法', base: 36, baseHis: 42, strengths: ['法学', '新闻传播学'], majors: ['法学', '侦查学', '新闻学', '知识产权'], baoyan: 14, further: 34, employRate: 92, salary: 9500, industries: ['法律', '公检法系统', '企业法务', '知识产权'], employers: ['重庆/四川公检法', '红圈所', '企业法务', '银行合规'] },

  // ================= 普通本科 / 民办 =================
  { name: '河南科技大学', prov: 'henan', city: '洛阳', level: '普通本科', kind: '理工', base: -14, strengths: ['机械工程', '材料科学与工程', '车辆工程'], majors: ['机械设计制造', '车辆工程', '材料科学与工程', '计算机科学与技术'], baoyan: 6, further: 18, employRate: 91, salary: 7800, industries: ['装备制造', '汽车', '新材料', '信息技术'], employers: ['中信重工', '中国一拖', '宁德时代', '洛阳钼业'] },
  { name: '郑州轻工业大学', prov: 'henan', city: '郑州', level: '普通本科', kind: '理工', base: -22, strengths: ['食品科学与工程', '电气工程'], majors: ['食品科学与工程', '电气工程', '计算机科学与技术', '工业设计'], baoyan: 4, further: 14, employRate: 91, salary: 7600, industries: ['食品', '电力设备', '信息技术', '消费品'], employers: ['双汇集团', '思念食品', '许继电气', '宇通客车'] },
  { name: '中原工学院', prov: 'henan', city: '郑州', level: '普通本科', kind: '理工', base: -34, strengths: ['纺织科学与工程', '机电工程'], majors: ['纺织工程', '机械设计制造', '计算机科学与技术', '服装设计'], baoyan: 2, further: 10, employRate: 90, salary: 7200, industries: ['纺织服装', '装备制造', '信息技术', '电商'], employers: ['河南豫光', '中原大化', '郑州日产', '华为'] },
  { name: '洛阳师范学院', prov: 'henan', city: '洛阳', level: '普通本科', kind: '师范', base: -30, baseHis: -24, strengths: ['教育学', '中国语言文学'], majors: ['汉语言文学', '数学与应用数学', '英语', '小学教育'], baoyan: 2, further: 12, employRate: 90, salary: 6800, industries: ['基础教育', '公共管理', '文化传媒'], employers: ['河南各地中小学', '教育局', '河南日报'] },
  { name: '黄河科技学院', prov: 'henan', city: '郑州', level: '民办/独立学院', kind: '理工', base: -70, strengths: ['应用型工科', '护理'], majors: ['计算机科学与技术', '机械设计制造', '护理学', '艺术设计'], baoyan: 0, further: 6, employRate: 88, salary: 6000, industries: ['信息技术', '医疗护理', '智能制造', '电商'], employers: ['河南本地中小企业', '郑州 hospitals 护理岗', '宇通客车', '河南 IT 外包'] },
  { name: '郑州工商学院', prov: 'henan', city: '郑州', level: '民办/独立学院', kind: '综合', base: -85, strengths: ['应用型商科', '工程管理'], majors: ['会计学', '计算机科学与技术', '英语', '工程管理'], baoyan: 0, further: 5, employRate: 86, salary: 5600, industries: ['财会', '信息技术', '建筑工程', '零售'], employers: ['河南本地中小企业', '郑州会计师事务所', '房地产企业'] },
]

/** 城市热度（影响同层次院校在不同省份的录取线差） */
export const cityHeat: Record<string, number> = {
  北京: 8, 上海: 8, 深圳: 7, 杭州: 4, 南京: 3, 广州: 3, 苏州: 3, 厦门: 3, 珠海: 2,
  成都: 2, 宁波: 2, 无锡: 2, 武汉: 1, 合肥: 1, 福州: 1, 青岛: 1, 天津: 0, 长沙: 0,
  重庆: -1, 扬州: -1, 大连: -1, 温州: -1, 济南: -2, 镇江: -2, 烟台: -2, 常州: 0,
  郑州: -2, 南昌: -3, 石家庄: -3, 芜湖: -3, 徐州: -2, 保定: -4, 秦皇岛: -4, 湘潭: -4,
  株洲: -4, 咸阳: -5, 绵阳: -5, 洛阳: -5, 太原: -5, 昆明: -5, 贵阳: -5, 南宁: -5,
  桂林: -5, 海口: -4, 三亚: -4, 雅安: -6, 开封: -6, 鞍山: -6, 沈阳: -4, 长春: -6,
  哈尔滨: -6, 兰州: -8, 呼和浩特: -6, 乌鲁木齐: -7, 石河子: -8, 杨凌: -8, 拉萨: -8,
  银川: -8, 西宁: -8, 大庆: -7, 吉林: -7, 抚顺: -7,
}

Object.assign(cityHeat, extraCityHeat)

/** 内置院校库：核心条目 + 扩充条目（按名称去重，核心条目优先） */
const builtinSeeds: UniversitySeed[] = (() => {
  const seen = new Set(coreSeeds.map((s) => s.name))
  return [...coreSeeds, ...extraSeeds.filter((s) => !seen.has(s.name))]
})()

/** 由「数据接入 → 院校库」导入的官方院校（localStorage），可选 */
let importedSeeds: UniversitySeed[] = []

function normalizeName(name: string): string {
  return name.replace(/[（(].*?[)）]/g, '').replace(/\s+/g, '').replace(/[·•]/g, '')
}

/** 合并单条：内置手工标注优先，官方数据只补空位 */
function mergeSeed(builtin: UniversitySeed, incoming: UniversitySeed): UniversitySeed {
  const out: UniversitySeed = { ...builtin, ...incoming }
  const scalarKeys = ['prov', 'city', 'level', 'kind', 'base', 'baseHis', 'baoyan', 'further', 'employRate', 'salary'] as const
  for (const key of scalarKeys) {
    if (builtin[key] != null) Object.assign(out, { [key]: builtin[key] })
  }
  const listKeys = ['strengths', 'majors', 'industries', 'employers'] as const
  for (const key of listKeys) {
    if (builtin[key]?.length) Object.assign(out, { [key]: builtin[key] })
  }
  out.name = builtin.name
  return out
}

/** 注册导入的官方院校清单（由 App 在读取 dataset 后调用） */
export function setImportedUniversities(seeds: UniversitySeed[] | undefined) {
  importedSeeds = Array.isArray(seeds) ? seeds : []
  cacheSeed = null
}

let cacheSeed: UniversitySeed[] | null = null

/** 当前生效的完整院校库：内置条目 + 官方导入补空位（重复名称以内置优先） */
export function universitySeeds(): UniversitySeed[] {
  if (cacheSeed) return cacheSeed
  if (!importedSeeds.length) {
    cacheSeed = builtinSeeds
    return cacheSeed
  }
  const index = new Map<string, number>()
  const out: UniversitySeed[] = builtinSeeds.map((s, i) => {
    index.set(normalizeName(s.name), i)
    return s
  })
  for (const s of importedSeeds) {
    const key = normalizeName(s.name)
    if (!key) continue
    const idx = index.get(key)
    if (idx == null) {
      index.set(key, out.length)
      out.push(s)
      continue
    }
    // 同名：保留内置手工标注，用官方数据补齐缺失字段（如院校代码、办学性质）
    out[idx] = mergeSeed(out[idx], s)
  }
  cacheSeed = out
  return out
}

/** 内置院校数量（不含导入增量），用于「是否已有官方补充」的判断 */
export const builtinSeedCount = builtinSeeds.length

export function cityHeatOf(city: string | undefined): number {
  return city ? cityHeat[city] ?? 0 : 0
}
