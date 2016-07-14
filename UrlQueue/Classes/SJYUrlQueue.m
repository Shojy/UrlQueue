//
//  UrlQueue.m
//  UrlQueue
//
//  Created by Joshua Moon on 13/07/2016.
//  Copyright © 2016 Joshua Moon. All rights reserved.
//

#import "SJYUrlQueue.h"

@interface SJYUrlQueue()

@property (strong, nonatomic) NSMutableArray* requestQueue;
@property (strong, nonatomic) NSMutableDictionary* requestAttempts;
@property bool isBusy;
@property NSUInteger connectionLimit;
@property NSUInteger numberCompleted;
@property NSUInteger currentQueueIndex;
@property NSURLSession* session;
@property NSUInteger maximumAttempts;


/**
 Recreates the upload or data request, and adds it back to the queue, as if it were a new task, with the reduced attempt
 counter.
 
 @param request The request that failed to complete.
 @param asUpload Boolean flag indicating if this request is an upload request. Handled as data if False.
 @param data The data to be attached as the body of the request.
 @param completionHandler The completion handler assigned for calling as a task completes.
 @param attempts The pre-reduced number of remaining attempts.
 @return Boolean value indicating whether the task was allowed to retry.
 */
-(bool)requeueRequest:(NSURLRequest*)request asUpload:(bool)upload withData:(NSData*)data andCompletionHandler:(void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, bool reattempting))completionHandler andAttempts:(NSInteger)attempts;

/**
 Recreates the download request, and adds it back to the queue, as if it were a new task, with the reduced attempt counter.
 
 @param task The task that failed to complete.
 @param completionHandler The completion handler assigned for calling as a task completes.
 @param attempts The pre-reduced number of remaining attempts.
 @return Boolean value indicating whether the task was allowed to retry.
 */
-(bool)requeueDownloadRequest:(NSURLRequest*)request withCompletionHandler:(void (NSURL *url, NSURLResponse *response, NSError *error, bool reattempting))completionHandler andAttempts:(NSInteger)attempts;


/**
 Checks if a request can be reattempted based on the number of remaining attempts. If the remaining attempts is equal to
 0, then the request would be denied. If positive or negative, the request would be allowed. Negative values indicate a
 no-limit request.
 
 @param tries The number of attempts remaining.
 @return Boolean value indicating whether the request should be permitted to try again.
 */
-(bool)canReattemptWithRemainingTries:(NSInteger)tries;

/**
 Advances to the next request in the queue and begins execution.
 */
-(void) makeNextRequest;

@end

@implementation SJYUrlQueue

#pragma mark Instance Creation


-(instancetype)init
{
    return [self initWithConnectionLimit:4];
}

-(instancetype) initWithConnectionLimit:(NSUInteger)limit
{
    return [self initWithConnectionLimit:limit andSession:[NSURLSession sharedSession]];
}

-(instancetype) initWithConnectionLimit:(NSUInteger)limit andSession:(NSURLSession *)session
{
    self.connectionLimit = limit;
    self.session = session;
    self.requestQueue = [NSMutableArray new];
    self.requestAttempts = [NSMutableDictionary new];
    self.currentQueueIndex = 0;
    self.maximumAttempts = 3;
    return self;
}


+(id) sharedQueue
{
    static SJYUrlQueue* queue = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        queue = [[self alloc] init];
    });
    
    return queue;
}

#pragma mark Queue Control



-(NSURLSessionTask*) queueDataRequest:(NSURLRequest*)request withCompletionHandler:(void (NSData *data, NSURLResponse *response, NSError *error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts
{
    __typeof__ (self) __weak weakSelf = self;
    NSLog(@"Queued %@", request.URL);
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
                                                
                                                weakSelf.numberCompleted++;
                                                bool isReattempting = NO;
                                                
                                                if(error) {
                                                    NSInteger tries;
                                                    if(0 > attempts) {
                                                        tries = -1;
                                                    } else {
                                                        tries = attempts - 1;
                                                    }
                                                    isReattempting = [self requeueRequest:request
                                                                                 asUpload:YES
                                                                                 withData:nil
                                                                     andCompletionHandler:completionHandler
                                                                              andAttempts:tries];
                                                }
                                                
                                                if(completionHandler) {
                                                    completionHandler(data, response, error, isReattempting);
                                                }
                                                
                                                [weakSelf makeNextRequest];
                                            }];
    
    
    [self.requestQueue addObject:task];
    
    
    if(!self.isBusy || (self.currentQueueIndex - self.numberCompleted) < self.connectionLimit) {
        [self makeNextRequest];
    }
    
    return task;
}


-(NSURLSessionTask*) queueDownloadRequest:(NSURLRequest*)request withCompletionHandler:(void (NSURL * _Nullable url, NSURLResponse * _Nullable response, NSError * _Nullable error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts
{
    __typeof__ (self) __weak weakSelf = self;
    NSLog(@"Queued %@", request.URL);
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request
                                                    completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                        
                                                        
                                                        weakSelf.numberCompleted++;
                                                        bool isReattempting = NO;
                                                        
                                                        if(error) {
                                                            NSInteger tries;
                                                            if(0 > attempts) {
                                                                tries = -1;
                                                            } else {
                                                                tries = attempts - 1;
                                                            }
                                                            isReattempting = [self requeueDownloadRequest:request
                                                                                    withCompletionHandler:completionHandler
                                                                                              andAttempts:tries];
                                                        }
                                                        
                                                        if(completionHandler) {
                                                            completionHandler(location, response, error, isReattempting);
                                                        }
                                                        
                                                        [weakSelf makeNextRequest];
                                                    }];
    
    
    [self.requestQueue addObject:task];
    
    
    if(!self.isBusy || (self.currentQueueIndex - self.numberCompleted) < self.connectionLimit) {
        [self makeNextRequest];
    }
    
    return task;
}

-(NSURLSessionTask*) queueUploadRequest:(NSURLRequest*)request withFile:(NSURL*)filePath andCompletionHandler:(void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts
{
    __typeof__ (self) __weak weakSelf = self;
    NSLog(@"Queued %@", request.URL);
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task = [session uploadTaskWithRequest:request
                                                       fromFile:filePath
                                              completionHandler:^(NSData * _Nullable retdata, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                  weakSelf.numberCompleted++;
                                                  bool isReattempting = NO;
                                                  
                                                  if(error) {
                                                      NSInteger tries;
                                                      if(0 > attempts) {
                                                          tries = -1;
                                                      } else {
                                                          tries = attempts - 1;
                                                      }
                                                      isReattempting = [self requeueRequest:request
                                                                                   asUpload:YES
                                                                                   withData:nil
                                                                       andCompletionHandler:completionHandler
                                                                                andAttempts:tries];
                                                  }
                                                  
                                                  if(completionHandler) {
                                                      completionHandler(retdata, response, error, isReattempting);
                                                  }
                                                  
                                                  [weakSelf makeNextRequest];
                                              }];
    
    
    [self.requestQueue addObject:task];
    
    
    if(!self.isBusy || (self.currentQueueIndex - self.numberCompleted) < self.connectionLimit) {
        [self makeNextRequest];
    }
    
    return task;
}


-(NSURLSessionTask*) queueUploadRequest:(NSURLRequest*)request withData:(NSData*)data andCompletionHandler:(void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts
{
    __typeof__ (self) __weak weakSelf = self;
    NSLog(@"Queued %@", request.URL);
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task = [session uploadTaskWithRequest:request
                                                       fromData:data
                                              completionHandler:^(NSData * _Nullable retdata, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                  weakSelf.numberCompleted++;
                                                  bool isReattempting = NO;
                                                  
                                                  if(error) {
                                                      NSInteger tries;
                                                      if(0 > attempts) {
                                                          tries = -1;
                                                      } else {
                                                          tries = attempts - 1;
                                                      }
                                                      
                                                      isReattempting = [self requeueRequest:request
                                                                                   asUpload:YES
                                                                                   withData:data
                                                                       andCompletionHandler:completionHandler
                                                                                andAttempts:tries];
                                                  }
                                                  
                                                  if(completionHandler) {
                                                      completionHandler(retdata, response, error, isReattempting);
                                                  }
                                                  
                                                  [weakSelf makeNextRequest];
                                              }];
    
    
    [self.requestQueue addObject:task];
    
    
    if(!self.isBusy || (self.currentQueueIndex - self.numberCompleted) < self.connectionLimit) {
        [self makeNextRequest];
    }
    
    return task;
}



-(bool)requeueRequest:(NSURLRequest*)request asUpload:(bool)upload withData:(NSData*)data andCompletionHandler:(void (NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error, bool reattempting))completionHandler andAttempts:(NSInteger)attempts
{
    if(![self canReattemptWithRemainingTries:attempts]) {
        return NO;
    }
    
    //NSURLRequest* request = task.originalRequest;
    //NSData *data = request.HTTPBody;
    
    if(upload) {
        [self queueUploadRequest:request withData:data andCompletionHandler:completionHandler andMaxAttempts:attempts];
    }
    else {
        [self queueDataRequest:request withCompletionHandler:completionHandler andMaxAttempts:attempts];
    }
    
    return YES;
}


-(bool)requeueDownloadRequest:(NSURLRequest*)request withCompletionHandler:(void (NSURL * _Nullable url, NSURLResponse * _Nullable response, NSError * _Nullable error, bool reattempting))completionHandler andAttempts:(NSInteger)attempts
{
    if(![self canReattemptWithRemainingTries:attempts]) {
        return NO;
    }
    
    //NSURLRequest* request = task.originalRequest;
    
    [self queueDownloadRequest:request withCompletionHandler:completionHandler andMaxAttempts:attempts];
    
    return YES;
}

-(bool)canReattemptWithRemainingTries:(NSInteger)tries
{
    if(tries == 0) {
        return NO;
    }
    return YES;
}

-(void) makeNextRequest
{
    if(self.currentQueueIndex >= [self.requestQueue count]) {
        self.isBusy = NO;
        return;
    }
    self.isBusy = YES;
    
    NSURLSessionTask *task = self.requestQueue[self.currentQueueIndex];
    
    NSLog(@"Starting download %@", [task currentRequest]);
    [task resume];
    
    self.currentQueueIndex++;
}

#pragma mark Stats

-(NSUInteger)numberOfRequestsInQueue
{
    return [self.requestQueue count];
}

-(NSUInteger)numberOfRequestsCompleted
{
    return self.numberCompleted;
}

-(NSUInteger)numberOfUncompletedRequestsInQueue
{
    return [self numberOfRequestsInQueue] - [self numberOfRequestsCompleted];
}

-(bool)queueIsBusy
{
    return self.isBusy;
}


@end
