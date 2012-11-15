//
//  SFUtilities.m
//  Nitra
//
//  Created by Sergey Filippov on 21/10/12.
//  Copyright (c) 2012 Bowyer. All rights reserved.
//

#import "SFUtilities.h"

@implementation SFUtilities


+ (float)fahrenheitFromCelsius:(float)celsius {
	
	// convertion formula: °C  x  9/5 + 32 = °F
	// source: http://www.manuelsweb.com/temp.htm
	
	return celsius * 9.0 / 5.0 + 32.0;
}


+ (float)celsiusFromFahrenheit:(float)fahrenheit {
	
	// convertion formula: (°F  -  32)  x  5/9 = °C
	// source: http://www.manuelsweb.com/temp.htm
	
	return (fahrenheit - 32.0) * 5.0 / 9.0;
}


@end
