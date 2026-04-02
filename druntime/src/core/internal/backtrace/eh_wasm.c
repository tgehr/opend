/*
 * eh_wasm.c — Wasm EH throw/catch shim for druntime
 *
 * Uses the Wasm 'throw' instruction (via __builtin_wasm_throw) to throw D
 * exceptions.  The catch side uses 'catch 0' (emitted by our trycatchfinally.cpp
 * changes) which retrieves the thrown pointer via llvm.wasm.get.exception.
 *
 * Both sides use the new-style Wasm EH proposal (throw/catch with tags),
 * which is what emcc's clang 23 emits when -fwasm-exceptions is used.
 *
 * The thrown value is the raw D Throwable pointer — no __cxa_exception
 * wrapper needed.  llvm.wasm.get.exception in the catch block returns this
 * pointer directly, which is then passed to _d_eh_enter_catch/_d_wasm_begin_catch.
 */

/* __builtin_wasm_throw(tag, ptr) lowers to the Wasm 'throw' instruction.
 * Tag 0 is the C++ exception tag (__cpp_exception), which is what emcc
 * registers and what our 'catch 0' blocks intercept.
 */
__attribute__((noreturn))
void _d_wasm_throw(void *throwable) {
    __builtin_wasm_throw(0, throwable);
}

/*
 * _d_wasm_begin_catch(exception_object)
 *
 * Called from D landing pad code (via _d_eh_enter_catch) after catchret
 * exits the funclet.  On the new-style Wasm EH path, the exception pointer
 * from llvm.wasm.get.exception IS the raw Throwable pointer we threw —
 * no unwrapping needed.
 *
 * Returns the Throwable pointer.
 */
void *_d_wasm_begin_catch(void *exception_object) {
    return exception_object;
}

/*
 * _d_wasm_get_throwable(unwind_exception)
 *
 * Called from _d_eh_personality_common to extract the Throwable for type
 * matching.  With new-style Wasm EH, the personality receives the raw
 * Throwable pointer directly as the exception value.
 */
void *_d_wasm_get_throwable(void *unwind_exception) {
    return unwind_exception;
}


