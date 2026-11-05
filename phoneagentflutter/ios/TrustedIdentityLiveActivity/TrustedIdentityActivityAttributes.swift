import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct TrustedIdentityActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var displayStatus: Int
    var verificationFailMessage: String
  }
  var eventId: String
  var userName: String
  var title: String
  var departmentAndPosition: String
  var companyName: String
  var job: String
  var school: String
  var showType: Int
  var callerPhone: String
  var avatarData: Data = Data()
}

@available(iOS 16.1, *)
extension TrustedIdentityActivityAttributes {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    eventId = try c.decode(String.self, forKey: .eventId)
    userName = try c.decode(String.self, forKey: .userName)
    title = try c.decode(String.self, forKey: .title)
    departmentAndPosition = try c.decode(String.self, forKey: .departmentAndPosition)
    companyName = try c.decode(String.self, forKey: .companyName)
    job = try c.decode(String.self, forKey: .job)
    school = try c.decode(String.self, forKey: .school)
    showType = try c.decode(Int.self, forKey: .showType)
    callerPhone = try c.decode(String.self, forKey: .callerPhone)
    avatarData = try c.decodeIfPresent(Data.self, forKey: .avatarData) ?? Data()
  }
}
