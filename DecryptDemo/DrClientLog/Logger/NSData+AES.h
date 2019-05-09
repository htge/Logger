//
//  NSData+AES.h
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (AES)

- (NSData *)crypt256:(NSString *)password iv:(NSData *)iv;
- (NSData *)decrypt256:(NSString *)password iv:(NSData *)iv;
- (NSData *)updateEncrypt256:(CCCryptorRef)cryptor password:(NSString *)password iv:(NSData *)iv;

@end

NS_ASSUME_NONNULL_END
