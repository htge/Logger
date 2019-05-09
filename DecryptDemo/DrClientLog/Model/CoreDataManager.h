//
//  CoreDataManager.h
//  DrClientLog
//
//  Created by Ge on 2019/5/8.
//  Copyright © 2019 Ge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CoreDataManager : NSObject

+ (instancetype)defaultManager;

//插入
-(id)insertNewObjectForEntityForName:(NSString *)entityName;
-(id)insertNewObjectWithNoContextForEntity:(NSString *)entityName;

//查询
-(NSArray *)fetchDataForAttribute:(NSString *)attributeName;
-(NSArray *)fetchDataForAttribute:(NSString *)attributeName sortDescriptor:(NSSortDescriptor *)sortDescriptor;
-(void)clearDataForAttribute:(NSString *)attributeName;

-(id)objectsForEntity:(NSString *)entityName matchingPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray *_Nullable)sortDescriptors;
-(id)objectsForEntity:(NSString *)entityName matchingPredicate:(NSPredicate *)predicate;
-(id)objectsForEntity:(NSString *)entityName matchingPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray *_Nullable)sortDescriptors limit:(NSUInteger)limit;
-(id)getObjectForEntity:(NSString *)entityName attribute:(NSString *)attributeName value:(id)value;

//删除
-(void)deleteObjects:(NSArray *)objects;
-(void)deleteObject:(NSManagedObject *)object;

//保存
-(void)saveData;
-(void)saveDataWithTemporaryMergePolicy:(id)temporaryMergePolicy;
-(BOOL)wipeData;
-(BOOL)isExist;

-(NSString *)storeFileName;
-(NSString *)currentStoreFileName;
-(BOOL)migrateData;

@end

NS_ASSUME_NONNULL_END
