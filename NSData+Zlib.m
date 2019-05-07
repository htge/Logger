//
//  NSData+Zlib.m
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import "NSData+Zlib.h"

@implementation NSData(ZLIB)

- (NSData *)deflate {
    NSMutableData *mdata = [NSMutableData data];
    z_stream strm = { 0 };
    int windowBits = 15;
    int GZIP_ENCODING = 16;
    if (deflateInit2(&strm, Z_BEST_SPEED, Z_DEFLATED, windowBits | GZIP_ENCODING,
                     8, Z_DEFAULT_STRATEGY) < 0) {
        return nil;
    }
    int chunk = 128;
    char *chunk_in = malloc(chunk);
    if (!chunk_in) {
        return nil;
    }
    char *chunk_out = malloc(chunk);
    if (!chunk_out) {
        free(chunk_in);
        return nil;
    }
    int start = 0;
    int len = (int)(self.length > chunk ? chunk : self.length);
    while (true) {
        [self getBytes:chunk_in range:NSMakeRange(start, len)];
        strm.next_in = (Bytef *)chunk_in;
        strm.avail_in = len;
        strm.avail_out = chunk;
        strm.next_out = (Bytef *)chunk_out;
        if (deflate(&strm, Z_BLOCK) < 0) {
            break;
        }
        int have = chunk - strm.avail_out;
        [mdata appendBytes:chunk_out length:have];
        start += len;
        int remain = (int)(self.length - start);
        len = remain > chunk ? chunk : remain;
        if (len <= 0) break;
    }
    free(chunk_in);
    free(chunk_out);
    deflateEnd(&strm);
    return mdata;
}

- (NSData *)deflateWithStream:(z_stream *)pstrm chunk:(int)chunk {
    if (chunk < 128) {
        return nil;
    }
    NSMutableData *mdata = [NSMutableData data];
    int start = 0;
    int len = (int)(self.length > chunk ? chunk : self.length);
    char *chunk_in = malloc(chunk);
    if (!chunk_in) {
        return nil;
    }
    char *chunk_out = malloc(chunk);
    if (!chunk_out) {
        free(chunk_in);
        return nil;
    }
    while (true) {
        @try {
            [self getBytes:chunk_in range:NSMakeRange(start, len)];
        } @catch (NSException *e) {
            NSLog(@"deflateWithStream cause exception: %@", e);
            break;
        }
        
        pstrm->next_in = (Bytef *)chunk_in;
        pstrm->avail_in = len;
        pstrm->avail_out = chunk;
        pstrm->next_out = (Bytef *)chunk_out;
        if (deflate(pstrm, Z_BLOCK) < 0) {
            break;
        }
        int have = chunk - pstrm->avail_out;
        [mdata appendBytes:chunk_out length:have];
        start += len;
        int remain = (int)(self.length - start);
        len = remain > chunk ? chunk : remain;
        if (len <= 0) break;
    }
    return mdata;
}

- (NSData *)inflate {
    NSMutableData *mdata = [NSMutableData data];
    z_stream strm = { 0 };
    int windowBits = 15;
    int GZIP_ENCODING = 16;
    if (inflateInit2(&strm, windowBits | GZIP_ENCODING) < 0) {
        return nil;
    }
    int chunkout = 10240;
    int chunkin = 1024;
    char *chunk_in = malloc(chunkin);
    if (!chunk_in) {
        return nil;
    }
    char *chunk_out = malloc(chunkout);
    if (!chunk_out) {
        free(chunk_in);
        return nil;
    }
    int start = 0;
    int len = (int)(self.length > chunkin ? chunkin : self.length);
    while (true) {
        [self getBytes:chunk_in range:NSMakeRange(start, len)];
        strm.next_in = (Bytef *)chunk_in;
        strm.avail_in = len;
        strm.avail_out = chunkout;
        strm.next_out = (Bytef *)chunk_out;
        if (inflate(&strm, Z_NO_FLUSH) < 0) {
            NSLog(@"inflate_err: %i", errno);
            break;
        }
        int have = chunkout - strm.avail_out;
        [mdata appendBytes:chunk_out length:have];
        start += len;
        int remain = (int)(self.length - start);
        len = remain > chunkin ? chunkin : remain;
        if (len <= 0) break;
    }
    free(chunk_in);
    free(chunk_out);
    inflateEnd(&strm);
    return mdata;
}

@end
