//
//  BallerImageProcessController.h
//  Baller
//
//  Created by Ping Chen on 12/13/17.
//

#import <Foundation/Foundation.h>



@interface BallerImageProcessController : NSObject {
    
    int gaussianBlurDimension; // must be odd
    int binaryThreshold;
    double accumulationAlpha;
    #ifdef __cplusplus
        std::vector<cv::Mat> hsvim;
        cv::Mat hist;
        cv::Mat cdf;
        std::queue<int> overexp;
        std::queue<int> underexp;
        int sumoe;
        int sumue;
    #endif
}

- (instancetype)init;


- (UIImage *)backgroundFuckery:(UIImage *)img;

- (UIImage *)thresholdedImage:(UIImage *)img;

- (float)computeMotionIntensity:(UIImage *)image;

- (UIImage *)autoBrightnessContrast;

- (BOOL)overexposed;

- (BOOL)underexposed;

- (void)convertImage:(UIImage *)img;

- (UIImage *)histogram;

@end
