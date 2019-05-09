//
//  CommonDataManager.m
//  DrClientLog
//
//  Created by Ge on 2019/5/8.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "CommonDataManager.h"
#import "CoreDataManager.h"

@implementation CommonDataManager

+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    static CommonDataManager *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CommonDataManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"id = %d", 1];
        NSArray<Pref *>* prefs = [[CoreDataManager defaultManager] objectsForEntity:@"Pref" matchingPredicate:predicate];
        Pref *pref = nil;
        if (prefs.count == 0) {
            pref = [[CoreDataManager defaultManager] insertNewObjectForEntityForName:@"Pref"];
            //init
            if (pref != nil) {
                pref.id = 1;
                pref.header = @"";
                pref.password = @"";
                pref.iv = [NSData data];
            }
            [[CoreDataManager defaultManager] saveData];
        } else {
            pref = prefs.firstObject;
        }
        self.pref = pref;
    }
    return self;
}

@end
