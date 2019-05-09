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

//控制台的日志分级，默认Error，只输出错误日志
+ (void)setLogLevel:(LoggerLevel)level;

//文件的日志分级，默认Debug：所有日志都输出
+ (void)setFileLogLevel:(LoggerLevel)level;

//初始化文件之前，先设置好参数再初始化
+ (void)initFilePath:(NSString *)path secretKey:(NSString *_Nullable)secretKey iv:(NSData *_Nullable)iv useZip:(BOOL)useZip;

+ (void)info:(NSString *)format, ...;
+ (void)debug:(NSString *)format, ...;
+ (void)error:(NSString *)format, ...;

//流式加密写入需要手动调用结束过程
+ (void)endLogFile;

//解密
+ (NSArray <NSString *>*)decryptFromData:(NSData *)data password:(NSString *)password
                                      iv:(NSData *)iv useZip:(BOOL)useZip;
+ (NSData *)encryptData:(NSArray <NSString *>*)allLog password:(NSString *)password
                     iv:(NSData *)iv useZip:(BOOL)useZip;

@end

NS_ASSUME_NONNULL_END
