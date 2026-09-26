#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *DDDoctorDir(void) {
    NSString *base=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/DauDat"];
    [[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
    return base;
}
static NSString *DDDoctorReportPath(void) { return [DDDoctorDir() stringByAppendingPathComponent:@"DauDat-Diagnostic.txt"]; }
static NSString *DDDoctorBaselinePath(void) { return [DDDoctorDir() stringByAppendingPathComponent:@"DauDat-Baseline.txt"]; }
static NSString *DDDoctorEventPath(void) { return [DDDoctorDir() stringByAppendingPathComponent:@"DauDat-Runtime.log"]; }
static NSString *DDDoctorExportPath(void) { return @"/var/mobile/Documents/DauDat-Diagnostic.txt"; }

static BOOL DDDoctorPublishReport(NSString *sourcePath) {
    if (!sourcePath.length) return NO;
    NSData *data=[NSData dataWithContentsOfFile:sourcePath];
    if (!data.length) return NO;
    NSString *dir=[DDDoctorExportPath() stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [data writeToFile:DDDoctorExportPath() atomically:YES];
}

static void DDDoctorLogEvent(NSString *event, NSString *detail) {
    NSString *line=[NSString stringWithFormat:@"%@ | %@ | %@ | %@\n",NSDate.date,NSProcessInfo.processInfo.processName,event?:@"EVENT",detail?:@""];
    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:DDDoctorEventPath()];
    if (!h) {
        [line writeToFile:DDDoctorEventPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [h seekToEndOfFile];
    [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [h closeFile];
}

static NSString *DDDoctorSnapshot(BOOL fullscreen, UIWindow *statusBar) {
    NSMutableString *o=[NSMutableString string];
    [o appendFormat:@"=== DAUDAT DOCTOR ===\nDate: %@\nProcess: %@ pid=%d\nDevice: %@ %@\n",
      NSDate.date, NSProcessInfo.processInfo.processName, getpid(), UIDevice.currentDevice.model, UIDevice.currentDevice.systemVersion];
    NSDictionary *cfg=DDLoadConfiguration();
    [o appendFormat:@"Config: %@\nFullscreen: %d\n",cfg,fullscreen ? 1 : 0];
    [o appendFormat:@"Bridge: enabled=%@ autostart=%@ layout=%@ split=%@ ratio=%@ left=%@ right=%@ third=%@\n",
      cfg[DDAppBridgeEnabledKey],cfg[DDAppBridgeAutostartKey],cfg[DDAppBridgeLayoutKey],cfg[DDSplitEnabledKey],
      cfg[DDRatioKey],cfg[DDLeftAppKey],cfg[DDRightAppKey],cfg[DDThirdAppKey]];
    [o appendFormat:@"Fractional: a=%@ b=%@ layout=%@ bridgedApps=%@\n",
      cfg[DDSplitFracAKey],cfg[DDSplitFracBKey],cfg[DDSplitFracLayoutKey],cfg[DDBridgedAppsKey]];
    [o appendFormat:@"Navigation: dock=%@ autostart=%@ selected=%@\n",
      cfg[DDNavBubbleDockModeKey],cfg[DDNavProviderAutostartKey],cfg[DDNavProviderSelectedKey]];
    NSArray *screens=UIScreen.screens;
    [o appendFormat:@"Screens: %lu\n",(unsigned long)screens.count];
    [screens enumerateObjectsUsingBlock:^(UIScreen *s, NSUInteger i, BOOL *stop){
        [o appendFormat:@"SCREEN[%lu] bounds=%@ native=%@ scale=%.3f nativeScale=%.3f\n",
         (unsigned long)i,NSStringFromCGRect(s.bounds),NSStringFromCGRect(s.nativeBounds),s.scale,s.nativeScale];
    }];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        [o appendFormat:@"SCENE role=%@ state=%ld screen=%@ windows=%lu\n",scene.session.role,(long)scene.activationState,
         NSStringFromCGRect(ws.screen.bounds),(unsigned long)ws.windows.count];
        [ws.windows enumerateObjectsUsingBlock:^(UIWindow *w, NSUInteger i, BOOL *stop){
            NSString *root=w.rootViewController?NSStringFromClass(w.rootViewController.class):@"(null)";
            UIView *rv=w.rootViewController.view;
            CGRect rootFrame=rv ? rv.frame : CGRectZero;
            CGRect rootBounds=rv ? rv.bounds : CGRectZero;
            [o appendFormat:@" WIN[%lu] class=%@ frame=%@ bounds=%@ safe=%@ hidden=%d level=%.1f root=%@\n",
             (unsigned long)i,NSStringFromClass(w.class),NSStringFromCGRect(w.frame),NSStringFromCGRect(w.bounds),
             NSStringFromUIEdgeInsets(w.safeAreaInsets),w.hidden,w.windowLevel,root];
            [o appendFormat:@"  ROOT frame=%@ bounds=%@ safe=%@ subviews=%lu\n",
             NSStringFromCGRect(rootFrame),NSStringFromCGRect(rootBounds),
             rv?NSStringFromUIEdgeInsets(rv.safeAreaInsets):@"(null)",(unsigned long)rv.subviews.count];
            if (rv) {
                [rv.subviews enumerateObjectsUsingBlock:^(UIView *v, NSUInteger vi, BOOL *vstop){
                    [o appendFormat:@"   VIEW[%lu] class=%@ frame=%@ bounds=%@ safe=%@ hidden=%d\n",
                     (unsigned long)vi,NSStringFromClass(v.class),NSStringFromCGRect(v.frame),NSStringFromCGRect(v.bounds),
                     NSStringFromUIEdgeInsets(v.safeAreaInsets),v.hidden];
                }];
            }
        }];
    }
    UIWindow *bar=statusBar;
    [o appendFormat:@"Sidebar: %@\n",bar?NSStringFromCGRect(bar.frame):@"NOT_FOUND"];
    [o appendString:@"\n=== RUNTIME HEALTH ===\n"];
    [o appendFormat:@"StatusBarWindow: %@\n",bar?@"OK":@"MISSING"];
    [o appendFormat:@"CarPlayScreen: %@\n",screens.count>1?@"PRESENT":@"NOT_DETECTED"];
    [o appendFormat:@"SystemUptime: %.1fs\n",NSProcessInfo.processInfo.systemUptime];
    [o appendFormat:@"PhysicalMemory: %llu\n",NSProcessInfo.processInfo.physicalMemory];
    [o appendFormat:@"LowPowerMode: %d\n",NSProcessInfo.processInfo.lowPowerModeEnabled ? 1 : 0];
    [o appendFormat:@"DoctorDirWritable: %d\n",[[NSFileManager defaultManager] isWritableFileAtPath:DDDoctorDir()] ? 1 : 0];
    return o;
}
static NSString *DDDoctorGeometryAssessment(void) {
    NSMutableArray<NSString *> *issues=[NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        CGSize ss=ws.screen.bounds.size;
        if (fabs(ss.width-427.0)>2.0 || fabs(ss.height-240.0)>2.0) continue;
        for (UIWindow *w in ws.windows) {
            if (w.hidden || !w.rootViewController) continue;
            UIView *rv=w.rootViewController.view;
            CGRect f=rv.frame;
            if (f.origin.x>=40.0 && f.origin.x<=50.0)
                [issues addObject:[NSString stringWithFormat:@"ROOT_X_RESERVED_45 class=%@ frame=%@",NSStringFromClass(rv.class),NSStringFromCGRect(f)]];
            if (f.size.width>=370.0 && f.size.width<=390.0)
                [issues addObject:[NSString stringWithFormat:@"ROOT_WIDTH_MINUS_SIDEBAR class=%@ frame=%@",NSStringFromClass(rv.class),NSStringFromCGRect(f)]];
            for (UIView *v in rv.subviews) {
                CGRect vf=v.frame;
                if (vf.origin.x>=40.0 && vf.origin.x<=50.0)
                    [issues addObject:[NSString stringWithFormat:@"CHILD_X_RESERVED_45 class=%@ frame=%@",NSStringFromClass(v.class),NSStringFromCGRect(vf)]];
                if (vf.size.width>=370.0 && vf.size.width<=390.0)
                    [issues addObject:[NSString stringWithFormat:@"CHILD_WIDTH_MINUS_SIDEBAR class=%@ frame=%@",NSStringFromClass(v.class),NSStringFromCGRect(vf)]];
            }
        }
    }
    return issues.count ? [issues componentsJoinedByString:@"\n"] : @"NO_OBVIOUS_45PT_RESERVATION";
}

static NSString *DDDoctorWrite(BOOL baseline, BOOL fullscreen, UIWindow *statusBar) {
    NSMutableString *snap=[DDDoctorSnapshot(fullscreen,statusBar) mutableCopy];
    [snap appendFormat:@"\n=== GEOMETRY ASSESSMENT ===\n%@\n",DDDoctorGeometryAssessment()];
    NSString *events=[NSString stringWithContentsOfFile:DDDoctorEventPath() encoding:NSUTF8StringEncoding error:nil];
    [snap appendFormat:@"\n=== RUNTIME EVENTS ===\n%@\n",events.length?events:@"NO_EVENTS"];
    CFPropertyListRef shared=CFPreferencesCopyAppValue(CFSTR("payload.DDTRACE"),CFSTR("com.chuong.daudat.diagnostic"));
    NSString *sharedTrace=(shared && CFGetTypeID(shared)==CFStringGetTypeID())?[(__bridge NSString *)shared copy]:@"";
    if (shared) CFRelease(shared);
    [snap appendFormat:@"\n=== SHARED CARPLAY TRACE ===\n%@\n",sharedTrace.length?sharedTrace:@"NO_SHARED_TRACE"];
    NSString *path=baseline?DDDoctorBaselinePath():DDDoctorReportPath();
    if (!baseline) {
        NSString *b=[NSString stringWithContentsOfFile:DDDoctorBaselinePath() encoding:NSUTF8StringEncoding error:nil];
        if (b.length) [snap appendFormat:@"\n=== BASELINE PRESENT ===\nBaseline bytes: %lu\n",(unsigned long)[b lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        else [snap appendString:@"\n=== BASELINE ===\nMISSING\n"];
    }
    [snap writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if (!baseline) DDDoctorPublishReport(path);
    return path;
}
