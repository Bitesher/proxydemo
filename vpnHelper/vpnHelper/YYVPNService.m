//
//  TBVPNService.m
//  ProxyDemo
//
//  Created by yang shizhong on 8/7/14.
//  Copyright (c) 2014 Tapberts Inc. All rights reserved.
//

#import "YYVPNService.h"

@interface YYVPNService ()
@end
@implementation YYVPNService

+(instancetype)sharedService {
    static YYVPNService *vpnServie_ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vpnServie_ = [[[self class] alloc] init];
    });
    return vpnServie_;
}

- (CFArrayRef )vpnList {
    CFMutableArrayRef servicesList = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    SCNetworkServiceRef	service;
    
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SCNetworkConnectionCopyAvailableServices"), NULL);
    if (prefs != NULL) {
        CFArrayRef services = SCNetworkServiceCopyAll(prefs);
        CFRelease(prefs);
        if (!services) return servicesList;
        
        for (int i = 0; i < CFArrayGetCount(services); i++) {
            service = CFArrayGetValueAtIndex(services, i);
            CFStringRef interfaceType = [self nameOfPPPService:service];
            if(!interfaceType)  continue;
            if (CFEqual(interfaceType, kSCNetworkInterfaceTypeIPSec)
                || CFEqual(interfaceType, kSCNetworkInterfaceTypeL2TP)
                || CFEqual(interfaceType, kSCNetworkInterfaceTypePPTP)) {
                CFArrayAppendValue(servicesList, service);
            }
        }
    }
    
    return servicesList;
}

- (SCNetworkConnectionRef )createAConnectionWithService:(SCNetworkServiceRef )service {
    if (NULL == service) return NULL;
    SCNetworkConnectionContext context = { 0, NULL, NULL, NULL, NULL };
    CFStringRef service_id = SCNetworkServiceGetServiceID(service);
    SCNetworkConnectionRef connection = SCNetworkConnectionCreateWithServiceID(NULL, service_id, NULL, &context);
    return connection;
}

- (CFStringRef )nameOfPPPService:(SCNetworkServiceRef)service {
    SCNetworkInterfaceRef interface;
    CFStringRef interfaceType;
    
    interface = SCNetworkServiceGetInterface(service);
    if (interface == NULL) return NULL;
    
    interfaceType = SCNetworkInterfaceGetInterfaceType(interface);
    if (!CFEqual(interfaceType, kSCNetworkInterfaceTypePPP))     return NULL;
    interface = SCNetworkInterfaceGetInterface(interface);
    interfaceType = SCNetworkInterfaceGetInterfaceType(interface);
    return interfaceType;
}

- (CFStringRef )nameOfPPPServiceID:(CFStringRef)service_id{
    SCNetworkServiceRef service = [self serviceFromServiceID:service_id];
    return [self nameOfPPPService:service];
}

- (void)startWithService:(SCNetworkServiceRef )service {
    SCNetworkConnectionRef connection = [self createAConnectionWithService:service];
    
    switch (SCNetworkConnectionGetStatus(connection)) {
        case kSCNetworkConnectionDisconnected: {
            if (!SCNetworkConnectionStart(connection, NULL, FALSE))
                NSLog(@"连接不成功!");
        }
            break;
        case kSCNetworkConnectionConnecting:
            NSLog(@"正在尝试连接...");
            break;
        case kSCNetworkConnectionDisconnecting:
            NSLog(@"连接已中断");
            break;
        case kSCNetworkConnectionConnected:
            NSLog(@"已经连接");
            break;
        case kSCNetworkConnectionInvalid:
            NSLog(@"无效服务");
            break;
        default:
            NSLog(@"异常");
            break;
    }
}

- (void)stopWithService:(SCNetworkServiceRef )service {
    SCNetworkConnectionRef connection = [self createAConnectionWithService:service];
    
    switch (SCNetworkConnectionGetStatus(connection)) {
        case kSCNetworkConnectionDisconnected: {
            NSLog(@"无连接");
            break;
        case kSCNetworkConnectionConnecting:
            NSLog(@"正在尝试连接...");
            break;
        case kSCNetworkConnectionDisconnecting:
            NSLog(@"连接已中断");
            break;
        case kSCNetworkConnectionConnected: {
            NSLog(@"正在断开连接...\n");
            if (!SCNetworkConnectionStop(connection, TRUE)) {
                NSLog(@"断开不成功!");
            }else {
                NSLog(@"断开成功!");
            }
        }
            break;
        case kSCNetworkConnectionInvalid:
            NSLog(@"无效服务");
            break;
        default:
            NSLog(@"异常");
            break;
        }
    }
}

- (SCNetworkServiceRef )serviceFromServiceID:(CFStringRef )service_id {
    //Catch off state
    if (CFEqual(service_id, CFSTR(""))) return NULL;
    //Look up name
    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SCNetworkConnectionCopyAvailableServices"), NULL);
    SCNetworkServiceRef service = SCNetworkServiceCopy(prefs, service_id);
    CFRelease(prefs);
    return service;
}

- (SCNetworkConnectionStatus )statusServiceAvilable:(SCNetworkServiceRef )service {
    SCNetworkConnectionRef connection_ = [self createAConnectionWithService:service];
    if (connection_ == NULL) return kSCNetworkConnectionInvalid;
    return SCNetworkConnectionGetStatus(connection_);
}


@end
