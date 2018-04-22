//
//  TurnRestrictController.m
//  Go Map!!
//
//  Created by Mukul Bakshi on 02/11/17.
//  Copyright © 2017 Bryce Cogswell. All rights reserved.
//

#import "TurnRestrictController.h"

#import "AppDelegate.h"
#import "EditorMapLayer.h"
#import "MapView.h"
#import "OsmNotesDatabase.h"
#import "OsmMapData.h"
#import "OsmMapData+Orthogonalize.h"
#import "OsmMapData+Straighten.h"
#import "OsmObjects.h"


@interface TurnRestrictController ()
{
	NSMutableArray		*	_parentWays;
	NSMutableArray		*	_highwayViewArray; //	Array of TurnRestrictHwyView to Store number of ways

	TurnRestrictHwyView	*	_selectedFromHwy;
	UIButton			*   _uTurnButton;
	OsmRelation 		*   _currentUTurnRelation;

	NSMutableArray		*	_allRelations;
	NSMutableArray		*	_editedRelations;
}
@end


@implementation TurnRestrictController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _highwayViewArray = [[NSMutableArray alloc] init];
    [self createMapWindow];
}

// To dray Popup window
-(void)createMapWindow
{
	// Popup Window Size iPhone
	CGSize size = { 240, 220 };
	if ( [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ) {
		//Popup Window 2X Size iPad
		size.width *= 2;
		size.height *= 2;
	}
	size.height += 30;	// Popup Window Topbar height
	_constraintViewWithTitleWidth.constant = size.width;
	_constraintViewWithTitleHeight.constant = size.height;

	[self.view layoutIfNeeded];

	_detailView.clipsToBounds = true;

	_viewWithTitle.clipsToBounds		= true;
	_viewWithTitle.alpha 				= 1;
	_viewWithTitle.layer.borderColor 	= UIColor.grayColor.CGColor;
	_viewWithTitle.layer.borderWidth 	= 1;
	_viewWithTitle.layer.cornerRadius 	= 3;

	// get highways that contain selection
	OsmMapData * mapData = [AppDelegate getAppDelegate].mapView.editorLayer.mapData;
	NSArray * parentWays = [mapData waysContainingNode:_centralNode];
	parentWays = [parentWays filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OsmWay * way, NSDictionary *bindings) {
		return way.tags[@"highway"] != nil;
	}]];
	_parentWays = [parentWays mutableCopy];
	
	// Creating roads using adjacent connected nodes
	NSArray * conectedNodes = [TurnRestrictController getAdjacentNodes:_centralNode ways:_parentWays];
	[self createHighwayViews:conectedNodes];
	
	// if there is only one reasonable thing to highlight initially select it
	OsmWay * fromWay = nil;
	if ( _allRelations.count == 1 ) {
		// only one relation, so select it
		OsmRelation * relation = _allRelations.lastObject;
		fromWay = [relation memberByRole:@"from"].ref;
	} else {
		// no relations or multiple relations, so select highway already selected by user
		EditorMapLayer * editor = [AppDelegate getAppDelegate].mapView.editorLayer;
		fromWay = editor.selectedWay;
	}
	if ( fromWay ) {
		for ( TurnRestrictHwyView * hwy in _highwayViewArray ) {
			if ( hwy.wayObj == fromWay ) {
				[self toggleHighwaySelection:hwy];
				break;
			}
		}
	}
}

+(NSArray *)getAdjacentNodes:(OsmNode *)centerNode ways:(NSArray *)parentWays
{
	NSMutableArray * connectedNodes = [NSMutableArray new];

	for (OsmWay * way in parentWays) {
		if (way.isArea)
			continue; // An area won't have any connected ways to it
		
		for ( int i = 0; i < way.nodes.count; i++) {
			OsmNode * node = [way.nodes objectAtIndex:i];
			if ( node == centerNode ) {
				if ( i+1 < way.nodes.count) {
					OsmNode * nodeNext = way.nodes[i+1];
					if ( ![connectedNodes containsObject:nodeNext] ) 	{
						nodeNext.turnRestrictionParentWay = way;
						[connectedNodes addObject:nodeNext];
					}
				}

				if ( i > 0 ) {
					OsmNode * nodePrev = way.nodes[i-1];
					if ( ![connectedNodes containsObject:nodePrev]) {
						nodePrev.turnRestrictionParentWay = way;
						[connectedNodes addObject:nodePrev];
					}
				}
			}
		}
	}
	return connectedNodes;
}

+(void)setAssociatedTurnRestrictionWays:(NSArray *)allWays
{
	for ( OsmWay * way in allWays ) {
		for ( OsmNode * node in way.nodes ) {
			node.turnRestrictionParentWay = way;
		}
	}
}



//MARK: Create Path From Points
-(void)createHighwayViews:(NSArray *)adjacentNodesArray
{
	CGPoint	centerNodePos		= [self screenPointForLatitude:_centralNode.lat longitude:_centralNode.lon];
	CGPoint detailViewCenter	= CGPointMake( _detailView.frame.size.width/2, _detailView.frame.size.height/2 );
	CGPoint positionOffset		= CGPointSubtract( centerNodePos, detailViewCenter );

	// Get relations related to restrictions
	_allRelations = [NSMutableArray new];
	for ( OsmRelation * relation in _centralNode.relations )  {
		if ( relation.isRestriction && relation.members.count >= 3 )  {
			[_allRelations addObject:relation];
		}
	}

	_editedRelations = [_allRelations mutableCopy];

	// create highway views
	_highwayViewArray = [NSMutableArray new];
	for ( OsmNode * node in adjacentNodesArray )  {
		// get location of node
		CGPoint nodePoint = [self screenPointForLatitude:node.lat longitude:node.lon];
		nodePoint = CGPointSubtract(nodePoint, positionOffset);

		// force highway segment to extend from center node to edge of view
		CGSize size = _detailView.frame.size;
		OSMPoint direction = OSMPointMake( nodePoint.x - detailViewCenter.x, nodePoint.y - detailViewCenter.y );
		double distTop    = DistanceToVector( OSMPointFromCGPoint(detailViewCenter), direction, OSMPointMake(0,0),			OSMPointMake(size.width,0) );
		double distLeft   = DistanceToVector( OSMPointFromCGPoint(detailViewCenter), direction, OSMPointMake(0,0), 			OSMPointMake(0,size.height) );
		double distRight  = DistanceToVector( OSMPointFromCGPoint(detailViewCenter), direction, OSMPointMake(size.width,0), OSMPointMake(0,size.height) );
		double distBottom = DistanceToVector( OSMPointFromCGPoint(detailViewCenter), direction, OSMPointMake(0,size.height),OSMPointMake(size.width,0) );
		double best = FLT_MAX;
		if ( distTop > 0 && distTop < best )		best = distTop;
		if ( distLeft > 0 && distLeft < best )		best = distLeft;
		if ( distRight > 0 && distRight < best )	best = distRight;
		if ( distBottom > 0 && distBottom < best )	best = distBottom;
		nodePoint = CGPointMake( detailViewCenter.x+best*direction.x, detailViewCenter.y+best*direction.y );
		
		// highway path
		UIBezierPath * bezierPath = [UIBezierPath bezierPath];
		[bezierPath moveToPoint:detailViewCenter];
		[bezierPath addLineToPoint:nodePoint];
		
		// Highlight shape
		CAShapeLayer * highlightLayer = [CAShapeLayer layer];
		highlightLayer.lineWidth   	=  DEFAULT_POPUPLINEWIDTH + 6;
		highlightLayer.strokeColor 	= UIColor.cyanColor.CGColor;
		highlightLayer.lineCap 		= kCALineCapRound;
		highlightLayer.path   		= bezierPath.CGPath;
		highlightLayer.bounds 		= _detailView.bounds;
		highlightLayer.position 	= detailViewCenter;
		highlightLayer.hidden		= YES;

		// Highway shape
		CAShapeLayer * highwayLayer = [CAShapeLayer layer];
		highwayLayer.lineWidth   	= DEFAULT_POPUPLINEWIDTH;
		highwayLayer.lineCap 		= kCALineCapRound;
		highwayLayer.path 	  		= bezierPath.CGPath;
		highwayLayer.strokeColor 	= node.turnRestrictionParentWay.tagInfo.lineColor.CGColor ?: UIColor.blackColor.CGColor;
		highwayLayer.bounds 		= _detailView.bounds;
		highwayLayer.position	 	= detailViewCenter;
		highwayLayer.masksToBounds 	= NO;

		// Highway view
		TurnRestrictHwyView * hwyView = [[TurnRestrictHwyView alloc] initWithFrame:_detailView.bounds];
		hwyView.wayObj 				= node.turnRestrictionParentWay;
		hwyView.centerNode 			= _centralNode;
		hwyView.connectedNode	 	= node;
		hwyView.centerPoint 		= detailViewCenter;
		hwyView.endPoint 			= nodePoint;
		hwyView.parentWaysArray		= _parentWays;
		hwyView.highwayLayer 		= highwayLayer;
		hwyView.highlightLayer 		= highlightLayer;
		hwyView.backgroundColor		= UIColor.clearColor;
		
		[hwyView.layer addSublayer:highwayLayer];
		[hwyView.layer insertSublayer:highlightLayer below:highwayLayer];

		[hwyView createTurnRestrictionButton];
		[hwyView createOneWayArrowsForHighway];
		hwyView.arrowButton.hidden 		= YES;
		hwyView.lineButtonPressCallback = ^(TurnRestrictHwyView *objLine) { [self toggleTurnRestriction:objLine]; };
		hwyView.lineSelectionCallback 	= ^(TurnRestrictHwyView *objLine) { [self toggleHighwaySelection:objLine]; };

		[_detailView addSubview:hwyView];
		[_highwayViewArray addObject:hwyView];
	}
	
	// Place green circle in center
	UIView * centerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 16)];
	centerView.backgroundColor 		= UIColor.greenColor;
	centerView.layer.cornerRadius 	= centerView.frame.size.height/2;
	centerView.center 				= detailViewCenter;
	[_detailView addSubview:centerView];
	[_detailView bringSubviewToFront:centerView];
	
	self.view.backgroundColor = UIColor.clearColor;

	// Create U-Turn restriction button
	_uTurnButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
	_uTurnButton.imageView.contentMode	= UIViewContentModeScaleAspectFit;
	_uTurnButton.center 				= detailViewCenter;
	[_uTurnButton setImage:[UIImage imageNamed:@"uTurnAllow"]	 forState:UIControlStateNormal];
	[_uTurnButton setImage:[UIImage imageNamed:@"uTurnRestrict"] forState:UIControlStateSelected];
	[_uTurnButton addTarget:self action:@selector(uTurnButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
	[_detailView addSubview:_uTurnButton];
	_uTurnButton.hidden = true;
}



// Select a new "From" highway
-(void)toggleHighwaySelection:(TurnRestrictHwyView *)selectedHwy
{
	_selectedFromHwy = selectedHwy;
	
	selectedHwy.wayObj = selectedHwy.connectedNode.turnRestrictionParentWay;
	_uTurnButton.hidden = _selectedFromHwy.wayObj.isOneWay != ONEWAY_NONE;
	
	CGFloat angle = [TurnRestrictHwyView headingFromPoint:selectedHwy.endPoint toPoint:selectedHwy.centerPoint];
	_uTurnButton.transform = CGAffineTransformMakeRotation(angle);
	
	_currentUTurnRelation = [self findRelation:_editedRelations
										   from:_selectedFromHwy.wayObj
											via:_centralNode
											 to:_selectedFromHwy.wayObj];
	_uTurnButton.selected = (_currentUTurnRelation != nil);

	// highway exits center one-way
	BOOL selectedHwyIsOneWayExit = [selectedHwy isOneWayExitingCenter];
	
	for ( TurnRestrictHwyView * highway in _highwayViewArray ) {

		selectedHwy.wayObj = selectedHwy.connectedNode.turnRestrictionParentWay;
		
		if ( highway == selectedHwy ) {
			// highway is selected
			highway.highlightLayer.hidden = NO;
			highway.arrowButton.hidden = YES;
		} else {
			// highway is deselected, so display restrictions applied to it
			highway.highlightLayer.hidden = YES;
			
			OsmRelation * relation = [self findRelation:_editedRelations from:selectedHwy.wayObj via:_centralNode to:highway.wayObj];
			BOOL isSelected = (relation == nil);
			
			highway.objRel = relation;
			highway.arrowButton.hidden = NO;
			highway.arrowButton.selected = !isSelected;
			
			if ( selectedHwyIsOneWayExit ) {
				highway.arrowButton.hidden = YES;
			} else if ( [highway isOneWayEnteringCenter] ) {
				highway.arrowButton.hidden = YES;	// highway is one way into intersection, so we can't turn onto it
			}
		}
	}
}

-(OsmRelation *)applyTurnRestriction:(OsmMapData *)mapData from:(OsmWay *)fromWay fromNode:(OsmNode *)fromNode to:(OsmWay *)toWay toNode:(OsmNode *)toNode restriction:(NSString *)restriction
{
	OsmRelation * relation = [self findRelation:_allRelations from:fromWay via:_centralNode to:toWay];
	NSArray		* newWays = nil;
	relation = [mapData updateTurnRestrictionRelation:relation viaNode:_centralNode
											  fromWay:fromWay fromWayNode:fromNode
												toWay:toWay toWayNode:toNode
												 turn:restriction newWays:&newWays willSplit:nil];
	if ( newWays.count ) {
		// had to split some ways to create restriction, so process them
		[_parentWays addObjectsFromArray:newWays];
		[TurnRestrictController setAssociatedTurnRestrictionWays:_parentWays];
		for ( TurnRestrictHwyView * hwy in _highwayViewArray )  {
			hwy.wayObj = hwy.connectedNode.turnRestrictionParentWay;
		}
	}
	if ( ! [_allRelations containsObject:relation] )
		[_allRelations addObject:relation];
	if ( ! [_editedRelations containsObject:relation] )
		[_editedRelations addObject:relation];
	
	return relation;
}
-(void)removeTurnRestriction:(OsmMapData *)mapData relation:(OsmRelation *)relation
{
	[mapData deleteRelation:relation];
}


// Enable/disable a left/right/straight turn restriction
-(void)toggleTurnRestriction:(TurnRestrictHwyView *)targetHwy
{
	AppDelegate * appDelegate = [AppDelegate getAppDelegate];
	OsmMapData * mapData = appDelegate.mapView.editorLayer.mapData;
	
	bool isRestricting = targetHwy.arrowButton.selected;
	
	if ( isRestricting )  {
		
		double angle = [targetHwy turnAngleDegreesFromPoint:_selectedFromHwy.endPoint];
				
		NSString *str = nil;
		if (ABS(angle) < 3)   {
			str = @"no_straight_on";
		} else if ( angle < 0 )   {
			str = @"no_left_turn";
		} else {
			str = @"no_right_turn";
		}
		
		targetHwy.objRel = [self applyTurnRestriction:mapData from:_selectedFromHwy.wayObj fromNode:_selectedFromHwy.connectedNode to:targetHwy.wayObj toNode:targetHwy.connectedNode restriction:str];

	} else {
		
		// Remove Relation
		if ( targetHwy.objRel )  {

			[self removeTurnRestriction:mapData relation:targetHwy.objRel];
			[_editedRelations removeObject:targetHwy.objRel];
			
			targetHwy.objRel = nil;
		}
	}

	[appDelegate.mapView.editorLayer setNeedsDisplay];
	[appDelegate.mapView.editorLayer setNeedsLayout];
}

// Use clicked the U-Turn button
-(void)uTurnButtonClicked:(UIButton *)sender
{
	AppDelegate * appDelegate = [AppDelegate getAppDelegate];
	OsmMapData * mapData = appDelegate.mapView.editorLayer.mapData;

	sender.selected = !sender.selected;

	BOOL isRestricting = sender.selected;

	if ( isRestricting ) {
		NSString *str = @"no_u_turn";
		_currentUTurnRelation = [self applyTurnRestriction:mapData from:_selectedFromHwy.wayObj fromNode:_selectedFromHwy.connectedNode to:_selectedFromHwy.wayObj toNode:_selectedFromHwy.connectedNode restriction:str];
		[appDelegate.mapView.editorLayer setNeedsDisplay];
		[appDelegate.mapView.editorLayer setNeedsLayout];

	} else {
		if ( _currentUTurnRelation ) {
			[self removeTurnRestriction:mapData relation:_currentUTurnRelation];
			[_editedRelations removeObject:_currentUTurnRelation];
			_currentUTurnRelation = nil;
		}
	}
}


// Getting restriction relation by From node, To node and Via node
-(OsmRelation *)findRelation:(NSArray *)relationList
                         from:(OsmWay *)fromTarget
                          via:(OsmNode *)viaTarget
                           to:(OsmWay *)toTarget
{
	for ( OsmRelation * relation in relationList )  {
		OsmWay 	*	fromWay = [relation memberByRole:@"from"].ref;
		OsmNode *	viaNode = [relation memberByRole:@"via"].ref;
		OsmWay 	*	toWay	= [relation memberByRole:@"to"].ref;
		if ( fromWay == fromTarget && viaNode == viaTarget && toWay == toTarget )
			return relation;
	}
	return nil;
}



// Close the window if user touches outside it
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	CGPoint locationPoint = [[touches anyObject] locationInView:self.view];
	CGPoint viewPoint     = [_viewWithTitle convertPoint:locationPoint fromView:self.view];

	if ( ![_viewWithTitle pointInside:viewPoint withEvent:event] )  {
		[self dismissViewControllerAnimated:true completion:nil];
	}
}


// Convert location point to CGPoint
-(CGPoint)screenPointForLatitude:(double)latitude longitude:(double)longitude
{
	OSMPoint pt = MapPointForLatitudeLongitude( latitude, longitude );
	pt = OSMPointApplyTransform( pt, _screenFromMapTransform );
	return CGPointFromOSMPoint(pt);
}

@end

