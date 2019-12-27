//
//  LoggerXPCInfo.h
//  DrClient_mac
//
//  Created by ge on 2019/9/2.
//

#import <Foundation/Foundation.h>
#import "LoggerConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface LoggerXPCInfo : NSObject<NSCoding>

@property (strong, nonatomic) NSString *destLog;
@property (assign, nonatomic) LoggerLevel level;

@end

NS_ASSUME_NONNULL_END
