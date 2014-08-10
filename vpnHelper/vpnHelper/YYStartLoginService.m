//
//  YYStartLogin.m
//  vpnHelper
//
//  Created by yang shizhong on 8/10/14.
//  Copyright (c) 2014 Tapberts Inc. All rights reserved.
//

#import "YYStartLoginService.h"

@implementation YYStartLoginService

+(instancetype)sharedService {
    static YYStartLoginService *startLoginServie_ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        startLoginServie_ = [[[self class] alloc] init];
    });
    return startLoginServie_;
}

//添加开机启动
-(void)addAppAsLoginItem {
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
-(void)deleteAppFromLoginItem{
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
