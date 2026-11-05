#import <UIKit/UIKit.h>
#if CONTACTS_FLUTTER
#import <Flutter/Flutter.h>
#else
#import <Masonry/Masonry.h>
// Pure modal compatibility only; no service, SDK or system permission hooks.
@interface UIViewController (ContactsReferenceAccessibility)
- (void)ai_prepareAccessibilityModalWithBackdropView:(UIView *)view;
- (void)ai_postAccessibilityModalScreenChanged;
- (void)ai_restoreAccessibilityFocusAfterModalDismissalIfNeeded;
@end
@implementation UIViewController (ContactsReferenceAccessibility)
- (void)ai_prepareAccessibilityModalWithBackdropView:(UIView *)view { self.view.accessibilityViewIsModal = YES; view.isAccessibilityElement = NO; }
- (void)ai_postAccessibilityModalScreenChanged { UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil); }
- (void)ai_restoreAccessibilityFocusAfterModalDismissalIfNeeded { UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil); }
@end
static UIColor *AIAppAccentColor(void) { return [UIColor colorWithRed:0.04 green:0.52 blue:1 alpha:1]; }
#import "GeneratedContactsPresentation.m"
#if CONTACTS_PERMISSION
#import "AIContactPermissionDialogViewController.h"
#import "AIContactsTabPermissionPolicy.h"
@interface PermissionReference : UIViewController
@end
@implementation PermissionReference
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.whiteColor;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"联系人" forState:UIControlStateNormal];
    button.frame = CGRectMake(20, 100, 120, 48);
    [button addTarget:self action:@selector(openPermission) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}
- (void)openPermission {
    BOOL settings = [NSProcessInfo.processInfo.arguments containsObject:@"--settings"];
    AIContactPermissionDialogViewController *dialog = [[AIContactPermissionDialogViewController alloc]
        initWithTitle:settings ? AIContactsPermissionSettingsTitle : AIContactsPermissionConsentTitle
        message:settings ? AIContactsPermissionSettingsMessage : AIContactsPermissionConsentMessage
        cancelTitle:settings ? AIContactsPermissionSettingsCancelTitle : AIContactsPermissionConsentCancelTitle
        confirmTitle:settings ? AIContactsPermissionSettingsConfirmTitle : AIContactsPermissionConsentConfirmTitle];
    dialog.onCancel = ^{};
    dialog.onConfirm = ^{}; // Presentation only: no OS permission or settings.
    [self presentViewController:dialog animated:YES completion:nil];
}
@end
#endif

@implementation ContactsDetailReference (Actions)
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)editRemark {
    AIContactRemarkSheetViewController *editor = [AIContactRemarkSheetViewController new];
    editor.remarkText = self.remarkText;
    __weak typeof(self) weakSelf = self;
    editor.onSave = ^(NSString *text, void (^completion)(NSError *)) {
        weakSelf.remarkText = text;
        [weakSelf applyRemarkValueText:text.length ? text : @"暂无备注" color:[UIColor colorWithWhite:text.length ? 0.07 : 0.56 alpha:1]];
        weakSelf.remarkDeleteButton.hidden = NO;
        completion(nil); // Synthetic in-memory reply only.
    };
    [self presentViewController:editor animated:YES completion:nil];
}
- (void)deleteRemark {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除联系人备注？" message:@"本机通讯录联系人不会被删除。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        self.remarkText = @"";
        [self applyRemarkValueText:@"暂无备注" color:[UIColor colorWithWhite:0.56 alpha:1]];
        self.remarkDeleteButton.hidden = YES;
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)reloadDirectoryEntry {} // No directory repository linked.
- (void)openSystemDial {} // No phone operation linked.
- (void)openSkillSelection {
    AIContactSkillSheetViewController *sheet = [AIContactSkillSheetViewController new];
    sheet.contactName = self.contactName;
    AIContactSkillOption *option = [AIContactSkillOption new];
    option.cardId = @"synthetic"; option.title = @"合成可用技能";
    option.subtitle = @"仅用于联系人页面对照"; option.enabled = YES;
    option.skillId = @"synthetic"; option.actionType = AIContactSkillActionTypeOpenSkill;
    sheet.options = @[option];
    sheet.onSelect = ^(AIContactSkillOption *selected) {}; // No task/Agent linked.
    [self presentViewController:sheet animated:YES completion:nil];
}
@end

@implementation ContactsListReference (Actions)
- (void)viewDidLoad {
    [super viewDidLoad]; [self buildLayout];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--empty"]) [self updateEmptyState];
}
- (void)refreshControlTriggered:(UIRefreshControl *)control { [control endRefreshing]; }
- (void)openSystemSettings {} // Never open settings in pure native reference.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [NSProcessInfo.processInfo.arguments containsObject:@"--empty"] ? 0 : 3;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AIContactsRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AIContactsRowCell" forIndexPath:indexPath];
    [cell configureWithDisplayName:indexPath.row == 2 ? @"演示餐厅" : @"演示联系人"
                             phone:[NSString stringWithFormat:@"202555010%ld", (long)indexPath.row + 1]
                     dividerHidden:indexPath.row == 2];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactsDetailReference *detail = [ContactsDetailReference new];
    detail.contactName = indexPath.row == 2 ? @"演示餐厅" : @"演示联系人";
    detail.phone = [NSString stringWithFormat:@"202555010%ld", (long)indexPath.row + 1];
    detail.hint = @"本机通讯录联系人"; detail.remarkText = @"";
    [self.navigationController pushViewController:detail animated:YES];
}
@end
#endif

@interface ContactsReferenceApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ContactsReferenceApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
#if CONTACTS_FLUTTER
    FlutterViewController *root = [[FlutterViewController alloc] initWithProject:nil nibName:nil bundle:nil];
#else
#if CONTACTS_PERMISSION
    UINavigationController *root = [[UINavigationController alloc] initWithRootViewController:[PermissionReference new]];
#else
    UINavigationController *root = [[UINavigationController alloc] initWithRootViewController:[ContactsListReference new]];
#endif
    root.navigationBarHidden = YES;
#endif
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ContactsReferenceApp.class)); }
}
