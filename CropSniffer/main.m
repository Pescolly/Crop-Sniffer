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
#import "MVFAssetHandler.h"

#define VIDEOQC @"VIDEOQC"
#define AUDIOQC @"AUDIOQC"
#define VIDEOHEADERQC @"VIDEOHEADERQC"
#define AUDIOHANDLEQC @"AUDIOHANDLEQC"
#define AUDIOHANDLELENGTH @"AUDIOHANDLELENGTH"
#define VIDEODROPOUTQC @"VIDEODROPOUTQC"
#define SPECFRAMEWIDTH @"SPECFRAMEWIDTH"
#define SPECFRAMEHEIGHT @"SPECFRAMEHEIGHT"
#define SPECCOLORMATRIX @"SPECCOLORMATRIX"
#define SPECCODEC @"SPECCODEC"
#define SPECPIXELFORMAT @"SPECPIXELFORMAT"
#define VIDEOCROPCHECK @"VIDEOCROPCHECK"
#define VIDEOASPECTRATIO @"VIDEOASPECTRATIO"

#define TEMPLATE_TRUE @"TRUE"
#define TEMPLATE_FALSE @"FALSE"

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
            fprintf(stdout, "Add a file to check and a minimum silence length in seconds\n");
            exit(1);
        }
        NSString *incomingFile = args[1];      
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:incomingFile])
        {
            fprintf(stdout, "File does not exist: %s\n", [incomingFile UTF8String]);
            exit(1);
        }
        
         MVF_AssetHandler *handler = [[MVF_AssetHandler alloc] initWithFile:incomingFile];
         [handler VideoFrameAspectRatioDetection];
         
    }
    return 0;
}


