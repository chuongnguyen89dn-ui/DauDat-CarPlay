#import <Foundation/Foundation.h>

static NSString * const DDPreferencesDomain = @"com.chuong.daudat.settings";

// Preserve the original DuoDash preference semantics under the new Đầu Đất namespace.
// This lets the compatibility layer keep every layout/state dimension instead of collapsing
// the project to a simple two-pane prototype.
static NSString * const DDAppBridgeAutostartKey = @"appbridge_autostart";
static NSString * const DDAppBridgeEnabledKey = @"appbridge_enabled";
static NSString * const DDAppBridgeLayoutKey = @"appbridge_layout";
static NSString * const DDSplitEnabledKey = @"appbridge_split_enabled";
static NSString * const DDSplitFracAKey = @"appbridge_split_frac_a";
static NSString * const DDSplitFracBKey = @"appbridge_split_frac_b";
static NSString * const DDSplitFracLayoutKey = @"appbridge_split_frac_layout";
static NSString * const DDLeftAppKey = @"appbridge_split_left";
static NSString * const DDRatioKey = @"appbridge_split_ratio";
static NSString * const DDRightAppKey = @"appbridge_split_right";
static NSString * const DDThirdAppKey = @"appbridge_split_third";
static NSString * const DDBridgedAppsKey = @"bridgedApps";
static NSString * const DDNavBubbleDockModeKey = @"navbubble_dock_mode";
static NSString * const DDNavProviderAutostartKey = @"navprovider_autostart";
static NSString * const DDNavProviderSelectedKey = @"navprovider_selected";

static NSDictionary *DDDefaultConfiguration(void) {
    return @{
        DDAppBridgeAutostartKey:@YES,
        DDAppBridgeEnabledKey:@YES,
        DDAppBridgeLayoutKey:@2,
        DDSplitEnabledKey:@YES,
        DDSplitFracAKey:@0,
        DDSplitFracBKey:@0,
        DDSplitFracLayoutKey:@0,
        DDLeftAppKey:@"com.google.ios.youtube",
        DDRatioKey:@50,
        DDRightAppKey:@"com.waze.iphone",
        DDThirdAppKey:@"",
        DDBridgedAppsKey:@[@"com.zhiliaoapp.musically", @"com.facebook.Facebook", @"com.waze.iphone", @"com.google.ios.youtube"],
        DDNavBubbleDockModeKey:@0,
        DDNavProviderAutostartKey:@NO,
        DDNavProviderSelectedKey:@""
    };
}

static NSDictionary *DDLoadConfiguration(void) {
    NSMutableDictionary *v=[DDDefaultConfiguration() mutableCopy];
    NSDictionary *saved=[[NSUserDefaults standardUserDefaults] persistentDomainForName:DDPreferencesDomain];
    if (saved) [v addEntriesFromDictionary:saved];
    return v;
}
