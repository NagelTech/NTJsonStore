//
//  NTJsonLiveQuery.h
//  Pods-NTJsonStoreTests
//
//  Created by  Ethan Nagel on 6/24/17.
//

#import <Foundation/Foundation.h>
#import "NTJsonChangeSet.h"

@class NTJsonCollection;

@interface NTJsonLiveQuery : NSObject

@property (nonatomic, readonly) NSString *where;
@property (nonatomic, readonly) NSArray *args;
@property (nonatomic, readonly) NSString *orderBy;
@property (nonatomic, readonly) int limit;
@property (nonatomic, readonly) NSError *lastError;

@property(nonatomic, readonly) NSArray<NSDictionary *> *items;

-(BOOL)pushChanges;
-(void)addSubscriber:(void (^)(NTJsonChangeSet *changeSet))subscriber;
-(void)close;

@end


@interface NTJsonLiveQuery(Private)

-(instancetype)initWithCollection:(NTJsonCollection *)collection where:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;

-(void)collectionWasChanged;
-(void)itemWasUpdated:(NSDictionary *)item;
-(void)itemWasInserted:(NSDictionary *)item;
-(void)itemWasDeleted:(NSDictionary *)item;

@end
