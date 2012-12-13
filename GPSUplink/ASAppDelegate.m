//
//  ASAppDelegate.m
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import "ASAppDelegate.h"
#import "ASRemoteDevice.h"

const unsigned char _endBytes[2] = { 0x0d, 0x0a };

const unsigned char gpsTestData[30]= {
    0x78,0x78,0x19,0x10,0x0B,0x03,
    0x1A,0x0B,0x1B,0x31,0xCC,0x02,
    0x7A,0xC7,0xFD,0x0C,0x46,0x57,
    0xBF,0x01,0x15,0x21,0x00,0x01,
    0x00,0x1C,0xC6,0x07,0x0D,0x0A};
#define READ_TIMEOUT    20.0

@implementation ASAppDelegate
@synthesize deviceTable;

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSError *error = nil;
    
    // Start a listening socket on port 19913
    
    gps_gprs_host_listener = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:nil];
    dispatch_queue_t hlist = dispatch_queue_create("GPS listener", DISPATCH_QUEUE_SERIAL);
    [gps_gprs_host_listener setDelegateQueue:hlist];
    if (![gps_gprs_host_listener acceptOnPort:19913 error:&error]) {
        NSLog(@"Error: %@", error);
    }
    
    endBytes = [[NSData alloc] initWithBytes:_endBytes length:2];
    
    connectedSockets = [[NSMutableArray alloc] initWithCapacity:25];
    
    NSLog(@"Now listening on port 19913.");
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"Accepted new socket from %@.", [newSocket connectedHost]);
    // Create a new device, and add it to the table
    
    ASRemoteDevice *device = [[ASRemoteDevice alloc] init];
    [newSocket setUserData:device];
    
    @synchronized(connectedSockets) {
        [connectedSockets addObject:newSocket];
    };
    
    [newSocket readDataToData:endBytes withTimeout:READ_TIMEOUT tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"A socket disconnected");
    @synchronized(connectedSockets) {
        [connectedSockets removeObject:sock];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.deviceTable reloadData];
        });
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    // Ok, we have a data packet in 'data'.

    if ([ASRemoteDevice validatePackage:data]) {
        ASRemoteDevice *device = (ASRemoteDevice *)[sock userData];
        
        NSData *response = [device handlePackage:data];
        if ([ASRemoteDevice isLoginPackage:data] && device.imei != nil) {
            // Check for duplicate IMEIs.
            NSMutableArray *removeThese = [NSMutableArray arrayWithCapacity:10];
            for (GCDAsyncSocket *socket in connectedSockets) {
                ASRemoteDevice *otherDevice = [socket userData];
                if (socket == sock) continue;
                if ([device.imei isEqualToString:otherDevice.imei]) {
                    [socket disconnect];
                    [removeThese addObject:socket];
                }
            }
            @synchronized (connectedSockets) {
                [connectedSockets removeObjectsInArray:removeThese];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.deviceTable reloadData];
            self.responseField.stringValue = device.lastResponse;
        });
        [sock writeData:response withTimeout:READ_TIMEOUT tag:1];
    } else {
        NSLog(@"Data %@ did not validate correctly.", data);
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [sock readDataToData:endBytes withTimeout:READ_TIMEOUT tag:0]; 
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    
    ASRemoteDevice *device = [sock userData];
    device.accumulatedReadTimeout = elapsed;
    return 10.0;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [connectedSockets count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if (rowIndex >= [connectedSockets count]) return nil;
    ASRemoteDevice *device = [[connectedSockets objectAtIndex:rowIndex] userData];
    if ([[aTableColumn identifier] isEqualToString:@"imei"]) {
        return device.imei;
    } else {
        ASGPSLocation *location = [device lastLocation];
        if (location != nil) {
            if ([[aTableColumn identifier] isEqualToString:@"latitude"]) {
                return [NSString stringWithFormat:@"%.6f", location.latitude];
            }   
            return [NSString stringWithFormat:@"%.6f", location.longitude];
        }
        return nil;
    }
    return nil;
}
    
- (IBAction)showSelectedDevice:(id)sender {
    NSInteger r = [self.deviceTable selectedRow];
    if (r < 0 || r >= [connectedSockets count]) return;
    
    ASRemoteDevice *device = [[connectedSockets objectAtIndex:r] userData];
    ASGPSLocation *location = [device lastLocation];
    if (location != nil) {
        NSString *s = [NSString stringWithFormat:@"http://maps.google.se/?ie=UTF8&ll=%.6f,%.6f", location.latitude, location.longitude];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:s]];
    }
}

- (IBAction)sendGPSON:(id)sender {
    NSInteger r = [self.deviceTable selectedRow];
    if (r < 0 || r >= [connectedSockets count]) return;
    
    self.responseField.stringValue = [NSString stringWithFormat:@"Sending GPSON#"];

    GCDAsyncSocket *socket = [connectedSockets objectAtIndex:r];
    ASRemoteDevice *device = [socket userData];
    NSData *rpackage = [device reactivationPackage];
    [socket writeData:rpackage withTimeout:10.0 tag:34];
}

- (IBAction)sendCommand:(id)sender {
    NSInteger r = [self.deviceTable selectedRow];
    if (r < 0 || r >= [connectedSockets count]) return;
    
    self.responseField.stringValue = [NSString stringWithFormat:@"Sending %@", self.commandField.stringValue];

    GCDAsyncSocket *socket = [connectedSockets objectAtIndex:r];
    ASRemoteDevice *device = [socket userData];
    NSData *rpackage = [device packageForCommand:self.commandField.stringValue];
    [socket writeData:rpackage withTimeout:10.0 tag:34];
}
@end
