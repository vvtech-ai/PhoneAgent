// View adapted from fixed iOS bb9ff349; source SHA256 0c5191c109357e8199006614b710e87a0699c670bed1f1bc68c8bb27ce270190
import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

// Incoming-call presentation mirrors the corresponding branches in kxphone.
// Activity creation, APNs handling, and the destination deep link stay owned by PhoneAgent.
@main
struct TrustedIdentityLiveActivity: Widget {
    private func deepLinkURL(_ attributes: TrustedIdentityActivityAttributes) -> URL? {
        var parts = URLComponents()
        parts.scheme = "aiassistanttrustedcall"
        parts.host = "identity"
        parts.queryItems = [URLQueryItem(name: "eventId", value: attributes.eventId)]
        return parts.url
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrustedIdentityActivityAttributes.self) { context in
            lockScreenView(context.attributes)
                .activityBackgroundTint(.black)
                .widgetURL(deepLinkURL(context.attributes))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedIncomingIdentity(context.attributes)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 0.5)
                            .padding(.horizontal, 8)
                        incomingStatus(context.attributes)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .offset(y: 2)
                    }
                    .offset(y: 7)
                }
            } compactLeading: {
                avatar(context.attributes, size: 20)
            } compactTrailing: {
                HStack(alignment: .center) {
                    Text(context.attributes.userName)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(height: 20, alignment: .leading)
                        .lineLimit(1)
                        .bold()
                    titleSuffix(context.attributes, size: 10)
                    if context.attributes.showType == 6 {
                        Image("head_noauthen_icon")
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
            } minimal: {
                avatar(context.attributes, size: 25)
            }
            .widgetURL(deepLinkURL(context.attributes))
            .keylineTint(.black)
        }
    }

    private func lockScreenView(_ attributes: TrustedIdentityActivityAttributes) -> some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                avatar(attributes, size: 50)
                    .padding(.top, 20)
                    .padding(.leading, 25)
                incomingIdentity(attributes)
                    .padding(.top, tagTexts(attributes).isEmpty ? 0 : 20)
            }
            incomingStatus(attributes)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func avatar(_ attributes: TrustedIdentityActivityAttributes, size: CGFloat) -> some View {
        let image = attributes.avatarData.count <= 32768 ? UIImage(data: attributes.avatarData) : nil
        Group {
            if let image { Image(uiImage: image).resizable() }
            else { Image("trusted_identity_avatar_default").resizable() }
        }
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    private func incomingStatus(_ attributes: TrustedIdentityActivityAttributes) -> some View {
        HStack {
            Text(attributes.showType == 6
                 ? "此来电身份为未认证身份，建议您谨慎采信"
                 : "来电身份经可信身份认证 Powered by CHAKEN®")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private func titleSuffix(_ attributes: TrustedIdentityActivityAttributes, size: CGFloat) -> some View {
        Text(attributes.title)
            .font(.system(size: size))
            .foregroundColor(.white)
            .bold()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
    }

    private func expandedIncomingIdentity(_ attributes: TrustedIdentityActivityAttributes) -> some View {
        HStack(alignment: .center, spacing: 6) {
            avatar(attributes, size: 50)
                .frame(width: 52, height: 52, alignment: .center)
                .layoutPriority(3)
            incomingIdentity(attributes)
                .layoutPriority(1)
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func incomingIdentity(_ attributes: TrustedIdentityActivityAttributes) -> some View {
        let showType = attributes.showType
        let hasTags = !tagTexts(attributes).isEmpty
        if showType == 3 || showType == 4 || showType == 8 {
            VStack(alignment: .leading, spacing: hasTags ? 4 : 2) {
                HStack(spacing: 2) {
                    if showType == 8 {
                        Text(attributes.userName).font(.system(size: 16)).foregroundColor(.white).bold().lineLimit(1)
                        titleSuffix(attributes, size: 16)
                        Image("head_company_icon").resizable().frame(width: 14, height: 14).padding(.leading, -3)
                    } else {
                        Text(attributes.callerPhone).font(.system(size: 16)).foregroundColor(.white).bold().lineLimit(1)
                    }
                    Spacer()
                }
                HStack {
                    if showType == 8 {
                        Text(attributes.callerPhone).font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                    } else {
                        Text(attributes.companyName).font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                        Image("head_company_icon").resizable().frame(width: 14, height: 14).padding(.leading, -3)
                    }
                    Spacer()
                }
                tagPills(attributes)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.leading, 8)
        } else {
            VStack(alignment: .leading, spacing: hasTags ? 4 : 2) {
                HStack(spacing: 2) {
                    if showType == 1102 {
                        Text(attributes.userName)
                            .font(.system(size: 16)).foregroundColor(.white).frame(width: 70, height: 20, alignment: .leading).bold()
                    } else {
                        if !attributes.departmentAndPosition.isEmpty && attributes.userName.count > 3 {
                            Text(attributes.userName)
                                .font(.system(size: 16)).foregroundColor(.white)
                                .frame(width: 70, height: 20, alignment: .leading).bold()
                        } else {
                            Text(attributes.userName)
                                .font(.system(size: 16)).foregroundColor(.white).lineLimit(1).bold()
                        }
                        if !attributes.title.isEmpty {
                            titleSuffix(attributes, size: 16)
                        }
                        if !attributes.departmentAndPosition.isEmpty {
                            Text(attributes.departmentAndPosition)
                                .font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                        }
                    }
                    Spacer()
                }
                HStack(spacing: 2) {
                    if showType == 1102 {
                        Text(attributes.departmentAndPosition).font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                        Image("head_company_icon").resizable().frame(width: 14, height: 14).padding(.leading, -3)
                    } else {
                        Text(attributes.companyName).font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                        Image(showType == 6 ? "head_company_no_icon" : "head_company_icon")
                            .resizable().frame(width: 14, height: 14)
                            .padding(.leading, showType == 6 ? 0 : -3)
                    }
                    Spacer()
                }
                tagPills(attributes)
                HStack {
                    Text(attributes.callerPhone).font(.system(size: 13)).foregroundColor(.gray).lineLimit(1)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.leading, 8)
        }
    }

    private func tagTexts(_ attributes: TrustedIdentityActivityAttributes) -> [String] {
        let job = attributes.job.trimmingCharacters(in: .whitespacesAndNewlines)
        let school = attributes.school.trimmingCharacters(in: .whitespacesAndNewlines)
        return [job, school.isEmpty ? "" : "毕业于\(school)"].filter { !$0.isEmpty }
    }

    private func tagWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)]).width) + 18
    }

    @ViewBuilder
    private func tagPills(_ attributes: TrustedIdentityActivityAttributes) -> some View {
        let tags = tagTexts(attributes)
        if !tags.isEmpty {
            let shouldWrap = tags.count > 1 &&
                min(tagWidth(tags[0]), 252) + 8 + min(tagWidth(tags[1]), 252) > 250
            if shouldWrap {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tags, id: \.self) { tag in tagPill(tag) }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in tagPill(tag) }
                    Spacer()
                }
            }
        }
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .frame(width: min(tagWidth(text), 252), height: 18)
            .background(Color.white.opacity(0.2))
            .cornerRadius(4)
    }
}
