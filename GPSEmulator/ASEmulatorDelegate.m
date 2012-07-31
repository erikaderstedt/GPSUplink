//
//  ASAppDelegate.m
//  GPSEmulator
//
//  Created by Erik Aderstedt on 2012-07-31.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import "ASEmulatorDelegate.h"
#import "crc_check.h"

const unsigned char _endBytes[2] = { 0x0d, 0x0a };

const unsigned char gpsTestData[30]= {
    0x78,0x78,0x19,0x10,0x0B,0x03,
    0x1A,0x0B,0x1B,0x31,0xCC,0x02,
    0x7A,0xC7,0xFD,0x0C,0x46,0x57,
    0xBF,0x01,0x15,0x21,0x00,0x01,
    0x00,0x1C,0xC6,0x07,0x0D,0x0A};

unsigned char loginTestData[20] = {
    0x78,0x78, /* Start bit */
    0x0F, /* Length */
    0x01, /* Login package */
    0x03,0x53,0x41,0x90,0x30,0x08,0x01,0x59, /* IMEI */
    0x10,0x0B, /* Device type */
    0x00,0x01, /* Serial */
    0x00,0x00, /* CRC */
    0x0d,0x0a};

@implementation ASEmulatorDelegate

@synthesize connectionButton;
@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    connected = NO;
    uint16 j = GetCrc16(loginTestData + 2, 14);
    loginTestData[16] = j >> 8;
    loginTestData[17] = j & 255;
    endBytes = [[NSData alloc] initWithBytes:_endBytes length:2];
 }

- (IBAction)connect:(id)sender {
    if (connected) {
        [uplinkService disconnect];
        hlist = NULL;
    } else {
        hlist = dispatch_queue_create("GPS sender", DISPATCH_QUEUE_SERIAL);
        uplinkService = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:hlist];
        NSError *error = nil;
        NSString *host = @"localhost";
        host = @"77.53.0.109";
        if (![uplinkService connectToHost:host onPort:19913 error:&error]) {
            NSLog(@"rror: %@", error);
        }
    }
}

- (IBAction)sendInitialPackage:(id)sender {
    NSData *data = [[NSData alloc] initWithBytes:loginTestData length:20];
    [uplinkService writeData:data withTimeout:10.0 tag:22];
}

- (IBAction)sendGPSPackage:(id)sender {
    NSData *data = [[NSData alloc] initWithBytes:gpsTestData length:30];
    [uplinkService writeData:data withTimeout:10.0 tag:23];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [connectionButton setTitle:@"Disconnect"];
    connected = YES;
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"Wrote data with tag %ld, expecting response.", tag);
    [sock readDataToData:endBytes withTimeout:10.0 tag:1];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"Received response: %@", data);
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    NSLog(@"No response received within timeout.");
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    NSLog(@"Write timeout, retrying 10s …");
    return 10.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [connectionButton setTitle:@"Connect"];
    connected = NO;
}


@end
