//
//  Logger.h
//  DrClient_mac
//
//  Created by haitong on 2019/4/30.
//

#import <Foundation/Foundation.h>
#import "LoggerConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface Logger : NSObject

//输出文件缓存，默认64KB
+ (void)setMaxCacheSize:(NSInteger)cacheSize;

//控制台的日志分级，默认Error，只输出错误日志
+ (void)setLogLevel:(LoggerLevel)level;

//初始化文件之前，先设置好参数再初始化
+ (void)initFilePath:(NSString *)path config:(LoggerConfig *)config;

+ (void)info:(NSString *)format, ...;
+ (void)debug:(NSString *)format, ...;
+ (void)warn:(NSString *)format, ...;
+ (void)error:(NSString *)format, ...;

//流式加密写入需要手动调用结束过程
+ (void)endLogFile;

//解密
+ (NSArray <NSString *>*)decryptFromData:(NSData *)data config:(LoggerConfig *)config;
+ (NSData *)encryptData:(NSArray <NSString *>*)allLog config:(LoggerConfig *)config;

@end

NS_ASSUME_NONNULL_END
