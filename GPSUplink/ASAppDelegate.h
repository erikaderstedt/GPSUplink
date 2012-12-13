//
//  ASAppDelegate.h
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"

@interface ASAppDelegate : NSObject <NSApplicationDelegate, GCDAsyncSocketDelegate, NSTableViewDataSource> {
    GCDAsyncSocket *gps_gprs_host_listener;
    NSData *endBytes;
    
    NSMutableArray *connectedSockets;
}

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTableView *deviceTable;

- (IBAction)showSelectedDevice:(id)sender;
- (IBAction)sendGPSON:(id)sender;
@property (weak) IBOutlet NSTextField *responseField;
- (IBAction)sendCommand:(id)sender;
@property (weak) IBOutlet NSTextField *commandField;

@end
