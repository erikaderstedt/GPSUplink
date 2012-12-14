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

+ (NSArray *)loadGPXFileAtURL:(NSURL *)url {
    NSError *error = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:&error];
    
    NSArray *tracks = [[document rootElement] elementsForName:@"trk"];
    if ([tracks count] == 0) return @[];
    tracks = [[tracks objectAtIndex:0] elementsForName:@"trkseg"];
    if ([tracks count] == 0) return @[];

    NSNumberFormatter *numberFormatter;
    numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setLocale:[NSLocale systemLocale]];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    NSArray *points = [[tracks objectAtIndex:0] elementsForName:@"trkpt"];
    NSMutableArray *locations = [NSMutableArray arrayWithCapacity:[points count]];
    for (NSXMLElement *trackPoint in points) {
        ASGPSLocation *location = [[ASGPSLocation alloc] init];
        location.longitude = [[numberFormatter numberFromString:[[trackPoint attributeForName:@"lon"] stringValue]] doubleValue];
        location.latitude = [[numberFormatter numberFromString:[[trackPoint attributeForName:@"lat"] stringValue]] doubleValue];
        
        NSArray *times = [trackPoint elementsForName:@"time"];
        for (NSXMLElement *time in times) {
            location.timestamp = [dateFormatter dateFromString:[time stringValue]];
        }
        [locations addObject:location];
    }
    return locations;
}


@end
