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
}

-(instancetype)initWithFile:(NSString *)inFilepathString;

//get aspect ratio of video signal in canvas
-(float) VideoFrameAspectRatioDetection;

@end
