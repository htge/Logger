//
//  AppDelegate.m
//  DrClientLog
//
//  Created by Ge on 2019/5/7.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "AppDelegate.h"
#import "PrefWindowController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (IBAction)openPref:(id)sender {
    PrefWindowController *prefCtrl = [[PrefWindowController alloc] initWithWindowNibName:@"PrefWindowController"];
    [prefCtrl showWindow:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
