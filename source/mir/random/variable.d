/++
Authors: Ilya Yaroshenko, Sebastian Wilzbach (Discrete)
Copyright: Copyright, Ilya Yaroshenko 2016-.
License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).

Macros:
    WIKI_D = $(HTTP en.wikipedia.org/wiki/$1_distribution, $1 random variable)
+/
module mir.random.variable;

import mir.random;
import std.traits;

import std.math : nextDown, isFinite, LN2;

import mir.math.internal;

private T sumSquares(T)(const T a, const T b)
{
    return fmuladd(a, a, b * b);
}

/// User Defined Attribute definition for Random Variable.
enum RandomVariable;

/++
Test if T is a random variable.
+/
template isRandomVariable(T)
{
    static if (hasUDA!(T, RandomEngine))
        enum isRandomVariable = is(typeof({
                auto gen = Random(1);
                T rv;
                auto x = rv(gen);
                auto y = rv!Random(gen);
                static assert(is(typeof(x) == typeof(y)));
            }));
    else enum isRandomVariable = false;
}

/++
$(WIKI_D Discrete_uniform).
Returns: `X ~ U[a, b]`
+/
@RandomVariable struct UniformVariable(T)
    if (isIntegral!T)
{
    private alias U = Unsigned!T;
    private U _length;
    private T _location = 0;

    /++
    Constraints: `a <= b`.
    +/
    this(T a, T b)
    {
        assert(a <= b, "constraint: a <= b");
        _length = b - a + 1;
        _location = a;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        return _length ? gen.randIndex!U(_length) + _location : gen.rand!U;
    }

    ///
    T min() @property { return _location; }
    ///
    T max() @property { return _length - 1 + _location; }
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = UniformVariable!int(-10, 10); // [-10, 10]
    auto x = rv(gen); // random variable
    assert(rv.min == -10);
    assert(rv.max == 10);
}

/++
$(HTTP en.wikipedia.org/wiki/Uniform_distribution_(continuous), Uniform distribution (continuous)).
Returns: `X ~ U[a, b)`
+/
@RandomVariable struct UniformVariable(T)
    if (isFloatingPoint!T)
{
    private T _a;
    private T _b;

    /++
    Constraints: `a < b`, `a` and `b` are finite numbers.
    +/
    this(T a, T b)
    {
        assert(a < b, "constraint: a < b");
        assert(a.isFinite);
        assert(b.isFinite);
        _a = a;
        _b = b;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        auto ret =  gen.rand!T.fabs.fmuladd(_b - _a, _a);
        if(ret < _b)
            return ret;
        return max;
    }

    ///
    T min() @property { return _a; }
    ///
    T max() @property { return _b.nextDown; }
}

///
unittest
{
    import std.math : nextDown;
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = UniformVariable!double(-8, 10); // [-8, 10)
    auto x = rv(gen); // random variable
    assert(rv.min == -8.0);
    assert(rv.max == 10.0.nextDown);
}

unittest
{
    import std.math : nextDown;
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = UniformVariable!double(-8, 10); // [-8, 10)
    foreach(_; 0..1000)
    {
        auto x = rv(gen);
        assert(rv.min <= x && x <= rv.max);
    }
}

/++
$(WIKI_D Exponential).
Returns: `X ~ Exp(β)`
+/
@RandomVariable struct ExponentialVariable(T)
    if (isFloatingPoint!T)
{
    private T _scale = T(LN2);

    ///
    this(T scale)
    {
        _scale = T(LN2) * scale;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        return gen.randExponential2!T * _scale;
    }

    ///
    enum T min = 0;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(14);
    auto rv = ExponentialVariable!double(1);
    auto x = rv(gen);
}

/++
$(WIKI_D Weibull).
+/
@RandomVariable struct WeibullVariable(T)
    if (isFloatingPoint!T)
{
    private T _pow = 1;
    private T _scale = 1;

    ///
    this(T shape, T scale = 1)
    {
        _pow = 1 / shape;
        _scale = scale;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        return ExponentialVariable!T()(gen).pow(_pow) * _scale;
    }

    ///
    enum T min = 0;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(13);
    auto rv = WeibullVariable!double(3, 2);
    auto x = rv(gen);
}

/++
$(WIKI_D Gamma).
Returns: `X ~ Gamma(𝝰, 𝞫)`
Params:
    T = floating point type
    Exp = if true log-scaled values are produced. `ExpGamma(𝝰, 𝞫)`.
        The flag is useful when shape parameter is small (`𝝰 << 1`).
+/
@RandomVariable struct GammaVariable(T, bool Exp = false)
    if (isFloatingPoint!T)
{
    private T _shape = 1;
    private T _scale = 1;

    ///
    this(T shape, T scale = 1)
    {
        _shape = shape;
        if(Exp)
            _scale = log(scale);
        else
            _scale = scale;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        T x = void;
        if (_shape > 1)
        {
            T b = _shape - 1;
            T c = fmuladd(3, _shape, - 0.75f);
            for(;;)
            {
                T u = gen.rand!T;
                T v = gen.rand!T;
                T w = (u + 1) * (1 - u);
                T y = sqrt(c / w) * u;
                x = b + y;
                if (!(0 <= x && x < T.infinity))
                    continue;
                auto z = w * v;
                if (z * z * w <= 1 - 2 * y * y / x)
                    break;
                if (fmuladd(3, log(w), 2 * log(fabs(v))) <= 2 * (b * log(x / b) - y))
                    break;
            }
        }
        else
        if (_shape < 1)
        {
            T b = 1 - _shape;
            T c = 1 / _shape;
            for (;;)
            {
                T u = gen.rand!T.fabs;
                T v = gen.randExponential2!T * T(LN2);
                if (u > b)
                {
                    T e = -log((1 - u) * c);
                    u = fmuladd(_shape, e, b);
                    v += e;
                }
                static if (Exp)
                {
                    x = log(u) * c;
                    if (x <= log(v))
                        return x + _scale;
                }
                else
                {
                    x = pow(u, c);
                    if (x <= v)
                        break;
                }
            }
        }
        else
        {
            x = gen.randExponential2!T * T(LN2);
        }
        static if (Exp)
            return log(x) + _scale;
        else
            return x * _scale;
    }

    ///
    enum T min = Exp ? -T.infinity : 0;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = GammaVariable!double(1, 1);
    auto x = rv(gen);
}

/++
$(WIKI_D Chi-squared).
+/
@RandomVariable struct ChiSquaredVariable(T)
    if (isFloatingPoint!T)
{
    private T _shape = 1;

    ///
    this(size_t k)
    {
        _shape = T(k) / 2;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        return GammaVariable!T(_shape, 2)(gen);
    }

    ///
    enum T min = 0;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(32);
    auto rv = ChiSquaredVariable!double(3);
    auto x = rv(gen);
}

/++
$(WIKI_D F).
+/
@RandomVariable struct FisherFVariable(T)
    if (isFloatingPoint!T)
{
    private T _d1 = 1, _d2 = 1;

    ///
    this(T d1, T d2)
    {
        _d1 = d1;
        _d2 = d2;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        auto xv = GammaVariable!T(_d1 * 0.5f);
        auto yv = GammaVariable!T(_d2 * 0.5f);
        auto x = xv(gen);
        auto y = yv(gen);
        x *= _d1;
        y *= _d2;
        return x / y; 
    }

    ///
    enum T min = 0;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(32);
    auto rv = FisherFVariable!double(3, 4);
    auto x = rv(gen);
}

/++
$(WIKI_D Student's_t).
+/
@RandomVariable struct StudentTVariable(T)
    if (isFloatingPoint!T)
{
    private NormalVariable!T _nv;
    private T _nu = 1;

    ///
    this(T nu)
    {
        _nu = nu;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        auto x = _nv(gen);
        auto y = _nu / GammaVariable!T(_nu * 0.5f, 2)(gen);
        if(y < T.infinity)
            x *= y.sqrt;
        return x;
    }

    ///
    enum T min = -T.infinity;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(32);
    auto rv = StudentTVariable!double(10);
    auto x = rv(gen);
}

private T hypot01(T)(const T x, const T y)
{
    // Scale x and y to avoid underflow and overflow.
    // If one is huge and the other tiny, return the larger.
    // If both are huge, avoid overflow by scaling by 1/sqrt(real.max/2).
    // If both are tiny, avoid underflow by scaling by sqrt(real.min_normal*real.epsilon).

    enum T SQRTMIN = 0.5f * sqrt(T.min_normal); // This is a power of 2.
    enum T SQRTMAX = 1 / SQRTMIN; // 2^^((max_exp)/2) = nextUp(sqrt(T.max))

    static assert(2*(SQRTMAX/2)*(SQRTMAX/2) <= T.max);

    // Proves that sqrt(T.max) ~~  0.5/sqrt(T.min_normal)
    static assert(T.min_normal*T.max > 2 && T.min_normal*T.max <= 4);

    T u = fabs(x);
    T v = fabs(y);
    if (u < v)
    {
        auto t = v;
        v = u;
        u = t;
    }

    if (u <= SQRTMIN)
    {
        // hypot (tiny, tiny) -- avoid underflow
        // This is only necessary to avoid setting the underflow
        // flag.
        u *= SQRTMAX / T.epsilon;
        v *= SQRTMAX / T.epsilon;
        return sumSquares(u, v).sqrt * (SQRTMIN * T.epsilon);
    }

    if (u * T.epsilon > v)
    {
        // hypot (huge, tiny) = huge
        return u;
    }

    // both are in the normal range
    return sumSquares(u, v).sqrt;
}

/++
$(WIKI_D Normal).
Returns: `X ~ N(μ, σ)`
+/
@RandomVariable struct NormalVariable(T)
    if (isFloatingPoint!T)
{
    private T _location = 0;
    private T _scale = 1;
    private T y = 0;
    private bool hot;

    ///
    this(T location, T scale = 1)
    {
        _location = location;
        _scale = scale;
    }

    this(this)
    {
        hot = false;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        T x = void;
        if (hot)
        {
            hot = false;
            x = y;
        }
        else
        {
            T u = void;
            T v = void;
            T s = void;
            do
            {
                u = gen.rand!T;
                v = gen.rand!T;
                s = hypot01(u, v);
            }
            while (s > 1 || s == 0);
            s = 2 * sqrt(-log(s)) / s;
            y = v * s;
            x = u * s;
            hot = true;
        }
        return fmuladd(x, _scale, _location);
    }

    ///
    enum T min = -T.infinity;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = NormalVariable!double(0, 1);
    auto x = rv(gen);
}

/++
$(WIKI_D Log-normal).
+/
@RandomVariable struct LogNormalVariable(T)
    if (isFloatingPoint!T)
{
    private NormalVariable!T _nv;

    /++
    Params:
        normalLocation = location of associated normal
        normalScale = scale of associated normal
    +/
    this(T normalLocation, T normalScale = 1)
    {
        _nv = NormalVariable!T(normalLocation, normalScale);
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
       return _nv(gen);
    }

    ///
    enum T min = 0;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = LogNormalVariable!double(0, 1);
    auto x = rv(gen);
}

/++
$(WIKI_D Cauchy).
Returns: `X ~ Cauchy(x, γ)`
+/
@RandomVariable struct CauchyVariable(T)
    if (isFloatingPoint!T)
{
    private T _location = 0;
    private T _scale = 1;

    ///
    this(T location, T scale = 1)
    {
        _location = location;
        _scale = scale;
    }

    ///
    T opCall(G)(ref G gen)
        if (isSaturatedRandomEngine!G)
    {
        T u = void;
        T v = void;
        T x = void;
        do
        {
            u = gen.rand!T;
            v = gen.rand!T;
        }
        while (sumSquares(u, v) > 1 || !(fabs(x = u / v) < T.infinity));
        return fmuladd(x, _scale, _location);
    }

    ///
    enum T min = -T.infinity;
    ///
    enum T max = T.infinity;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    auto rv = CauchyVariable!double(0, 1);
    auto x = rv(gen);
}

/++
$(WIKI_D Bernoulli).
+/
@RandomVariable struct BernoulliVariable(T)
    if (isFloatingPoint!T)
{
    private T p = 0;

    /++
    Params:
        p = `true` probability
    +/
    this(T p)
    {
        assert(0 <= p && p <= 1);
        this.p = p;
    }

    ///
    bool opCall(RNG)(ref RNG gen)
        if (isSaturatedRandomEngine!RNG)
    {
        return gen.rand!T.fabs < p;
    }

    ///
    enum bool min = 0;
    ///
    enum bool max = 1;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(42);
    auto rv = BernoulliVariable!double(0.7);
    size_t[bool] hist;
    foreach(_; 0..1000)
        hist[rv(gen)]++;
    //import std.stdio;
    //writeln(hist);
}

/++
$(WIKI_D Geometric).
+/
@RandomVariable struct GeometricVariable(T)
    if (isFloatingPoint!T)
{
    private T scale = 0;

    /++
    Params:
        p = probability
        reverse = p is success probability if `true` and failure probability otherwise.
    +/
    this(T p, bool success = true)
    {
        assert(0 <= p && p <= 1);
        scale = -1 / log2(success ? 1 - p : p);
    }

    ///
    size_t opCall(RNG)(ref RNG gen)
        if (isSaturatedRandomEngine!RNG)
    {
        auto ret = gen.randExponential2!T * scale;
        return ret < size_t.max ? cast(size_t)ret : size_t.max;
    }

    ///
    enum size_t min = 0;
    ///
    enum size_t max = size_t.max;
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(42);
    auto rv = GeometricVariable!double(0.1);
    size_t[size_t] hist;
    foreach(_; 0..1000)
        hist[rv(gen)]++;
    //import std.stdio;
    //foreach(i; 0..100)
    //    if(auto count = i in hist)
    //        write(*count, ", ");
    //    else
    //        write("0, ");
    //writeln();
}

/++
_Discrete distribution sampler that draws random values from a _discrete
distribution given an array of the respective probability density points (weights).
+/
@RandomVariable struct Discrete(T)
    if (isNumeric!T)
{
    private T[] cdf;

    /++
    The density points `weights`.
    `Discrete` constructor computes comulative density points
    in place without memory allocation.

    Params:
        weights = density points
        comulative = optional flag indiciates if `weights` are already comulative
    +/
    this(T[] weights, bool comulative = false)
    {
        if(!comulative)
        {
            static if (isFloatingPoint!T)
            {
                import mir.math.sum;
                Summator!(T, Summation.kb2) s = 0;
                foreach(ref e; weights)
                {
                    s += e;
                    e = s.sum;
                }
            }
            else
            {
                import mir.math.sum;
                T s = 0;
                foreach(ref e; weights)
                {
                    s += e;
                    e = s;
                }
            }
        }
        this.cdf = weights;
    }

    /++
    Samples a value from the discrete distribution using a custom random generator.
    Complexity:
        `O(log n)` where `n` is the number of `weights`.
    +/
    size_t opCall(RNG)(ref RNG gen)
        if (isSaturatedRandomEngine!RNG)
    {
        import std.range : assumeSorted;
        static if (isFloatingPoint!T)
            T v = gen.rand!T.fabs * cdf[$-1];
        else
            T v = gen.randIndex!(Unsigned!T)(cdf[$-1]);
        return cdf.length - cdf.assumeSorted!"a < b".upperBound(v).length;
    }
}

///
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    // 10%, 20%, 20%, 40%, 10%
    auto weights = [10.0, 20, 20, 40, 10];
    auto ds = Discrete!double(weights);

    // weight is changed to comulative sums
    assert(weights == [10, 30, 50, 90, 100]);

    // sample from the discrete distribution
    auto obs = new uint[weights.length];
    
    foreach (i; 0..1000)
        obs[ds(gen)]++;

    //import std.stdio;
    //writeln(obs);
}

/// Comulative
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);

    auto comulative = [10.0, 30, 40, 90, 120];
    auto ds = Discrete!double(comulative, true);

    // weight is changed to comulative sums
    assert(comulative == [10.0, 30, 40, 90, 120]);

    // sample from the discrete distribution
    auto obs = new uint[comulative.length];
    foreach (i; 0..1000)
        obs[ds(gen)]++;
}

//
unittest
{
    import mir.random.engine.xorshift;
    auto gen = Xorshift(1);
    // 10%, 20%, 20%, 40%, 10%
    auto weights = [10.0, 20, 20, 40, 10];
    auto ds = Discrete!double(weights);

    // weight is changed to comulative sums
    assert(weights == [10, 30, 50, 90, 100]);

    // sample from the discrete distribution
    auto obs = new uint[weights.length];
    foreach (i; 0..1000)
        obs[ds(gen)]++;

    //import std.stdio;
    //writeln(obs);
    //[999, 1956, 2063, 3960, 1022]
}

// test with cumulative probs
unittest
{
    import mir.random.engine.xorshift : Xorshift;
    auto gen = Xorshift(42);

    // 10%, 20%, 20%, 40%, 10%
    auto weights = [0.1, 0.3, 0.5, 0.9, 1];
    auto ds = Discrete!double(weights, true);

    auto obs = new uint[weights.length];
    foreach (i; 0..1000)
        obs[ds(gen)]++;


    //assert(obs == [1030, 1964, 1968, 4087, 951]);
}

// test with cumulative count
unittest
{
    import mir.random.engine.xorshift : Xorshift;
    auto gen = Xorshift(42);

    // 1, 2, 1
    auto weights = [1, 2, 1];
    auto ds = Discrete!int(weights);

    auto obs = new uint[weights.length];
    foreach (i; 0..1000)
        obs[ds(gen)]++;

    //assert(obs == [2536, 4963, 2501]);
}

// test with zero probabilities
unittest
{
    import mir.random.engine.xorshift : Xorshift;
    auto gen = Xorshift(42);

    // 0, 1, 2, 0, 1
    auto weights = [0, 1, 3, 3, 4];
    auto ds = Discrete!int(weights, true);

    auto obs = new uint[weights.length];
    foreach (i; 0..1000)
        obs[ds(gen)]++;

    assert(obs[3] == 0);
}
