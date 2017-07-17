//
//  NTJsonLiveQuery.m
//  Pods-NTJsonStoreTests
//
//  Created by  Ethan Nagel on 6/24/17.
//

#import "NTJsonStore+Private.h"

@interface NTJsonLiveQuery()

@property (nonatomic, readonly) NTJsonCollection *collection;

//@property (nonatomic, readonly) NSSet *fields;      // field names used in the query
//@property (nonatomic, readonly) NSSet *rowIds;      // ids of rows currently returned in the query
@property (nonatomic, readonly) BOOL hasChanged;    // true if changes are pending
@property (nonatomic, readonly) BOOL needsRequery;  // true if a full requery is required

//@property (nonatomic) NSMutableDictionary<NSNumber *, NSDictionary *> *updatedItems;
@property (nonatomic) NSMutableArray<void (^)(NTJsonChangeSet *)> *subscribers;

@end


@implementation NTJsonLiveQuery


-(instancetype)initWithCollection:(NTJsonCollection *)collection where:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit
{
    if (self = [super init])
    {
        _collection = collection;
        _where = [where copy];
        _args = [args copy]; // todo: deep copy
        _orderBy = [orderBy copy];
        _limit = limit;
        _subscribers = [NSMutableArray array];
        
        NSError *error;
        _items = [self.collection findWhere:self.where args:self.args orderBy:self.orderBy limit:self.limit error:&error];
        _lastError = error;
    }
    
    return self;
}


-(void)addSubscriber:(void (^)(NTJsonChangeSet *))subscriber
{
    [self.subscribers addObject:subscriber];
}


-(BOOL)hasChanged
{
    return _needsRequery;
}


- (void)collectionWasChanged
{
    _needsRequery = YES;
}


-(void)itemWasUpdated:(NSDictionary *)item
{
    [self collectionWasChanged];
}


-(void)itemWasInserted:(NSDictionary *)item
{
    [self collectionWasChanged];
}


-(void)itemWasDeleted:(NSDictionary *)item
{
    [self collectionWasChanged];
}


-(BOOL)pushChanges
{
    if (!self.hasChanged)
        return NO;
    
    NSArray *oldItems = self.items;
    NSArray *newItems;
    
    if (_needsRequery)
    {
        NSError *error;
        newItems = [self.collection findWhere:self.where args:self.args orderBy:self.orderBy limit:self.limit error:&error];
        
        _lastError = error;
        
        _needsRequery = NO;
    }
    
    else
    {
        newItems = oldItems;
        // todo - make in-memory changes
    }
    
    if (newItems)
        _items = newItems;
    
    NTJsonChangeSet *changeSet = [[NTJsonChangeSet alloc] initWithOldItems:oldItems newItems:newItems];
    
    if (!changeSet.hasChanges)
        return NO;
    
    [self.subscribers enumerateObjectsUsingBlock:^(void (^subscriber)(NTJsonChangeSet *), NSUInteger idx, BOOL * _Nonnull stop) {
        subscriber(changeSet);
    }];
    
    return YES;
}


-(void)close
{
    [self.collection closeLiveQuery:self];
}


@end

