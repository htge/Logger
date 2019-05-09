//
//  CommonDataManager.h
//  DrClientLog
//
//  Created by Ge on 2019/5/8.
//  Copyright © 2019 Ge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Pref+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface CommonDataManager : NSObject

+ (instancetype)defaultManager;

@property (strong, nonatomic) Pref *pref;

@end

NS_ASSUME_NONNULL_END
