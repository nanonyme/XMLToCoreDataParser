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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface XMLToCoreDataConverter : NSObject<NSXMLParserDelegate> {
	@private
	NSManagedObjectContext * context;
	NSManagedObjectModel* model;
	NSMutableArray * objectStack;
	NSMutableArray * attributeStack;
	NSMutableArray * relationshipStack;
	Class lastType;
	NSNumberFormatter * numberFormatter;
	NSDateFormatter * dateFormatter;
	NSMutableString * foundCharacters;
	NSError* error;
}


	
-(BOOL) parseClassData :(NSData*) data 
		   intoContext :(NSManagedObjectContext*)_context
					   :(NSError**) _error;
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict;

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;
@end

@interface XMLToCoreDataConverter ()
@property (nonatomic, retain) NSManagedObjectContext* context;
@property (nonatomic, retain) NSMutableArray* objectStack;
@property (nonatomic, retain) NSMutableArray* relationshipStack;
@property (nonatomic, retain) NSMutableArray* attributeStack;
@property (nonatomic, assign) Class lastType;
@property (nonatomic, retain) NSMutableString* foundCharacters;
@property (nonatomic, retain) NSNumberFormatter* numberFormatter;
@property (nonatomic, retain) NSDateFormatter* dateFormatter;
@property (nonatomic, retain) NSManagedObjectModel* model;
@property (nonatomic, copy) NSError* error;
@end
