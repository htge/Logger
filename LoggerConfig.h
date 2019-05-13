//
//  LoggerConfig.h
//  DrClientLog
//
//  Created by Ge on 2019/5/13.
//  Copyright © 2019 Ge. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LoggerLevel) {
    LoggerLevelNone = 0,
    LoggerLevelError = 1,
    LoggerLevelWarn = 2,
    LoggerLevelInfo = 3,
    LoggerLevelDebug = 4,
};

@interface LoggerConfig : NSObject

@property (assign, nonatomic) NSUInteger cacheSize;
@property (assign, nonatomic) LoggerLevel logLevel;
@property (strong, nonatomic) NSString *header;
@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSData *iv;
@property (assign, nonatomic) BOOL isGzip;

@end

NS_ASSUME_NONNULL_END
