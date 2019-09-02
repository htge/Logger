//
//  LogXPCInfo.m
//  DrClient_mac
//
//  Created by ge on 2019/9/2.
//

#import "LoggerXPCInfo.h"

#define CODER_KEY_DESTLOG   @"destLog"
#define CODER_KEY_LEVEL     @"level"

@implementation LoggerXPCInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _destLog = [aDecoder decodeObjectForKey:CODER_KEY_DESTLOG];
        _level = [aDecoder decodeIntegerForKey:CODER_KEY_LEVEL];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_destLog forKey:CODER_KEY_DESTLOG];
    [aCoder encodeInteger:_level forKey:CODER_KEY_LEVEL];
}

@end
