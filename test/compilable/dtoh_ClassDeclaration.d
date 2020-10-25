/++
REQUIRED_ARGS: -HC -c -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
// Automatically generated by Digital Mars D Compiler

#pragma once

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <math.h>

#ifdef CUSTOM_D_ARRAY_TYPE
#define _d_dynamicArray CUSTOM_D_ARRAY_TYPE
#else
/// Represents a D [] array
template<typename T>
struct _d_dynamicArray
{
    size_t length;
    T *ptr;

    _d_dynamicArray() : length(0), ptr(NULL) { }

    _d_dynamicArray(size_t length_in, T *ptr_in)
        : length(length_in), ptr(ptr_in) { }

    T& operator[](const size_t idx) {
        assert(idx < length);
        return ptr[idx];
    }

    const T& operator[](const size_t idx) const {
        assert(idx < length);
        return ptr[idx];
    }
};
#endif

class C;
class A;
struct Inner;

class C
{
public:
    int8_t a;
    int32_t b;
    int64_t c;
};

class C2
{
public:
    int32_t a;
    int32_t b;
    int64_t c;
    C2(int32_t a);
    virtual const C* const constRet();
    virtual void constPar(const C* const c);
    virtual void constThis() const;
};

class Aligned
{
public:
    int8_t a;
    int32_t b;
    int64_t c;
    Aligned(int32_t a);
};

class A
{
public:
    int32_t a;
    C* c;
    virtual void foo();
    extern "C" virtual void bar();
    virtual void baz(int32_t x = 42);
    struct
    {
        int32_t x;
        int32_t y;
    };
    union
    {
        int32_t u1;
        char u2[4$?:32=u|64=LLU$];
    };
    struct Inner
    {
        int32_t x;
        Inner() :
            x()
        {
        }
        Inner(int32_t x) :
            x(x)
            {}
    };

    class InnerC
    {
    public:
        int32_t x;
    };

    class NonStaticInnerC
    {
    public:
        int32_t x;
        A* this;
    };

    typedef Inner I;
    class CC;

};

class I1
{
public:
    virtual void foo() = 0;
};

class I2 : public I1
{
public:
    virtual void bar() = 0;
};

class B : public A, public I1, public I2
{
public:
    void foo();
    void bar();
};

class Parent
{
    virtual void __vtable_slot_0();
    virtual void __vtable_slot_1();
public:
    virtual void foo();
};

class Child final : public Parent
{
public:
    void foo() /* const */;
};
---
+/

/*
ClassDeclaration has the following issues:
  * align(n) does nothing. You can use align on classes in C++, though It is generally regarded as bad practice and should be avoided
*/

extern (C++) class C
{
    byte a;
    int b;
    long c;
}

extern (C++) class C2
{
    int a = 42;
    int b;
    long c;

    this(int a) {}

    const(C) constRet() { return null; }
    void constPar(const C c) {}
    void constThis() const {}
}

extern (C) class C3
{
    int a = 42;
    int b;
    long c;

    this(int a) {}
}

extern (C++) align(1) class Aligned
{
    byte a;
    int b;
    long c;

    this(int a) {}
}

extern (C++) class A
{
    int a;
    C c;

    void foo();
    extern (C) void bar() {}
    extern (C++) void baz(int x = 42) {}

    struct
    {
        int x;
        int y;
    }

    union
    {
        int u1;
        char[4] u2;
    }

    struct Inner
    {
        int x;
    }

    static extern(C++) class InnerC
    {
        int x;
    }

    class NonStaticInnerC
    {
        int x;
    }

    alias I = Inner;

    extern(C++) class CC;

}

extern(C++):
interface I1
{
    void foo();
}
interface I2 : I1
{
    void bar();
}

class B : A, I1, I2
{
    override void foo() {}
    override void bar() {}
}

class Parent
{
    extern(D) void over() {}
    extern(D) void over(int) {}
    void foo() {}
}

final class Child : Parent
{
    extern(D) override void over() {}
    override void foo() const {}
}
