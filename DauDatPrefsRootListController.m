#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

@interface DauDatPrefsRootListController : PSListController
@end

@implementation DauDatPrefsRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers=[self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (NSString *)doctorPayload {
    CFPropertyListRef value=CFPreferencesCopyAppValue(CFSTR("payload.DDTRACE"),CFSTR("com.chuong.daudat.diagnostic"));
    NSString *trace=(value && CFGetTypeID(value)==CFStringGetTypeID())?[(__bridge NSString *)value copy]:@"";
    if (value) CFRelease(value);
    return trace ?: @"";
}
- (NSURL *)materializeDoctor {
    NSString *trace=[self doctorPayload];
    if (!trace.length) return nil;
    NSMutableString *out=[NSMutableString string];
    [out appendString:@"=== DAUDAT CARPLAY RUNTIME TRACE ===\n"];
    [out appendFormat:@"Exported: %@\nDevice: %@ %@\n\n",NSDate.date,UIDevice.currentDevice.model,UIDevice.currentDevice.systemVersion];
    [out appendString:trace];
    NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"DauDat-CarPlay-Diagnostic.txt"];
    NSError *err=nil;
    if (![out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) return nil;
    return [NSURL fileURLWithPath:path];
}
- (void)runDoctor {
    NSString *trace=[self doctorPayload];
    NSString *message=trace.length ? [NSString stringWithFormat:@"Đã có runtime trace (%lu bytes). Bấm Export Doctor để gửi file .txt.",(unsigned long)[trace lengthOfBytesUsingEncoding:NSUTF8StringEncoding]] : @"Chưa có runtime trace. Kết nối CarPlay và thao tác Fullscreen trước.";
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Đầu Đất Doctor" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)exportDoctor {
    NSURL *url=[self materializeDoctor];
    if (!url) { [self runDoctor]; return; }
    UIActivityViewController *vc=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    [self presentViewController:vc animated:YES completion:nil];
}
@end
