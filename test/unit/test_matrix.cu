#include <numeric>
#include <random>
#include <vector>

#include <cuda.h>

#include <arbor/math.hpp>

#include "algorithms.hpp"
#include "matrix.hpp"
#include "memory/memory.hpp"
#include "util/span.hpp"

#include "backends/gpu/cuda_common.hpp"
#include "backends/gpu/matrix_state_flat.hpp"
#include "backends/gpu/matrix_state_interleaved.hpp"
#include "backends/gpu/matrix_interleave.hpp"

#include "../gtest.h"
#include "common.hpp"


using namespace arb;

using gpu::impl::npos;
using util::make_span;
using util::assign_from;
using memory::on_gpu;
using memory::on_host;

using testing::seq_almost_eq;

using std::begin;
using std::end;


// Test the flat_to_interleaved and interleaved_to_flat operations for the
// set of matrices defined by sizes and starts.
// Applies the interleave to the vector in values, and checks this against
// a reference result generated using a host side reference implementation.
// Then the interleave result is reverse_interleaved, and the result is
// compared to the original input.
//
// This is implemented in a separate function to facilitate testing on a
// broad range of BlockWidth and LoadWidth compile time parameters.
template <typename T, typename I, int BlockWidth, int LoadWidth>
::testing::AssertionResult test_interleave(
        std::vector<I> sizes,
        std::vector<I> starts,
        std::vector<T> values,
        int padded_size)
{
    auto num_mtx = sizes.size();

    auto in  = on_gpu(memory::make_const_view(values));
    auto sizes_d = on_gpu(memory::make_const_view(sizes));
    auto starts_d = on_gpu(memory::make_const_view(starts));

    int packed_size = padded_size * BlockWidth * gpu::impl::block_count(num_mtx, BlockWidth);

    // forward will hold the result of the interleave operation on the GPU
    auto forward = memory::device_vector<T>(packed_size, npos<T>());

    // find the reference interleaved values using host side implementation
    auto baseline = gpu::flat_to_interleaved(values, sizes, starts, BlockWidth, num_mtx, padded_size);

    // find the interleaved values on gpu
    gpu::flat_to_interleaved<T, I, BlockWidth, LoadWidth>(in.data(), forward.data(), sizes_d.data(), starts_d.data(), padded_size, num_mtx);

    std::vector<T> result_f = assign_from(on_host(forward));
    std::vector<T> expected = gpu::flat_to_interleaved(values, sizes, starts, BlockWidth, num_mtx, padded_size);
    const auto forward_success = (result_f==expected);
    if (!forward_success) {
        return ::testing::AssertionFailure() << "interleave to flat failed: BlockWidth "
            << BlockWidth << ", LoadWidth " << LoadWidth << "\n";
    }

    // backward will hold the result of reverse interleave on the GPU
    auto backward = memory::device_vector<T>(values.size(), npos<T>());
    gpu::interleaved_to_flat<T, I, BlockWidth, LoadWidth>(forward.data(), backward.data(), sizes_d.data(), starts_d.data(), padded_size, num_mtx);

    std::vector<T> result_b = assign_from(on_host(backward));

    // we expect that the result of the reverse permutation is the original input vector
    const auto backward_success = (result_b==values);
    if (!backward_success) {
        return ::testing::AssertionFailure() << "flat to interleave failed: BlockWidth "
            << BlockWidth << ", LoadWidth " << LoadWidth << "\n";
    }

    return ::testing::AssertionSuccess();
}

// test conversion to and from interleaved back end storage format
TEST(matrix, interleave)
{
    using I = int;
    using T = int;
    using ivec = std::vector<I>;
    using tvec = std::vector<T>;

    // simple case with 4 matrices of length 2
    {
        const int padded_size = 2;
        const int num_mtx = 4;
        ivec sizes(num_mtx, padded_size);

        // find the start position of each matrix in the flat storage
        // we are assuming that the matrices are unpermuted
        ivec starts(num_mtx, 0);
        std::partial_sum(begin(sizes), end(sizes)-1, begin(starts)+1);

        tvec values(padded_size*num_mtx);
        std::iota(values.begin(), values.end(), 0);

        EXPECT_TRUE((test_interleave<T, I, 1, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 2, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 3, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 4, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 5, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 6, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 7, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 8, 1>(sizes, starts, values, padded_size)));

        EXPECT_TRUE((test_interleave<T, I, 1, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 2, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 3, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 4, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 5, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 6, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 7, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 8, 2>(sizes, starts, values, padded_size)));

        EXPECT_TRUE((test_interleave<T, I, 1, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 2, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 3, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 4, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 5, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 6, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 7, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 8, 3>(sizes, starts, values, padded_size)));
    }

    // another small example with matrices of differing lengths
    {
        const int padded_size = 8;
        const int num_mtx = 8;
        ivec sizes = {6, 5, 4, 4, 3, 2, 2, 1};

        // find the start position of each matrix in the flat storage
        // we are assuming that the matrices are unpermuted
        ivec starts(num_mtx, 0);
        std::partial_sum(begin(sizes), end(sizes)-1, begin(starts)+1);

        tvec values(algorithms::sum(sizes));
        std::iota(values.begin(), values.end(), 0);

        EXPECT_TRUE((test_interleave<T, I, 1, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 2, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 3, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 4, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 5, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 6, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 7, 1>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 8, 1>(sizes, starts, values, padded_size)));

        EXPECT_TRUE((test_interleave<T, I, 1, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 2, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 3, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 4, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 5, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 6, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 7, 2>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 8, 2>(sizes, starts, values, padded_size)));

        EXPECT_TRUE((test_interleave<T, I, 1, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 2, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 3, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 4, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 5, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 6, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 7, 3>(sizes, starts, values, padded_size)));
        EXPECT_TRUE((test_interleave<T, I, 8, 3>(sizes, starts, values, padded_size)));
    }

    // more interesting case...
    {
        const int padded_size = 256;
        const int num_mtx = 1000;
        ivec sizes(num_mtx);
        for (auto i: make_span(  0, 100)) sizes[i] = 250;
        for (auto i: make_span(100, 103)) sizes[i] = 213;
        for (auto i: make_span(103, 150)) sizes[i] = 200;
        for (auto i: make_span(150, 500)) sizes[i] = 178;
        for (auto i: make_span(500, 999)) sizes[i] = 6;

        // we are assuming that the matrices are unpermuted
        ivec starts(num_mtx, 0);
        std::partial_sum(begin(sizes), end(sizes)-1, begin(starts)+1);

        tvec values(algorithms::sum(sizes));
        std::iota(values.begin(), values.end(), 0);

        // test in "full" 1024 thread configuration with 32 threads per matrix
        EXPECT_TRUE((test_interleave<T, I, 32, 32>(sizes, starts, values, padded_size)));
    }
}

// test that the flat and interleaved storage back ends produce identical results
TEST(matrix, backends)
{
    using T = fvm_value_type;
    using I = fvm_index_type;

    using state_flat = gpu::matrix_state_flat<T, I>;
    using state_intl = gpu::matrix_state_interleaved<T, I>;

    using gpu_array  = memory::device_vector<T>;

    // There are two matrix structures:
    //
    // p_1: 3 branches, 6 compartments
    //
    //           3
    //          /.
    // 0 - 1 - 2
    //          \.
    //           4
    //            \.
    //             5
    //
    // p_2: 5 branches, 8 compartments
    //
    //             4
    //            /.
    //           3
    //          / \.
    // 0 - 1 - 2   5
    //          \.
    //           6
    //            \.
    //             7

    // The parent indexes that define the two matrix structures
    std::vector<std::vector<I>>
        p_base = { {0,0,1,2,2,4}, {0,0,1,2,3,3,2,6} };

    // Make a set of matrices based on repeating this pattern.
    // We assign the patterns round-robin, i.e. so that the input
    // matrices will have alternating sizes of 6 and 8, which will
    // test the solver with variable matrix size, and exercise
    // solvers that reorder matrices according to size.
    const int num_mtx = 200;

    std::vector<I> p;
    std::vector<I> cell_cv_divs;
    for (auto m=0; m<num_mtx; ++m) {
        auto &p_ref = p_base[m%2];
        auto first = p.size();
        for (auto i: p_ref) {
            p.push_back(i + first);
        }
        cell_cv_divs.push_back(first);
    }
    cell_cv_divs.push_back(p.size());

    auto group_size = cell_cv_divs.back();

    // Build the capacitance and conductance vectors and
    // populate with nonzero random values
    auto gen  = std::mt19937();
    gen.seed(100);
    auto dist = std::uniform_real_distribution<T>(1, 200);

    std::vector<T> Cm(group_size);
    std::vector<T> g(group_size);
    std::vector<T> v(group_size);
    std::vector<T> i(group_size);
    std::vector<T> area(group_size, 1e3);

    std::generate(Cm.begin(), Cm.end(), [&](){return dist(gen);});
    std::generate(g.begin(), g.end(), [&](){return dist(gen);});
    std::generate(v.begin(), v.end(), [&](){return dist(gen);});
    std::generate(i.begin(), i.end(), [&](){return dist(gen);});

    // Make the reference matrix and the gpu matrix
    auto flat = state_flat(p, cell_cv_divs, Cm, g, area); // flat
    auto intl = state_intl(p, cell_cv_divs, Cm, g, area); // interleaved

    // Set the integration times for the cells to be between 0.01 and 0.02 ms.
    std::vector<T> dt(num_mtx, 0);

    auto dt_dist = std::uniform_real_distribution<T>(0.01, 0.02);
    std::generate(dt.begin(), dt.end(), [&](){return dt_dist(gen);});

    // Voltage and current values.
    auto gpu_dt = on_gpu(dt);
    auto gpu_v = on_gpu(v);
    auto gpu_i = on_gpu(i);

    flat.assemble(gpu_dt, gpu_v, gpu_i);
    intl.assemble(gpu_dt, gpu_v, gpu_i);

    flat.solve();
    intl.solve();

    // Compare the results.
    // We expect exact equality for the two gpu matrix implementations because both
    // perform the same operations in the same order on the same inputs.
    std::vector<double> x_flat = assign_from(on_host(flat.solution()));
    std::vector<double> x_intl = assign_from(on_host(intl.solution()));
    EXPECT_EQ(x_flat, x_intl);
}

/*

// Test for special zero diagonal behaviour. (see `test_matrix.cpp`.)
TEST(matrix, zero_diagonal)
{
    using util::assign;

    using value_type = gpu::backend::value_type;
    using size_type = gpu::backend::size_type;
    using matrix_type = gpu::backend::matrix_state;
    using vvec = std::vector<value_type>;

    // Combined matrix may have zero-blocks, corresponding to a zero dt.
    // Zero-blocks are indicated by zero value in the diagonal (the off-diagonal
    // elements should be ignored).
    // These submatrices should leave the rhs as-is when solved.

    // Three matrices, sizes 3, 3 and 2, with no branching.
    std::vector<size_type> p = {0, 0, 1, 3, 3, 5, 5};
    std::vector<size_type> c = {0, 3, 5, 7};

    // Face conductances.
    std::vector<value_type> g = {0, 1, 1, 0, 1, 0, 2};

    // dt of 1e-3.
    std::vector<value_type> dt(3, 1.0e-3);

    // Capacitances.
    std::vector<value_type> Cm = {1, 1, 1, 1, 1, 2, 3};

    // Intial voltage of zero; currents alone determine rhs.
    std::vector<value_type> v(7, 0.0);
    std::vector<value_type> i = {-3, -5, -7, -6, -9, -16, -32};

    // Expected matrix and rhs:
    // u = [ 0 -1 -1  0 -1  0 -2]
    // d = [ 2  3  2  2  2  4  5]
    // b = [ 3  5  7  2  4 16 32]
    //
    // Expected solution:
    // x = [ 4  5  6  7  8  9 10]

    matrix_type m(p, c, Cm, g);
    auto gpu_dt = on_gpu(dt);
    auto gpu_v  = on_gpu(v);
    auto gpu_i  = on_gpu(i);
    m.assemble(gpu_dt, gpu_v, gpu_i);
    m.solve();

    vvec x;
    assign(x, on_host(m.solution()));
    std::vector<value_type> expected = {4, 5, 6, 7, 8, 9, 10};

    EXPECT_TRUE(testing::seq_almost_eq<double>(expected, x));

    // Set dt of 2nd (middle) submatrix to zero. Solution
    // should then return voltage values for that submatrix.

    dt[1] = 0;
    gpu_dt = on_gpu(dt);

    v[3] = 20;
    v[4] = 30;
    gpu_v  = on_gpu(v);

    m.assemble(gpu_dt, gpu_v, gpu_i);
    m.solve();

    assign(x, on_host(m.solution()));
    expected = {4, 5, 6, 20, 30, 9, 10};

    EXPECT_TRUE(testing::seq_almost_eq<double>(expected, x));
}

*/
