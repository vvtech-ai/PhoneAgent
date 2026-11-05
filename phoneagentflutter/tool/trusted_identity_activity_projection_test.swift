import Foundation

@main
struct ProjectionTests {
  static func main() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func report(_ phase: String = "verified", time: String = "1700000000", type: String = "0") -> [String: Any] {
      ["eventId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "activityFresh": true,
       "identity": ["verification": phase, "name": "合成姓名", "deptZh": "合成部门",
                    "position": "合成职位", "commonName": "合成企业", "phoneno": "12025550100",
                    "callTime": time, "showType": type]]
    }
    func decode(_ value: [String: Any]) -> TrustedIdentityActivityProjection? {
      TrustedIdentityActivityProjection(report: value, now: now)
    }
    precondition(decode(report())?.userName == "合成姓名")
    precondition(decode(report(type: "1"))?.userName == "合成职位")
    precondition(decode(report(type: "2"))?.departmentAndPosition == "合成职位")
    precondition(decode(report(type: "3"))?.userName == "合成企业")
    for phase in ["pending", "failed", "authorized"] { precondition(decode(report(phase)) == nil) }
    precondition(decode(report(type: "6"))?.showType == 6)
    precondition(decode(report("uncertified", type: "6"))?.showType == 6)
    precondition(decode(report("uncertified")) == nil)
    precondition(decode(report(time: "1700000000000")) == decode(report()))
    precondition(decode(report(time: "1699998800")) != nil)
    precondition(decode(report(time: "1699998799")) == nil)
    precondition(decode(report(time: "1700000060")) != nil)
    precondition(decode(report(time: "1700000061")) == nil)
    for time in ["", "nan", "inf", "-1"] { precondition(decode(report(time: time)) == nil) }
    var fakeFresh = report(); fakeFresh["activityFresh"] = 1
    precondition(decode(fakeFresh) == nil)
    var oversized = report()
    var identity = oversized["identity"] as! [String: String]
    for key in ["name", "deptZh", "position", "commonName", "title", "job", "school"] {
      identity[key] = String(repeating: "合", count: 1000)
    }
    oversized["identity"] = identity
    precondition(decode(oversized) == nil)
    var aliases = report()
    var aliasIdentity = aliases["identity"] as! [String: String]
    aliasIdentity.removeValue(forKey: "name"); aliasIdentity["userName"] = "合成别名"
    aliasIdentity.removeValue(forKey: "deptZh"); aliasIdentity["department"] = "合成部门别名"
    aliases["identity"] = aliasIdentity
    precondition(decode(aliases)?.userName == "合成别名")
    precondition(decode(aliases)?.departmentAndPosition == "合成部门别名 合成职位")
    print("Activity projection verification, freshness, display type and size tests passed")
  }
}
