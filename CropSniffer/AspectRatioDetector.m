#import "AspectRatioDetector.h"

#define RANGE_COUNT 10                  //number of ranges in feature to check
#define QC_DURATION_FRACTION 1000       //duration/fraction to determine number of frames to check
#define UPPER_BLACK_THRESHHOLD 80       //maximum allowed black level
#define HD_VIDEO_BLACK 64               //lowest allowed black level
#define TOP_BOTTOM_MARGIN_DIVISIONS 5   //fraction of the screen required before row is considered black

@implementation AspectRatioDetector

- (instancetype)initWithFile:(NSString *)inFilepathString;
{
    self = [super init];
    if (self)
    {
        //setup asset
        NSURL *mediaURL = [NSURL fileURLWithPath:inFilepathString];
        self->asset = [[AVURLAsset alloc] initWithURL:mediaURL options:nil];

        //setup dictionaries to store video start/end pixel data
        self->videoSignal_VerResolutionDictionary = [[NSMutableDictionary alloc] init];
        self->videoSignal_HorResolutionDictionary = [[NSMutableDictionary alloc] init];
        
        //setup dictionarires to hold size of margins
        self->videoSignal_LeftMarginSize = [[NSMutableDictionary alloc] init];
        self->videoSignal_RightMarginSize = [[NSMutableDictionary alloc] init];
        self->videoSignal_BottomMarginSize = [[NSMutableDictionary alloc] init];
        self->videoSignal_TopMarginSize = [[NSMutableDictionary alloc] init];
        
    }
    return self;
}

- (void *)getLumaPixelBuffer:(size_t)pixelBufferSize pixelBufferPos_p:(UInt16 **)pixelBufferPos_p
{
    //setup destination buffer for luma pixels (Y0 Y1 Y2 Y3)
    size_t lumaPixelBufferSize = pixelBufferSize / 2;
    void *lumaPixelBufferBase = malloc(lumaPixelBufferSize);
    if (lumaPixelBufferBase != NULL)
    {
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

        //get pointer to current row
        UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
        pixel += ((int)row * (int)resolution.width);                                // row offset
        
        for (int col = 0; col < resolution.width; col++)                                //iterate thru columns
        {
            //advance to next pixel in row
            pixel ++;                                                               //col(pixel) offset
            UInt16 pixelValue = *pixel >> 6;                                            //offset by six bits to convert to 10 bit video
            
            if (pixelValue <= BLACK_THRESHHOLD && pixelValue >= HD_VIDEO_BLACK)
                blackPixels++;
        }
        //if X percentage of row is black then increment margin
        if (blackPixels > resolution.width / TOP_BOTTOM_MARGIN_DIVISIONS)                                                                  //set video signal top line and break if row is not black
            videoSignal_TopRow++;
        else
            break;
    }
    //add two extra lines for SD Material
    if (resolution.height < 720)
        videoSignal_TopRow += 2;
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
        UInt16 *pixel = (UInt16 *)lumaPixelBufferBase;                              //get basepointer for pixel buffer
        pixel += ((int)row * (int)resolution.width);                                // row offset
        
        for (int col = 0; col < resolution.width; col++)                                //iterate thru columns
        {
            //advance to next pixel and wrap around if column
            pixel ++;                                                               //col(pixel) offset
            
            UInt16 pixelValue = *pixel >> 6;                                            //offset by six bits to convert to 10 bit video
            
            if (pixelValue <= BLACK_THRESHHOLD && pixelValue >= HD_VIDEO_BLACK)
                blackPixels++;
        }
        //if X percentage of row is black then increment margin
        if (blackPixels > resolution.width / TOP_BOTTOM_MARGIN_DIVISIONS)                                //set video signal top line and break if row is not black
            videoSignal_BottomRow--;
        else
            break;
    }
    if (resolution.height < 720)
        videoSignal_BottomRow -= 2;
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
    if (resolution.height < 720)
        videoSignal_LeftCol += 2;
    
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
    if (resolution.height < 720)
        videoSignal_RightCol -= 2;
    
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
    
    //setup queue to add items to dictionary write
    dispatch_queue_t dictionaryWriteQ = dispatch_queue_create("com.mvf.DictionaryWriteQueue", NULL);
    
    //setup queue and group for concurrent range scanning
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
                    int BLACK_THRESHHOLD = UPPER_BLACK_THRESHHOLD;
                    
                    //setup pixel buffer
                    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                    
                    //setup image property vars
                    CGSize resolution = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
                    
                    //setup source buffer (Cr Y0 Cb Y1)
                    UInt16 *pixelBufferBaseAddress = (UInt16 *)CVPixelBufferGetBaseAddress(pixelBuffer);
                    size_t pixelBufferSize = CVPixelBufferGetDataSize(pixelBuffer);
                    UInt16 *pixelBufferPos = pixelBufferBaseAddress;
                    pixelBufferPos++;
                    
                    void *lumaPixelBufferBase = [self getLumaPixelBuffer:pixelBufferSize pixelBufferPos_p:&pixelBufferPos];

                    //base black level in image in case it is lower than set threshold
                    [self findImageBlack:&BLACK_THRESHHOLD resolution:resolution lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    //get first of video signal after margins
                    int videoSignal_TopRow = [self findTopMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    int videoSignal_BottomRow = [self findBottomMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    int videoSignal_LeftCol = [self findLeftMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    int videoSignal_RightCol = [self findRightMatte:resolution BLACK_THRESHHOLD:BLACK_THRESHHOLD lumaPixelBufferBase:lumaPixelBufferBase];
                    
                    //create semaphore for async thread to call
                    
                    dispatch_semaphore_t dictionaryWriteDone = dispatch_semaphore_create(0);
                    //put margins into dictionaries for sorting later after all frames have been analyzed
                    //add block to dictionary write queue to prevent memory deadlock
                    dispatch_async(dictionaryWriteQ, ^{
                        // put top and bottom margin into dictionary
                        if (videoSignal_TopRow < resolution.height/2)
                        {
                            NSString *topMarginString = [@(videoSignal_TopRow) stringValue];
                            NSNumber *topRowCount = videoSignal_TopMarginSize[topMarginString];
                            int newTopRowCount = [topRowCount intValue];
                            newTopRowCount++;
                            [videoSignal_TopMarginSize setValue:@(newTopRowCount) forKey:topMarginString];
                        }
                        
                        if (videoSignal_BottomRow > resolution.height/2)
                        {
                            NSString *bottomMarginString = [@(resolution.height - videoSignal_BottomRow) stringValue];
                            NSNumber *bottomRowCount = videoSignal_BottomMarginSize[bottomMarginString];
                            int newBottomRowCount = [bottomRowCount intValue];
                            newBottomRowCount++;
                            [videoSignal_BottomMarginSize setValue:@(newBottomRowCount) forKey:bottomMarginString];
                        }
                        // put left and right margin into dictionary
                        if (videoSignal_LeftCol < resolution.width/2)
                        {
                            NSString *leftMarginString = [@(videoSignal_LeftCol) stringValue];
                            NSNumber *leftColCount = videoSignal_LeftMarginSize[leftMarginString];
                            int newleftColCount = [leftColCount intValue];
                            newleftColCount++;
                            [videoSignal_LeftMarginSize setValue:@(newleftColCount) forKey:leftMarginString];
                        }
                        
                        if (videoSignal_RightCol > resolution.width/2)
                        {
                            NSString *rightMarginString = [@(resolution.width - videoSignal_RightCol) stringValue];
                            NSNumber *rightColCount = videoSignal_RightMarginSize[rightMarginString];
                            int newRightColCount = [rightColCount intValue];
                            newRightColCount++;
                            [videoSignal_RightMarginSize setValue:@(newRightColCount) forKey:rightMarginString];   
                        }
                        
                        //put final vertical resolution for frame into dictionary
                        int videoSignal_VertResolution = ((resolution.height - videoSignal_TopRow) - (resolution.height - videoSignal_BottomRow));
                        if (videoSignal_VertResolution > 0)
                        {
                            NSString *videoSignal_VertResolutionString = [@(videoSignal_VertResolution) stringValue];
                            NSNumber *vertResolutionCount = videoSignal_VerResolutionDictionary[videoSignal_VertResolutionString];
                            int newVertResolutionCount = [vertResolutionCount intValue];
                            newVertResolutionCount++;
                            [videoSignal_VerResolutionDictionary setValue:@(newVertResolutionCount) forKey:videoSignal_VertResolutionString];
                        }
                        
                        //put final horizontal resolution for frame into dictionary
                        int videoSignal_HorizResolution = ((resolution.height - videoSignal_LeftCol) - (resolution.height - videoSignal_RightCol));
                        if(videoSignal_HorizResolution > 0)
                        {
                            NSString *videoSignal_HorizResolutionString = [@(videoSignal_HorizResolution) stringValue];
                            NSNumber *horizResolutionCount = videoSignal_HorResolutionDictionary[videoSignal_HorizResolutionString];
                            int newHorizResolutionCount = [horizResolutionCount intValue];
                            newHorizResolutionCount++;
                            [videoSignal_HorResolutionDictionary setValue:@(newHorizResolutionCount) forKey:videoSignal_HorizResolutionString];
                            
                        }
                        
                        //signal that dictionary write has completed
                        dispatch_semaphore_signal(dictionaryWriteDone);
                    });

                    //wait for async dictionary write to finish
                    dispatch_semaphore_wait(dictionaryWriteDone, DISPATCH_TIME_FOREVER);

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

