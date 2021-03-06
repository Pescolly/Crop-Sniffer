//
//  main.m
//  Buhtton
//
//  Created by Armen Karamian on 12/4/15.
//  Copyright © 2015 Armen Karamian. All rights reserved.
//
//  automated QC applicaiton
//
//  ./application infile.mov templateFile
//
//  create a template dictinary from the template file and uses that to determine what type of qc check to perform


#import <Foundation/Foundation.h>
#import "AspectRatioDetector.h"

#define kAR_16X9    @1.78
#define kAR_4X3     @1.33
#define kAR_235     @2.35
#define kAR_185     @1.85



@import AVFoundation;

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        
        //fetch args
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        if ([args count] < 2)
        {
            fprintf(stdout, "Add a file to check...\n");
            exit(1);
        }
        //get first argument as file name
        NSString *incomingFile = args[1];
        //append any remaining parts seperated by white space
        for (int i = 2; i < [args count]; i++)
        {
            incomingFile = [[incomingFile stringByAppendingString:@" "] stringByAppendingString:args[i]];
        }
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:incomingFile])
        {
            fprintf(stdout, "File does not exist: %s\n", [incomingFile UTF8String]);
            exit(1);
        }
        
        AspectRatioDetector *handler = [[AspectRatioDetector alloc] initWithFile:incomingFile];
        [handler VideoFrameAspectRatioDetection];
         
    }
    return 0;
}


