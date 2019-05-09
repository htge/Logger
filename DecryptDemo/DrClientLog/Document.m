//
//  Document.m
//  DrClientLog
//
//  Created by Ge on 2019/5/7.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "Document.h"
#import "Logger/Logger.h"
#import "CommonDataManager.h"

@interface Document ()

@end

@implementation Document

+ (BOOL)autosavesInPlace {
    return YES;
}


- (void)makeWindowControllers {
    // Override to return the Storyboard file name of the document.
    [self addWindowController:[[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"]];
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error if you return nil.
    // Alternatively, you could remove this method and override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    @try {
        Pref *pref = [CommonDataManager defaultManager].pref;
        NSString *header = pref.header;
        NSString *password = pref.password;
        NSData *iv = pref.iv;
        BOOL useGzip = pref.gzip;
        [Logger setLogHeader:header];
        return [Logger encryptData:self.list password:password iv:iv useZip:useGzip];
    } @catch (NSException *e) {
        [Logger error:@"dataOfType: %@", e];
        return nil;
    }
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    if (self.isEntireFileLoaded) {
        return [self updateDataWithData:data];
    }
    return NO;
}

- (void)updateData {
    if (self.fileURL == nil) {
        return;
    }
    
    //刷新时，重读文件即可
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL options:NSDataReadingMappedAlways error:nil];
    if (data) {
        [self updateDataWithData:data];
    }
}

- (BOOL)updateDataWithData:(NSData *)data {
    // 解密完以后，后续触发列表显示
    // 限制文件长度为100M，数据不是完整的就不处理
    if (data.length > 0 && data.length < 104857600) {
        Pref *pref = [CommonDataManager defaultManager].pref;
        NSString *header = pref.header;
        NSString *password = pref.password;
        NSData *iv = pref.iv;
        BOOL useGzip = pref.gzip;
        if (iv.length == 0) {
            iv = nil;
        }
        if (password.length == 0) {
            password = nil;
        }
        [Logger setLogHeader:header];
        @try {
            self.list = [Logger decryptFromData:data password:password
                                             iv:iv useZip:useGzip];
            NSLog(@"data updated: count=%d", (int)self.list.count);
        } @catch (NSException *e) {
            [Logger error:@"updateDataWithData: %@", e];
        }
        return YES;
    }
    return NO;
}

@end
