//
//  ASAppDelegate.h
//  GPSEmulator
//
//  Created by Erik Aderstedt on 2012-07-31.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"

@interface ASEmulatorDelegate : NSObject <NSApplicationDelegate,GCDAsyncSocketDelegate> {
    GCDAsyncSocket *uplinkService;
    BOOL connected;
    dispatch_queue_t hlist;
    NSData *endBytes;
}
@property (weak) IBOutlet NSButton *connectionButton;

@property (assign) IBOutlet NSWindow *window;
- (IBAction)connect:(id)sender;
- (IBAction)sendInitialPackage:(id)sender;
- (IBAction)sendGPSPackage:(id)sender;
- (IBAction)sendGPXFile:(id)sender;
@property (weak) IBOutlet NSProgressIndicator *gpxTransmissionProgress;

@end
