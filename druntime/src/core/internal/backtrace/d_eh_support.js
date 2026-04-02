/**
 * d_eh_support.js — Emscripten JS library for D exception handling.
 *
 * Overrides ___throw_exception_with_stack_trace, which Emscripten
 * unconditionally hooks into every __cxa_throw call to display a type name.
 * The default implementation calls __get_exception_message → __dynamic_cast
 * on the C++ type_info pointer, which crashes when type_info is NULL (as D
 * exceptions pass to __cxa_throw).
 *
 * Our override skips the type-name lookup entirely and just throws the
 * WebAssembly.Exception directly with a fixed "D exception" message.
 *
 * This file is shipped alongside libdruntime-ldc.a and automatically picked
 * up by ldc2-emcc.sh when LDC2_RTDIR points to the druntime build directory.
 */
addToLibrary({
  __throw_exception_with_stack_trace__deps: ['$getCppExceptionTag'],
  __throw_exception_with_stack_trace: function(ex) {
    var e = new WebAssembly.Exception(getCppExceptionTag(), [ex], {traceStack: true});
    e.message = 'D exception';
    throw e;
  },
});
