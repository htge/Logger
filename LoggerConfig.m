//
//  LoggerConfig.m
//  DrClientLog
//
//  Created by Ge on 2019/5/13.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "LoggerConfig.h"

//64kb
#define MAX_CACHE_SIZE  65536

@implementation LoggerConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        self.header =  @"LOG_HEADER";
        self.cacheSize = MAX_CACHE_SIZE;
        self.logLevel = LoggerLevelDebug;
    }
    return self;
}

@end
