//
//  PrefWindowController.m
//  DrClientLog
//
//  Created by Ge on 2019/5/8.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "PrefWindowController.h"
#import "CoreDataManager.h"
#import "CommonDataManager.h"
#import "Document.h"
#import "ViewController.h"

@interface PrefWindowController ()

@property (weak) IBOutlet NSTextField *logHeader;
@property (weak) IBOutlet NSTextField *logPassword;
@property (weak) IBOutlet NSTextField *logIV;
@property (weak) IBOutlet NSButtonCell *useGzip;

@end

@implementation PrefWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];

    Pref *pref = [CommonDataManager defaultManager].pref;
    if (pref.header != nil) {
        self.logHeader.stringValue = pref.header;
    }
    if (pref.password != nil) {
        self.logPassword.stringValue = pref.password;
    }
    
    NSMutableString *iv = [NSMutableString string];
    if (pref.iv) {
        NSData *ivData = pref.iv;
        for (int i=0; i<ivData.length; i++) {
            uint data = 0;
            [ivData getBytes:&data range:NSMakeRange(i, 1)];
            [iv appendFormat:@"%02X", data];
        }
    }
    self.logIV.stringValue = iv;
    self.useGzip.intValue = pref.gzip;
    
    [self.window makeKeyAndOrderFront:self];
    [self.window orderFrontRegardless];
    
    //非得这样设置才可以触发windowWillClose，只做通知中心监听和delegate都没用
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(INT_MAX * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.window performClose:nil];
    });
}

- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"will close");
    Pref *pref = [CommonDataManager defaultManager].pref;
    pref.header = self.logHeader.stringValue;
    pref.password = self.logPassword.stringValue;
    pref.gzip = self.useGzip.intValue;
    
    NSString *iv = self.logIV.stringValue;
    
    NSMutableData *mIV = [NSMutableData data];
    NSRange range = NSMakeRange(0, iv.length>=2?2:iv.length);
    while (range.length > 0) {
        NSString *substr = [iv substringWithRange:range];
        NSScanner *scanner = [NSScanner scannerWithString:substr];
        uint val = 0;
        if ([scanner scanHexInt:&val]) {
            //如果是单数的情况，后面自动补0
            if (range.length == 1) {
                val*=16;
            }
            [mIV appendBytes:&val length:1];
        } else {
            break;
        }
        range.location += 2;
        NSInteger remain = iv.length-range.location;
        range.length = remain>=2?2:remain;
    }
    pref.iv = mIV;
    [[CoreDataManager defaultManager] saveData];
   
    //通知，所有窗口都重新更新一遍
    NSArray *docs = [NSDocumentController sharedDocumentController].documents;
    for (NSDocument *document in docs) {
        if ([document isKindOfClass:[Document class]]) {
            [((Document *)document) updateData];
            NSArray<__kindof NSWindowController *>*windows = document.windowControllers;
            for (NSWindowController *window in windows) {
                NSViewController *viewctrl = window.contentViewController;
                if ([viewctrl isKindOfClass:[ViewController class]]) {
                    [((ViewController *)viewctrl) updateData];
                }
            }
        }
    }
}

@end
