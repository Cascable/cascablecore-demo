//
//  Macros.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.
//
//

#ifndef Macros_h
#define Macros_h

#define THIS_FILE [@(__FILE__) lastPathComponent]

#define CBLWeakify(var) __weak typeof(var) CBLWeak_##var = var;

#define CBLStrongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = CBLWeak_##var; \
_Pragma("clang diagnostic pop")

#define CBLKeyPath(object, property) ((void)(NO && ((void)object.property, NO)), @#property)

#endif /* Macros_h */
