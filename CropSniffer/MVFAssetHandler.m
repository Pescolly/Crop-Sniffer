#import "MVFAssetHandler.h"

@implementation MVF_AssetHandler

- (instancetype)initWithFile:(NSString *)inFilepathString;
{
    self = [super init];
    if (self)
    {
        //setup asset
        NSURL *mediaURL = [NSURL fileURLWithPath:inFilepathString];
        
        self->asset = [[AVURLAsset alloc] initWithURL:mediaURL options:nil];
        
    }
    return self;
}

-(float) VideoFrameAspectRatioDetection
{
    NSLog(@"Starting aspect ratio calculation");
    CMTime duration = self->asset.duration;
    CMTime qcDuration = CMTimeMake(duration.value/1000, self->asset.duration.timescale);
    
    CMTimeRange range1 = CMTimeRangeMake(kCMTimeZero, qcDuration);
    
    CMTime range2Start = CMTimeMake(duration.value*.1, duration.timescale);
    CMTimeRange range2 = CMTimeRangeMake(range2Start, qcDuration);
    
    CMTime range3Start = CMTimeMake(duration.value*.2, duration.timescale);
    CMTimeRange range3 = CMTimeRangeMake(range3Start, qcDuration);
    
    CMTime range4Start = CMTimeMake(duration.value*.3, duration.timescale);
    CMTimeRange range4 = CMTimeRangeMake(range4Start, qcDuration);
    
    CMTime range5Start = CMTimeMake(duration.value*.4, duration.timescale);
    CMTimeRange range5 = CMTimeRangeMake(range5Start, qcDuration);
    
    CMTime range6Start = CMTimeMake(duration.value*.5, duration.timescale);
    CMTimeRange range6 = CMTimeRangeMake(range6Start, qcDuration);
    
    CMTime range7Start = CMTimeMake(duration.value*.6, duration.timescale);
    CMTimeRange range7 = CMTimeRangeMake(range7Start, qcDuration);
    
    CMTime range8Start = CMTimeMake(duration.value*.7, duration.timescale);
    CMTimeRange range8 = CMTimeRangeMake(range8Start, qcDuration);
    
    CMTime range9Start = CMTimeMake(duration.value*.8, duration.timescale);
    CMTimeRange range9 = CMTimeRangeMake(range9Start, qcDuration);
    
    CMTime range10Start = CMTimeMake(duration.value*.9, duration.timescale);
    CMTimeRange range10 = CMTimeRangeMake(range10Start, qcDuration);
    
    CMTime range11Start = CMTimeMake(duration.value*.99, duration.timescale);
    CMTimeRange range11 = CMTimeRangeMake(range11Start, qcDuration);
    
    CMTimeRange timeRanges[] = {range1, range2, range3, range4, range5, range6, range7, range8, range9, range10, range11};
    
    
    
    //setup dictionaries to store video start/end pixel data
    NSMutableDictionary *videoSignal_VerResolutionDictionary = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_HorResolutionDictionary = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *videoSignal_TopMarginSize = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_BottomMarginSize = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_LeftMarginSize = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_RightMarginSize = [[NSMutableDictionary alloc] init];
    
    CGSize resolution;
    
    int BLACK_THRESHHOLD = 75;
    
    //loop thru time ranges to get sampling of feature.
    for (int range = 0; range < 11; range++)
    {
        //setup asset reader
        NSError *error;
        AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:self->asset error:&error];
        
        //setup asset track
        AVAssetTrack *videoTrack = [[self->asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        
        //setup track output
        NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr16] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        AVAssetReaderTrackOutput *trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
        
        //add output to reader
        [reader addOutput:trackOutput];
        
        reader.timeRange = timeRanges[range];
        //start reading
        [reader startReading];
        
        while(reader.status == AVAssetReaderStatusReading)
        {
            CMSampleBufferRef sampleBuffer = [trackOutput copyNextSampleBuffer];
            
            if(sampleBuffer)
            {
                //setup pixel buffer
                CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                
                //setup image property vars
                resolution = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
                
                //setup source buffer (Cr Y0 Cb Y1)
                size_t pixelBufferSize = CVPixelBufferGetDataSize(pixelBuffer);
                void *pixelBufferBaseAddress = (UInt16 *)CVPixelBufferGetBaseAddress(pixelBuffer);
                UInt16 *pixelBufferPos = pixelBufferBaseAddress;
                pixelBufferPos++;
                
                //setup destination buffer for luma pixels (Y0 Y1 Y2 Y3)
                size_t lumaPixelBufferSize = pixelBufferSize / 2;
                void *lumaPixelBufferBase = malloc(lumaPixelBufferSize);
                if (lumaPixelBufferBase == NULL)
                {
                    NSLog(@"Coud not allocate memory for luma buffer");
                }
                //creation buffer for luma pixels
                memset(lumaPixelBufferBase, 0, lumaPixelBufferSize);
                UInt16 *lumaPixelBufferPos = lumaPixelBufferBase;
                void *lumaPixelBufferEnd = lumaPixelBufferBase + lumaPixelBufferSize;
                
                //step pixel pointers thru memory, copy from main buffer to luma pixel buffer
                while(lumaPixelBufferPos < (UInt16*)lumaPixelBufferEnd)                             //use UInt16 as word size
                {
                    memcpy(lumaPixelBufferPos, pixelBufferPos, 2);
                    pixelBufferPos += 2;
                    lumaPixelBufferPos += 1;
                }
                
/*
                //find black threshold
                for (int col = 0; col < resolution.width; col++)
                {
                    UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
                    pixel += col + ((int)resolution.height * (int)resolution.width) / 2;                                                               //col(pixel) offset
                    UInt16 pixelValue = *pixel >> 6;
                    if (pixelValue < BLACK_THRESHHOLD && pixelValue > 64)                      //set 64 as lowest possible black value
                    {
                        BLACK_THRESHHOLD = pixelValue;
                    }
                }
  */
                
                //find top matte size
                int videoSignal_TopRow = 0;
                
                for (int row = 0; row < resolution.height; row++)                                   //iterate thru rows
                {
                    //reset mean
                    UInt64 mean = 0;
                    
                    for (int col = 0; col < resolution.width; col++)                                //iterate thru columns
                    {
                        //advance to next pixel and wrap around if column
                        UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
                        pixel += ((int)row * (int)resolution.width);                                // row offset
                        pixel += col;                                                               //col(pixel) offset
                        
                        UInt16 pixelValue = *pixel >> 6;                                            //offset by six bits to convert to 10 bit video
                        
                        mean += pixelValue;
                    }
                    //find mean for each row of luma pixel buffer
                    mean /= ceil(resolution.width);                                                       //get mean for each row
                    
                    if (mean <= BLACK_THRESHHOLD)                                                                  //set video signal top line and break if row is not black
                    {
                        videoSignal_TopRow++;
                    }
                    else
                    {
                        break;
                    }
                }
                
                //find bottom matte size
                int videoSignal_BottomRow = resolution.height;
                
                for (int row = (resolution.height-1); row >= 0; row--)                                   //iterate thru rows
                {
                    //reset mean
                    UInt64 mean = 0;
                    
                    for (int col = 0; col < resolution.width; col++)                                //iterate thru columns
                    {
                        //advance to next pixel and wrap around if column
                        UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
                        pixel += ((int)row * (int)resolution.width);                                // row offset
                        pixel += col;                                                               //col(pixel) offset
                        
                        UInt16 pixelValue = *pixel >> 6;                                            //offset by six bits to convert to 10 bit video
                        
                        mean += pixelValue;
                    }
                    //find mean for each row of luma pixel buffer
                    mean /= ceil(resolution.width);                                                       //get mean for each row
                    
                    if (mean <= BLACK_THRESHHOLD)                                                                  //  calculate AR if row is not black
                    {
                        videoSignal_BottomRow--;
                    }
                    else
                    {
                        break;
                    }
                    
                }
                
                //find left margin
                int videoSignal_LeftCol = 0;
                
                for (int col = 0; col < resolution.width; col++)
                {
                    UInt64 mean = 0;
                    
                    for (int row = 0; row < resolution.height-1; row++)
                    {
                        UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;
                        pixel += ((int)row * (int)resolution.width);
                        pixel += col;
                        
                        UInt16 pixelValue = *pixel >> 6;
                        
                        mean += pixelValue;
                    }
                    
                    mean /= ceil(resolution.height);
                    
                    if (mean <= BLACK_THRESHHOLD)
                    {
                        videoSignal_LeftCol++;
                    }
                    else
                    {
                        break;
                    }
                }
                
                
                //find right margin
                int videoSignal_RightCol = resolution.width;
                
                for (int col = resolution.width-1; col >= 0; col--)
                {
                    UInt64 mean = 0;
                    
                    for (int row = 0; row < resolution.height-1; row++)
                    {
                        UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;
                        pixel += ((int)row * (int)resolution.width);
                        pixel += col;
                        
                        UInt16 pixelValue = *pixel >> 6;
                        
                        mean += pixelValue;
                    }
                    
                    mean /= ceil(resolution.height);
                    
                    if (mean <= BLACK_THRESHHOLD)
                    {
                        videoSignal_RightCol--;
                    }
                    else
                    {
                        break;
                    }
                }
                
                
                //put margins into dictionaries for sorting later after all frames have been analyzed
                
                // put top and bottom margin into dictionary
                NSString *topMarginString = [@(videoSignal_TopRow) stringValue];
                NSNumber *topRowCount = videoSignal_TopMarginSize[topMarginString];
                int newTopRowCount = [topRowCount intValue];
                newTopRowCount++;
                [videoSignal_TopMarginSize setValue:@(newTopRowCount) forKey:topMarginString];
                
                NSString *bottomMarginString = [@(resolution.height - videoSignal_BottomRow) stringValue];
                NSNumber *bottomRowCount = videoSignal_BottomMarginSize[bottomMarginString];
                int newBottomRowCount = [bottomRowCount intValue];
                newBottomRowCount++;
                [videoSignal_BottomMarginSize setValue:@(newBottomRowCount) forKey:bottomMarginString];
                
                
                //put final vertical resolution for frame into dictionary
                int videoSignal_VertResolution = ((resolution.height - videoSignal_TopRow) - (resolution.height - videoSignal_BottomRow));
                NSString *videoSignal_VertResolutionString = [@(videoSignal_VertResolution) stringValue];
                NSNumber *vertResolutionCount = videoSignal_VerResolutionDictionary[videoSignal_VertResolutionString];
                int newVertResolutionCount = [vertResolutionCount intValue];
                newVertResolutionCount++;
                [videoSignal_VerResolutionDictionary setValue:@(newVertResolutionCount) forKey:videoSignal_VertResolutionString];
                
                
                //put final horizontal resolution for frame into dictionary
                int videoSignal_HorizResolution = ((resolution.height - videoSignal_LeftCol) - (resolution.height - videoSignal_RightCol));
                NSString *videoSignal_HorizResolutionString = [@(videoSignal_HorizResolution) stringValue];
                NSNumber *horizResolutionCount = videoSignal_HorResolutionDictionary[videoSignal_HorizResolutionString];
                int newHorizResolutionCount = [horizResolutionCount intValue];
                newHorizResolutionCount++;
                [videoSignal_HorResolutionDictionary setValue:@(newHorizResolutionCount) forKey:videoSignal_HorizResolutionString];
                
                // put left and right margin into dictionary
                NSString *leftMarginString = [@(videoSignal_LeftCol) stringValue];
                NSNumber *leftColCount = videoSignal_LeftMarginSize[leftMarginString];
                int newleftColCount = [leftColCount intValue];
                newleftColCount++;
                [videoSignal_LeftMarginSize setValue:@(newleftColCount) forKey:leftMarginString];
                
                NSString *rightMarginString = [@(resolution.width - videoSignal_RightCol) stringValue];
                NSNumber *rightColCount = videoSignal_RightMarginSize[rightMarginString];
                int newRightColCount = [rightColCount intValue];
                newRightColCount++;
                [videoSignal_RightMarginSize
                 
                 
                 setValue:@(newRightColCount) forKey:rightMarginString];
                
                //release buffers and move onto next frame
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                CMSampleBufferInvalidate(sampleBuffer);
                CFRelease(sampleBuffer);
                free(lumaPixelBufferBase);
            }
        }
        
        /*        if (reader.status == AVAssetReaderStatusCompleted)
         {
         
         }
         */
        if (reader.status == AVAssetReaderStatusFailed)
        {
            NSLog(@"AR detection failed...");
        }
    }
    
    
    //calcuate resolution
    NSLog(@"Encoded vertical resolution: %d", (int)resolution.height);
    
    NSArray *sortedKeys = [videoSignal_VerResolutionDictionary keysSortedByValueUsingSelector:@selector(compare:)];
    int finalVerticalResolution = [[sortedKeys lastObject] intValue];
    NSLog(@"Most common final vertical resolution: %d, %@ frames.", finalVerticalResolution, [videoSignal_VerResolutionDictionary objectForKey:[sortedKeys lastObject]]);
    
    NSLog(@"Encoded horizontal resolution: %d", (int)resolution.width);
    
    sortedKeys = [videoSignal_HorResolutionDictionary keysSortedByValueUsingSelector:@selector(compare:)];
    int finalHorizontalResolution = [[sortedKeys lastObject] intValue];
    NSLog(@"Most common final horizontal resolution: %d, %@ frames.", finalHorizontalResolution, [videoSignal_HorResolutionDictionary objectForKey:[sortedKeys lastObject]]);
    
    //get most common margins from dictionaries and use as cropping guides.
    //print margins
    //top
    sortedKeys = [videoSignal_TopMarginSize keysSortedByValueUsingSelector:@selector(compare:)];
    int finalTopMarginSize = [[sortedKeys lastObject] intValue];
    if ((finalTopMarginSize % 2) != 0) finalTopMarginSize++;
    NSLog(@"Top Margin Size: %d", finalTopMarginSize);
    
    //bottom
    sortedKeys = [videoSignal_BottomMarginSize keysSortedByValueUsingSelector:@selector(compare:)];
    int finalBottomMarginSize = [[sortedKeys lastObject] intValue];
    if ((finalBottomMarginSize % 2) != 0) finalBottomMarginSize++;
    NSLog(@"Bottom Margin Size: %d", finalBottomMarginSize);
    
    //left
    sortedKeys = [videoSignal_LeftMarginSize keysSortedByValueUsingSelector:@selector(compare:)];
    int finalLeftMarginSize = [[sortedKeys lastObject] intValue];
    if ((finalLeftMarginSize % 2) != 0) finalLeftMarginSize++;
    NSLog(@"Left Margin Size: %d", finalLeftMarginSize);
    
    //right
    sortedKeys = [videoSignal_RightMarginSize keysSortedByValueUsingSelector:@selector(compare:)];
    int finalRightMarginSize = [[sortedKeys lastObject] intValue];
    if ((finalRightMarginSize % 2) != 0) finalRightMarginSize++;
    NSLog(@"Right Margin Size: %d", finalRightMarginSize);
    
    
    //calculate approx. aspect ratio
    float predictedAspectRatio = (float)finalHorizontalResolution / (float)finalVerticalResolution;
    NSLog(@"Predicted aspect ratio: %.02f", predictedAspectRatio);
    
    
    return predictedAspectRatio;
}


@end

