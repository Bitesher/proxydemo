//
//  YYStartLogin.h
//  vpnHelper
//
//  Created by yang shizhong on 8/10/14.
//  Copyright (c) 2014 Tapberts Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YYStartLoginService : NSObject

+ (instancetype)sharedService;
//添加进开机启动
-(void)addAppAsLoginItem;
//从开机启动中删除
-(void)deleteAppFromLoginItem;
@end
