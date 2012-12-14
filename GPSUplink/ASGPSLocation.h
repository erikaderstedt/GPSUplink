//
//  ASGPSLocation.h
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ASGPSLocation : NSObject

@property (assign) double latitude; // In degrees. Negative values -> south.
@property (assign) double longitude; // In degrees. Negative values -> west.
@property (strong) NSDate *timestamp;

- (NSString *)stringRepresentation;
+ (NSString *)timestampRepresentationFor:(NSDate *)timestamp ;

+ (NSArray *)loadGPXFileAtURL:(NSURL *)url ;

@end
