#import "MVFAssetHandler.h"

#define RANGE_COUNT 10
#define QC_DURATION_FRACTION 1000
#define BLACK_THRESHHOLD_MACRO 68
#define HD_VIDEO_BLACK 64

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

- (void *)getLumaPixelBuffer:(size_t)pixelBufferSize pixelBufferPos_p:(UInt16 **)pixelBufferPos_p
{
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
        memcpy(lumaPixelBufferPos, *pixelBufferPos_p, 2);
        *pixelBufferPos_p += 2;
        lumaPixelBufferPos += 1;
    }
    return lumaPixelBufferBase;
}

- (void)findImageBlack:(int *)BLACK_THRESHHOLD_p resolution:(CGSize)resolution lumaPixelBufferBase:(void *)lumaPixelBufferBase
{
    //find image black by scanning frame within a safe zone
    for (int col = resolution.width/10; col < (resolution.width * .9); col++)
    {
        for (int row = resolution.height/10; row < (resolution.height * .9); row++)
        {
            UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                                                                  //get basepointer for pixel buffer
            pixel += col;                                                                   //col offset
            pixel += row * (int)resolution.width;                                        //row offset
            UInt16 pixelValue = *pixel >> 6;
            if (pixelValue < *BLACK_THRESHHOLD_p && pixelValue > HD_VIDEO_BLACK)                                                           //set 64 as lowest possible black value
                *BLACK_THRESHHOLD_p = pixelValue;
        }
    }
}

- (int)findTopMatte:(CGSize)resolution BLACK_THRESHHOLD:(int)BLACK_THRESHHOLD lumaPixelBufferBase:(void *)lumaPixelBufferBase
{
    //find top matte size
    int videoSignal_TopRow = 0;
    
    for (int row = 0; row < resolution.height; row++)                                   //iterate thru rows
    {
        //count number of black pixels in each row
        int blackPixels = 0;
        
        for (int col = 0; col < resolution.width; col++)                                //iterate thru columns
        {
            //advance to next pixel and wrap around if column
            UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
            pixel += ((int)row * (int)resolution.width);                                // row offset
            pixel += col;                                                               //col(pixel) offset
            
            UInt16 pixelValue = *pixel >> 6;                                            //offset by six bits to convert to 10 bit video
            
            if (pixelValue < BLACK_THRESHHOLD)
                blackPixels++;
            
        }
        //if X percentage of row is black then increment margin
        if (blackPixels > resolution.width / 20)                                                                  //set video signal top line and break if row is not black
            videoSignal_TopRow++;
        else
            break;
    }
    return videoSignal_TopRow;
}

- (int)findBottomMatte:(CGSize)resolution BLACK_THRESHHOLD:(int)BLACK_THRESHHOLD lumaPixelBufferBase:(void *)lumaPixelBufferBase
{
    //find bottom matte size
    int videoSignal_BottomRow = resolution.height;
    
    for (int row = (resolution.height-1); row >= 0; row--)                                   //iterate thru rows
    {
        //count number of black pixels in each row
        int blackPixels = 0;
        
        for (int col = 0; col < resolution.width; col++)                                //iterate thru columns
        {
            //advance to next pixel and wrap around if column
            UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
            pixel += ((int)row * (int)resolution.width);                                // row offset
            pixel += col;                                                               //col(pixel) offset
            
            UInt16 pixelValue = *pixel >> 6;                                            //offset by six bits to convert to 10 bit video
            
            if (pixelValue < BLACK_THRESHHOLD)
                blackPixels++;
        }
        //if X percentage of row is black then increment margin
        if (blackPixels > resolution.width / 20)                                                                  //set video signal top line and break if row is not black
            videoSignal_BottomRow--;
        else
            break;
    }
    return videoSignal_BottomRow;
}

- (int)findLeftMatte:(CGSize)resolution BLACK_THRESHHOLD:(int)BLACK_THRESHHOLD lumaPixelBufferBase:(void *)lumaPixelBufferBase
{
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
            videoSignal_LeftCol++;
        else
            break;
    }
    return videoSignal_LeftCol;
}

- (int)findRightMatte:(CGSize)resolution BLACK_THRESHHOLD:(int)BLACK_THRESHHOLD lumaPixelBufferBase:(void *)lumaPixelBufferBase
{
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
            videoSignal_RightCol--;
        else
            break;
    }
    return videoSignal_RightCol;
}

-(float) VideoFrameAspectRatioDetection
{
    NSLog(@"Starting aspect ratio calculation");
    CMTime duration = self->asset.duration;
    CMTime qcDuration = CMTimeMake(duration.value/QC_DURATION_FRACTION, self->asset.duration.timescale);
    
    //setup ranges for QC
    CMTimeRange timeRanges[RANGE_COUNT];
    for (int counter = 0; counter < RANGE_COUNT; counter++)
    {
        int64_t rangeTime = (int64_t)((float)duration.value * ((float)counter/RANGE_COUNT));
        CMTime rangeStartTime = CMTimeMake(rangeTime, duration.timescale);
        CMTimeRange qcRange = CMTimeRangeMake(rangeStartTime, qcDuration);
        timeRanges[counter] = qcRange;
    }
    
    //setup dictionaries to store video start/end pixel data
    NSMutableDictionary *videoSignal_VerResolutionDictionary = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_HorResolutionDictionary = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *videoSignal_TopMarginSize = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_BottomMarginSize = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_LeftMarginSize = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *videoSignal_RightMarginSize = [[NSMutableDictionary alloc] init];
    
    //setup queue
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    //loop thru time ranges to get sampling of feature.
    for (int range = 0; range < RANGE_COUNT; range++)
    {
        //setup asset reader
        NSError *error;
        AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:self->asset error:&error];
        CMTimeRange currentRange = timeRanges[range];
        
        //add range to queue, add queue to dispatch group
        dispatch_group_async(dispatchGroup, q, ^{
            
        
            //setup asset track
            AVAssetTrack *videoTrack = [[self->asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
            
            //setup track output
            NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr16] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
            AVAssetReaderTrackOutput *trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
            
            //add output to reader
            [reader addOutput:trackOutput];
            reader.timeRange = currentRange;
            //start reading
            [reader startReading];
            
            while(reader.status == AVAssetReaderStatusReading)
            {
                CMSampleBufferRef sampleBuffer = [trackOutput copyNextSampleBuffer];
                
                if(sampleBuffer)
                {
                    int BLACK_THRESHHOLD = BLACK_THRESHHOLD_MACRO;
                    
                    //setup pixel buffer
                    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                    
                    //setup image property vars
                    CGSize resolution = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
                    
                    //setup source buffer (Cr Y0 Cb Y1)
                    size_t pixelBufferSize = CVPixelBufferGetDataSize(pixelBuffer);
                    void *pixelBufferBaseAddress = (UInt16 *)CVPixelBufferGetBaseAddress(pixelBuffer);
                    UInt16 *pixelBufferPos = pixelBufferBaseAddress;
                    pixelBufferPos++;
                    
                    void *lumaPixelBufferBase;
                    lumaPixelBufferBase = [self getLumaPixelBuffer:pixelBufferSize pixelBufferPos_p:&pixelBufferPos];
                    

                    [self findImageBlack:&BLACK_THRESHHOLD resolution:resolution lumaPixelBufferBase:lumaPixelBufferBase];
//NSLog(@"Black: %d", BLACK_THRESHHOLD);
                    
                    
                    int videoSignal_TopRow = [self findTopMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    int videoSignal_BottomRow = [self findBottomMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    int videoSignal_LeftCol = [self findLeftMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    int videoSignal_RightCol = [self findRightMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    
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
                    [videoSignal_RightMarginSize setValue:@(newRightColCount) forKey:rightMarginString];
            
             //release buffers and move onto next frame
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                    CMSampleBufferInvalidate(sampleBuffer);
                    CFRelease(sampleBuffer);
                    free(lumaPixelBufferBase);
                }
            }
            

            if (reader.status == AVAssetReaderStatusFailed)
            {
                NSLog(@"AR detection failed...");
            }
        });
                       
    }
    
    dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
    
    NSArray *sortedKeys = [videoSignal_VerResolutionDictionary keysSortedByValueUsingSelector:@selector(compare:)];
    int finalVerticalResolution = [[sortedKeys lastObject] intValue];
    NSLog(@"Most common final vertical resolution: %d, %@ frames.", finalVerticalResolution, [videoSignal_VerResolutionDictionary objectForKey:[sortedKeys lastObject]]);
    
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

