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

- (void)stopWithService:(SCNetworkServiceRef )service;

- (SCNetworkConnectionStatus )statusServiceAvilable:(SCNetworkServiceRef )service;

- (CFStringRef )nameOfPPPService:(SCNetworkServiceRef )service;

- (CFStringRef )nameOfPPPServiceID:(CFStringRef )service_id;

- (SCNetworkServiceRef )serviceFromServiceID:(CFStringRef )service_id;

@end
