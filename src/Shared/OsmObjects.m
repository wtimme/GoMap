//
//  OsmObjects.m
//  OpenStreetMap
//
//  Created by Bryce Cogswell on 10/27/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "BingMapsGeometry.h"
#import "CommonTagList.h"
#import "CurvedTextLayer.h"
#import "DLog.h"
#import "OsmMapData.h"
#import "OsmObjects.h"
#import "UndoManager.h"
#import "iosapi.h"

extern const double PATH_SCALING;

BOOL IsOsmBooleanTrue(NSString *value) {
    if ([value isEqualToString:@"true"])
        return YES;
    if ([value isEqualToString:@"yes"])
        return YES;
    if ([value isEqualToString:@"1"])
        return YES;
    return NO;
}
BOOL IsOsmBooleanFalse(NSString *value) {
    if ([value respondsToSelector:@selector(boolValue)]) {
        BOOL b = [value boolValue];
        return !b;
    }
    if ([value isEqualToString:@"false"])
        return YES;
    if ([value isEqualToString:@"no"])
        return YES;
    if ([value isEqualToString:@"0"])
        return YES;
    return NO;
}
NSString *OsmValueForBoolean(BOOL b) {
    return b ? @"true" : @"false";
}

#pragma mark OsmBaseObject

@implementation OsmBaseObject
@synthesize deleted = _deleted;
@synthesize tags = _tags;
@synthesize modifyCount = _modifyCount;
@synthesize ident = _ident;
@synthesize parentRelations = _parentRelations;
@synthesize boundingBox = _boundingBox;

- (NSString *)description {
    NSMutableString *text = [NSMutableString stringWithFormat:@"id=%@ constructed=%@ deleted=%@ modifyCount=%d",
                                                              _ident,
                                                              _constructed ? @"Yes" : @"No",
                                                              self.deleted ? @"Yes" : @"No",
                                                              _modifyCount];
    [_tags enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
      [text appendFormat:@"\n  '%@' = '%@'", key, value];
    }];
    return text;
}

BOOL IsInterestingTag(NSString *key) {
    if ([key isEqualToString:@"attribution"])
        return NO;
    if ([key isEqualToString:@"created_by"])
        return NO;
    if ([key isEqualToString:@"source"])
        return NO;
    if ([key isEqualToString:@"odbl"])
        return NO;
    if ([key rangeOfString:@"tiger:"].location == 0)
        return NO;
    return YES;
}

- (BOOL)hasInterestingTags {
    for (NSString *key in self.tags) {
        if (IsInterestingTag(key))
            return YES;
    }
    return NO;
}

- (BOOL)isCoastline {
    NSString *natural = _tags[@"natural"];
    if (natural) {
        if ([natural isEqualToString:@"coastline"])
            return YES;
        if ([natural isEqualToString:@"water"]) {
            if (!self.isRelation && _parentRelations.count == 0)
                return NO; // its a lake or something
            return YES;
        }
    }
    return NO;
}

- (OsmNode *)isNode {
    return nil;
}
- (OsmWay *)isWay {
    return nil;
}
- (OsmRelation *)isRelation {
    return nil;
}
- (OSMRect)boundingBox {
    if (_boundingBox.origin.x == 0 && _boundingBox.origin.y == 0 && _boundingBox.size.width == 0 && _boundingBox.size.height == 0)
        [self computeBoundingBox];
    return _boundingBox;
}
- (void)computeBoundingBox {
    assert(NO);
    _boundingBox = OSMRectMake(0, 0, 0, 0);
}

- (double)distanceToLineSegment:(OSMPoint)point1 point:(OSMPoint)point2 {
    assert(NO);
    return 1000000.0;
}

- (OSMPoint)selectionPoint {
    assert(NO);
    return OSMPointMake(0, 0);
}

- (OSMPoint)pointOnObjectForPoint:(OSMPoint)target {
    assert(NO);
    return OSMPointMake(0, 0);
}

// suitable for drawing outlines for highlighting, but doesn't correctly connect relation members into loops
- (CGPathRef)linePathForObjectWithRefPoint:(OSMPoint *)refPoint CF_RETURNS_RETAINED {
    NSArray *wayList = self.isWay ? @[ self ] : self.isRelation ? self.isRelation.waysInMultipolygon : nil;
    if (wayList == nil)
        return nil;

    CGMutablePathRef path = CGPathCreateMutable();
    OSMPoint initial = {0, 0};
    BOOL haveInitial = NO;

    for (OsmWay *way in wayList) {

        BOOL first = YES;
        for (OsmNode *node in way.nodes) {
            OSMPoint pt = MapPointForLatitudeLongitude(node.lat, node.lon);
            if (isinf(pt.x))
                break;
            if (!haveInitial) {
                initial = pt;
                haveInitial = YES;
            }
            pt.x -= initial.x;
            pt.y -= initial.y;
            pt.x *= PATH_SCALING;
            pt.y *= PATH_SCALING;
            if (first) {
                CGPathMoveToPoint(path, NULL, pt.x, pt.y);
                first = NO;
            } else {
                CGPathAddLineToPoint(path, NULL, pt.x, pt.y);
            }
        }
    }

    if (refPoint && haveInitial) {
        // place refPoint at upper-left corner of bounding box so it can be the origin for the frame/anchorPoint
        CGRect bbox = CGPathGetPathBoundingBox(path);
        if (!isinf(bbox.origin.x)) {
            CGAffineTransform tran = CGAffineTransformMakeTranslation(-bbox.origin.x, -bbox.origin.y);
            CGPathRef path2 = CGPathCreateCopyByTransformingPath(path, &tran);
            CGPathRelease(path);
            path = (CGMutablePathRef)path2;
            *refPoint = OSMPointMake(initial.x + (double)bbox.origin.x / PATH_SCALING, initial.y + (double)bbox.origin.y / PATH_SCALING);
        } else {
#if DEBUG
            DLog(@"bad path: %@", self);
#endif
        }
    }
    return path;
}

// suitable for drawing polygon areas with holes, etc.
- (CGPathRef)shapePathForObjectWithRefPoint:(OSMPoint *)pRefPoint CF_RETURNS_RETAINED {
    assert(NO);
    return nil;
}

static NSInteger _nextUnusedIdentifier = 0;

+ (NSInteger)nextUnusedIdentifier {
    if (_nextUnusedIdentifier == 0) {
        _nextUnusedIdentifier = [[NSUserDefaults standardUserDefaults] integerForKey:@"nextUnusedIdentifier"];
    }
    --_nextUnusedIdentifier;
    [[NSUserDefaults standardUserDefaults] setInteger:_nextUnusedIdentifier forKey:@"nextUnusedIdentifier"];
    return _nextUnusedIdentifier;
}

NSDictionary *MergeTags(NSDictionary *ourTags, NSDictionary *otherTags, BOOL allowConflicts) {
    if (ourTags.count == 0)
        return otherTags ? [otherTags copy] : @{};

    __block NSMutableDictionary *merged = [ourTags mutableCopy];
    [otherTags enumerateKeysAndObjectsUsingBlock:^(NSString *otherKey, NSString *otherValue, BOOL *stop) {
      NSString *ourValue = merged[otherKey];
      if (![ourValue isEqualToString:otherValue]) {
          if (!allowConflicts) {
              if (IsInterestingTag(otherKey)) {
                  *stop = YES;
                  merged = nil;
              }
          } else {
              merged[otherKey] = otherValue;
          }
      }
    }];
    if (merged == nil)
        return nil; // conflict
    return [NSDictionary dictionaryWithDictionary:merged];
}

#pragma mark Construction

- (void)constructBaseAttributesWithVersion:(int32_t)version changeset:(int64_t)changeset user:(NSString *)user uid:(int32_t)uid ident:(int64_t)ident timestamp:(NSString *)timestmap {
    assert(!_constructed);
    _version = version;
    _changeset = changeset;
    _user = user;
    _uid = uid;
    _visible = YES;
    _ident = @(ident);
    _timestamp = timestmap;
}

- (void)constructBaseAttributesFromXmlDict:(NSDictionary *)attributeDict {
    int32_t version = (int32_t)[[attributeDict objectForKey:@"version"] integerValue];
    int64_t changeset = [[attributeDict objectForKey:@"changeset"] longLongValue];
    NSString *user = [attributeDict objectForKey:@"user"];
    int32_t uid = (int32_t)[[attributeDict objectForKey:@"uid"] integerValue];
    int64_t ident = [[attributeDict objectForKey:@"id"] longLongValue];
    NSString *timestamp = [attributeDict objectForKey:@"timestamp"];

    [self constructBaseAttributesWithVersion:version changeset:changeset user:user uid:uid ident:ident timestamp:timestamp];
}

- (void)constructTag:(NSString *)tag value:(NSString *)value {
    // drop deprecated tags
    if ([tag isEqualToString:@"created_by"])
        return;

    assert(!_constructed);
    if (_tags == nil) {
        _tags = [NSMutableDictionary dictionaryWithObject:value forKey:tag];
    } else {
        [((NSMutableDictionary *)_tags) setValue:value forKey:tag];
    }
}

- (BOOL)constructed {
    return _constructed;
}
- (void)setConstructed {
    if (_user == nil)
        _user = @""; // some old objects don't have users attached to them
    _constructed = YES;
    _modifyCount = 0;
}

+ (NSDateFormatter *)rfc3339DateFormatter {
    static NSDateFormatter *rfc3339DateFormatter = nil;
    if (rfc3339DateFormatter == nil) {
        rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        assert(rfc3339DateFormatter != nil);
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        assert(enUSPOSIXLocale != nil);
        [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
        [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    return rfc3339DateFormatter;
}
- (NSDate *)dateForTimestamp {
    NSDate *date = [[OsmBaseObject rfc3339DateFormatter] dateFromString:_timestamp];
    assert(date);
    return date;
}
- (void)setTimestamp:(NSDate *)date undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [undo registerUndoWithTarget:self selector:@selector(setTimestamp:undo:) objects:@[ [self dateForTimestamp], undo ]];
    }
    _timestamp = [[OsmBaseObject rfc3339DateFormatter] stringFromDate:date];
    assert(_timestamp);
}

- (void)clearCachedProperties {
    _tagInfo = nil;
    renderPriorityCached = 0;
    _isOneWay = nil;
    _isShown = TRISTATE_UNKNOWN;
    _boundingBox = OSMRectZero();

    for (CALayer *layer in _shapeLayers) {
        [layer removeFromSuperlayer];
    }
    _shapeLayers = nil;
}

- (BOOL)isModified {
    return _modifyCount > 0;
}
- (void)incrementModifyCount:(UndoManager *)undo {
    assert(_modifyCount >= 0);
    if (_constructed) {
        assert(undo);
        // [undo registerUndoWithTarget:self selector:@selector(incrementModifyCount:) objects:@[undo]];
    }
    if (undo.isUndoing)
        --_modifyCount;
    else
        ++_modifyCount;
    assert(_modifyCount >= 0);

    // update cached values
    [self clearCachedProperties];
}
- (void)resetModifyCount:(UndoManager *)undo {
    assert(undo);
    _modifyCount = 0;

    [self clearCachedProperties];
}

- (void)serverUpdateVersion:(NSInteger)version {
    _version = (int32_t)version;
}
- (void)serverUpdateChangeset:(OsmIdentifier)changeset {
    _changeset = changeset;
}
- (void)serverUpdateIdent:(OsmIdentifier)ident {
    assert(_ident.longLongValue < 0 && ident > 0);
    _ident = @(ident);
}
- (void)serverUpdateInPlace:(OsmBaseObject *)newerVersion {
    assert([self.ident isEqualToNumber:newerVersion.ident]);
    assert(self.version < newerVersion.version);
    _tags = newerVersion.tags;
    _user = newerVersion.user;
    _timestamp = newerVersion.timestamp;
    _version = newerVersion.version;
    _changeset = newerVersion.changeset;
    _uid = newerVersion.uid;
    // derived data
    [self clearCachedProperties];
}

- (ONEWAY)isOneWay {
    if (_isOneWay == nil)
        _isOneWay = @(self.isWay.computeIsOneWay);
    return (ONEWAY)_isOneWay.intValue;
}

- (BOOL)deleted {
    return _deleted;
}
- (void)setDeleted:(BOOL)deleted undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [self incrementModifyCount:undo];
        [undo registerUndoWithTarget:self selector:@selector(setDeleted:undo:) objects:@[ @((BOOL)self.deleted), undo ]];
    }
    _deleted = deleted;
}

- (NSDictionary *)tags {
    return _tags;
}
- (void)setTags:(NSDictionary *)tags undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [self incrementModifyCount:undo];
        [undo registerUndoWithTarget:self selector:@selector(setTags:undo:) objects:@[ _tags ?: [NSNull null], undo ]];
    }
    _tags = tags;
    [self clearCachedProperties];
}

// get all keys that contain another part, like "restriction:conditional"
- (NSArray *)extendedKeysForKey:(NSString *)key {
    NSArray *keys = nil;
    for (NSString *tag in _tags) {
        if ([tag hasPrefix:key] && [tag characterAtIndex:key.length] == ':') {
            if (keys == nil) {
                keys = @[ tag ];
            } else {
                keys = [keys arrayByAddingObject:tag];
            }
        }
    }
    return keys;
}

- (NSSet *)nodeSet {
    assert(NO);
    return nil;
}
- (BOOL)overlapsBox:(OSMRect)box {
    return OSMRectIntersectsRect(self.boundingBox, box);
}

+ (NSDictionary *)featureKeys {
    static NSDictionary *keyDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      keyDict = @{
          @"building" : @YES,
          @"landuse" : @YES,
          @"highway" : @YES,
          @"railway" : @YES,
          @"amenity" : @YES,
          @"shop" : @YES,
          @"natural" : @YES,
          @"waterway" : @YES,
          @"power" : @YES,
          @"barrier" : @YES,
          @"leisure" : @YES,
          @"man_made" : @YES,
          @"tourism" : @YES,
          @"boundary" : @YES,
          @"public_transport" : @YES,
          @"sport" : @YES,
          @"emergency" : @YES,
          @"historic" : @YES,
          @"route" : @YES,
          @"aeroway" : @YES,
          @"place" : @YES,
          @"craft" : @YES,
          @"entrance" : @YES,
          @"playground" : @YES,
          @"aerialway" : @YES,
          @"healthcare" : @YES,
          @"military" : @YES,
          @"building:part" : @YES,
          @"training" : @YES,
          @"traffic_sign" : @YES,
          @"xmas:feature" : @YES,
          @"seamark:type" : @YES,
          @"waterway:sign" : @YES,
          @"university" : @YES,
          @"pipeline" : @YES,
          @"club" : @YES,
          @"golf" : @YES,
          @"junction" : @YES,
          @"office" : @YES,
          @"piste:type" : @YES,
          @"harbour" : @YES,
      };
    });
    return keyDict;
}

- (NSString *)friendlyDescription {
    NSString *name = [_tags objectForKey:@"name"];
    if (name.length)
        return name;

    NSString *featureName = [CommonTagList featureNameForObjectDict:self.tags geometry:self.geometryName];
    if (featureName) {
        CommonTagFeature *feature = [CommonTagFeature commonTagFeatureWithName:featureName];
        name = feature.friendlyName;
        if (name.length > 0)
            return name;
    }

    if (self.isRelation) {
        NSString *restriction = self.tags[@"restriction"];
        if (restriction == nil) {
            NSArray *a = [self extendedKeysForKey:@"restriction"];
            if (a.count) {
                NSString *key = a.lastObject;
                restriction = self.tags[key];
            }
        }
        if (restriction) {
            if ([restriction hasPrefix:@"no_left_turn"])
                return @"No Left Turn restriction";
            if ([restriction hasPrefix:@"no_right_turn"])
                return @"No Right Turn restriction";
            if ([restriction hasPrefix:@"no_straight_on"])
                return @"No Straight On restriction";
            if ([restriction hasPrefix:@"only_left_turn"])
                return @"Only Left Turn restriction";
            if ([restriction hasPrefix:@"only_right_turn"])
                return @"Only Right Turn restriction";
            if ([restriction hasPrefix:@"only_straight_on"])
                return @"Only Straight On restriction";
            if ([restriction hasPrefix:@"no_u_turn"])
                return @"No U-Turn restriction";
            return [NSString stringWithFormat:@"Restriction: %@", restriction];
        } else {
            return [NSString stringWithFormat:@"Relation: %@", self.tags[@"type"]];
        }
    }

#if DEBUG
    NSString *indoor = self.tags[@"indoor"];
    if (indoor) {
        NSString *text = [NSString stringWithFormat:@"Indoor %@", indoor];
        NSString *level = self.tags[@"level"];
        if (level)
            text = [text stringByAppendingFormat:@", level %@", level];
        return text;
    }
#endif

    // if the object has any tags that aren't throw-away tags then use one of them
    NSSet *ignoreTags = [OsmMapData tagsToAutomaticallyStrip];

    __block NSString *tagDescription = nil;
    NSDictionary *featureKeys = [OsmBaseObject featureKeys];
    // look for feature key
    [_tags enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
      if (featureKeys[key]) {
          *stop = YES;
          tagDescription = [NSString stringWithFormat:@"%@ = %@", key, value];
      }
    }];
    if (tagDescription == nil) {
        // any non-ignored key
        [_tags enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
          if (![ignoreTags containsObject:key]) {
              *stop = YES;
              tagDescription = [NSString stringWithFormat:@"%@ = %@", key, value];
          }
        }];
    }
    if (tagDescription)
        return tagDescription;

    if (self.isNode && self.isNode.wayCount > 0)
        return NSLocalizedString(@"(node in way)", nil);

    if (self.isNode)
        return NSLocalizedString(@"(node)", nil);

    if (self.isWay)
        return NSLocalizedString(@"(way)", nil);

    if (self.isRelation) {
        OsmRelation *relation = self.isRelation;
        NSString *type = relation.tags[@"type"];
        if (type.length) {
            name = relation.tags[type];
            if (name.length) {
                return [NSString stringWithFormat:@"%@ (%@)", type, name];
            } else {
                return [NSString stringWithFormat:NSLocalizedString(@"%@ (relation)", nil), type];
            }
        }
        return [NSString stringWithFormat:NSLocalizedString(@"(relation %@)", nil), self.ident];
    }

    return NSLocalizedString(@"other object", nil);
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_ident forKey:@"ident"];
    [coder encodeObject:_user forKey:@"user"];
    [coder encodeObject:_timestamp forKey:@"timestamp"];
    [coder encodeInteger:_version forKey:@"version"];
    [coder encodeInteger:(NSInteger)_changeset forKey:@"changeset"];
    [coder encodeInteger:_uid forKey:@"uid"];
    [coder encodeBool:_visible forKey:@"visible"];
    [coder encodeObject:_tags forKey:@"tags"];
    [coder encodeBool:_deleted forKey:@"deleted"];
    [coder encodeInt32:_modifyCount forKey:@"modified"];
}
- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _ident = [coder decodeObjectForKey:@"ident"];
        _user = [coder decodeObjectForKey:@"user"];
        _timestamp = [coder decodeObjectForKey:@"timestamp"];
        _version = [coder decodeInt32ForKey:@"version"];
        _changeset = [coder decodeIntegerForKey:@"changeset"];
        _uid = [coder decodeInt32ForKey:@"uid"];
        _visible = [coder decodeBoolForKey:@"visible"];
        _tags = [coder decodeObjectForKey:@"tags"];
        _deleted = [coder decodeBoolForKey:@"deleted"];
        _modifyCount = [coder decodeInt32ForKey:@"modified"];
    }
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)constructAsUserCreated:(NSString *)userName {
    // newly created by user
    assert(!_constructed);
    _ident = @([OsmBaseObject nextUnusedIdentifier]);
    _visible = YES;
    _user = userName ?: @"";
    _version = 1;
    _changeset = 0;
    _uid = 0;
    _deleted = YES;
    [self setTimestamp:[NSDate date] undo:nil];
}

- (void)addRelation:(OsmRelation *)relation undo:(UndoManager *)undo {
    if (_constructed && undo) {
        [undo registerUndoWithTarget:self selector:@selector(removeRelation:undo:) objects:@[ relation, undo ]];
    }

    if (_parentRelations) {
        if (![_parentRelations containsObject:relation])
            _parentRelations = [_parentRelations arrayByAddingObject:relation];
    } else {
        _parentRelations = @[ relation ];
    }
}
- (void)removeRelation:(OsmRelation *)relation undo:(UndoManager *)undo {
    if (_constructed && undo) {
        [undo registerUndoWithTarget:self selector:@selector(addRelation:undo:) objects:@[ relation, undo ]];
    }
    NSInteger index = [_parentRelations indexOfObject:relation];
    if (index == NSNotFound) {
        DLog(@"missing relation");
        return;
    }
    if (_parentRelations.count == 1) {
        _parentRelations = nil;
    } else {
        NSMutableArray *a = [_parentRelations mutableCopy];
        [a removeObjectAtIndex:index];
        _parentRelations = [NSArray arrayWithArray:a];
    }
}

- (NSString *)geometryName {
    if (self.isWay) {
        if (self.isWay.isArea)
            return GEOMETRY_AREA;
        else
            return GEOMETRY_WAY;
    } else if (self.isNode) {
        if (self.isNode.wayCount > 0)
            return GEOMETRY_VERTEX;
        else
            return GEOMETRY_NODE;
    } else if (self.isRelation) {
        if (self.isRelation.isMultipolygon)
            return GEOMETRY_AREA;
        else
            return GEOMETRY_WAY;
    }
    return @"unknown";
}

- (OSM_TYPE)extendedType {
    return self.isNode ? OSM_TYPE_NODE : self.isWay ? OSM_TYPE_WAY : OSM_TYPE_RELATION;
}

+ (OsmIdentifier)extendedIdentifierForType:(OSM_TYPE)type identifier:(OsmIdentifier)identifier {
    return (identifier & (((uint64_t)1 << 62) - 1)) | ((uint64_t)type << 62);
}

- (OsmIdentifier)extendedIdentifier {
    OSM_TYPE type = self.extendedType;
    return _ident.longLongValue | ((uint64_t)type << 62);
}

+ (void)decomposeExtendedIdentifier:(OsmIdentifier)extendedIdentifier type:(OSM_TYPE *)pType ident:(OsmIdentifier *)pIdent {
    *pType = extendedIdentifier >> 62 & 3;
    int64_t ident = extendedIdentifier & (((uint64_t)1 << 62) - 1);
    ident = (ident << 2) >> 2; // sign extend
    *pIdent = ident;
}

@end

#pragma mark OsmNode

@implementation OsmNode
@synthesize lon = _lon;
@synthesize lat = _lat;
@synthesize wayCount = _wayCount;

- (NSString *)description {
    return [NSString stringWithFormat:@"OsmNode (%f,%f) %@", self.lon, self.lat, [super description]];
}

- (OsmNode *)isNode {
    return self;
}

- (OSMPoint)location {
    return OSMPointMake(_lon, _lat);
}

- (OSMPoint)selectionPoint {
    return OSMPointMake(_lon, _lat);
}

- (OSMPoint)pointOnObjectForPoint:(OSMPoint)target {
    return OSMPointMake(_lon, _lat);
}

- (BOOL)isBetterToKeepThan:(OsmNode *)node {
    if ((self.ident.longLongValue > 0) == (node.ident.longLongValue > 0)) {
        // both are new or both are old, so take whichever has more tags
        return _tags.count > node.tags.count;
    }
    // take the previously existing one
    return self.ident.longLongValue > 0;
}

- (NSSet *)nodeSet {
    return [NSSet setWithObject:self];
}
- (void)computeBoundingBox {
    OSMRect rc = {_lon, _lat, 0, 0};
    _boundingBox = rc;
}

- (double)distanceToLineSegment:(OSMPoint)point1 point:(OSMPoint)point2 {
    OSMPoint metersPerDegree = {MetersPerDegreeLongitude(_lat), MetersPerDegreeLatitude(_lat)};
    point1.x = (point1.x - _lon) * metersPerDegree.x;
    point1.y = (point1.y - _lat) * metersPerDegree.y;
    point2.x = (point2.x - _lon) * metersPerDegree.x;
    point2.y = (point2.y - _lat) * metersPerDegree.y;
    double dist = DistanceFromPointToLineSegment(OSMPointMake(0, 0), point1, point2);
    return dist;
}

- (void)setLongitude:(double)longitude latitude:(double)latitude undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [self incrementModifyCount:undo];
        [undo registerUndoWithTarget:self selector:@selector(setLongitude:latitude:undo:) objects:@[ @(_lon), @(_lat), undo ]];
    }
    _lon = longitude;
    _lat = latitude;
}
- (void)serverUpdateInPlace:(OsmNode *)newerVersion {
    [super serverUpdateInPlace:newerVersion];
    _lon = newerVersion.lon;
    _lat = newerVersion.lat;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        if ([coder allowsKeyedCoding]) {
            _lat = [coder decodeDoubleForKey:@"lat"];
            _lon = [coder decodeDoubleForKey:@"lon"];
            _wayCount = [coder decodeIntegerForKey:@"wayCount"];
        } else {
            NSUInteger len;
            _lat = *(double *)[coder decodeBytesWithReturnedLength:&len];
            _lon = *(double *)[coder decodeBytesWithReturnedLength:&len];
            _wayCount = *(NSInteger *)[coder decodeBytesWithReturnedLength:&len];
        }
        _constructed = YES;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding]) {
        [coder encodeDouble:_lat forKey:@"lat"];
        [coder encodeDouble:_lon forKey:@"lon"];
        [coder encodeInteger:_wayCount forKey:@"wayCount"];
    } else {
        [coder encodeBytes:&_lat length:sizeof _lat];
        [coder encodeBytes:&_lon length:sizeof _lon];
        [coder encodeBytes:&_wayCount length:sizeof _wayCount];
    }
}

- (NSInteger)wayCount {
    return _wayCount;
}
- (void)setWayCount:(NSInteger)wayCount undo:(UndoManager *)undo {
    if (_constructed && undo) {
        [undo registerUndoWithTarget:self selector:@selector(setWayCount:undo:) objects:@[ @(_wayCount), undo ]];
    }
    _wayCount = wayCount;
}

@end

#pragma mark OsmWay

@implementation OsmWay

- (NSString *)description {
    return [NSString stringWithFormat:@"OsmWay %@", [super description]];
}

- (void)constructNode:(NSNumber *)node {
    assert(!_constructed);
    if (_nodes == nil) {
        _nodes = [NSMutableArray arrayWithObject:node];
    } else {
        [_nodes addObject:node];
    }
}
- (void)constructNodeList:(NSMutableArray *)nodes {
    assert(!_constructed);
    _nodes = nodes;
}

- (OsmWay *)isWay {
    return self;
}

- (void)resolveToMapData:(OsmMapData *)mapData {
    for (NSInteger i = 0, e = _nodes.count; i < e; ++i) {
        NSNumber *ref = _nodes[i];
        if (![ref isKindOfClass:[NSNumber class]])
            continue;
        OsmNode *node = [mapData nodeForRef:ref];
        NSAssert(node, nil);
        _nodes[i] = node;
        [node setWayCount:node.wayCount + 1 undo:nil];
    }
}

- (void)removeNodeAtIndex:(NSInteger)index undo:(UndoManager *)undo {
    assert(undo);
    OsmNode *node = _nodes[index];
    [self incrementModifyCount:undo];
    [undo registerUndoWithTarget:self selector:@selector(addNode:atIndex:undo:) objects:@[ node, @(index), undo ]];
    [_nodes removeObjectAtIndex:index];
    [node setWayCount:node.wayCount - 1 undo:nil];
    [self computeBoundingBox];
}
- (void)addNode:(OsmNode *)node atIndex:(NSInteger)index undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [self incrementModifyCount:undo];
        [undo registerUndoWithTarget:self selector:@selector(removeNodeAtIndex:undo:) objects:@[ @(index), undo ]];
    }
    if (_nodes == nil) {
        _nodes = [NSMutableArray new];
    }
    [_nodes insertObject:node atIndex:index];
    [node setWayCount:node.wayCount + 1 undo:nil];
    [self computeBoundingBox];
}

- (void)serverUpdateInPlace:(OsmWay *)newerVersion {
    [super serverUpdateInPlace:newerVersion];
    _nodes = [newerVersion.nodes mutableCopy];
}

- (BOOL)isArea {
    return [CommonTagList isArea:self];
}

- (BOOL)isClosed {
    return _nodes.count > 2 && _nodes[0] == _nodes.lastObject;
}

- (ONEWAY)computeIsOneWay {
    static NSDictionary *oneWayTags = nil;
    if (oneWayTags == nil) {
        oneWayTags = @{
            @"aerialway" : @{
                @"chair_lift" : @YES,
                @"mixed_lift" : @YES,
                @"t-bar" : @YES,
                @"j-bar" : @YES,
                @"platter" : @YES,
                @"rope_tow" : @YES,
                @"magic_carpet" : @YES,
                @"yes" : @YES
            },
            @"highway" : @{
                @"motorway" : @YES,
                @"motorway_link" : @YES,
                @"steps" : @YES
            },
            @"junction" : @{
                @"roundabout" : @YES
            },
            @"man_made" : @{
                @"piste:halfpipe" : @YES,
                @"embankment" : @YES
            },
            @"natural" : @{
                @"cliff" : @YES,
                @"coastline" : @YES
            },
            @"piste:type" : @{
                @"downhill" : @YES,
                @"sled" : @YES,
                @"yes" : @YES
            },
            @"waterway" : @{
                @"brook" : @YES,
                @"canal" : @YES,
                @"ditch" : @YES,
                @"drain" : @YES,
                @"fairway" : @YES,
                @"river" : @YES,
                @"stream" : @YES,
                @"weir" : @YES
            }
        };
    }

    NSString *oneWayVal = [_tags objectForKey:@"oneway"];
    if (oneWayVal) {
        if ([oneWayVal isEqualToString:@"yes"] || [oneWayVal isEqualToString:@"1"])
            return ONEWAY_FORWARD;
        if ([oneWayVal isEqualToString:@"no"] || [oneWayVal isEqualToString:@"0"])
            return ONEWAY_NONE;
        if ([oneWayVal isEqualToString:@"-1"])
            return ONEWAY_BACKWARD;
    }

    __block ONEWAY oneWay = ONEWAY_NONE;
    [_tags enumerateKeysAndObjectsUsingBlock:^(NSString *tag, NSString *value, BOOL *stop) {
      NSDictionary *valueDict = [oneWayTags objectForKey:tag];
      if (valueDict) {
          if (valueDict[value]) {
              oneWay = ONEWAY_FORWARD;
              *stop = YES;
          }
      }
    }];
    return oneWay;
}

- (BOOL)sharesNodesWithWay:(OsmWay *)way {
    if (_nodes.count * way.nodes.count < 100) {
        for (OsmNode *n in way.nodes) {
            if ([_nodes containsObject:n])
                return YES;
        }
        return NO;
    } else {
        NSSet *set1 = [NSSet setWithArray:way.nodes];
        NSSet *set2 = [NSSet setWithArray:_nodes];
        return [set1 intersectsSet:set2];
    }
}

- (BOOL)isMultipolygonMember {
    for (OsmRelation *parent in self.parentRelations) {
        if (parent.isMultipolygon && parent.tags.count > 0)
            return YES;
    }
    return NO;
}

- (BOOL)isSimpleMultipolygonOuterMember {
    NSArray *parents = self.parentRelations;
    if (parents.count != 1)
        return NO;

    OsmRelation *parent = parents[0];
    if (!parent.isMultipolygon || parent.tags.count > 1)
        return NO;

    for (OsmMember *member in parent.members) {
        if (member.ref == self) {
            if (![member.role isEqualToString:@"outer"])
                return NO; // Not outer member
        } else {
            if ((member.role == nil || [member.role isEqualToString:@"outer"]))
                return NO; // Not a simple multipolygon
        }
    }
    return YES;
}

- (double)wayArea {
    assert(NO);
    return 0;
}

// return the point on the way closest to the supplied point
- (OSMPoint)pointOnObjectForPoint:(OSMPoint)target {
    switch (_nodes.count) {
    case 0:
        return target;
    case 1:
        return ((OsmNode *)_nodes.lastObject).location;
    }
    OSMPoint bestPoint = {0, 0};
    double bestDist = 360 * 360;
    for (NSInteger i = 1; i < _nodes.count; ++i) {
        OSMPoint p1 = [((OsmNode *)_nodes[i - 1]) location];
        OSMPoint p2 = [((OsmNode *)_nodes[i]) location];
        OSMPoint linePoint = ClosestPointOnLineToPoint(p1, p2, target);
        double dist = MagSquared(Sub(linePoint, target));
        if (dist < bestDist) {
            bestDist = dist;
            bestPoint = linePoint;
        }
    }
    return bestPoint;
}

- (double)distanceToLineSegment:(OSMPoint)point1 point:(OSMPoint)point2 {
    if (_nodes.count == 1) {
        return [_nodes.lastObject distanceToLineSegment:point1 point:point2];
    }
    double dist = 1000000.0;
    OsmNode *prevNode = nil;
    for (OsmNode *node in _nodes) {
        if (prevNode && LineSegmentsIntersect(prevNode.location, node.location, point1, point2)) {
            return 0.0;
        }
        double d = [node distanceToLineSegment:point1 point:point2];
        if (d < dist) {
            dist = d;
        }
        prevNode = node;
    }
    return dist;
}

- (NSSet *)nodeSet {
    return [NSSet setWithArray:_nodes];
}

- (void)computeBoundingBox {
    double minX, maxX, minY, maxY;
    BOOL first = YES;
    for (OsmNode *node in _nodes) {
        OSMPoint loc = node.location;
        if (first) {
            first = NO;
            minX = maxX = loc.x;
            minY = maxY = loc.y;
        } else {
            if (loc.y < minY)
                minY = loc.y;
            if (loc.x < minX)
                minX = loc.x;
            if (loc.y > maxY)
                maxY = loc.y;
            if (loc.x > maxX)
                maxX = loc.x;
        }
    }
    if (first) {
        _boundingBox = OSMRectMake(0, 0, 0, 0);
    } else {
        _boundingBox = OSMRectMake(minX, minY, maxX - minX, maxY - minY);
    }
}
- (OSMPoint)centerPointWithArea:(double *)pArea {
    double dummy;
    if (pArea == NULL)
        pArea = &dummy;

    BOOL isClosed = self.isClosed;

    NSInteger nodeCount = isClosed ? _nodes.count - 1 : _nodes.count;

    if (nodeCount > 2) {
        if (isClosed) {
            // compute centroid
            double sum = 0;
            double sumX = 0;
            double sumY = 0;
            BOOL first = YES;
            OSMPoint offset = {0, 0};
            OSMPoint previous;
            for (OsmNode *node in _nodes) {
                if (first) {
                    offset.x = node.lon;
                    offset.y = node.lat;
                    previous.x = 0;
                    previous.y = 0;
                    first = NO;
                } else {
                    OSMPoint current = {node.lon - offset.x, node.lat - offset.y};
                    CGFloat partialSum = previous.x * current.y - previous.y * current.x;
                    sum += partialSum;
                    sumX += (previous.x + current.x) * partialSum;
                    sumY += (previous.y + current.y) * partialSum;
                    previous = current;
                }
            }
            *pArea = sum / 2;
            OSMPoint point = {sumX / 6 / *pArea, sumY / 6 / *pArea};
            point.x += offset.x;
            point.y += offset.y;
            return point;
        } else {
            // compute average
            double sumX = 0, sumY = 0;
            for (OsmNode *node in _nodes) {
                sumX += node.lon;
                sumY += node.lat;
            }
            OSMPoint point = {sumX / nodeCount, sumY / nodeCount};
            return point;
        }
    } else if (nodeCount == 2) {
        *pArea = 0;
        OsmNode *n1 = _nodes[0];
        OsmNode *n2 = _nodes[1];
        return OSMPointMake((n1.lon + n2.lon) / 2, (n1.lat + n2.lat) / 2);
    } else if (nodeCount == 1) {
        *pArea = 0;
        OsmNode *node = _nodes.lastObject;
        return OSMPointMake(node.lon, node.lat);
    } else {
        *pArea = 0;
        OSMPoint pt = {0, 0};
        return pt;
    }
}

- (OSMPoint)centerPoint {
    return [self centerPointWithArea:NULL];
}

- (double)lengthInMeters {
    BOOL first = YES;
    double len = 0;
    OSMPoint prev = {0, 0};
    for (OsmNode *node in _nodes) {
        OSMPoint pt = node.location;
        if (!first) {
            len += GreatCircleDistance(pt, prev);
        }
        first = NO;
        prev = pt;
    }
    return len;
}

// pick a point close to the center of the way
- (OSMPoint)selectionPoint {
    double dist = [self lengthInMeters] / 2;
    BOOL first = YES;
    OSMPoint prev = {0, 0};
    for (OsmNode *node in _nodes) {
        OSMPoint pt = node.location;
        if (!first) {
            double segment = GreatCircleDistance(pt, prev);
            if (segment >= dist) {
                OSMPoint pos = Add(prev, Mult(Sub(pt, prev), dist / segment));
                return pos;
            }
            dist -= segment;
        }
        first = NO;
        prev = pt;
    }
    return prev; // dummy value, shouldn't ever happen
}

+ (BOOL)isClockwiseArrayOfNodes:(NSArray *)nodes {
    if (nodes.count < 4 || nodes[0] != nodes.lastObject)
        return NO;
    CGFloat sum = 0;
    BOOL first = YES;
    OSMPoint offset;
    OSMPoint previous;
    for (OsmNode *node in nodes) {
        OSMPoint point = node.location;
        if (first) {
            offset = point;
            previous.x = previous.y = 0;
            first = NO;
        } else {
            OSMPoint current = {point.x - offset.x, point.y - offset.y};
            sum += previous.x * current.y - previous.y * current.x;
            previous = current;
        }
    }
    return sum >= 0;
}

- (BOOL)isClockwise {
    return [OsmWay isClockwiseArrayOfNodes:self.nodes];
}

+ (CGPathRef)shapePathForNodes:(NSArray *)nodes forward:(BOOL)forward withRefPoint:(OSMPoint *)pRefPoint CF_RETURNS_RETAINED;
{
    if (nodes.count == 0 || nodes[0] != nodes.lastObject)
        return nil;
    CGMutablePathRef path = CGPathCreateMutable();
    BOOL first = YES;
    // want loops to run clockwise
    NSEnumerator *enumerator = forward ? nodes.objectEnumerator : nodes.reverseObjectEnumerator;
    for (OsmNode *n in enumerator) {
        OSMPoint pt = MapPointForLatitudeLongitude(n.lat, n.lon);
        if (first) {
            first = NO;
            *pRefPoint = pt;
            CGPathMoveToPoint(path, NULL, 0, 0);
        } else {
            CGPathAddLineToPoint(path, NULL, (pt.x - pRefPoint->x) * PATH_SCALING, (pt.y - pRefPoint->y) * PATH_SCALING);
        }
    }
    return path;
}

- (CGPathRef)shapePathForObjectWithRefPoint:(OSMPoint *)pRefPoint CF_RETURNS_RETAINED;
{
    return [OsmWay shapePathForNodes:self.nodes forward:self.isClockwise withRefPoint:pRefPoint];
}

- (BOOL)hasDuplicatedNode {
    OsmNode *prev = nil;
    for (OsmNode *node in _nodes) {
        if (node == prev)
            return YES;
        prev = node;
    }
    return NO;
}

- (OsmNode *)connectsToWay:(OsmWay *)way {
    if (_nodes.count > 0 && way.nodes.count > 0) {
        if (_nodes[0] == way.nodes[0] || _nodes[0] == way.nodes.lastObject)
            return _nodes[0];
        if (_nodes.lastObject == way.nodes[0] || _nodes.lastObject == way.nodes.lastObject)
            return _nodes.lastObject;
    }
    return nil;
}

- (NSInteger)segmentClosestToPoint:(OSMPoint)point {
    NSInteger best = -1;
    double bestDist = 100000000.0;
    for (NSInteger index = 0; index + 1 < _nodes.count; ++index) {
        OsmNode *this = _nodes[index];
        OsmNode *next = _nodes[index + 1];
        double dist = DistanceFromPointToLineSegment(point, this.location, next.location);
        if (dist < bestDist) {
            bestDist = dist;
            best = index;
        }
    }
    return best;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _nodes = [coder decodeObjectForKey:@"nodes"];
        _constructed = YES;
#if DEBUG
        for (OsmNode *node in _nodes) {
            assert(node.wayCount > 0);
        }
#endif
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
#if DEBUG
    for (OsmNode *node in _nodes) {
        assert(node.wayCount > 0);
    }
#endif

    [super encodeWithCoder:coder];
    [coder encodeObject:_nodes forKey:@"nodes"];
}

@end

#pragma mark OsmRelation

@implementation OsmRelation

- (NSString *)description {
    return [NSString stringWithFormat:@"OsmRelation %@", [super description]];
}

- (void)constructMember:(OsmMember *)member {
    assert(!_constructed);
    if (_members == nil) {
        _members = [NSMutableArray arrayWithObject:member];
    } else {
        [_members addObject:member];
    }
}

- (OsmRelation *)isRelation {
    return self;
}

- (void)forAllMemberObjectsRecurse:(void (^)(OsmBaseObject *))callback relations:(NSMutableSet *)relations {
    for (OsmMember *member in _members) {
        OsmBaseObject *obj = member.ref;
        if ([obj isKindOfClass:[OsmBaseObject class]]) {
            if (obj.isRelation) {
                if ([relations containsObject:obj]) {
                    // skip
                } else {
                    callback(obj);
                    [relations addObject:obj];
                    [obj.isRelation forAllMemberObjectsRecurse:callback relations:relations];
                }
            } else {
                callback(obj);
            }
        }
    }
}
- (void)forAllMemberObjects:(void (^)(OsmBaseObject *))callback {
    NSMutableSet *relations = [NSMutableSet setWithObject:self];
    [self forAllMemberObjectsRecurse:callback relations:relations];
}
- (NSSet *)allMemberObjects {
    __block NSMutableSet *objects = [NSMutableSet new];
    [self forAllMemberObjects:^(OsmBaseObject *obj) {
      [objects addObject:obj];
    }];
    return objects;
}

- (void)resolveToMapData:(OsmMapData *)mapData {
    BOOL needsRedraw = NO;
    for (OsmMember *member in _members) {
        id ref = member.ref;
        if (![ref isKindOfClass:[NSNumber class]])
            // already resolved
            continue;

        if (member.isWay) {
            OsmWay *way = [mapData wayForRef:ref];
            if (way) {
                [member resolveRefToObject:way];
                [way addRelation:self undo:nil];
                needsRedraw = YES;
            } else {
                // way is not in current view
            }
        } else if (member.isNode) {
            OsmNode *node = [mapData nodeForRef:ref];
            if (node) {
                [member resolveRefToObject:node];
                [node addRelation:self undo:nil];
                needsRedraw = YES;
            } else {
                // node is not in current view
            }
        } else if (member.isRelation) {
            OsmRelation *rel = [mapData relationForRef:ref];
            if (rel) {
                [member resolveRefToObject:rel];
                [rel addRelation:self undo:nil];
                needsRedraw = YES;
            } else {
                // relation is not in current view
            }
        } else {
            assert(NO);
        }
    }
    if (needsRedraw) {
        [self clearCachedProperties];
    }
}

// convert references to objects back to NSNumber
- (void)deresolveRefs {
    for (OsmMember *member in _members) {
        OsmBaseObject *ref = member.ref;
        if ([ref isKindOfClass:[OsmBaseObject class]]) {
            [ref removeRelation:self undo:nil];
            [member resolveRefToObject:(OsmBaseObject *)ref.ident];
        }
    }
}

- (void)assignMembers:(NSArray *)members undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [self incrementModifyCount:undo];
        [undo registerUndoWithTarget:self selector:@selector(assignMembers:undo:) objects:@[ _members, undo ]];
    }

    // figure out which members changed and update their relation parents
#if 1
    NSMutableSet *old = [NSMutableSet new];
    NSMutableSet *new = [ NSMutableSet new ];
    for (OsmMember *m in _members) {
        if ([m.ref isKindOfClass:[OsmBaseObject class]]) {
            [old addObject:m.ref];
        }
    }
    for (OsmMember *m in members) {
        if ([m.ref isKindOfClass:[OsmBaseObject class]]) {
            [new addObject:m.ref];
        }
    }
    NSMutableSet *common = [new mutableCopy];
    [common intersectSet:old];
    [new minusSet:common]; // added items
    [old minusSet:common]; // removed items
    for (OsmBaseObject *obj in old) {
        [obj removeRelation:self undo:nil];
    }
    for (OsmBaseObject *obj in new) {
        [obj addRelation:self undo:nil];
    }
#else
    NSArray *old = [_members sortedArrayUsingComparator:^NSComparisonResult(OsmMember *obj1, OsmMember *obj2) {
      NSNumber *r1 = [obj1.ref isKindOfClass:[OsmBaseObject class]] ? ((OsmBaseObject *)obj1.ref).ident : obj1.ref;
      NSNumber *r2 = [obj2.ref isKindOfClass:[OsmBaseObject class]] ? ((OsmBaseObject *)obj2.ref).ident : obj2.ref;
      return [r1 compare:r2];
    }];
    NSArray *new = [ members sortedArrayUsingComparator : ^NSComparisonResult(OsmMember *obj1, OsmMember *obj2) {
      NSNumber *r1 = [obj1.ref isKindOfClass:[OsmBaseObject class]] ? ((OsmBaseObject *)obj1.ref).ident : obj1.ref;
      NSNumber *r2 = [obj2.ref isKindOfClass:[OsmBaseObject class]] ? ((OsmBaseObject *)obj2.ref).ident : obj2.ref;
      return [r1 compare:r2];
    } ];
#endif

    _members = [members mutableCopy];
}

- (void)removeMemberAtIndex:(NSInteger)index undo:(UndoManager *)undo {
    assert(undo);
    OsmMember *member = _members[index];
    [self incrementModifyCount:undo];
    [undo registerUndoWithTarget:self selector:@selector(addMember:atIndex:undo:) objects:@[ member, @(index), undo ]];
    [_members removeObjectAtIndex:index];
    OsmBaseObject *obj = member.ref;
    if ([obj isKindOfClass:[OsmBaseObject class]]) {
        [obj removeRelation:self undo:nil];
    }
}
- (void)addMember:(OsmMember *)member atIndex:(NSInteger)index undo:(UndoManager *)undo {
    if (_constructed) {
        assert(undo);
        [self incrementModifyCount:undo];
        [undo registerUndoWithTarget:self selector:@selector(removeMemberAtIndex:undo:) objects:@[ @(index), undo ]];
    }
    if (_members == nil) {
        _members = [NSMutableArray new];
    }
    [_members insertObject:member atIndex:index];
    OsmBaseObject *obj = member.ref;
    if ([obj isKindOfClass:[OsmBaseObject class]]) {
        [obj addRelation:self undo:nil];
    }
}

- (void)serverUpdateInPlace:(OsmRelation *)newerVersion {
    [super serverUpdateInPlace:newerVersion];
    _members = [newerVersion.members mutableCopy];
}

- (void)computeBoundingBox {
    BOOL first = YES;
    OSMRect box = {0, 0, 0, 0};
    NSSet *objects = [self allMemberObjects];
    for (OsmBaseObject *obj in objects) {
        OSMRect rc = obj.boundingBox;
        if (rc.origin.x == 0 && rc.origin.y == 0 && rc.size.height == 0 && rc.size.width == 0) {
            // skip
        } else if (first) {
            box = rc;
            first = NO;
        } else {
            box = OSMRectUnion(box, rc);
        }
    }
    _boundingBox = box;
}

- (NSSet *)nodeSet {
    NSMutableSet *set = [NSMutableSet set];
    for (OsmMember *member in _members) {
        if ([member.ref isKindOfClass:[NSNumber class]])
            continue; // unresolved reference

        if (member.isNode) {
            OsmNode *node = member.ref;
            [set addObject:node];
        } else if (member.isWay) {
            OsmWay *way = member.ref;
            [set addObjectsFromArray:way.nodes];
        } else if (member.isRelation) {
            OsmRelation *relation = member.ref;
            for (OsmNode *node in [relation nodeSet]) {
                [set addObject:node];
            }
        } else {
            assert(NO);
        }
    }
    return set;
}

- (OsmMember *)memberByRole:(NSString *)role {
    for (OsmMember *member in _members) {
        if ([member.role isEqualToString:role]) {
            return member;
        }
    }
    return nil;
}
- (NSArray *)membersByRole:(NSString *)role {
    NSMutableArray *a = [NSMutableArray new];
    for (OsmMember *member in _members) {
        if ([member.role isEqualToString:role]) {
            [a addObject:member];
        }
    }
    return a;
}
- (OsmMember *)memberByRef:(OsmBaseObject *)ref {
    for (OsmMember *member in _members) {
        if (member.ref == ref)
            return member;
    }
    return nil;
}

- (BOOL)isMultipolygon {
    return [_tags[@"type"] isEqualToString:@"multipolygon"];
}

- (BOOL)isRoute {
    return [_tags[@"type"] isEqualToString:@"route"];
}

- (BOOL)isRestriction {
    NSString *type = self.tags[@"type"];
    if (type) {
        if ([type isEqualToString:@"restriction"])
            return YES;
        if ([type hasPrefix:@"restriction:"])
            return YES;
    }
    return NO;
}

- (NSMutableArray *)waysInMultipolygon {
    if (!self.isMultipolygon)
        return nil;
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:_members.count];
    for (OsmMember *mem in _members) {
        NSString *role = mem.role;
        if ([role isEqualToString:@"outer"] || [role isEqualToString:@"inner"]) {
            if ([mem.ref isKindOfClass:[OsmWay class]]) {
                [a addObject:mem.ref];
            }
        }
    }
    return a;
}

+ (NSArray *)buildMultipolygonFromMembers:(NSArray *)memberList repairing:(BOOL)repairing isComplete:(BOOL *)isComplete {
    NSMutableArray *loopList = [NSMutableArray new];
    NSMutableArray *loop = nil;
    NSMutableArray *members = [memberList mutableCopy];
    [members filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OsmMember *member, NSDictionary<NSString *, id> *bindings) {
               return [member.ref isKindOfClass:[OsmWay class]] && ([member.role isEqualToString:@"outer"] || [member.role isEqualToString:@"inner"]);
             }]];
    BOOL isInner = NO;
    BOOL foundAdjacent = NO;

    *isComplete = members.count == memberList.count;

    while (members.count) {
        if (loop == nil) {
            // add a member to loop
            OsmMember *member = members.lastObject;
            [members removeObjectAtIndex:members.count - 1];
            isInner = [member.role isEqualToString:@"inner"];
            OsmWay *way = member.ref;
            loop = [way.nodes mutableCopy];
            foundAdjacent = YES;
        } else {
            // find adjacent way
            foundAdjacent = NO;
            for (NSInteger i = 0; i < members.count; ++i) {
                OsmMember *member = members[i];
                if ([member.role isEqualToString:@"inner"] != isInner)
                    continue;
                OsmWay *way = member.ref;
                NSEnumerator *enumerator = way.nodes[0] == loop.lastObject ? way.nodes.objectEnumerator
                                                                           : way.nodes.lastObject == loop.lastObject ? way.nodes.reverseObjectEnumerator
                                                                                                                     : nil;
                if (enumerator) {
                    foundAdjacent = YES;
                    BOOL first = YES;
                    for (OsmNode *n in enumerator) {
                        if (first) {
                            first = NO;
                        } else {
                            [loop addObject:n];
                        }
                    }
                    [members removeObjectAtIndex:i];
                    break;
                }
            }
            if (!foundAdjacent && repairing) {
                // invalid, but we'll try to continue
                *isComplete = NO;
                [loop addObject:loop[0]]; // force-close the loop
            }
        }

        if (loop.count && (loop.lastObject == loop[0] || !foundAdjacent)) {
            // finished a loop. Outer goes clockwise, inner goes counterclockwise
            NSArray *lp = [OsmWay isClockwiseArrayOfNodes:loop] == isInner ? [[loop reverseObjectEnumerator] allObjects] : loop;
            [loopList addObject:lp];
            loop = nil;
        }
    }
    return loopList;
}

- (NSArray *)buildMultipolygonRepairing:(BOOL)repairing {
    if (!self.isMultipolygon)
        return nil;
    BOOL isComplete = YES;
    NSArray *a = [OsmRelation buildMultipolygonFromMembers:self.members repairing:repairing isComplete:&isComplete];
    return a;
}

- (CGPathRef)shapePathForObjectWithRefPoint:(OSMPoint *)pRefPoint CF_RETURNS_RETAINED {
    NSArray *loopList = [self buildMultipolygonRepairing:YES];
    if (loopList.count == 0)
        return NULL;

    CGMutablePathRef path = CGPathCreateMutable();
    BOOL hasRefPoint = NO;
    OSMPoint refPoint;

    for (NSArray *loop in loopList) {
        BOOL first = YES;
        for (OsmNode *n in loop) {
            OSMPoint pt = MapPointForLatitudeLongitude(n.lat, n.lon);
            if (first) {
                first = NO;
                if (!hasRefPoint) {
                    hasRefPoint = YES;
                    refPoint = pt;
                }
                CGPathMoveToPoint(path, NULL, (pt.x - refPoint.x) * PATH_SCALING, (pt.y - refPoint.y) * PATH_SCALING);
            } else {
                CGPathAddLineToPoint(path, NULL, (pt.x - refPoint.x) * PATH_SCALING, (pt.y - refPoint.y) * PATH_SCALING);
            }
        }
    }
    *pRefPoint = refPoint;
    return path;
}

- (OSMPoint)centerPoint {
    NSMutableArray *outerSet = [NSMutableArray new];
    for (OsmMember *member in _members) {
        if ([member.role isEqualToString:@"outer"]) {
            OsmWay *way = member.ref;
            if ([way isKindOfClass:[OsmWay class]]) {
                [outerSet addObject:way];
            }
        }
    }
    if (outerSet.count == 1) {
        return [outerSet[0] centerPoint];
    } else {
        OSMRect rc = self.boundingBox;
        return OSMPointMake(rc.origin.x + rc.size.width / 2, rc.origin.y + rc.size.height / 2);
    }
}
- (OSMPoint)selectionPoint {
    OSMRect bbox = self.boundingBox;
    OSMPoint center = {bbox.origin.x + bbox.size.width / 2, bbox.origin.y + bbox.size.height / 2};
    if ([self isMultipolygon]) {
        // pick a point on an outer polygon that is close to the center of the bbox
        for (OsmMember *member in _members) {
            if ([member.role isEqualToString:@"outer"]) {
                OsmWay *way = member.ref;
                if ([way isKindOfClass:[OsmWay class]] && way.nodes.count > 0) {
                    return [way pointOnObjectForPoint:center];
                }
            }
        }
    }
    if ([self isRestriction]) {
        // pick via node or way
        for (OsmMember *member in _members) {
            if ([member.role isEqualToString:@"via"]) {
                OsmBaseObject *object = member.ref;
                if ([object isKindOfClass:[OsmBaseObject class]]) {
                    if (object.isNode || object.isWay) {
                        return [object selectionPoint];
                    }
                }
            }
        }
    }
    // choose any node/way member
    NSSet *all = [self allMemberObjects]; // might be a super relation, so need to recurse down
    OsmBaseObject *object = [all anyObject];
    return [object selectionPoint];
}

- (double)distanceToLineSegment:(OSMPoint)point1 point:(OSMPoint)point2 {
    double dist = 1000000.0;
    for (OsmMember *member in _members) {
        OsmBaseObject *object = member.ref;
        if ([object isKindOfClass:[OsmBaseObject class]]) {
            if (!object.isRelation) {
                double d = [object distanceToLineSegment:point1 point:point2];
                if (d < dist) {
                    dist = d;
                }
            }
        }
    }
    return dist;
}

- (OSMPoint)pointOnObjectForPoint:(OSMPoint)target {
    OSMPoint bestPoint = target;
    double bestDistance = 10000000.0;
    for (OsmBaseObject *object in self.allMemberObjects) {
        OSMPoint pt = [object pointOnObjectForPoint:target];
        double dist = DistanceFromPointToPoint(target, pt);
        if (dist < bestDistance) {
            bestDistance = dist;
            bestPoint = pt;
        }
    }
    return bestPoint;
}

- (BOOL)containsObject:(OsmBaseObject *)object {
    OsmNode *node = object.isNode;
    NSSet *set = [self allMemberObjects];
    for (OsmBaseObject *obj in set) {
        if (obj == object) {
            return YES;
        }
        if (node && obj.isWay && [obj.isWay.nodes containsObject:object]) {
            return YES;
        }
    }
    return NO;

#if 0
	__block contains = NO;
	[self forAllMemberObjects:^(OsmBaseObject * obj) {
		if ( obj == object ) {
			contains = YES;
			break;
		}
		if ( object.isNode && obj.isWay ) {
			if ( && obj.isWay.nodes containsObject:object]) )
		{
		}
	}];
#endif
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:_members forKey:@"members"];
}
- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _members = [coder decodeObjectForKey:@"members"];
        _constructed = YES;
    }
    return self;
}

@end

#pragma mark OsmMember

@implementation OsmMember

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ role=%@; type=%@;ref=%@;", [super description], _role, _type, _ref];
}
- (id)initWithType:(NSString *)type ref:(NSNumber *)ref role:(NSString *)role {
    self = [super init];
    if (self) {
        _type = type;
        _ref = ref;
        _role = role;
    }
    return self;
}
- (id)initWithRef:(OsmBaseObject *)ref role:(NSString *)role {
    self = [super init];
    if (self) {
        _ref = ref;
        _role = role;
        if (ref.isNode)
            _type = @"node";
        else if (ref.isWay)
            _type = @"way";
        else if (ref.isRelation)
            _type = @"relation";
        else {
            _type = nil;
        }
    }
    return self;
}

- (void)resolveRefToObject:(OsmBaseObject *)object {
    assert([_ref isKindOfClass:[NSNumber class]] || [_ref isKindOfClass:[OsmBaseObject class]]);
    assert([object isKindOfClass:[NSNumber class]] || (object.isNode && self.isNode) || (object.isWay && self.isWay) || (object.isRelation && self.isRelation));
    _ref = object;
}

- (BOOL)isNode {
    return [_type isEqualToString:@"node"];
}
- (BOOL)isWay {
    return [_type isEqualToString:@"way"];
}
- (BOOL)isRelation {
    return [_type isEqualToString:@"relation"];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    OsmBaseObject *o = _ref;
    NSNumber *ref = [_ref isKindOfClass:[OsmBaseObject class]] ? o.ident : _ref;
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeObject:ref forKey:@"ref"];
    [coder encodeObject:_role forKey:@"role"];
}
- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _type = [coder decodeObjectForKey:@"type"];
        _ref = [coder decodeObjectForKey:@"ref"];
        _role = [coder decodeObjectForKey:@"role"];
    }
    return self;
}

@end
