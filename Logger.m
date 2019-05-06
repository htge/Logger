//
//  Logger.m
//  DrClient_mac
//
//  Created by haitong on 2019/4/30.
//

#import "Logger.h"
#import <CommonCrypto/CommonCrypto.h>

//64kb
#define MAX_CACHE_SIZE  65536

@interface Logger()

@property (assign, nonatomic) NSString *logHeader;
@property (assign, nonatomic) NSInteger cacheSize;
@property (strong, nonatomic) NSData *iv;
@property (assign, nonatomic) LoggerLevel level;
@property (assign, nonatomic) LoggerLevel fileLevel;
@property (strong, nonatomic) NSFileHandle *fileHandle;
@property (strong, nonatomic) NSString *fileSecretKey;
@property (assign, nonatomic) CCCryptorRef fileCryptor;
@property (strong, nonatomic) NSMutableData *fileCache;
@property (strong, nonatomic) NSLock *fileLock;

@end

@implementation Logger

+ (Logger *)getInstance {
    static dispatch_once_t onceToken;
    static Logger *logger;
    dispatch_once(&onceToken, ^{
        logger = [[Logger alloc] init];
        logger.fileCache = [NSMutableData data];
        logger.fileLock = [[NSLock alloc] init];
        logger.logHeader = @"LOG_HEADER";
        logger.cacheSize = MAX_CACHE_SIZE;
    });
    return logger;
}

+ (void)setLogHeader:(NSString *)logHeader {
    NSAssert(logHeader != nil, @"logHeader could not be null");
    [self getInstance].logHeader = logHeader;
}

+ (void)setMaxCacheSize:(NSInteger)cacheSize {
    NSAssert(cacheSize > 0 && cacheSize < 131072, @"Cache size out of range");
    [self getInstance].cacheSize = cacheSize;
}

+ (void)setIV:(NSData *)data {
    [self getInstance].iv = data;
}

+ (void)setLogLevel:(LoggerLevel)level {
    [self getInstance].level = level;
}

+ (void)setFileLogLevel:(LoggerLevel)level {
    [self getInstance].fileLevel = level;
}

+ (void)initFilePath:(NSString *)path secretKey:(NSString *)secretKey {
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    }
    if (isDirectory) {
        NSString *message = [NSString stringWithFormat:@"Is directory: \"%@\"", path];
        @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    if (!handle) {
        NSString *message = [NSString stringWithFormat:@"Could not write to file: \"%@\"", path];
        @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
    }
    [handle seekToEndOfFile];
    [handle writeData:[[self getInstance].logHeader dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self getInstance].fileHandle = handle;
    [self getInstance].fileSecretKey = secretKey;
    
    if (secretKey.length > 0) {
        CCCryptorRef cryptor;
        char keyPtr[kCCKeySizeAES256 + 1] = {0};
        [secretKey getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
        
        //建立句柄，用来动态追加，最后调用endLogFile销毁
        if (kCCSuccess == CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding, keyPtr, kCCKeySizeAES256,
                                          [self getInstance].iv.bytes, &cryptor)) {
            [self getInstance].fileCryptor = cryptor;
        }
    }
}

+ (NSData *)aes256Encrypt:(NSString *)string {
    NSString *key = [self getInstance].fileSecretKey;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger dataLength = data.length;
    char keyPtr[kCCKeySizeAES256 + 1] = {0};
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    //堆缓存建立，足够的长度即可
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    if (kCCSuccess == CCCryptorUpdate([self getInstance].fileCryptor,
                                      [data bytes], dataLength, buffer, bufferSize, &numBytesEncrypted)) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}

+ (NSData*)aes256Decrypt:(NSData*)data password:(NSString *)password {
    char keyPtr[kCCKeySizeAES256 + 1] = {0};

    [password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [data length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void* buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256, [self getInstance].iv.bytes,
                                          [data bytes], dataLength, buffer, bufferSize, &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

+ (void)outputToFile:(NSMutableString *)string {
    //最后要加换行符
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS "];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    [string insertString:dateStr atIndex:0];
    [string appendString:@"\n"];
    NSData *data = nil;
    if ([self getInstance].fileSecretKey.length > 0) {
        data = [self aes256Encrypt:string];
    } else {
        data = [string dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    //用队列写
    [[self getInstance].fileLock lock];
    NSMutableData *fileCache = [self getInstance].fileCache;
    [fileCache appendData:data];
    if (fileCache.length > MAX_CACHE_SIZE) {
        [[self getInstance].fileHandle writeData:fileCache];
        
        //每写一次以后就清缓存
        [self getInstance].fileCache = [NSMutableData data];
    }
    [[self getInstance].fileLock unlock];
}

+ (void)info:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelInfo;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelInfo && [self getInstance].fileHandle != nil;
    
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"INFO: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

+ (void)debug:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");

    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelDebug;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelDebug && [self getInstance].fileHandle != nil;
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"DEBUG: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

+ (void)error:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");

    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelError;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelError && [self getInstance].fileHandle != nil;
    
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"ERROR: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

+ (void)endLogFile {
    CCCryptorRef cryptor = [self getInstance].fileCryptor;
    if (cryptor) {
        NSFileHandle *handle = [self getInstance].fileHandle;
        if (handle) {
            char buffer[kCCBlockSizeAES128] = {0};
            size_t dataOutMoved = 0;
            if (kCCSuccess == CCCryptorFinal(cryptor, buffer, sizeof(buffer), &dataOutMoved)) {
                __block NSData *data = [NSData dataWithBytes:buffer length:dataOutMoved];

                [[self getInstance].fileLock lock];
                NSMutableData *fileCache = [self getInstance].fileCache;
                [fileCache appendData:data];
                [handle writeData:fileCache];
                
                //最后写肯定得清缓存
                [self getInstance].fileCache = [NSMutableData data];
                [[self getInstance].fileLock unlock];
            }
        }
        CCCryptorRelease(cryptor);
    }
}

+ (NSString *)decrypt:(NSString *)path password:(NSString *)password {
    NSAssert(path != nil, @"path could not be null");
    NSAssert(password != nil, @"password could not be null");

    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSMutableString *mStr = [NSMutableString stringWithString:@""];
    if (handle) {
        [handle seekToFileOffset:0];
        NSData *allData = [handle readDataToEndOfFile];
        NSInteger dataBegin = -1;
        NSData *headData = [[self getInstance].logHeader dataUsingEncoding:NSUTF8StringEncoding];
        while (true) {
            NSInteger searchBegin = dataBegin+1;
            NSRange searchRange = NSMakeRange(searchBegin, allData.length-searchBegin);
            NSRange headerRange = [allData rangeOfData:headData options:0 range:searchRange];
            if (headerRange.length != headData.length) {
                NSData *data = [allData subdataWithRange:NSMakeRange(dataBegin+1, allData.length-dataBegin-1)];
                [mStr appendFormat:@"%@ START\n", [self getInstance].logHeader];
                [mStr appendString:[self decryptData:data password:password]];
                [mStr appendFormat:@"%@ END\n", [self getInstance].logHeader];
                break;
            }
            if (dataBegin != -1) {
                NSInteger dataEnd = (NSInteger)headerRange.location;
                NSData *data = [allData subdataWithRange:NSMakeRange(dataBegin+1, dataEnd-dataBegin-1)];
                [mStr appendFormat:@"%@ START\n", [self getInstance].logHeader];
                [mStr appendString:[self decryptData:data password:password]];
                [mStr appendFormat:@"%@ END\n", [self getInstance].logHeader];
            }
            dataBegin = (NSInteger)(headerRange.location+headerRange.length-1);
        }
    }
    return mStr;
}

+ (NSString *)decryptData:(NSData *)data password:(NSString *)password {
    NSString *str = @"";
    if (data.length > 0) {
        NSData *decData = [self aes256Decrypt:data password:password];
        if (decData) {
            str = [[NSString alloc] initWithData:decData encoding:NSUTF8StringEncoding];
        }
    }
    return str;
}

@end
