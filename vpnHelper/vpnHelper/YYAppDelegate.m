//
//  YYAppDelegate.m
//  vpnHelper
//
//  Created by yang shizhong on 8/9/14.
//  Copyright (c) 2014 Tapberts Inc. All rights reserved.
//

#import "YYAppDelegate.h"
#import "DDHotKeyCenter.h"
#import <Carbon/Carbon.h>
#import "YYVPNService.h"
#import "YYStartLoginService.h"

NSString *const autoStartKey = @"startAtLogin";
NSString *const autoVPNKey = @"autoVPNKey";

@interface YYAppDelegate ()
@property (weak) IBOutlet NSMenu *menuBar;
@property IBOutlet NSMenuItem *startAtLogin;
@property (nonatomic, strong) NSMutableDictionary *vpnDict;
@property (nonatomic, strong) NSStatusItem  *statusBarItem;
@end


@implementation YYAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [self observeHotKey];
    [self setupStatusItem];
    [self setupStartLogin];
}

//初始化Menuitem

- (void)setupStatusItem {
    self.statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:23.0];
    self.statusBarItem.image = [NSImage imageNamed:@"status_item_icon"];
    self.statusBarItem.menu = self.menuBar;
    [self.statusBarItem setHighlightMode:YES];
    
    self.vpnDict = [@{} mutableCopy];
    [self.menuBar insertItem:[NSMenuItem separatorItem] atIndex:1];
    
    CFArrayRef vpnlist = [[YYVPNService sharedService] vpnList];
    if (!CFArrayGetCount(vpnlist)) return;
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    if (![prefs objectForKey:autoVPNKey]) {
        [prefs setObject:(__bridge NSString *)(SCNetworkServiceGetServiceID(CFArrayGetValueAtIndex(vpnlist, 0))) forKey:autoVPNKey];
    }
    
    for (CFIndex i = 0; i< CFArrayGetCount(vpnlist); i++) {
        //遍历可用vpn
        SCNetworkServiceRef service = CFArrayGetValueAtIndex(vpnlist, i);
        NSString *serviceName =  (__bridge NSString *)[[YYVPNService sharedService] nameOfPPPService:service];
        NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:serviceName action:@selector(handleVpnMenu:) keyEquivalent:@""];
        newItem.representedObject = serviceName;
        if (kSCNetworkConnectionConnected
            == [[YYVPNService sharedService] statusServiceAvilable:service]) {
            newItem.state = 1;
            //保存默认选择项
            [prefs setObject:(__bridge NSString *)(SCNetworkServiceGetServiceID(service)) forKey:autoVPNKey];
        }
        newItem.tag = i;
        [self.menuBar insertItem:newItem atIndex:i+2];
        
        //记录vpn名字和id
        self.vpnDict[serviceName] = (__bridge NSString *)(SCNetworkServiceGetServiceID(service));
    }
    [prefs synchronize];
}

- (void)setupStartLogin{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if([prefs boolForKey:autoStartKey]) {
        [[YYStartLoginService sharedService] addAppAsLoginItem];
    } else {
        [[YYStartLoginService sharedService] deleteAppFromLoginItem];
    }
    self.startAtLogin.state = [prefs boolForKey:autoStartKey];
}

- (void)observeHotKey {
    DDHotKeyCenter *ddhot = [DDHotKeyCenter sharedHotKeyCenter];
    //设置监听快捷键
    [ddhot registerHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:NSControlKeyMask|NSShiftKeyMask task:^(NSEvent *event) {
        //快捷键触发操作
        
        CFStringRef serviceID = (__bridge CFStringRef)([[NSUserDefaults standardUserDefaults] objectForKey:autoVPNKey]);
        SCNetworkServiceRef service = [[YYVPNService sharedService] serviceFromServiceID:serviceID];
        
        if (kSCNetworkConnectionConnected != [[YYVPNService sharedService] statusServiceAvilable:service]
            && kSCNetworkConnectionDisconnected != [[YYVPNService sharedService] statusServiceAvilable:service])
            return;//当vpn不在已连接/未连接状态下时不做任何操作(避免在正在连接时重复发起连接)
        
        [[YYVPNService sharedService] startWithService:service successfullBlock:nil failureBlock:nil];
        if (kSCNetworkConnectionDisconnected == [[YYVPNService sharedService] statusServiceAvilable:service]) {
            [[YYVPNService sharedService] startWithService:service successfullBlock:nil failureBlock:nil];
        }else {
            [[YYVPNService sharedService] stopWithService:service successfullBlock:nil failureBlock:nil];
        }
        
    }];
}

#pragma mark action
- (void)handleVpnMenu:(NSMenuItem *)item {
    CFStringRef serviceid = (__bridge CFStringRef)(self.vpnDict[item.title]);
    SCNetworkServiceRef service = [[YYVPNService sharedService] serviceFromServiceID:serviceid];
    if (kSCNetworkConnectionConnected != [[YYVPNService sharedService] statusServiceAvilable:service]
        && kSCNetworkConnectionDisconnected != [[YYVPNService sharedService] statusServiceAvilable:service])
        return;//当vpn不在已连接/未连接状态下时不做任何操作(避免在正在连接时重复发起连接)
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:(__bridge NSString *)(SCNetworkServiceGetServiceID(service)) forKey:autoVPNKey];
    [prefs synchronize];
    
    if ((item.state = !item.state)) {
        [[YYVPNService sharedService] startWithService:service successfullBlock:nil failureBlock:^(NSError *error) {
            item.state = !item.state;
        }];
    }else {
        [[YYVPNService sharedService] stopWithService:service successfullBlock:nil failureBlock:^(NSError *error) {
            item.state = !item.state;
        }];
    }
}

#pragma mark 开机启动

- (IBAction)startAtLoginToggle:(id)pid {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:!self.startAtLogin.state forKey:autoStartKey];
    [prefs synchronize];
    
    if([prefs boolForKey:autoStartKey]) {
        [[YYStartLoginService sharedService] addAppAsLoginItem];
    } else {
        [[YYStartLoginService sharedService] deleteAppFromLoginItem];
    }
    self.startAtLogin.state = [prefs boolForKey:autoStartKey];
}


@end
