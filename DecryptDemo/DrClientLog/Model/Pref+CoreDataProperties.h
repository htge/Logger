//
//  Pref+CoreDataProperties.h
//  DrClientLog
//
//  Created by Ge on 2019/5/8.
//  Copyright © 2019 Ge. All rights reserved.
//
//

#import "Pref+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Pref (CoreDataProperties)

+ (NSFetchRequest<Pref *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *header;
@property (nullable, nonatomic, retain) NSData *iv;
@property (nullable, nonatomic, copy) NSString *password;
@property (nonatomic) int64_t id;
@property (nonatomic) BOOL gzip;

@end

NS_ASSUME_NONNULL_END
