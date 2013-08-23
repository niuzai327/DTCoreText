//
//  DTCSSStylesheet.m
//  DTCoreText
//
//  Created by Oliver Drobnik on 9/5/11.
//  Copyright (c) 2011 Drobnik.com. All rights reserved.
//

#import "DTCSSStylesheet.h"
#import "DTCSSListStyle.h"

#import "DTHTMLElement.h"
#import "NSScanner+HTML.h"
#import "NSString+CSS.h"
#import "NSString+HTML.h"


// external symbols generated via custom build rule and xxd
extern unsigned char default_css[];
extern unsigned int default_css_len;


@implementation DTCSSStylesheet
{
	NSMutableDictionary *_styles;
}

#pragma mark Creating Stylesheets

+ (DTCSSStylesheet *)defaultStyleSheet
{
	static DTCSSStylesheet *defaultDTCSSStylesheet = nil;
	if (defaultDTCSSStylesheet)
	{
		return defaultDTCSSStylesheet;
	}
	
	@synchronized(self)
	{
		if (!defaultDTCSSStylesheet)
		{
			// get the data from the external symbol
			NSData *data = [NSData dataWithBytes:default_css length:default_css_len];
			NSString *cssString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			
			defaultDTCSSStylesheet = [[DTCSSStylesheet alloc] initWithStyleBlock:cssString];
		}
	}
	return defaultDTCSSStylesheet;
}

- (id)initWithStyleBlock:(NSString *)css
{
	self = [super init];
	
	if (self)
	{
		_styles	= [[NSMutableDictionary alloc] init];
		
		[self parseStyleBlock:css];
	}
	
	return self;
}

- (id)initWithStylesheet:(DTCSSStylesheet *)stylesheet
{
	self = [super init];
	
	if (self)
	{
		_styles	= [[NSMutableDictionary alloc] init];
		
		[self mergeStylesheet:stylesheet];
	}
	
	return self;
}

- (NSString *)description
{
	return [_styles description];
}

#pragma mark Working with Style Blocks

- (void)_uncompressShorthands:(NSMutableDictionary *)styles
{
	// list-style shorthand
	NSString *shortHand = [[styles objectForKey:@"list-style"] lowercaseString];
	
	if (shortHand)
	{
		[styles removeObjectForKey:@"list-style"];
		
		if ([shortHand isEqualToString:@"inherit"])
		{
			[styles setObject:@"inherit" forKey:@"list-style-type"];
			[styles setObject:@"inherit" forKey:@"list-style-position"];
			return;
		}
		
		NSArray *components = [shortHand componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		BOOL typeWasSet = NO;
		BOOL positionWasSet = NO;
		
		DTCSSListStyleType listStyleType = DTCSSListStyleTypeNone;
		DTCSSListStylePosition listStylePosition = DTCSSListStylePositionInherit;
		
		for (NSString *oneComponent in components)
		{
			if ([oneComponent hasPrefix:@"url"])
			{
				// list-style-image
				NSScanner *scanner = [NSScanner scannerWithString:oneComponent];
				
				if ([scanner scanCSSURL:NULL])
				{
					[styles setObject:oneComponent forKey:@"list-style-image"];
					
					continue;
				}
			}
			
			if (!typeWasSet)
			{
				// check if valid type
				listStyleType = [DTCSSListStyle listStyleTypeFromString:oneComponent];
				
				if (listStyleType != DTCSSListStyleTypeInvalid)
				{
					[styles setObject:oneComponent forKey:@"list-style-type"];
					
					typeWasSet = YES;
					continue;
				}
			}
			
			if (!positionWasSet)
			{
				// check if valid position
				listStylePosition = [DTCSSListStyle listStylePositionFromString:oneComponent];
				
				if (listStylePosition != DTCSSListStylePositionInvalid)
				{
					[styles setObject:oneComponent forKey:@"list-style-position"];
					
					positionWasSet = YES;
					continue;
				}
			}
		}
	}
	
	// font shorthand, see http://www.w3.org/TR/CSS21/fonts.html#font-shorthand
	shortHand = [styles objectForKey:@"font"];
	
	if (shortHand)
	{
		NSString *fontStyle = @"normal";
		NSArray *validFontStyles = [NSArray arrayWithObjects:@"italic", @"oblique", nil];
		
		NSString *fontVariant = @"normal";
		NSArray *validFontVariants = [NSArray arrayWithObjects:@"small-caps", nil];
		BOOL fontVariantSet = NO;
		
		NSString *fontWeight = @"normal";
		NSArray *validFontWeights = [NSArray arrayWithObjects:@"bold", @"bolder", @"lighter", @"100", @"200", @"300", @"400", @"500", @"600", @"700", @"800", @"900", nil];
		BOOL fontWeightSet = NO;
		
		NSString *fontSize = @"normal";
		NSArray *validFontSizes = [NSArray arrayWithObjects:@"xx-small", @"x-small", @"small", @"medium", @"large", @"x-large", @"xx-large", @"larger", @"smaller", nil];
		BOOL fontSizeSet = NO;
		
		NSArray *suffixesToIgnore = [NSArray arrayWithObjects:@"caption", @"icon", @"menu", @"message-box", @"small-caption", @"status-bar", @"inherit", nil];
		
		NSString *lineHeight = @"normal";
		
		NSMutableString *fontFamily = [NSMutableString string];
		
		NSArray *components = [shortHand componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		for (NSString *oneComponent in components)
		{
			// try font size keywords
			if ([validFontSizes containsObject:oneComponent])
			{
				fontSize = oneComponent;
				fontSizeSet = YES;
				
				continue;
			}
			
			NSInteger slashIndex = [oneComponent rangeOfString:@"/"].location;
			
			if (slashIndex != NSNotFound)
			{
				// font-size / line-height
				
				fontSize = [oneComponent substringToIndex:slashIndex-1];
				fontSizeSet = YES;
				
				lineHeight = [oneComponent substringFromIndex:slashIndex+1];
				
				continue;
			}
			else
			{
				// length
				if ([oneComponent hasSuffix:@"%"] || [oneComponent hasSuffix:@"em"] || [oneComponent hasSuffix:@"px"] || [oneComponent hasSuffix:@"pt"])
				{
					fontSize = oneComponent;
					fontSizeSet = YES;
					
					continue;
				}
			}
			
			if (fontSizeSet)
			{
				if ([suffixesToIgnore containsObject:oneComponent])
				{
					break;
				}
				
				// assume that this is part of font family
				if ([fontFamily length])
				{
					[fontFamily appendString:@" "];
				}
				
				[fontFamily appendString:oneComponent];
			}
			else
			{
				if (!fontWeightSet && [validFontStyles containsObject:oneComponent])
				{
					fontStyle = oneComponent;
				}
				else if (!fontVariantSet && [validFontVariants containsObject:oneComponent])
				{
					fontVariant = oneComponent;
					fontVariantSet = YES;
				}
				else if (!fontWeightSet && [validFontWeights containsObject:oneComponent])
				{
					fontWeight = oneComponent;
					fontWeightSet = YES;
				}
			}
		}
		
		[styles removeObjectForKey:@"font"];
		
		// size and family are mandatory, without them this is invalid
		if ([fontSize length] && [fontFamily length])
		{
			[styles setObject:fontStyle forKey:@"font-style"];
			[styles setObject:fontWeight forKey:@"font-weight"];
			[styles setObject:fontVariant forKey:@"font-variant"];
			[styles setObject:fontSize forKey:@"font-size"];
			[styles setObject:lineHeight forKey:@"line-height"];
			[styles setObject:fontFamily forKey:@"font-family"];
		}
	}
	
	shortHand = [styles objectForKey:@"margin"];
	
	if (shortHand)
	{
		NSArray *parts = [shortHand componentsSeparatedByString:@" "];
		
		NSString *topMargin;
		NSString *rightMargin;
		NSString *bottomMargin;
		NSString *leftMargin;
		
		if ([parts count] == 4)
		{
			topMargin = [parts objectAtIndex:0];
			rightMargin = [parts objectAtIndex:1];
			bottomMargin = [parts objectAtIndex:2];
			leftMargin = [parts objectAtIndex:3];
		}
		else if ([parts count] == 3)
		{
			topMargin = [parts objectAtIndex:0];
			rightMargin = [parts objectAtIndex:1];
			bottomMargin = [parts objectAtIndex:2];
			leftMargin = [parts objectAtIndex:1];
		}
		else if ([parts count] == 2)
		{
			topMargin = [parts objectAtIndex:0];
			rightMargin = [parts objectAtIndex:1];
			bottomMargin = [parts objectAtIndex:0];
			leftMargin = [parts objectAtIndex:1];
		}
		else
		{
			NSString *onlyValue = [parts objectAtIndex:0];
			
			topMargin = onlyValue;
			rightMargin = onlyValue;
			bottomMargin = onlyValue;
			leftMargin = onlyValue;
		}
		
		// only apply the ones where there is no previous direct setting
		
		if (![styles objectForKey:@"margin-top"])
		{
			[styles setObject:topMargin forKey:@"margin-top"];
		}
		
		if (![styles objectForKey:@"margin-right"])
		{
			[styles setObject:rightMargin forKey:@"margin-right"];
		}
		
		if (![styles objectForKey:@"margin-bottom"])
		{
			[styles setObject:bottomMargin forKey:@"margin-bottom"];
		}
		
		if (![styles objectForKey:@"margin-left"])
		{
			[styles setObject:leftMargin forKey:@"margin-left"];
		}
		
		// remove the shorthand
		[styles removeObjectForKey:@"margin"];
	}
	
	shortHand = [styles objectForKey:@"padding"];
	
	if (shortHand)
	{
		NSArray *parts = [shortHand componentsSeparatedByString:@" "];
		
		NSString *topPadding;
		NSString *rightPadding;
		NSString *bottomPadding;
		NSString *leftPadding;
		
		if ([parts count] == 4)
		{
			topPadding = [parts objectAtIndex:0];
			rightPadding = [parts objectAtIndex:1];
			bottomPadding = [parts objectAtIndex:2];
			leftPadding = [parts objectAtIndex:3];
		}
		else if ([parts count] == 3)
		{
			topPadding = [parts objectAtIndex:0];
			rightPadding = [parts objectAtIndex:1];
			bottomPadding = [parts objectAtIndex:2];
			leftPadding = [parts objectAtIndex:1];
		}
		else if ([parts count] == 2)
		{
			topPadding = [parts objectAtIndex:0];
			rightPadding = [parts objectAtIndex:1];
			bottomPadding = [parts objectAtIndex:0];
			leftPadding = [parts objectAtIndex:1];
		}
		else
		{
			NSString *onlyValue = [parts objectAtIndex:0];
			
			topPadding = onlyValue;
			rightPadding = onlyValue;
			bottomPadding = onlyValue;
			leftPadding = onlyValue;
		}
		
		// only apply the ones where there is no previous direct setting
		
		if (![styles objectForKey:@"padding-top"])
		{
			[styles setObject:topPadding forKey:@"padding-top"];
		}
		
		if (![styles objectForKey:@"padding-right"])
		{
			[styles setObject:rightPadding forKey:@"padding-right"];
		}
		
		if (![styles objectForKey:@"padding-bottom"])
		{
			[styles setObject:bottomPadding forKey:@"padding-bottom"];
		}
		
		if (![styles objectForKey:@"padding-left"])
		{
			[styles setObject:leftPadding forKey:@"padding-left"];
		}
		
		// remove the shorthand
		[styles removeObjectForKey:@"padding"];
	}
}

- (void)_addStyleRule:(NSString *)rule withSelector:(NSString*)selectors
{
	NSArray *split = [selectors componentsSeparatedByString:@","];
	
	for (NSString *selector in split)
	{
		NSString *cleanSelector = [selector stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		NSMutableDictionary *ruleDictionary = [[rule dictionaryOfCSSStyles] mutableCopy];
		
		// remove !important, we're ignoring these
		for (NSString *oneKey in [ruleDictionary allKeys])
		{
			id value = [ruleDictionary objectForKey:oneKey];
			if ([value isKindOfClass:[NSString class]])
			{
				NSRange rangeOfImportant = [value rangeOfString:@"!important" options:NSCaseInsensitiveSearch];
				
				if (rangeOfImportant.location != NSNotFound)
				{
					value = [value stringByReplacingCharactersInRange:rangeOfImportant withString:@""];
					value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					
					[ruleDictionary setObject:value forKey:oneKey];
				}
				
			} else if ([value isKindOfClass:[NSArray class]]) {
				
				NSMutableArray *newVal;
				
				for (NSUInteger i = 0; i < [value count]; ++i)
				{
					NSString *s = [value objectAtIndex:i];
					
					NSRange rangeOfImportant = [s rangeOfString:@"!important" options:NSCaseInsensitiveSearch];
					
					if (rangeOfImportant.location != NSNotFound)
					{
						s = [s stringByReplacingCharactersInRange:rangeOfImportant withString:@""];
						s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
						
						if (!newVal) {
							
							if ([value isKindOfClass:[NSMutableArray class]]) {
								newVal = value;
							} else {
								newVal = [value mutableCopy];
							}
						}
						
						newVal[i] = s;
					}
				}
				
				if (newVal) {
					
					[ruleDictionary setObject:newVal forKey:oneKey];
				}
			}
		}
		
		// need to uncompress because otherwise we might get shorthands and non-shorthands together
		[self _uncompressShorthands:ruleDictionary];
		
		// check if there is a pseudo selector
		NSRange colonRange = [cleanSelector rangeOfString:@":"];
		NSString *pseudoSelector = nil;
		
		if (colonRange.length==1)
		{
			pseudoSelector = [cleanSelector substringFromIndex:colonRange.location+1];
			cleanSelector = [cleanSelector substringToIndex:colonRange.location];
			
			// prefix all rules with the pseudo-selector
			for (NSString *oneRuleKey in [ruleDictionary allKeys])
			{
				id value = [ruleDictionary objectForKey:oneRuleKey];
				
				// prefix key with the pseudo selector
				NSString *prefixedKey = [NSString stringWithFormat:@"%@:%@", pseudoSelector, oneRuleKey];
				[ruleDictionary setObject:value forKey:prefixedKey];
				[ruleDictionary removeObjectForKey:oneRuleKey];
			}
		}
		
		NSDictionary *existingRulesForSelector = [_styles objectForKey:cleanSelector];
		
		if (existingRulesForSelector)
		{
			// substitute new rules over old ones
			NSMutableDictionary *tmpDict = [existingRulesForSelector mutableCopy];
			
			// append new rules
			[tmpDict addEntriesFromDictionary:ruleDictionary];
			
			// save it
			[_styles setObject:tmpDict forKey:cleanSelector];
		}
		else
		{
			[_styles setObject:ruleDictionary forKey:cleanSelector];
		}
	}
}


- (void)parseStyleBlock:(NSString*)css
{
	NSUInteger braceLevel = 0, braceMarker = 0;
	
	NSString* selector;
	
	NSUInteger length = [css length];
	
	for (NSUInteger i = 0; i < length; i++)
	{
		unichar c = [css characterAtIndex:i];
		
		if (c == '/')
		{
			i++;
			
			if (i < length)
			{
				c = [css characterAtIndex:i];
				
				if (c == '*')
				{
					// skip comment until closing /
					
					for (; i < length; i++)
					{
						if ([css characterAtIndex:i] == '/')
						{
							break;
						}
					}
					
					if (i < length)
					{
						braceMarker = i+1;
						continue;
					}
					else
					{
						// end of string
						return;
					}
				}
				else
				{
					// not a comment
					i--;
				}
			}
		}
		
		// An opening brace! It could be the start of a new rule, or it could be a nested brace.
		if (c == '{')
		{
			// If we start a new rule...
			
			if (braceLevel == 0)
			{
				// Grab the selector and clean up extraneous spaces (we'll process it in a moment)
				selector = [css substringWithRange:NSMakeRange(braceMarker, i-braceMarker)];
				NSArray *selectorParts = [selector componentsSeparatedByString:@" "];
				NSMutableArray *cleanSelectorParts = [NSMutableArray array];
				for (NSString *partialSelector in selectorParts)
				{
					if (partialSelector.length)
					{
						[cleanSelectorParts addObject:partialSelector];
					}
				}
				selector = [cleanSelectorParts componentsJoinedByString:@" "];
				
				// And mark our position so we can grab the rule's CSS when it is closed
				braceMarker = i + 1;
			}
			
			// Increase the brace level.
			braceLevel += 1;
		}
		
		// A closing brace!
		else if (c == '}')
		{
			// If we finished a rule...
			if (braceLevel == 1)
			{
				NSString *rule = [css substringWithRange:NSMakeRange(braceMarker, i-braceMarker)];
				
				[self _addStyleRule:rule withSelector: selector];
				
				braceMarker = i + 1;
			}
			
			braceLevel = MAX(braceLevel-1, 0ul);
		}
	}
}


- (void)mergeStylesheet:(DTCSSStylesheet *)stylesheet
{
	NSArray *otherStylesheetStyleKeys = [[stylesheet styles] allKeys];
	
	for (NSString *oneKey in otherStylesheetStyleKeys)
	{
		NSDictionary *existingStyles = [_styles objectForKey:oneKey];
		NSDictionary *stylesToMerge = [[stylesheet styles] objectForKey:oneKey];
		if (existingStyles)
		{
			NSMutableDictionary *mutableStyles = [existingStyles mutableCopy];
			
			for (NSString *oneStyleKey in stylesToMerge)
			{
				NSString *mergingStyleString = [stylesToMerge objectForKey:oneStyleKey];
				
				[mutableStyles setObject:mergingStyleString forKey:oneStyleKey];
			}
			
			[_styles setObject:mutableStyles forKey:oneKey];
		}
		else
		{
			// nothing to worry
			[_styles setObject:stylesToMerge forKey:oneKey];
		}
	}
}

#pragma mark Accessing Style Information

- (NSDictionary *)mergedStyleDictionaryForElement:(DTHTMLElement *)element matchedSelectors:(NSSet **)matchedSelectors
{
	// We are going to combine all the relevant styles for this tag.
	// (Note that when styles are applied, the later styles take precedence,
	//  so the order in which we grab them matters!)
	
	NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
	
	// Get based on element
	NSDictionary *byTagName = [self.styles objectForKey:element.name];
	
	if (byTagName)
	{
		[tmpDict addEntriesFromDictionary:byTagName];
	}
	
    // Get based on class(es)
	NSString *classString = [element.attributes objectForKey:@"class"];
	NSArray *classes = [classString componentsSeparatedByString:@" "];
	
	// Find all classes by walking up the heirarchy and compute possible selector combinations
	NSArray *ancestorSelectorArrays = [self findAncestorSelectorArraysForElement:element];
	NSArray *cascadedSelectors = [self computeCascadedSelectorsWithAncestorSelectors:ancestorSelectorArrays];
    
	NSMutableSet *tmpMatchedSelectors;
	
	if (matchedSelectors)
	{
		tmpMatchedSelectors = [[NSMutableSet alloc] init];
	}
	
	for (NSString *class in classes)
	{
		NSString *classAndTagRule = [NSString stringWithFormat:@"%@.%@", element.name, class];
		NSDictionary *byClassAndName = [_styles objectForKey:classAndTagRule];
		
		if (byClassAndName)
		{
			[tmpDict addEntriesFromDictionary:byClassAndName];
			[tmpMatchedSelectors addObject:classAndTagRule];
		}
	}
	
	//This covers the "by class" only case (e.g. .foo)
	for (NSString *cascadedSelector in cascadedSelectors)
	{
		NSDictionary *byCascadedClassName = [_styles objectForKey:cascadedSelector];
		if (byCascadedClassName)
		{
			[tmpDict addEntriesFromDictionary:byCascadedClassName];
			[tmpMatchedSelectors addObject:cascadedSelector];
		}
	}
	
	// Get based on id
	NSString *idRule = [NSString stringWithFormat:@"#%@", [element.attributes objectForKey:@"id"]];
	NSDictionary *byID = [_styles objectForKey:idRule];
	
	if (byID)
	{
		[tmpDict addEntriesFromDictionary:byID];
		[tmpMatchedSelectors addObject:idRule];
	}
	
	// Get tag's local style attribute
	NSString *styleString = [element.attributes objectForKey:@"style"];
	
	if ([styleString length])
	{
		NSMutableDictionary *localStyles = [[styleString dictionaryOfCSSStyles] mutableCopy];
		
		// need to uncompress because otherwise we might get shorthands and non-shorthands together
		[self _uncompressShorthands:localStyles];
		
		[tmpDict addEntriesFromDictionary:localStyles];
	}
	
	if ([tmpDict count])
	{
		if (matchedSelectors && [tmpMatchedSelectors count])
		{
			*matchedSelectors = [tmpMatchedSelectors copy];
		}
		
		return tmpDict;
	}
	else
	{
		return nil;
	}
}

- (NSDictionary *)styles
{
	return _styles;
}

- (NSSet *)findPartialSelectorElementNamesForElement:(DTHTMLElement *)element
{
    // NSSet has quick lookup time so it'll be our return type
    NSMutableSet *possibleElementNames = [NSMutableSet set];
    
    // Sort the array of defined selectors so we can binary search
    DTHTMLElement *currentElement = element;
    while (currentElement != nil)
    {
        if (![possibleElementNames containsObject:currentElement.name] && ![currentElement.name isEqualToString:@"html"]) {
            for (NSString *selector in _styles.allKeys)
            {
                if ([selector rangeOfString:currentElement.name].location != NSNotFound)
                {
                    [possibleElementNames addObject:currentElement.name];
                    break;
                }
            }
        }
        
        currentElement = currentElement.parentElement;
    }
    return possibleElementNames;
}

- (NSArray *)findAncestorSelectorArraysForElement:(DTHTMLElement *)element
{
    NSSet *possibleElementNames = [self findPartialSelectorElementNamesForElement:element];
	
    // Walk up the heirarchy looking for parents with class attributes then compute cascades
	NSMutableArray *ancestorSelectorArrays = [NSMutableArray array];
	
	DTHTMLElement *currentElement = element;
	while (currentElement != nil)
	{
		NSString *currentElementClassString = [currentElement.attributes objectForKey:@"class"];
		NSArray *currentElementClasses = [currentElementClassString componentsSeparatedByString:@" "];
		NSString *ancestorId = [currentElement.attributes objectForKey:@"id"];
		
		NSMutableArray *selectors = [NSMutableArray array];
		
		if (ancestorId && ancestorId.length)
		{
			[selectors insertObject:[NSString stringWithFormat:@"#%@", ancestorId] atIndex:0];
		}
		
		for (NSString *class in currentElementClasses)
		{
			if (class.length)
			{
				[selectors insertObject:[NSString stringWithFormat:@".%@", class] atIndex:0];
			}
		}
		
        // Optimization: only add element names that are in the known selectors to our ancestor array
        if ([possibleElementNames containsObject:currentElement.name]) {
            // We add the element's tag name so the computed cascades include things like "div .foo" and "div #bar"
            [selectors addObject:currentElement.name];
        }
		
		if (selectors.count)
		{
			[ancestorSelectorArrays insertObject:selectors atIndex:0];
		}
		
		currentElement = currentElement.parentElement;
	}
	
	return ancestorSelectorArrays;
}

- (NSArray *)computeCascadedSelectorsWithAncestorSelectors:(NSArray *)ancestorSelectors
{
	NSMutableArray *cascadedSelectors = [NSMutableArray array];
	
	if (ancestorSelectors.count)
	{
		NSArray *outerMostAncestorSelectors = ancestorSelectors[0];
		
		// Find selector combinations for all ancestors that are leaves of the ancesor the current class array belongs to
		NSArray *remainingAncessorSelectors = [ancestorSelectors subarrayWithRange:NSMakeRange(1, ancestorSelectors.count - 1)];
		NSArray *descendantSelectors = [self computeCascadedSelectorsWithAncestorSelectors:remainingAncessorSelectors];
		// Deduplicate computed selectors from recursive calls
		descendantSelectors = [[NSOrderedSet orderedSetWithArray:descendantSelectors] array];
		
		for (NSString *selector in outerMostAncestorSelectors)
		{
			// Although we include tag names (in findAncestorSelectorArraysForElement:) so we can compute their cascades,
			// we already handle them elsewhere differently from more complex selectors (e.g. id, class, and combinations of all 3)
			// so don't add them to our list of cascadedSelectors
			if ([selector hasPrefix:@"."] || [selector hasPrefix:@"#"])
			{
				[cascadedSelectors addObject:selector];
			}
		}
		
		for (NSString *selector in outerMostAncestorSelectors)
		{
			for (NSString *descendantSelector in descendantSelectors)
			{
				// Profiled this as it's the slowest part of this method.
				// Using NSMutableString is significantly faster than [NSArray componentsJoinedByString:] or [NSString stringWithFormat:]
				NSMutableString *combinedSelector = [NSMutableString stringWithString:selector];
				[combinedSelector appendString:@" "];
				[combinedSelector appendString:descendantSelector];
				[cascadedSelectors addObject:combinedSelector];
			}
		}
		
		for (NSString *descendantSelector in descendantSelectors)
		{
			[cascadedSelectors addObject:descendantSelector];
		}
	}
	
	return cascadedSelectors;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	DTCSSStylesheet *newStylesheet = [[DTCSSStylesheet allocWithZone:zone] initWithStylesheet:self];
	
	return newStylesheet;
}

@end
