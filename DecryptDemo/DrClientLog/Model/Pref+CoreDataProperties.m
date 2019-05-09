//
//  Pref+CoreDataProperties.m
//  DrClientLog
//
//  Created by Ge on 2019/5/8.
//  Copyright © 2019 Ge. All rights reserved.
//
//

#import "Pref+CoreDataProperties.h"

@implementation Pref (CoreDataProperties)

+ (NSFetchRequest<Pref *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Pref"];
}

@dynamic header;
@dynamic iv;
@dynamic password;
@dynamic id;
@dynamic gzip;

@end
