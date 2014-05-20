//
//  TBAppDelegate.m
//  ProxyDemo
//
//  Created by yang shizhong on 14-5-17.
//  Copyright (c) 2014年 Tapberts Inc. All rights reserved.
//

#import "TBAppDelegate.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "DDHotKeyCenter.h"
#import <Carbon/Carbon.h>
#import "THUserNotification.h"


static AuthorizationRef authRef;
static AuthorizationFlags authFlags;

@interface TBAppDelegate ()
@property (weak) IBOutlet NSMenu *menuBar;
@property (nonatomic, strong) NSStatusItem  *statusBarItem;
@property (nonatomic, assign) BOOL open;
@end

@implementation TBAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    if (authErr != noErr) {
        authRef = nil;
    }else {
        [self observeHotKey];
    }
    [self setupStatusItem];
}

- (void)setupStatusItem {
    self.statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:23.0];
    self.statusBarItem.image = [NSImage imageNamed:@"status_item_icon"];
    self.statusBarItem.alternateImage = [NSImage imageNamed:@"status_item_icon_alt"];
    self.statusBarItem.menu = self.menuBar;
    [self.statusBarItem setHighlightMode:YES];
}

- (IBAction)terminalPressed:(NSMenuItem *)sender {
    [NSApp terminate:nil];
}

- (void)observeHotKey {
    DDHotKeyCenter *ddhot = [DDHotKeyCenter sharedHotKeyCenter];
    typeof(self) weakSelf = self;
    [ddhot registerHotKeyWithKeyCode:kVK_ANSI_F modifierFlags:NSControlKeyMask|NSShiftKeyMask task:^(NSEvent *event) {
        [weakSelf changeSystemProxy];
    }];
}

- (void)changeSystemProxy{
    NSMutableDictionary *previousDeviceProxies = [NSMutableDictionary new];

    SCPreferencesRef prefRef = SCPreferencesCreateWithAuthorization(nil, CFSTR("modifyProxy"), nil, authRef);
    
    NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
    // 遍历系统中的网络设备列表，设置 AirPort 和 Ethernet 的代理
    if (previousDeviceProxies.count == 0) {
        for (NSString *key in [sets allKeys]) {
            NSMutableDictionary *dict = [sets objectForKey:key];
            NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
            if ([hardware isEqualToString:@"AirPort"] || [hardware isEqualToString:@"Ethernet"]) {
                NSDictionary *proxies = [dict objectForKey:(NSString *)kSCEntNetProxies];
                if (proxies != nil) {
                    [previousDeviceProxies setObject:[proxies mutableCopy] forKey:key];
                }
            }
        }
    }
    
    // 如果已经获取了旧的代理设置就直接用之前获取的，防止第二次获取到设置过的代理
    for (NSString *deviceId in previousDeviceProxies) {
        CFDictionaryRef proxies = SCPreferencesPathGetValue(prefRef, (__bridge CFStringRef)[self proxiesPathOfDevice:deviceId]);
        [self modifyPrefProxiesDictionary:(__bridge NSMutableDictionary *)proxies];
        SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)[self proxiesPathOfDevice:deviceId], proxies);
    }
    
    SCPreferencesCommitChanges(prefRef);
    SCPreferencesApplyChanges(prefRef);
    SCPreferencesSynchronize(prefRef);
    
    [self postLocalNotification:self.open];
}

- (NSString *)proxiesPathOfDevice:(NSString *)devId {
    NSString *path = [NSString stringWithFormat:@"/%@/%@/%@", kSCPrefNetworkServices, devId, kSCEntNetProxies];
    return path;
}

- (void)modifyPrefProxiesDictionary:(NSMutableDictionary *)proxies{
    NSInteger proxyPort = 8087;
    NSArray *proxyTypes = @[@"PROXY"];
    
    if ([proxyTypes indexOfObject:@"PROXY"] != NSNotFound) {
        [proxies setObject:[NSNumber numberWithInteger:proxyPort] forKey:(NSString *)kCFNetworkProxiesHTTPPort];
        [proxies setObject:@"127.0.0.1" forKey:(NSString *)kCFNetworkProxiesHTTPProxy];
        [proxies setObject:[NSNumber numberWithInteger:proxyPort] forKey:(NSString *)kCFNetworkProxiesHTTPSPort];
        [proxies setObject:@"127.0.0.1" forKey:(NSString *)kCFNetworkProxiesHTTPSProxy];
        
        BOOL previousEnable = [[proxies objectForKey:(NSString *)kCFNetworkProxiesHTTPEnable] boolValue];
        [proxies setObject:[NSNumber numberWithInt:previousEnable?0:1] forKey:(NSString *)kCFNetworkProxiesHTTPEnable];
        [proxies setObject:[NSNumber numberWithInt:previousEnable?0:1] forKey:(NSString *)kCFNetworkProxiesHTTPSEnable];
        self.open = !previousEnable;
    }
}

- (void)postLocalNotification:(BOOL )isopen{
    THUserNotification *notification = [THUserNotification notification];
    notification.title = @"Proxy";
    notification.informativeText = isopen?@"打开":@"关闭";
    //设置通知提交的时间
    notification.deliveryDate = [NSDate dateWithTimeIntervalSinceNow:1];
    
    THUserNotificationCenter *center = [THUserNotificationCenter notificationCenter];
    if ([center isKindOfClass:[THUserNotificationCenter class]]) {
        center.centerType = THUserNotificationCenterTypeBanner;
    }
    //删除已经显示过的通知(已经存在用户的通知列表中的)
    [center removeAllDeliveredNotifications];
    //递交通知
    [center deliverNotification:notification];
}

@end
