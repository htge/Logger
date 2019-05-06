//
//  Logger.h
//  DrClient_mac
//
//  Created by haitong on 2019/4/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LoggerLevel) {
    LoggerLevelNone = 0,
    LoggerLevelError = 1,
    LoggerLevelInfo = 2,
    LoggerLevelDebug = 3,
};

@interface Logger : NSObject

//文件头，用于区分加密日志段
+ (void)setLogHeader:(NSString *)logHeader;

//输出文件缓存，默认64KB
+ (void)setMaxCacheSize:(NSInteger)cacheSize;

//设置加密向量，默认nil
+ (void)setIV:(NSData *)data;

//控制台，默认None
+ (void)setLogLevel:(LoggerLevel)level;

//输出文件，默认不输出
+ (void)setFileLogLevel:(LoggerLevel)level;
+ (void)initFilePath:(NSString *)path secretKey:(NSString *)secretKey;

+ (void)info:(NSString *)format, ...;
+ (void)debug:(NSString *)format, ...;
+ (void)error:(NSString *)format, ...;

//流式加密写入需要手动调用结束过程
+ (void)endLogFile;

//解密
+ (NSString *)decrypt:(NSString *)path password:(NSString *)password ;

@end

NS_ASSUME_NONNULL_END
