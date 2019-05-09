//
//  Document.h
//  DrClientLog
//
//  Created by Ge on 2019/5/7.
//  Copyright © 2019 Ge. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Document : NSDocument

@property (strong) NSArray <NSString *>*list;

- (void)updateData;

@end

