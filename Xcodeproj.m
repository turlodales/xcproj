//
//  Xcodeproj.m
//  xcodeproj
//
//  Created by Cédric Luthi on 07.02.11.
//  Copyright Cédric Luthi 2011. All rights reserved.
//

#import "Xcodeproj.h"

@implementation Xcodeproj

static Class PBXProject_ = Nil;

+ (void) initialize
{
	if (self != [Xcodeproj class])
		return;
	
	PBXProject_ = NSClassFromString(@"PBXProject");
}

- (void) application:(DDCliApplication *)app willParseOptions:(DDGetoptLongParser *)optionsParser
{
	DDGetoptOption optionTable[] = 
	{
		// Long       Short  Argument options
		{@"project",  'p',   DDGetoptRequiredArgument},
		{@"target",   't',   DDGetoptRequiredArgument},
		{@"help",     'h',   DDGetoptNoArgument},
		{nil,          0,    0},
	};
	[optionsParser addOptionsFromTable:optionTable];
}

- (void) setProject:(NSString *)projectName
{
	if (![PBXProject_ isProjectWrapperExtension:[projectName pathExtension]])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project name %@ does not have a valid extension.", projectName] exitCode:EX_USAGE];
	
	NSString *projectPath = projectName;
	if (![projectName isAbsolutePath])
		projectPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:projectName];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath])
		@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not exist in this directory.", projectName] exitCode:EX_NOINPUT];
	
	[project release];
	project = [[PBXProject_ projectWithFile:projectPath] retain];
}

- (void) setTarget:(NSString *)aTargetName
{
	if (targetName == aTargetName)
		return;
	
	[targetName release];
	targetName = [aTargetName retain];
}

- (int) application:(DDCliApplication *)app runWithArguments:(NSArray *)arguments
{
	if (help)
	{
		ddprintf(@"Usage: %@ ...\n", app);
		return EX_OK;
	}
	
	NSString *currentDirectoryPath = [[NSFileManager defaultManager] currentDirectoryPath];
	
	if (!project)
	{
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:currentDirectoryPath error:NULL])
		{
			if ([PBXProject_ isProjectWrapperExtension:[fileName pathExtension]])
			{
				if (!project)
					[self setProject:fileName];
				else
				{
					ddfprintf(stderr, @"%@: The directory %@ contains more than one Xcode project. You will need to specify the project with the --project option.\n", app, currentDirectoryPath);
					return EX_USAGE;
				}
			}
		}
	}
	
	if (!project)
	{
		ddfprintf(stderr, @"%@: The directory %@ does not contain an Xcode project.\n", app, currentDirectoryPath);
		return EX_USAGE;
	}
	
	if (targetName)
	{
		target = [[project targetNamed:targetName] retain];
		if (!target)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The target %@ does not exist in this project.", targetName] exitCode:EX_DATAERR];
	}
	else
	{
		target = [[project activeTarget] retain];
		if (!target)
			@throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"The project %@ does not contain any target.", [project name]] exitCode:EX_DATAERR];
	}
	
	[self printBuildPhases];
	
	return EX_OK;
}

- (void) printBuildPhases
{
	for (NSString *buildPhase in [NSArray arrayWithObjects:@"Frameworks", @"Link", @"SourceCode", @"Resource", @"Header", nil])
	{
		ddprintf(@"%@\n", buildPhase);
		SEL buildPhaseSelector = NSSelectorFromString([NSString stringWithFormat:@"default%@BuildPhase", buildPhase]);
		id<PBXBuildPhase> buildPhase = [target performSelector:buildPhaseSelector];
		for (id<PBXBuildFile> buildFile in [buildPhase buildFiles])
		{
			ddprintf(@"\t%@\n", [buildFile absolutePath]);
		}
		ddprintf(@"\n");
	}
}

@end
