/* Copyright 2010-2011 Antti Aalto, Ronja Addams-Moring, Kristian Dahlgren,
 * Henri Junnilainen, David Muños, Naoufal Ouardi, Paulus Selin and Seppo 
 * Yli-Olli (the student team "Mixed Apples" during the course T-76.4115
 * Software development project at Aalto University School of Technology
 * 
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License. */


#import "XMLToCoreDataConverter.h"

void setRelationship (NSManagedObject* parent, NSManagedObject *object, 
					  NSRelationshipDescription * relationship) {
	if([relationship maxCount] != 1) {
		NSMutableSet * relatives = [parent mutableSetValueForKey:[relationship name]];
		[relatives addObject:object];
	}else {
		[parent setValue:object forKey:[relationship name]];
	}
}

void nukeRelationships(NSManagedObject *object) {
	for(NSRelationshipDescription * relationship in [[[object entity] relationshipsByName]objectEnumerator]) {
		if([relationship maxCount] != 1) {
			NSMutableSet * set = [object mutableSetValueForKey:[relationship name]];
			[set removeAllObjects];
		}else {
			[object setValue:nil forKey:[relationship name]];
		}
	}
}

NSString* capitalize(NSString * string) {
	return [string stringByReplacingCharactersInRange:
			NSMakeRange(0,1) withString:[[string substringToIndex:1] capitalizedString]];
}


@implementation XMLToCoreDataConverter
@synthesize context;
@synthesize model;
@synthesize attributeStack;
@synthesize relationshipStack;
@synthesize objectStack;
@synthesize lastType;
@synthesize foundCharacters;
@synthesize dateFormatter;
@synthesize numberFormatter;
@synthesize error;

-(id) init {
	if(self = [super init]) {
		self.numberFormatter = [[NSNumberFormatter new]autorelease];
		self.dateFormatter = [[NSDateFormatter new] autorelease];
		[self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
		self.relationshipStack = [NSMutableArray arrayWithCapacity:10];
		self.attributeStack = [NSMutableArray arrayWithCapacity:10];
		self.objectStack = [NSMutableArray arrayWithCapacity:10];
		self.lastType = NULL;
		self.foundCharacters = [NSMutableString stringWithCapacity:20];
	}
	return self;
}

-(BOOL) parseClassData : (NSData *)data 
		   intoContext : (NSManagedObjectContext*) _context 
					   : (NSError **)_error {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSXMLParser * parser = [[NSXMLParser alloc] initWithData:data];
	self.context = _context;
	NSAssert(self.context, @"Parser needs a context");
	self.model = [[self.context persistentStoreCoordinator] managedObjectModel];
	NSAssert(self.model, @"Parser needs a model");
	[parser setDelegate:self];
	[parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO]; 
    [parser setShouldResolveExternalEntities:NO];
	[self.context setUndoManager:[[[NSUndoManager alloc]init]autorelease]];
	[parser parse];
	self.context = nil;
	[parser release];
	[pool drain];
	if(error) {
		_error = &error;
		return NO;
	}
	return YES;
}

-(void)  parser : (NSXMLParser *) parser
didStartElement : (NSString *) elementName 
   namespaceURI : (NSString *) namespaceURI 
  qualifiedName : (NSString *) qName 
	 attributes : (NSDictionary *) attributeDict {
	if([elementName isEqual:@"description"])
		elementName = @"description_";
	if([elementName isEqual:@"id"])
		elementName = @"ident";
	NSAssert(![self.lastType isEqual:[NSAttributeDescription class]],
			   @"Attributes aren't allowed to have nested elements");
	if([self.lastType isEqual:[NSAttributeDescription class]]) {
		if([self.attributeStack count]) {
			/*
			 Be loose and pretend we reached an attribute
			 end tag before this.
			 */
			[self parser:parser 
		   didEndElement:elementName 
			namespaceURI:namespaceURI 
		   qualifiedName:qName];
		}
		/*
		 Continuing like the last element was the managed object.
		 */
		self.lastType = [NSManagedObject class];
	}
	if([self.lastType isEqual:[NSManagedObject class]]) {
		NSManagedObject * object = [self.objectStack lastObject];
		NSDictionary *attributes = [[object entity]attributesByName];
		NSDictionary *relationships = [[object entity]relationshipsByName];
		if([attributes objectForKey:elementName]) {
			[self.attributeStack addObject:[attributes objectForKey:elementName]];
			self.lastType = [NSAttributeDescription class];
			return;
		}else if([relationships objectForKey:elementName]) {
			[self.relationshipStack addObject:[relationships objectForKey:elementName]];
			self.lastType = [NSRelationshipDescription class];
		}else {
			self.lastType = NULL;
			return;
		}
	}
	NSDictionary * entities = [self.model entitiesByName];
	elementName = capitalize(elementName);
	if([entities objectForKey:elementName] &&
		[attributeDict objectForKey:@"id"]) {
		NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:elementName 
																inManagedObjectContext:self.context];
		[object performSelector:@selector(fetch)];
		[object setValue:[NSDate date] forKey : @"modifiedDate"];
		[self.objectStack addObject : object];
		self.lastType = [NSManagedObject class];
	}
}

-(void)  parser : (NSXMLParser *) parser 
  didEndElement : (NSString *) elementName 
   namespaceURI : (NSString *) namespaceURI 
  qualifiedName : (NSString *) qName {
	if([self.lastType isEqual:[NSAttributeDescription class]]) {
		if([self.attributeStack count]) {
			NSAttributeDescription * attribute = [self.attributeStack lastObject];
			if([self.objectStack count]) {
				NSManagedObject* object = [self.objectStack lastObject];
				Class class = NSClassFromString([attribute attributeValueClassName]);
/* Useless warnings aren't fun, let's make sure we don't emit one even if assertions are disabled */
#ifndef NS_BLOCK_ASSERTIONS
				NSString * message = [NSString stringWithFormat:@"Empty XML tag for elementName: %@", [attribute name]];
#endif
				NSAssert([self.foundCharacters length] > 0 || [attribute isOptional] == 0,
						 message);
				if([class isEqual:[NSNumber class]]) {
					[object setValue:[numberFormatter numberFromString:foundCharacters] forKey:[attribute name]];
				}else if([class isEqual:[NSDate class]]) {
					[object setValue:[dateFormatter dateFromString:foundCharacters] forKey:[attribute name]];
				}else{
					[object setValue:[NSString stringWithString:foundCharacters] forKey:[attribute name]];
				}
				[foundCharacters setString:@""];
			}
			[self.attributeStack removeLastObject];
		}
		self.lastType = NULL;
	}else if(self.lastType != NULL) {
		NSManagedObject* object = nil;
		if([self.objectStack count] && 
		   [[[[self.objectStack lastObject] entity]name] isEqual:capitalize(elementName)]) {
			object = [self.objectStack lastObject];
			[self.objectStack removeLastObject];
		}
		if([self.relationshipStack count]) {
			NSRelationshipDescription * relationship = [self.relationshipStack lastObject];
			if(object && [self.objectStack count]) {
				NSManagedObject * parent = [self.objectStack lastObject];
				NSDictionary * entities = [self.model entitiesByName];
				NSEntityDescription * entity = [entities valueForKey:[[parent entity]name]];
				relationship = [[entity relationshipsByName] valueForKey:[relationship name]];			
				setRelationship(parent, object, relationship);
			}
			if([[relationship name] isEqual:elementName]) {
				[self.relationshipStack removeLastObject];
				self.lastType = NULL;
			}else {
				self.lastType = [NSRelationshipDescription class];
			}
		}
	}
	if(!self.lastType) {
		self.lastType = [NSManagedObject class];
	}
	if(![self.objectStack count]) {
		[context save : &error];
		if(error) {
			[parser abortParsing];
			[self.context rollback];
		}
		self.lastType = NULL;
	}
}
	
-(void) parserDidEndDocument : (NSXMLParser*) parser {
	/*
	 Clean up in case some silly person fed us bad XML and we have objects left in stack.
	 */
	
	while([self.objectStack count]) {
		[self.objectStack removeLastObject];
	}
	while([self.attributeStack count]) {
		[self.attributeStack removeLastObject];
	}
	while([self.relationshipStack count]) {
		[self.relationshipStack removeLastObject];
	}	
}

-(void)  parser : (NSXMLParser *)parser 
foundCharacters : (NSString *) string {
	if([self.lastType isEqual:[NSAttributeDescription class]]) 
		[foundCharacters appendString:string];
}

-(void) dealloc {
	self.dateFormatter = nil;
	self.numberFormatter = nil;
	self.objectStack = nil;
	self.relationshipStack = nil;
	self.attributeStack = nil;
	self.foundCharacters = nil;
	[super dealloc];
}

@end
