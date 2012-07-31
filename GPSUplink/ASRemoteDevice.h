//
//  ASRemoteDevice.h
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASGPSLocation.h"

@interface ASRemoteDevice : NSObject

@property (strong) NSString *imei;
@property (assign) BOOL loggedIn;
@property (assign) NSInteger deviceType;
@property (strong) NSNumber *gsmSignalStrength;
@property (strong) NSMutableArray *gpsLocations;
@property (strong) NSDate *lastActivation;
@property (assign) NSTimeInterval accumulatedReadTimeout;
@property (assign) NSInteger packetCounter;

+ (BOOL)validatePackage:(NSData *)data;
- (NSData *)handlePackage:(NSData *)data;
+ (NSData *)standardServerResponseToPackage:(NSData *)data;
+ (BOOL)isLoginPackage:(NSData *)data;
- (ASGPSLocation *)lastLocation;

- (BOOL)shouldReactivate;
- (NSData *)reactivationPackage;

@end
