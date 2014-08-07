//
//  TBVPNService.h
//  ProxyDemo
//
//  Created by yang shizhong on 8/7/14.
//  Copyright (c) 2014 Tapberts Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface TBVPNService : NSObject

+ (instancetype)sharedService;

- (CFArrayRef )vpnList;

- (void)startWithService:(SCNetworkServiceRef )service;

- (SCNetworkConnectionStatus )isServiceAvilable:(SCNetworkServiceRef )service;

- (CFStringRef )typeOfPPPService:(SCNetworkServiceRef )service;
@end
