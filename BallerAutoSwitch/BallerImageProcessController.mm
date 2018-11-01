//
//  BallerSwitchingController.m
//  Baller
//
//  Created by Ping Chen on 12/13/17.
//

#import "BallerImageProcessController.h"
#import "BallerImageHelper.h"
#import <CoreImage/CoreImage.h>

#ifdef __cplusplus
#include <stdlib.h>
#import <opencv2/videoio/cap_ios.h>
//#include "opencv2/highgui/highgui.hpp"
#include <stdio.h>
#include <math.h>

#include <opencv2/opencv.hpp>

#endif

using namespace cv;
using namespace std;

@interface BallerImageProcessController ()

#ifdef __cplusplus
@property std::deque<cv::Mat> ring;

@property Ptr<BackgroundSubtractorMOG2> bgMOG2;

#endif

@end



@implementation BallerImageProcessController

- (instancetype)init {
    
    self = [super init];
    
    gaussianBlurDimension = 3;
    binaryThreshold = 25;
    accumulationAlpha = 0.03;
    
    _bgMOG2 = cv::createBackgroundSubtractorMOG2(5);
    
    return self;
}


#ifdef __cplusplus
- (UIImage *)backgroundFuckery:(UIImage *)img {
    
    cv::Mat image = [[self class] cvMatFromUIImage:img];
    int rows = image.rows;
    int cols = image.cols;
    
    cv::Mat fgMask;
    _bgMOG2->apply(image, fgMask);
    
//    cv::Mat bground(rows, cols, CV_8UC1);
//    _bgMOG2->getBackgroundImage(bground);
    
    UIImage *answer = [[self class] UIImageFromCVMat:fgMask];
    
    fgMask.release();
    image.release();
    
    return answer;
    
}

- (BOOL)overexposed:(UIImage *)img {
    return false;
}

- (BOOL)underexposed:(UIImage *)img {
    return false;
}

- (UIImage *)autoBrightnessContrast:(UIImage *)img {
    return img;
}

- (void)convertImage:(UIImage *)img {
    cv::Mat image = [[self class] cvMatFromUIImage:img];
    cv::Mat bgr;
    cvtColor(image, bgr, CV_BGRA2BGR);
    cv::Mat hsv;
    cvtColor(bgr, hsv, CV_BGR2HSV);
    split(hsv, hsvim);
    
    image.release();
    bgr.release();
    hsv.release();
}

- (UIImage *)histogram {
    //create histogram
    float range[] = {0, 256};
    const float* ranges[] = {range};
    int histSize[] = {256};
    int channels[] = {0};
    calcHist(&hsvim[2], 1, channels, Mat(), hist, 1, histSize, ranges);
    
    //create cdf
    cdf = hist.clone();
    for (int i=1; i<histSize[0]; i++) {
        cdf.at<float>(i) += cdf.at<float>(i-1);
    }
    for (int i=0; i<histSize[0]; i++) {
        cdf.at<float>(i) /= cdf.at<float>(255);
    }
    
    //Draw histogram pdf
    int hist_w = 512; int hist_h = 400;
    int bin_w = cvRound((double) hist_w/256);
    Mat histImage(hist_h, hist_w, CV_8UC1, Scalar(255, 255, 255));
//    std::vector<float> array(hist.rows*hist.cols);
//    for(int i=0; i<256; i++) {
//        array[i] = hist.at<float>(0, i);
//    }
//    // find the maximum intensity element from histogram
//    int max = array[0];
//    for(int i = 1; i < 256; i++){
//        if(max < array[i]){
//            max = array[i];
//        }
//    }
//    for(int i = 0; i < 256; i++){
//        array[i] = ((double)array[i]/max)*histImage.rows;
//    }
//    // draw the intensity line for histogram
//    for(int i = 0; i < 256; i++)
//    {
//        line(histImage, cv::Point(bin_w*(i), hist_h),
//             cv::Point(bin_w*(i), hist_h - array[i]),
//             Scalar(0,0,0), 1, 8, 0);
//    }
//
    return [[self class] UIImageFromCVMat:histImage];
    //return NULL;
}

- (BOOL)overexposed {
    cv::Size s = hsvim[2].size();
    int shape = s.height * s.width;
    int white = (int) hist.at<float>(0, 255);
    float whiteProp = ((float) white) / shape;
    int oe = 0;
    if (whiteProp > 0.18) {
        oe = 1;
    }
    if (overexp.size() >= 90) {
        int fronto = overexp.front();
        sumoe -= fronto;
        overexp.pop();
    }
    sumoe += oe;
    overexp.push(oe);
    float avgoe = ((float) sumoe) / overexp.size();
    if (avgoe > 0.5) {
        return true;
    }
    return false;
}

-(BOOL)underexposed {
    float ueclip = cdf.at<float>(254) - 0.1;
    int p = [self argmaxcdf:ueclip];
    int ue = 0;
    if (p < 150) {
        ue = 1;
    }
    if (underexp.size() >= 90) {
        int frontu = underexp.front();
        sumue -= frontu;
        underexp.pop();
    }
    sumue += ue;
    underexp.push(ue);
    float avgue = ((float) sumue) / underexp.size();
    if (avgue > 0.5) {
        return true;
    }
    return false;
}

-(UIImage *)autoBrightnessContrast {
    float clip = 0.004;
    
    //adjust top clip for special cases like underexposure from windows
    int normtop = [self argmaxcdf:(1 - clip)];
    float cliph;
    //if (hist.at<float>(0, 254)*hist.at<float>(0, 255) > 0) { //prevents overclipping of generally underexposed images?
        int lever = normtop - [self argmaxcdf:0.9];
        if (lever < 30) {
            cliph = clip;
        } else {
            if (lever >= 60){
                cliph = 0.03;
            } else {
                float s = ((float)(lever - 30)) / (60 - 30); //linear smoothing
                cliph = s * (0.03 - clip) + clip;
            }
        }
//    } else {
//        cliph = clip;
//    }
    cliph = cdf.at<float>(254) - cliph;
    
    //histclip, find max and min of histogram to clip
    int min = [self argmaxcdf:clip];
    int max = [self argmaxcdf:cliph];
    
    //clip image
   threshold(hsvim[2], hsvim[2], max, 255, THRESH_TRUNC);
    Mat threshl(1, 256, CV_8U);
    for (int i = 0; i<256; i++) {
        if (i <= min) {
            threshl.at<uchar>(0, i) = min;
        } else {
            threshl.at<uchar>(0, i) = i;
        }
    }
    LUT(hsvim[2], threshl, hsvim[2]);
    
    //adjust contrast and brightness
    int bright = 10;
    if (max > min) {
        float alpha = ((float)(255 - bright)) / (max - min);
        float beta = alpha * min;
        Mat lut(1, 256, CV_8U);
        for (int i=0; i<256; i++) {
            int val = round(i*alpha - beta + bright);
            if (val > 255) {
                val = 255;
            }
            lut.at<uchar>(0, i) = val;
        }
        LUT(hsvim[2], lut, hsvim[2]);
    }
    
    //combine layers and convert
    Mat merged;
    merge(hsvim, merged);
    Mat mergedbgr;
    cvtColor(merged, mergedbgr, CV_HSV2BGR);
    return [[self class] UIImageFromCVMat:mergedbgr];
//    float range[] = {0, 256};
//    const float* ranges[] = {range};
//    int histSize[] = {256};
//    int channels[] = {0};
//    Mat histtest;
//    calcHist(&hsvim[2], 1, channels, Mat(), histtest, 1, histSize, ranges);
//
//    //Draw histogram pdf
//    int hist_w = 512; int hist_h = 400;
//    int bin_w = cvRound((double) hist_w/256);
//    Mat histImage(hist_h, hist_w, CV_8UC1, Scalar(255, 255, 255));
//    std::vector<float> array(histtest.rows*histtest.cols);
//    for(int i=0; i<256; i++) {
//        array[i] = histtest.at<float>(0, i);
//    }
//    // find the maximum intensity element from histogram
//    int maxt = array[0];
//    for(int i = 1; i < 256; i++){
//        if(maxt < array[i]){
//            maxt = array[i];
//        }
//    }
//    for(int i = 0; i < 256; i++){
//        array[i] = ((double)array[i]/maxt)*histImage.rows;
//    }
//    // draw the intensity line for histogram
//    for(int i = 0; i < 256; i++)
//    {
//        line(histImage, cv::Point(bin_w*(i), hist_h),
//             cv::Point(bin_w*(i), hist_h - array[i]),
//             Scalar(0,0,0), 1, 8, 0);
//    }
//
//    return [[self class] UIImageFromCVMat:histImage];
}

-(int)argmaxcdf: (float)clip {
    float array [256];
    //std::vector<int> array(hist.rows*hist.cols);
    for(int i=0; i<256; i++) {
        array[i] = cdf.at<float>(0, i);
    }
    
    int low = 0, high = 256; // numElems is the size of the array i.e arr.size()
    while (low != high) {
        int mid = (low + high) / 2; // Or a fancy way to avoid int overflow
        if (array[mid] <= clip) {
            low = mid + 1;
        }
        else {
            /* This element is at least as large as the element, so anything after it can't
             * be the first element that's at least as large.
             */
            high = mid;
        }
    }
    int p = high;
    if (p >= 0 && p < 256) {
        return p;
    }
    return -1;
}

- (UIImage *)thresholdedImage:(UIImage *)img {
    UIImage *thresholdedImage = img;
    
    cv::Mat image = [[self class] cvMatFromUIImage:img];
    CGFloat ogCols = image.cols;
    CGFloat ogRows = image.rows;
    CGFloat ratio = ogCols/ogRows;
    
    cv::resize(image, image, cv::Size(ratio * 360, 360));
    
    CGFloat cols = image.cols;
    CGFloat rows = image.rows;
    
    // convert to grayscale and blur
    cv::Mat gray(rows, cols, CV_32FC1);
    cv::cvtColor(image, gray, CV_BGRA2GRAY);
//    cv::GaussianBlur(gray, gray, cv::Size(gaussianBlurDimension, gaussianBlurDimension), 0);

    
    if (_ring.size() >= 2) {
        
        // compute the absolute difference between the current frame and past
        cv::Mat frameDelta1(rows, cols, 0);
        cv::Mat frameDelta2(rows, cols, 0);
        cv::Mat frameDelta(rows, cols, 0);
//        cv::absdiff(_ring[0], _ring[1],frameDelta1);
        cv::absdiff(_ring[1], gray, frameDelta);
//        cv::bitwise_and(frameDelta1, frameDelta2, frameDelta);
        
        
        // Apply threshold
        cv::Mat thresh;
        cv::threshold(frameDelta, thresh, binaryThreshold, 255, THRESH_BINARY);
        thresh.convertTo(thresh, CV_8UC(thresh.channels()));
        
        
        thresholdedImage = [[self class] UIImageFromCVMat:frameDelta];
        
        
//        avgImg.release();
        frameDelta1.release();
        frameDelta2.release();
        frameDelta.release();
        thresh.release();

        
    }
    
    // add grayscale version to ringbuffer
    _ring.push_back(gray);

    if (_ring.size() > 2) {
        Mat temp = _ring.front();
        _ring.pop_front();
        temp.release();
    }
    
    return thresholdedImage;
    
}

- (float)computeMotionIntensity:(UIImage *)img {

    double motionValue = 0;
    
    cv::Mat image = [[self class] cvMatFromUIImage:img];
    CGFloat ogCols = image.cols;
    CGFloat ogRows = image.rows;
    CGFloat ratio = ogCols/ogRows;
    
    cv::resize(image, image, cv::Size(ratio * 360, 360));
    
    
    CGFloat cols = image.cols;
    CGFloat rows = image.rows;
    
    // convert to grayscale and blur
    cv::Mat gray(rows, cols, CV_32FC1);
    cv::cvtColor(image, gray, CV_BGRA2GRAY);
    //    cv::GaussianBlur(gray, gray, cv::Size(gaussianBlurDimension, gaussianBlurDimension), 0);
    
    if (_ring.size() >= 2) {
        
        // compute the absolute difference between the current frame and past
        cv::Mat frameDelta1(rows, cols, 0);
        cv::Mat frameDelta2(rows, cols, 0);
        cv::Mat frameDelta(rows, cols, 0);
        cv::absdiff(_ring[0], _ring[1],frameDelta1);
        cv::absdiff(_ring[1], gray, frameDelta2);
        cv::bitwise_or(frameDelta1, frameDelta2, frameDelta);
        
        
        // Apply threshold
        cv::Mat thresh;
        cv::threshold(frameDelta, thresh, binaryThreshold, 255, THRESH_BINARY);
        thresh.convertTo(thresh, CV_8UC(thresh.channels()));


        // Find all contours
        std::vector<std::vector<cv::Point> > contours;
        cv::findContours(thresh, contours, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);


        // Count all motion areas
        
        double maxArea = 1.0/25 * rows * cols;
//        double minArea = 1.0/10000 * rows * cols;
//        std::vector<std::vector<cv::Point> > motionAreas;
        for (int i = 0; i < contours.size(); i++) {

            
            double area = cv::contourArea(contours[i]);
            //only count motion above a certain size (filter some artifacts)
            if (area < maxArea){
                
                cv::Rect bound = cv::boundingRect(contours[i]);
                int bottomY = bound.y + bound.height;
                
                double normalizingFactor = double(rows - bottomY)/rows;
                
                double finalArea = area * pow(normalizingFactor, 1.9);
                
                
//                motionAreas.push_back(contours[i]);
                motionValue += finalArea;
//                motionValue += 1;
            }

        }

        frameDelta1.release();
        frameDelta2.release();
        frameDelta.release();
        thresh.release();

    }

    // add grayscale version to ringbuffer
    _ring.push_back(gray);

    if (_ring.size() > 2) {
        Mat temp = _ring.front();
        _ring.pop_front();
        temp.release();
    }

    image.release();
    
    return motionValue;

}


+ (cv::Mat)cvMatFromUIImage:(UIImage *)image {

    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;

}

+ (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;

    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );


    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    return finalImage;
}
#endif


@end
