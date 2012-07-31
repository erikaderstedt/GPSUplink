//
//  ASGPSLocation.m
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import "ASGPSLocation.h"

static NSDateFormatter *timestampFormatter;

@implementation ASGPSLocation

@synthesize latitude, longitude, timestamp;

+ (NSString *)timestampRepresentationFor:(NSDate *)timestamp {
    if (timestampFormatter == nil) {
        timestampFormatter = [[NSDateFormatter alloc] init];
        [timestampFormatter setDateStyle:NSDateFormatterNoStyle];
        [timestampFormatter setTimeStyle:NSDateFormatterLongStyle];
    }
    return [timestampFormatter stringFromDate:timestamp];
}
- (NSString *)stringRepresentation {
    NSString *s = [NSString stringWithFormat:@"(%.6f,%.6f) at %@", self.latitude, self.longitude, [ASGPSLocation timestampRepresentationFor:self.timestamp]]; 
    return s;
}

@end
