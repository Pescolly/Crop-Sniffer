//
//  VideoHandler.h
//  Check frame header information
//
//  Created by Armen Karamian on 12/4/15.
//  Copyright © 2015 Armen Karamian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <math.h>
@import AVFoundation;
@import CoreGraphics;



@interface MVF_AssetHandler : NSObject
{
    
    //private properties
@private int frameWidth;
@private int frameHeight;
@private int colorMatrix;
@private NSString *codec;
@private FourCharCode expectedFormat;
@private AVURLAsset *asset;
@private NSMutableDictionary *videoSignal_VerResolutionDictionary;
@private NSMutableDictionary *videoSignal_HorResolutionDictionary;
@private NSMutableDictionary *videoSignal_TopMarginSize;
@private NSMutableDictionary *videoSignal_BottomMarginSize;
@private NSMutableDictionary *videoSignal_LeftMarginSize;
@private NSMutableDictionary *videoSignal_RightMarginSize;
    
}

-(instancetype)initWithFile:(NSString *)inFilepathString;

//get aspect ratio of video signal in canvas
-(float) VideoFrameAspectRatioDetection;

@end
