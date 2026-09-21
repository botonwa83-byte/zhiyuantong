import Foundation

/// 内置数据（院校库 / 省份批次线 / 专业就业）随 App 打包，离线可用
final class DataStore {
    static let shared = DataStore(
        url: Bundle.main.url(forResource: "bundle", withExtension: "json")
    )

    let bundle: DataBundle
    let provinces: [Province]
    let provinceMap: [String: Province]
    let seeds: [UniversitySeed]
    let cityHeat: [String: Double]
    let majorProfiles: [MajorProfile]
    let majorProfileMap: [String: MajorProfile]
    let majorCareers: [MajorCareer]
    let hotMajors: [HotMajor]
    let cityCareers: [CityCareer]
    let cityCareerMap: [String: CityCareer]
    /** 省份 id -> 批次规则（志愿数上限、平行/顺序、志愿单位） */
    let batchRuleMap: [String: ProvinceBatchesDTO]

    var currentYear: Int { bundle.currentYear }
    var historyYears: [Int] { bundle.historyYears }

    init(url: URL?) {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DataBundle.self, from: data)
        else {
            fatalError("bundle.json 未打进 App 资源，请检查 Build Phases → Copy Bundle Resources")
        }
        bundle = decoded
        provinces = decoded.provinces.map(Province.init)
        provinceMap = Dictionary(uniqueKeysWithValues: provinces.map { ($0.id, $0) })
        seeds = decoded.universities
        cityHeat = decoded.cityHeat
        majorProfiles = decoded.majorProfiles
        majorProfileMap = Dictionary(uniqueKeysWithValues: decoded.majorProfiles.map { ($0.name, $0) })
        majorCareers = decoded.majorCareers
        hotMajors = decoded.hotMajors
        cityCareers = decoded.cityCareers
        cityCareerMap = Dictionary(uniqueKeysWithValues: decoded.cityCareers.map { ($0.name, $0) })
        batchRuleMap = Dictionary(uniqueKeysWithValues: decoded.batchRules.map { ($0.provId, $0) })
    }

    func province(_ id: String) -> Province {
        provinceMap[id] ?? provinces[0]
    }

    /// 该省的批次设置（按录取顺序）；没有规则时返回 nil，调用方需退回「不按批次」的单表模式
    func batches(of id: String) -> ProvinceBatchesDTO? {
        batchRuleMap[id]
    }

    /// 征集志愿（补录）提示
    func supplementNote(of id: String) -> String? {
        batchRuleMap[id]?.supplementNote
    }

    func heat(of city: String) -> Double {
        cityHeat[city] ?? 0
    }

    func majorProfile(_ name: String) -> MajorProfile? {
        majorProfileMap[name]
    }

    /// 学科门类下的全部专业
    func profiles(in discipline: String) -> [MajorProfile] {
        majorProfiles.filter { $0.discipline == discipline }
    }
}
