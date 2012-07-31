//
//  ASRemoteDevice.m
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import "ASRemoteDevice.h"
#import "crc_check.h"
#import "ASGPSLocation.h"

enum GT03BProtocolNumber {
    kGT03BLogin = 0x01,
    kGT03BGPS = 0x10,
    kGT03BLBS = 0x11,
    kGT03BGPSLBSMerged = 0x12,
    kGT03BStatus = 0x13,
    kGT03BSatelliteSNR = 0x14,
    kGT03BStrings = 0x15,
    kGT03BGPSLBSStatusMerged = 0x16,
    kGT03BLBSLocationViaPhoneNumber = 0x17,
    kGT03BLBSExtend = 0x18,
    kGT03BLBSStatusMerged = 0x19,
    kGT03BGPSLocationViaPhoneNumber = 0x1A,
    kGT03BServerCommandSet = 0x80,
    kGT03BServerCommandCheck = 0x81
};

#define PACKET_START_BYTE1  0
#define PACKET_START_BYTE2  1
#define PACKET_LENGTH       2
#define PACKET_PROTOCOL     3
#define PACKET_CONTENT_START 4

uint32_t get32Bits(const unsigned char *b) {
    uint32_t x;
    x = (b[0] << 24) + (b[1] << 16) + (b[2] << 8) + (b[3]);
    return x;
}

void set32Bits(unsigned char *b, uint32_t value) {
    b[0] = ((value & 0xff000000) >> 24);
    b[1] = ((value & 0x00ff0000) >> 16);
    b[2] = ((value & 0x0000ff00) >> 8);
    b[3] = ((value & 0x000000ff) >> 0);
}

uint16_t get16Bits(const unsigned char *b) {
    uint16_t x;
    x = (b[0] << 8) + (b[1]);
    return x;
}

void set16Bits(unsigned char *b, uint16_t value) {
    b[0] = ((value & 0x0000ff00) >> 8);
    b[1] = ((value & 0x000000ff) >> 0);
}

double secondsToDegrees(uint32_t fiveHundredthsOfASeconds) {
    double j = fiveHundredthsOfASeconds;
    j /= 500.0;
    
    j /= 3600.0;
    
    return j;
}

@implementation ASRemoteDevice

@synthesize imei, loggedIn;
@synthesize gpsLocations;
@synthesize deviceType;
@synthesize gsmSignalStrength;
@synthesize lastActivation;
@synthesize accumulatedReadTimeout;
@synthesize packetCounter;

- (id)init
{
    self = [super init];
    if (self) {
        self.gpsLocations = [[NSMutableArray alloc] init];
        self.packetCounter = 1;
    }
    return self;
}

+ (BOOL)validatePackage:(NSData *)data {
    NSUInteger length = [data length];
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    BOOL malformed = NO;
    
    // Confirm start bytes    
    if (length < 2 || bytes[PACKET_START_BYTE1] != 0x78 || bytes[PACKET_START_BYTE2] != 0x78) {
        malformed = YES;
    }
    // Confirm packet length
    if (length < 3 || bytes[PACKET_LENGTH] != length - 5) {
        malformed = YES;
    }
    
    if (!malformed && GetCrc16(bytes + 2, length - 6)) {
        unsigned short checksum = GetCrc16(bytes + 2, length - 6);
        // Big-endian
        unsigned short error_check = get16Bits(bytes + length - 4);
        
        if (error_check != checksum) malformed = YES;
    }
    
    return !malformed;
}

+ (BOOL)isLoginPackage:(NSData *)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    return ((enum GT03BProtocolNumber)bytes[PACKET_PROTOCOL] == kGT03BLogin);
}

- (NSData *)handlePackage:(NSData *)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    enum GT03BProtocolNumber pNumber = (enum GT03BProtocolNumber)bytes[PACKET_PROTOCOL];
    unsigned short i, j;
    ASGPSLocation *location;
    
    if (pNumber != kGT03BLogin && !self.loggedIn) {
        NSLog(@"Received data from a device that wasn't logged in.");
        return nil;
    }
    NSMutableString *imeiString = [NSMutableString stringWithCapacity:16];
    bytes += PACKET_CONTENT_START;
    char *serverResponse[257];
    switch (pNumber) {
        case kGT03BLogin:            
            // IMEI
            for (i = 0; i < 8; i++) {
                j = bytes[i];
                [imeiString appendString:[NSString stringWithFormat:@"%c%c",'0'+(j >> 4), '0'+(j & 0xf)]];
            }
            self.imei = imeiString;
            NSLog(@"Login from IMEI %@", self.imei);
            
            // Device type
            i = bytes[8];
            i = (i << 8) + bytes[9];
            self.deviceType = i;
            self.loggedIn = YES;
            
            break;
        case kGT03BStatus:
            self.gsmSignalStrength = [NSNumber numberWithChar:bytes[2]];
            NSLog(@"IMEI %@ reports signal strength %@", self.imei, self.gsmSignalStrength);
            break;
        case kGT03BGPS:
            location = [[ASGPSLocation alloc] init];
            location.timestamp = [NSDate dateWithString:[NSString stringWithFormat:@"2%03d-%02d-%02d %02d:%02d:%02d +0000", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]]];
            location.latitude = secondsToDegrees(get32Bits(bytes+7));
            location.longitude = secondsToDegrees(get32Bits(bytes+11));;
            if (!(bytes[16] & 4)) location.latitude *= -1.0;
            if (bytes[16] & 8) location.longitude *= -1.0;
            
            NSLog(@"Received location %@ from IMEI %@", [location stringRepresentation], self.imei);
            [self.gpsLocations addObject:location];
            break;
        case kGT03BLBS:
            
            // Not interesting for us.
            break;
        case kGT03BServerCommandSet:
            strncpy(serverResponse, bytes+5, bytes[0]);
            serverResponse[bytes[0]] = 0;
            NSLog(@"Device response: %@", self.imei, [NSString stringWithCString:serverResponse encoding:NSASCIIStringEncoding]);
            break;
        default:
            NSLog(@"Unexpected protocol %d from device %@.", pNumber, self.imei);
            break;
    }
    
    return [ASRemoteDevice standardServerResponseToPackage:data];
}

+ (NSData *)standardServerResponseToPackage:(NSData *)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    // Assumes a previous check against malformed data.
    unsigned char rbytes[10];
    rbytes[PACKET_START_BYTE1] = 0x78;
    rbytes[PACKET_START_BYTE2] = 0x78;
    rbytes[PACKET_LENGTH] = 5;
    rbytes[PACKET_PROTOCOL] = bytes[PACKET_PROTOCOL];
    rbytes[4] = bytes[[data length] - 6];
    rbytes[5] = bytes[[data length] - 5];
    
    unsigned short crc = GetCrc16(rbytes + 2, 4);
    rbytes[6] = (crc & 0xff00) >> 8;
    rbytes[7] = crc & 0xff;
    rbytes[8] = 0x0d;
    rbytes[9] = 0x0a;
    
    return [[NSData alloc] initWithBytes:rbytes length:10];
}

- (ASGPSLocation *)lastLocation {
    if ([self.gpsLocations count])
        return [self.gpsLocations lastObject];
    
    return nil;
}

- (BOOL)shouldReactivate {
    if (self.lastActivation == nil || 
        [[self.lastActivation dateByAddingTimeInterval:15.0*60] compare:[NSDate date]] == NSOrderedAscending) {
        return YES;
    }
    return NO;
}

- (NSData *)reactivationPackage {
    // Server command GPSOFF#, GPSON#. Behövs båda?
    unsigned char rbytes[21];
    rbytes[PACKET_START_BYTE1] = 0x78;
    rbytes[PACKET_START_BYTE2] = 0x78;
    rbytes[PACKET_LENGTH] = 0x10;
    rbytes[PACKET_PROTOCOL] = kGT03BServerCommandSet;
    rbytes[PACKET_CONTENT_START] = 10; // Length of command + server serial
    set32Bits(rbytes+PACKET_CONTENT_START+1, self.packetCounter ++);
    strncpy((char *)rbytes+PACKET_CONTENT_START+5, "GPSON#", 6);
    set16Bits(rbytes+PACKET_CONTENT_START+11, self.packetCounter - 1);
    set16Bits(rbytes+PACKET_CONTENT_START+13, GetCrc16(rbytes + 2, 15));
    rbytes[PACKET_CONTENT_START+15] = 0x0d;
    rbytes[PACKET_CONTENT_START+16] = 0x0a;
    
    return [[NSData alloc] initWithBytes:rbytes length:21];

    return nil;
}
@end
