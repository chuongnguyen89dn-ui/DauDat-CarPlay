#import <Foundation/Foundation.h>

static NSString * const DDPreferencesDomain = @"com.chuong.daudat.settings";
static NSString * const DDLeftAppKey = @"split_left";
static NSString * const DDRightAppKey = @"split_right";
static NSString * const DDRatioKey = @"split_ratio";
static NSString * const DDSplitEnabledKey = @"split_enabled";

static NSDictionary *DDDefaultConfiguration(void) {
    return @{
        DDSplitEnabledKey:@YES,
        DDLeftAppKey:@"com.google.ios.youtube",
        DDRightAppKey:@"com.waze.iphone",
        DDRatioKey:@50
    };
}

static NSDictionary *DDLoadConfiguration(void) {
    NSMutableDictionary *v=[DDDefaultConfiguration() mutableCopy];
    NSDictionary *saved=[[NSUserDefaults standardUserDefaults] persistentDomainForName:DDPreferencesDomain];
    if (saved) [v addEntriesFromDictionary:saved];
    return v;
}
