//
//  TBAppDelegate.m
//  ProxyDemo
//
//  Created by yang shizhong on 14-5-17.
//  Copyright (c) 2014年 Tapberts Inc. All rights reserved.
//

#import "TBAppDelegate.h"
#import "DDHotKeyCenter.h"
#import <Carbon/Carbon.h>
#import "TBVPNService.h"

NSString *const autoStartKey = @"startAtLogin";
NSString *const autoVPNKey = @"autoVPNKey";

@interface TBAppDelegate ()
@property (weak) IBOutlet NSMenu *menuBar;
@property IBOutlet NSMenuItem *startAtLogin;
@property (nonatomic, strong) NSMutableDictionary *vpnDict;
@property (nonatomic, strong) NSStatusItem  *statusBarItem;
@end

@implementation TBAppDelegate

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
    self.statusBarItem.alternateImage = [NSImage imageNamed:@"status_item_icon_alt"];
    self.statusBarItem.menu = self.menuBar;
    [self.statusBarItem setHighlightMode:YES];
    
    self.vpnDict = [@{} mutableCopy];
    [self.menuBar insertItem:[NSMenuItem separatorItem] atIndex:1];
    
    CFArrayRef vpnlist = [[TBVPNService sharedService] vpnList];
    if (!CFArrayGetCount(vpnlist)) return;
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    if (![prefs objectForKey:autoVPNKey]) {
        [prefs setObject:(__bridge NSString *)(SCNetworkServiceGetServiceID(CFArrayGetValueAtIndex(vpnlist, 0))) forKey:autoVPNKey];
        [prefs synchronize];
    }

    for (CFIndex i = 0; i< CFArrayGetCount(vpnlist); i++) {
        //遍历可用vpn
        SCNetworkServiceRef service = CFArrayGetValueAtIndex(vpnlist, i);
        NSString *serviceName =  (__bridge NSString *)[[TBVPNService sharedService] nameOfPPPService:service];
        NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:serviceName action:@selector(handleVpnMenu:) keyEquivalent:@""];
        newItem.representedObject = serviceName;
        if (kSCNetworkConnectionConnected
            == [[TBVPNService sharedService] statusServiceAvilable:service]) {
            newItem.state = 1;
            //保存默认选择项
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setObject:(__bridge NSString *)(SCNetworkServiceGetServiceID(service)) forKey:autoVPNKey];
            [prefs synchronize];
        }
        newItem.tag = i;
        [self.menuBar insertItem:newItem atIndex:i+2];
        
        //记录vpn名字和id
        self.vpnDict[serviceName] = (__bridge NSString *)(SCNetworkServiceGetServiceID(service));
    }
}

- (void)setupStartLogin{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if([prefs boolForKey:autoStartKey]) {
        [self addAppAsLoginItem];
    } else {
        [self deleteAppFromLoginItem];
    }
    self.startAtLogin.state = [prefs boolForKey:autoStartKey];
}

- (void)observeHotKey {
    DDHotKeyCenter *ddhot = [DDHotKeyCenter sharedHotKeyCenter];
    [ddhot registerHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:NSControlKeyMask|NSShiftKeyMask task:^(NSEvent *event) {
        //快捷键触发操作
        
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        CFStringRef serviceID = (__bridge CFStringRef)([prefs objectForKey:autoVPNKey]);
        SCNetworkServiceRef service = [[TBVPNService sharedService] serviceFromServiceID:serviceID];
        if (kSCNetworkConnectionConnected != [[TBVPNService sharedService] statusServiceAvilable:service]
            && kSCNetworkConnectionDisconnected != [[TBVPNService sharedService] statusServiceAvilable:service])
            return;//当vpn不在已连接/未连接状态下时不做任何操作(避免在正在连接时重复发起连接)
        [[TBVPNService sharedService] startWithService:service];
        if (kSCNetworkConnectionDisconnected == [[TBVPNService sharedService] statusServiceAvilable:service]) {
            [[TBVPNService sharedService] startWithService:service];
        }else {
            [[TBVPNService sharedService] stopWithService:service];
        }

    }];
}

#pragma mark action
- (void)handleVpnMenu:(NSMenuItem *)item {
    CFStringRef serviceid = (__bridge CFStringRef)(self.vpnDict[item.title]);
    SCNetworkServiceRef service = [[TBVPNService sharedService] serviceFromServiceID:serviceid];
    if (kSCNetworkConnectionConnected != [[TBVPNService sharedService] statusServiceAvilable:service]
        && kSCNetworkConnectionDisconnected != [[TBVPNService sharedService] statusServiceAvilable:service])
        return;//当vpn不在已连接/未连接状态下时不做任何操作(避免在正在连接时重复发起连接)
    
    if ((item.state = !item.state)) {
        [[TBVPNService sharedService] startWithService:service];
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setObject:(__bridge NSString *)(SCNetworkServiceGetServiceID(service)) forKey:autoVPNKey];
        [prefs synchronize];
    }else {
        [[TBVPNService sharedService] stopWithService:service];
    }
}

#pragma mark 开机启动

- (IBAction)startAtLoginToggle:(id)pid {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:!self.startAtLogin.state forKey:autoStartKey];
    [prefs synchronize];
    if([prefs boolForKey:autoStartKey]) {
        [self addAppAsLoginItem];
    } else {
        [self deleteAppFromLoginItem];
    }
    self.startAtLogin.state = [prefs boolForKey:autoStartKey];
}

//添加开机启动
-(void)addAppAsLoginItem{
    NSString * appPath = [[NSBundle mainBundle] bundlePath];
    NSURL *url = [NSURL fileURLWithPath:appPath];
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        //Insert an item to the list.
        LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)(url), NULL, NULL);
        if (item){
            CFRelease(item);
        }
        CFRelease(loginItems);
    }
}

//删除开机启动
-(void) deleteAppFromLoginItem{
    UInt32 seedValue;
    NSString * appPath = [[NSBundle mainBundle] bundlePath];
    NSURL *url = [NSURL fileURLWithPath:appPath];
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    CFURLRef urlRef = (__bridge CFURLRef)url;
    
    if (loginItems) {
        NSArray  *loginItemsArray = (NSArray *)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seedValue));
        for(int i = 0 ; i< [loginItemsArray count]; i++) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)([loginItemsArray objectAtIndex:i]);
            if (LSSharedFileListItemResolve(itemRef, 0, &urlRef, NULL) == noErr) {
                NSString *urlPath = [url path];
                if ([urlPath compare:appPath] == NSOrderedSame){
                    LSSharedFileListItemRemove(loginItems,itemRef);
                }
            }
        }
    }
}

@end
