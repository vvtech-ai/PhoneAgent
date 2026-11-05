import Foundation

@main
struct AdmissionTests {
  static func main() {
    var policy = TrustedIdentityActivityAdmission()
    precondition(policy.admit(event: "first", foreground: false))
    precondition(!policy.admit(event: "first", foreground: false))
    precondition(policy.admit(event: "first", foreground: true))
    precondition(policy.admit(event: "first", foreground: true))
    precondition(!policy.admit(event: "first", foreground: true))
    precondition(policy.admit(event: "second", foreground: true))
    precondition(policy.admit(event: "second", foreground: false))
    policy.reset()
    precondition(policy.admit(event: "second", foreground: true))
    print("Activity retry admission: bounded background/foreground, new event and reset passed")
  }
}
