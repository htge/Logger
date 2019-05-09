//
//  NSData+AES.m
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import "NSData+AES.h"

@implementation NSData (AES)

- (NSData *)crypt256:(NSString *)password iv:(NSData *)iv {
    char keyPtr[kCCKeySizeAES256 + 1] = {0};
    NSUInteger dataLength = [self length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    size_t numBytesDecrypted = 0;
    void *buffer = malloc(bufferSize);
    
    [password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    if (kCCSuccess == CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                              keyPtr, kCCKeySizeAES256, iv.bytes,
                              [self bytes], dataLength, buffer, bufferSize, &numBytesDecrypted)) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

- (NSData *)decrypt256:(NSString *)password iv:(NSData *)iv {
    char keyPtr[kCCKeySizeAES256 + 1] = {0};
    NSUInteger dataLength = [self length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    size_t numBytesDecrypted = 0;
    void *buffer = malloc(bufferSize);

    [password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    if (kCCSuccess == CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                keyPtr, kCCKeySizeAES256, iv.bytes,
                [self bytes], dataLength, buffer, bufferSize, &numBytesDecrypted)) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

- (NSData *)updateEncrypt256:(CCCryptorRef)cryptor password:(NSString *)password iv:(NSData *)iv {
    NSUInteger dataLength = self.length;
    char keyPtr[kCCKeySizeAES256 + 1] = {0};
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    size_t numBytesEncrypted = 0;
    void *buffer = malloc(bufferSize);
    
    //堆缓存建立，足够的长度即可
    [password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    if (kCCSuccess == CCCryptorUpdate(cryptor, [self bytes], dataLength,
                                      buffer, bufferSize, &numBytesEncrypted)) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}

@end
