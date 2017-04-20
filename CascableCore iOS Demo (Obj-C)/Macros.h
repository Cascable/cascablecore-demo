//
//  Macros.h
//  CascableCore Demo
//
//  Created by Daniel Kennett on 2017-04-19.

#ifndef Macros_h
#define Macros_h

/// Returns a string containing the current file name.
#define THIS_FILE [@(__FILE__) lastPathComponent]

/// Creates a weak reference to the given value.
#define CBLWeakify(var) __weak typeof(var) CBLWeak_##var = var;

/// Creates a strong reference to a previously weakified value.
#define CBLStrongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = CBLWeak_##var; \
_Pragma("clang diagnostic pop")

/// Returns a string for the given key path. This allows us to have compile-time checking of key paths.
#define CBLKeyPath(object, property) ((void)(NO && ((void)object.property, NO)), @#property)

#endif /* Macros_h */
