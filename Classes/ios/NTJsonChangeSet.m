//
//  NTJsonChangeSet.m
//  NTJsonStore
//
//  Created by  Ethan Nagel on 6/24/17.
//

#import "NTJsonStore+Private.h"


#define DEBUG_UPDATE_MANAGER

#ifdef DEBUG_UPDATE_MANAGER
#   define DBG(...)  NSLog(__VA_ARGS__)
#else
#   define DBG(...)
#endif

#define ERR(...)  NSLog(__VA_ARGS__)


@implementation NTJsonChangeSetChange


-(NSInteger)itemId
{
    return [self.item[NTJsonRowIdKey] integerValue];
}


- (instancetype)initWithAction:(NTJsonChangeSetAction)action oldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex item:(NSDictionary *)item
{
    if (self = [super init])
    {
        _action = action;
        _oldIndex = oldIndex;
        _newIndex = newIndex;
        _item = item;
    }
    
    return self;
}


+ (instancetype)insertWithNewIndex:(NSInteger)newIndex item:(NSDictionary *)item
{
    return [[NTJsonChangeSetChange alloc] initWithAction:NTJsonChangeSetActionInsert oldIndex:-1 newIndex:newIndex item:item];
}


+ (instancetype)deleteWithOldIndex:(NSInteger)oldIndex item:(NSDictionary *)item
{
    return [[NTJsonChangeSetChange alloc] initWithAction:NTJsonChangeSetActionDelete oldIndex:oldIndex newIndex:-1 item:item];
}


+(instancetype)updateWithOldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex item:(NSDictionary *)item
{
    return [[NTJsonChangeSetChange alloc] initWithAction:NTJsonChangeSetActionUpdate oldIndex:oldIndex newIndex:newIndex item:item];
}


+(instancetype)moveWithOldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex item:(NSDictionary *)item
{
    return [[NTJsonChangeSetChange alloc] initWithAction:NTJsonChangeSetActionMove oldIndex:oldIndex newIndex:newIndex item:item];
}


- (BOOL)isEqualToChange:(NTJsonChangeSetChange *)other
{
    return self.action == other.action && self.oldIndex == other.oldIndex && self.newIndex == other.newIndex;
    // && (self.item == other.item || [self.item isEqualToDictionary:other.item]);
}


- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[NTJsonChangeSetChange class]] && [self isEqualToChange:object];
}


- (NSUInteger)hash
{
    return self.action ^ (self.oldIndex << 5) ^ (self.newIndex << 10); // ^ (self.item.hash << 15);
}


- (NSString *)description
{
    NSString *desc;
    
    switch(self.action)
    {
        case NTJsonChangeSetActionInsert:
            desc = [NSString stringWithFormat:@"Insert[Id=%td] %td", self.itemId, self.newIndex];
            break;
            
        case NTJsonChangeSetActionDelete:
            desc = [NSString stringWithFormat:@"Delete[Id=%td] %td", self.itemId, self.oldIndex];
            break;
            
        case NTJsonChangeSetActionMove:
            desc = [NSString stringWithFormat:@"Move[Id=%td] %td -> %td", self.itemId, self.oldIndex, self.newIndex];
            break;
            
        case NTJsonChangeSetActionUpdate:
            desc = [NSString stringWithFormat:@"Update[Id=%td] %td -> %td", self.itemId, self.oldIndex, self.newIndex];
            break;
            
        default:
            desc = @"Unknown";
    }
    
    return [NSString stringWithFormat:@"NTJsonChangeSetChange(%@)", desc];
}


@end


@implementation NTJsonChangeSet


-(BOOL)hasChanges
{
    return self.changes.count > 0;
}


- (instancetype)initWithOldItems:(NSArray<NSDictionary *> *)oldItems newItems:(NSArray<NSDictionary *> *)newItems
{
    
    if (self = [super init])
    {
        _oldItems = oldItems;
        _items = newItems;
        _changes = [self.class getChangesWithOldItems:oldItems newItems:newItems];
    }
    
    return self;
}


+ (NSArray<NTJsonChangeSetChange *> *)getChangesWithOldItems:(NSArray<NSDictionary *> *)oldItems newItems:(NSArray<NSDictionary *> *)newItems
{
    return [self getChanges2WithOldItems:oldItems newItems:newItems];
}


+ (NSArray<NTJsonChangeSetChange *> *)getChanges1WithOldItems:(NSArray<NSDictionary *> *)oldItems newItems:(NSArray<NSDictionary *> *)newItems
{
    NSMutableArray *changes = [NSMutableArray array];
    
    // NOT WORKING CURRENTLY
    
    NSMutableSet *oldItemIds = [NSMutableSet setWithArray:[oldItems valueForKey:NTJsonRowIdKey]];
    NSMutableSet *newItemIds = [NSMutableSet setWithArray:[newItems valueForKey:NTJsonRowIdKey]];
    
    NSMutableDictionary<NSNumber *, NSNumber *> *movedFrom = [NSMutableDictionary dictionary]; // oldItemId -> oldIndex
    //NSMutableDictionary<NSNumber *, NSNumber *> *movedTo = [NSMutableDictionary dictionary]; // newItemId -> newIndex
    
    NSUInteger oldIndex = 0;
    
    for(NSUInteger newIndex=0; newIndex<newItems.count; newIndex++)
    {
        NSDictionary *newItem = newItems[newIndex];
        NSNumber *newItemId = newItem[NTJsonRowIdKey];
        
        //        DBG(@" --> index=%d, id=%@", index, itemId);
        
        if ( ![oldItemIds containsObject:newItemId] )     // if it's not in our snapshot, it's an add, go ahead and track that...
        {
            DBG(@"insert: %td", newIndex);
            [changes addObject:[NTJsonChangeSetChange insertWithNewIndex:newIndex item:newItem]];
            continue;   // all done!
        }
        
        while( oldIndex < oldItems.count )
        {
            NSDictionary *oldItem = oldItems[oldIndex];
            NSNumber *oldItemId = oldItem[NTJsonRowIdKey];
            
            //            DBG(@"     snapshotIndex=%d, id=%@", snapshotIndex, snapshotItem.itemId);
            
            if ( [oldItemId isEqual:newItemId] )        // ahh we have found the matching item.
            {
                // The id's match, let's see if the objects match...
                
                if ( ![oldItem isEqualToDictionary:newItem] )
                {
                    // if values don't match, then it must be an update...
                    DBG(@"update: %td -> %td", oldIndex, newIndex);
                    
                    [changes addObject:[NTJsonChangeSetChange updateWithOldIndex:oldIndex newIndex:newIndex item:newItem]];
                }
                
                [oldItemIds removeObject:oldItemId];
                ++oldIndex;
                break;
            }
            
            // we know the items don't match, if this item isn't in our new ids then it is a delete...
            
            if (![newItemIds containsObject:oldItemId])
            {
                DBG(@"delete: %td", oldIndex);
                [changes addObject:[NTJsonChangeSetChange deleteWithOldIndex:oldIndex item:oldItem]];
                
                [oldItemIds removeObject:oldItemId];
                ++oldIndex;
            }
            else
            {
                DBG(@"move(oldIndex): %td", oldIndex);
                
                // If the old item is in our new id's then it is not in the same order.
                // This is the oldItem half of a move.
                
                movedFrom[oldItemId] = @(oldIndex);
                
                ++oldIndex;
            }
        }
        
        
    }
    
    // If there are any remaining items in our snapshot, they must be deletes...
    
    [oldItemIds enumerateObjectsUsingBlock:^(NSNumber *oldItemId, BOOL *stop) {
        
        NSInteger oldIndex = [oldItems indexOfObjectPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
            return [item[NTJsonRowIdKey] isEqual:oldItemId];
        }];
        
        DBG(@"delete: %td", oldIndex);
        
        [changes addObject:[NTJsonChangeSetChange deleteWithOldIndex:oldIndex item:oldItems[oldIndex]]];
    }];
    
    
    // todo: sort appropriately
    
    return [changes copy];
}


+ (NSArray<NTJsonChangeSetChange *> *)getChanges2WithOldItems:(NSArray<NSDictionary *> *)oldItems newItems:(NSArray<NSDictionary *> *)newItems {
    NSMutableArray *changes = [NSMutableArray array];
    
    // Create maps of the item Id's and indexes for each of our source arrays...
    
    // oldItemId -> oldIndex
    NSMutableDictionary<NSNumber *, NSNumber *> *oldItemIds = [NSMutableDictionary dictionaryWithCapacity:oldItems.count];
    [oldItems enumerateObjectsUsingBlock:^(NSDictionary *oldItem, NSUInteger oldIndex, BOOL *stop) {
        oldItemIds[oldItem[NTJsonRowIdKey]] = @(oldIndex);
    }];
    
    // newItemId -> newIndex
    NSMutableDictionary<NSNumber *, NSNumber *> *newItemIds = [NSMutableDictionary dictionaryWithCapacity:newItems.count];
    [newItems enumerateObjectsUsingBlock:^(NSDictionary *newItem, NSUInteger newIndex, BOOL *stop) {
        newItemIds[newItem[NTJsonRowIdKey]] = @(newIndex);
    }];
    
    // Find deletes & build remaining old items...
    
    NSMutableArray<NSDictionary *> *remainingOldItems = [NSMutableArray array];
    [oldItems enumerateObjectsUsingBlock:^(NSDictionary *oldItem, NSUInteger oldIndex, BOOL *stop) {
        NSNumber *itemId = oldItem[NTJsonRowIdKey];
        if (!newItemIds[itemId])
            [changes addObject:[NTJsonChangeSetChange deleteWithOldIndex:oldIndex item:oldItem]];
        else
            [remainingOldItems addObject:oldItem];
    }];

    // Find Inserts & build remaining new items...
    
    NSMutableArray<NSDictionary *> *remainingNewItems = [NSMutableArray array];
    [newItems enumerateObjectsUsingBlock:^(NSDictionary *newItem, NSUInteger newIndex, BOOL *stop) {
        NSNumber *itemId = newItem[NTJsonRowIdKey];
        if (!oldItemIds[itemId])
            [changes addObject:[NTJsonChangeSetChange insertWithNewIndex:newIndex item:newItem]];
        else
            [remainingNewItems addObject:newItem];
    }];
    
    // Remaining items were not inserted or deleted, they could be the same, updates or moves...
    
    [remainingNewItems enumerateObjectsUsingBlock:^(NSDictionary *remainingNewItem, NSUInteger remainingNewIndex, BOOL *stop) {
        NSDictionary *remainingOldItem = remainingOldItems[remainingNewIndex];
        
        if ([remainingNewItem isEqualToDictionary:remainingOldItem])
            return; // no changes, we are done with this item.
        
        NSNumber *remainingNewItemId = remainingNewItem[NTJsonRowIdKey];
        NSNumber *remainingOldItemId = remainingOldItem[NTJsonRowIdKey];
        
        // this is either an update or a move. Either way we need to know the actual indexes...
        
        NSInteger oldIndex = [oldItemIds[remainingNewItemId] integerValue];    // the index of the NewItemId in oldItems
        NSInteger newIndex = [newItemIds[remainingNewItemId] integerValue];
        
        if ([remainingNewItemId isEqual:remainingOldItemId]) // if item ids are the same it's an update...
            [changes addObject:[NTJsonChangeSetChange updateWithOldIndex:oldIndex newIndex:newIndex item:remainingNewItem]];
        else
        {
            BOOL checkUpdate = YES;
            
            // if the NEXT itemId in remainingOldItems is the same as the current newRemainingId then we will do a
            // MOVE DOWN, otherwise we preform a MOVE UP. Either approach works, but when we can pick the right one.
            // it is more efficient and more visually pleasing.
            
            NSDictionary *nextRemainingOldItem = remainingOldItems[remainingNewIndex + 1];  // always safe because there must be a second item to reorder
            NSNumber *nextRemainingOldItemId = nextRemainingOldItem[NTJsonRowIdKey];
            
            if ([nextRemainingOldItemId isEqual:remainingNewItemId]) {
                // MOVE DOWN
                oldIndex = [oldItemIds[remainingOldItemId] integerValue];
                newIndex = [newItemIds[remainingOldItemId] integerValue];
                
                remainingNewItem = newItems[newIndex];
                remainingNewIndex = [remainingNewItems indexOfObject:remainingNewItem];
                
                checkUpdate = NO;   // we don't need to check for an update because the next loop iteration will do it
            } else {
                // MOVE UP
                // (all variables are already in place for this)
            }
            
            [changes addObject:[NTJsonChangeSetChange moveWithOldIndex:oldIndex newIndex:newIndex item:remainingNewItem]];
            
            // See if the move is also an update...
            
            remainingOldItem = oldItems[oldIndex];
            if (checkUpdate &![remainingNewItem isEqualToDictionary:remainingOldItem]) {
                [changes addObject:[NTJsonChangeSetChange updateWithOldIndex:oldIndex newIndex:newIndex item:remainingNewItem]];
            }
            
            // now we move the remainingOldItem into the new order so our algo continues to work...

            NSInteger remainingOldIndex = [remainingOldItems indexOfObject:remainingOldItem];

            NSDictionary *temp = remainingOldItems[remainingOldIndex];
            [remainingOldItems removeObjectAtIndex:remainingOldIndex];
            [remainingOldItems insertObject:temp atIndex:remainingNewIndex];
        }
    }];
    
    return [changes copy];
}


+ (NSArray *)applyChanges:(NSArray<NTJsonChangeSetChange *> *)changes oldItems:(NSArray<NSDictionary *> *)oldItems
{
    NSMutableArray<NSDictionary *> *newItems = [oldItems mutableCopy];
    
    // Handle deletes first, going in descending order...
    // The source is deleted for moves here.
    // Same for updates (they are deleted here and re-inserted at the correct location)
    
    for(NTJsonChangeSetChange *change in [changes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"oldIndex" ascending:NO]]])
    {
        if (change.oldIndex == -1)
            continue;   // it's not a delete
        
        [newItems removeObjectAtIndex:change.oldIndex];
    }

    // Now, handle inserts in ascending order...
    // Moves are re-inserted as are updates.
    
    for(NTJsonChangeSetChange *change in [changes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"newIndex" ascending:YES]]])
    {
        if (change.newIndex == -1)
            continue;   // it's not an insert or move
        
        [newItems insertObject:change.item atIndex:change.newIndex];
    }
    
    return [newItems copy];
}


- (BOOL)validateChanges
{
    NSArray *newItems = [self.class applyChanges:self.changes oldItems:self.oldItems];
    
    return [self.items isEqualToArray:newItems];
}


@end
