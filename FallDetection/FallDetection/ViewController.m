//
//  ViewController.m
//  FallDetection
//
//  Created by akshay on 11/1/18.
//  Copyright © 2018 akshay. All rights reserved.
//
#import "ViewController.h"
#include "math.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    currentMaxAccelX = 0;
    currentMaxAccelY = 0;
    currentMaxAccelZ = 0;
    
    currentMaxRotX = 0;
    currentMaxRotY = 0;
    currentMaxRotZ = 0;
//    gravity =  [-1.0, 0.0, 0.0]; //assumed "correct" orientation
    self.gravity = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithDouble:-1.0], [NSNumber numberWithDouble:0.0], [NSNumber numberWithDouble:0.0], nil];
    self.avg = [[NSMutableArray alloc] init];
    queueSum = 0;
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = 1; //(1/Hz)
    self.motionManager.gyroUpdateInterval = 1;
    
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                             withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
                                                 [self outputAccelerationData:accelerometerData.acceleration];
                                                 if(error){
                                                     
                                                     NSLog(@"%@", error);
                                                 }
                                             }];
    
    [self.motionManager startGyroUpdatesToQueue:[NSOperationQueue currentQueue]
                                    withHandler:^(CMGyroData *gyroData, NSError *error) {
                                        [self outputRotationData:gyroData.rotationRate];
                                    }];
}

-(void)outputAccelerationData:(CMAcceleration)acceleration {
    
    self.accX.text = [NSString stringWithFormat:@" %.2fg",acceleration.x];
    if(fabs(acceleration.x) > fabs(currentMaxAccelX)) {
        currentMaxAccelX = acceleration.x;
    }
    self.accY.text = [NSString stringWithFormat:@" %.2fg",acceleration.y];
    if(fabs(acceleration.y) > fabs(currentMaxAccelY)) {
        currentMaxAccelY = acceleration.y;
    }
    self.accZ.text = [NSString stringWithFormat:@" %.2fg",acceleration.z];
    if(fabs(acceleration.z) > fabs(currentMaxAccelZ)) {
        currentMaxAccelZ = acceleration.z;
    }
    
    self.maxAccX.text = [NSString stringWithFormat:@" %.2f",currentMaxAccelX];
    self.maxAccY.text = [NSString stringWithFormat:@" %.2f",currentMaxAccelY];
    self.maxAccZ.text = [NSString stringWithFormat:@" %.2f",currentMaxAccelZ];
    
    double gx = [[self.gravity objectAtIndex:0] doubleValue];
    double gy = [[self.gravity objectAtIndex:1] doubleValue];
    double gz = [[self.gravity objectAtIndex:2] doubleValue];
    
    double dot = acceleration.x * gx + acceleration.y * gy + acceleration.z * gz;
    double gnorm = sqrt(gx*gx + gy*gy + gz*gz);
    double vnorm = sqrt(acceleration.x*acceleration.x + acceleration.y*acceleration.y + acceleration.z*acceleration.z);
    if (!((gnorm == 0) || (vnorm == 0))) {
        dot /= gnorm * vnorm;
    } else {
        dot /= 0.00001;
    }
    
    int offAngle = 0;
    double anglediff = acos(dot) * 180 / M_PI;
    if (anglediff > 10) {
        offAngle = 1;
        //NSLog(@"Not Level");
    }
    if ([self.avg count] > 15) {
        queueSum -= [self pop];
    }
    queueSum += offAngle;
    [self push:offAngle];
    BOOL fallen = (BOOL) lroundf(((float) queueSum) / [self.avg count]);
    NSLog(@"%d", fallen);
    
    self.angle.text = [NSString stringWithFormat:@" %.2f", anglediff];
}

-(void)push:(int)angle {
    [self.avg addObject:[NSNumber numberWithInt:angle]];
}

-(int)pop {
    int popped = [[self.avg objectAtIndex:0] intValue];
    [self.avg removeObjectAtIndex:0];
    return popped;
}

-(void)outputRotationData:(CMRotationRate)rotation {
    
    self.rotX.text = [NSString stringWithFormat:@" %.2fr/s",rotation.x];
    if(fabs(rotation.x) > fabs(currentMaxRotX)) {
        currentMaxRotX = rotation.x;
    }
    self.rotY.text = [NSString stringWithFormat:@" %.2fr/s",rotation.y];
    if(fabs(rotation.y) > fabs(currentMaxRotY)) {
        currentMaxRotY = rotation.y;
    }
    self.rotZ.text = [NSString stringWithFormat:@" %.2fr/s",rotation.z];
    if(fabs(rotation.z) > fabs(currentMaxRotZ)) {
        currentMaxRotZ = rotation.z;
    }
    
    self.maxRotX.text = [NSString stringWithFormat:@" %.2f",currentMaxRotX];
    self.maxRotY.text = [NSString stringWithFormat:@" %.2f",currentMaxRotY];
    self.maxRotZ.text = [NSString stringWithFormat:@" %.2f",currentMaxRotZ];
}

- (IBAction)resetMaxValues:(id)sender {
    
    currentMaxAccelX = 0;
    currentMaxAccelY = 0;
    currentMaxAccelZ = 0;
    currentMaxRotX = 0;
    currentMaxRotY = 0;
    currentMaxRotZ = 0;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationPortrait) forKey:@"orientation"];
    [UINavigationController attemptRotationToDeviceOrientation];
}


@end
