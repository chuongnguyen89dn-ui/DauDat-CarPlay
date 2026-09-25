#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface DauDatPrefsRootListController : PSListController
@end

@implementation DauDatPrefsRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers=[self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (void)runDoctor {
    NSString *report=@"/var/mobile/Documents/DauDat-Diagnostic.txt";
    NSString *message=[[NSFileManager defaultManager] fileExistsAtPath:report] ? @"Đã tìm thấy báo cáo Doctor mới nhất." : @"Chưa có báo cáo. Kết nối CarPlay để Đầu Đất tạo diagnostic.";
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Đầu Đất Doctor" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)exportDoctor {
    NSURL *url=[NSURL fileURLWithPath:@"/var/mobile/Documents/DauDat-Diagnostic.txt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) { [self runDoctor]; return; }
    UIActivityViewController *vc=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    [self presentViewController:vc animated:YES completion:nil];
}
@end
