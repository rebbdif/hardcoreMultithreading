//
//  main.m
//  HardcoreMulthithreading
//
//  Created by iOS-School-1 on 18.05.17.
//  Copyright © 2017 serebryanyy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "pthread.h"

#define SUCCESS 0

//параллельный обход массива и подсчет суммы

static NSArray <NSNumber *> *collection;
static const NSUInteger maxThreadCount = 3;

pthread_mutex_t condVarMutex;
pthread_cond_t condVar;

//task struct
typedef struct Task {
    CFTypeRef collection;
    NSUInteger threadID;
    bool finished;
    NSUInteger sum;
} Task;

void *threadEnumerateArray(void *);
bool checkCondition(Task **);


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        collection = @[@(1),@(2),@(3),@(4),@(5),@(6),@(7),@(8),@(9),@(10),@(11),@(12),@(13),@(14),@(15)];
        
        Task* allThreadArgs[maxThreadCount];
        pthread_mutex_init(&condVarMutex,NULL);
        pthread_cond_init(&condVar,NULL);
        
        NSInteger addition = collection.count%maxThreadCount;
        
        //Fork
        for (NSUInteger i=0; i<maxThreadCount; ++i) {
            
            NSUInteger length = collection.count/maxThreadCount;
            NSUInteger step = collection.count/maxThreadCount;
            
            if (addition!=0 && i==(maxThreadCount-1)) {
                length = length +addition;
            }
            
            NSRange subarrayRange = NSMakeRange(i*step, length);
            pthread_t thread;
            Task *args = malloc(sizeof(Task));
            args->threadID=i;
            args->collection = (void *)CFBridgingRetain([collection subarrayWithRange:subarrayRange]);
            args->finished = false;
            allThreadArgs[i] = args;
            pthread_create(&thread, NULL, threadEnumerateArray, args);
        }
        
        pthread_mutex_lock(&condVarMutex);
        
        
        //condvar waiting
        while (!checkCondition(allThreadArgs)) {
            pthread_cond_wait(&condVar, &condVarMutex);
        }
        
        //join
        NSUInteger result =0;
        for (NSUInteger i=0; i<maxThreadCount;++i) {
            Task*args=allThreadArgs[i];
            result = result +args->sum;
        }
        NSLog(@"fork-join result %lu", result);
        
        for ( NSUInteger i=0; i<maxThreadCount; ++i) {
            Task *args = allThreadArgs[i];
            free(args);
            args = NULL;
        }
        pthread_mutex_unlock(&condVarMutex);
        
        pthread_mutex_destroy(&condVarMutex);
        pthread_cond_destroy(&condVar);
     
        //gcdCode
        __block NSInteger gcdResult=0;
        dispatch_apply([collection count], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index) {
            gcdResult = gcdResult +collection[index].integerValue;
        });
        NSLog(@"gcdResult %ld",(long)gcdResult);
        //
        
    }
    return 0;
}

bool checkCondition(Task **threadArguments) {
    bool result = true;
    for (NSUInteger i=0; i<maxThreadCount;++i){
        result = result & threadArguments[i]->finished;
    }
    return result;
}

void* threadEnumerateArray(void *args){
    Task* arguments = (Task*)args;
    NSArray<NSNumber*> *array = (NSArray<NSNumber*> *)CFBridgingRelease(arguments->collection);
    NSUInteger sum =0;
    
    for (NSNumber *number in array){
        sum = sum+number.integerValue;
        NSLog(@"thread: %lu number: %@",arguments->threadID, number);
    }
    
    pthread_mutex_lock(&condVarMutex);
    arguments->finished = true;
    arguments->sum = sum;
    pthread_cond_signal(&condVar);
    pthread_mutex_unlock(&condVarMutex);
    return SUCCESS;
}

