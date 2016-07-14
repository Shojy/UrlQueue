//
//  UrlQueue.h
//  UrlQueue
//
//  Created by Joshua Moon on 13/07/2016.
//  Copyright © 2016 Joshua Moon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SJYUrlQueue : NSObject
/**
 Gets the shared queue, setup with default settings. This will always return the same instance of the queue, and is
 recommended for general use.
 
 @return The singleton instance queue.
 */
+(id) sharedQueue;

/**
 Initializes a new instance with the shared session and a connection limit of 3.
 
 iOS9 can handle 4 simultaneous connections to a single server before issues start arising. A limit of 3 here allows a
 second queue to be run with a limit of 1 for the same server (for more urgent requests that shouldn't wait, for example).
 
 @return An instance of UrlQueue with default parameters.
 @see initWithConnectionLimit:
 @see initWithConnectionLimit:andSession:
 */
-(instancetype) init;

/**
 Initializes a new instance with the shared session and a user-defined connection limit.
 
 @param limit The maximum number of concurrent connections to make. A value of 0 will enforce no limit, and all requests
 will be run immediately.
 @return An instance of UrlQueue with default parameters.
 @see initWithConnectionLimit:andSession:
 @warning iOS9 can handle up to 4 simultaneous connections to a single server. You should ensure the connection limit
 does not exceed this if you need to make all your requests from the same server.
 */
-(instancetype) initWithConnectionLimit:(NSUInteger)limit;

/**
 Initializes a new instance with a user-defined session and connection limit.
 
 @param limit The maximum number of concurrent connections to make. A value of 0 will enforce no limit, and all requests
 will be run immediately.
 @param session The NSURLSession to use for the requests. Usually you will want to just use the sharedSession.
 @return An instance of UrlQueue with default parameters.
 @warning iOS9 can handle up to 4 simultaneous connections to a single server. You should ensure the connection limit
 does not exceed this if you need to make all your requests from the same server.
 @warning The simultaneous connections limit is cumulative over all sessions. Even with 5 sessions, only 4 of them can
 connect to the same server.
 */
-(instancetype) initWithConnectionLimit:(NSUInteger)limit andSession:(NSURLSession *)session;

/**
 Gets the number of requests in the queue that haven't yet completed.
 */
-(NSUInteger)numberOfUncompletedRequestsInQueue;

/**
 Gets the total number of both complete and incomplete requests in the queue.
 */
-(NSUInteger)numberOfRequestsInQueue;

/**
 Gets the number of completed requests in the queue.
 */
-(NSUInteger)numberOfRequestsCompleted;

/**
 Gets a value indicating if the queue is busy processing a request or not.
 */
-(bool)queueIsBusy;

/**
 Queues a request for execution as a data request. The task will be started when it reaches its position in the queue. It
 will retry the connection a number of times by requeuing in the event of an error.
 
 @param request The URL request to queue and execute.
 @param completionHandler Block to be executed whenever an attempt is completed. This will be called whether the request
 is successful or not. If the request has been requeued, the reattempting flag will be set to YES.
 @param attempts The maximum number of attempts to make before giving up. A value of 0 or negative will continue to attempt
 until successful response is complete.
 @return A pointer to the actual task in the queue.
 @warning Although the task is returned, you should avoid controlling it directly. It is provided for monitoring purposes
 rather than direct control. It will be started when its place in the queue is reached, and doing so earlier may result
 in problems for this request, or others, particularly in respect to the iOS concurrent connection limits.
 */
-(NSURLSessionTask*) queueDataRequest:(NSURLRequest*)request withCompletionHandler:(void (NSData *data, NSURLResponse *response, NSError *error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts;


-(NSURLSessionTask*) queueUploadRequest:(NSURLRequest*)request withFile:(NSURL*)filePath andCompletionHandler:(void (NSData *data, NSURLResponse *response, NSError *error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts;


-(NSURLSessionTask*) queueUploadRequest:(NSURLRequest*)request withData:(NSData*)data andCompletionHandler:(void (NSData *data, NSURLResponse *response, NSError *error, bool reattempting))completionHandler andMaxAttempts:(NSInteger)attempts;



@end
