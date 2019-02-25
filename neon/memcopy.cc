#include <iostream>
#include <cstring>
#include <cstdlib>
#include <random>
#include <cassert>

#ifdef __aarch64__
#include <arm_neon.h>
static void *memcpy_neon_128(void *dest, void *src, size_t count)
{
    int i;
    unsigned long *s = static_cast<unsigned long *>(src);
    unsigned long *d = static_cast<unsigned long *>(dest);
    /* copy 128 bytes on each iteration */
    const int num = count >> 7;
    for (i = 0; i < num; i++)
    {
        vst1q_u64(&d[0],  vld1q_u64(&s[0]));
        vst1q_u64(&d[2],  vld1q_u64(&s[2]));
        vst1q_u64(&d[4],  vld1q_u64(&s[4]));
        vst1q_u64(&d[6],  vld1q_u64(&s[6]));

        vst1q_u64(&d[8],  vld1q_u64(&s[8]));
        vst1q_u64(&d[10], vld1q_u64(&s[10]));
        vst1q_u64(&d[12], vld1q_u64(&s[12]));
        vst1q_u64(&d[14], vld1q_u64(&s[14]));

        d += 16; s += 16;
    }
    return dest;
}
#endif

void* memcpy_bulk_data(void* dest, const void* src, std::size_t count)
{
#ifdef __aarch64__
#  pragma message "Compiling on aarch64"
    if (count < 1024)
    {
        return memcpy(dest, src, count);
    }

    using __u64 = unsigned long;
    /* align bulk to 128 bytes boundary */
    constexpr __u64 Bulk_Alignment = 128;
    constexpr unsigned P = 7;
    static_assert((1 << P) == Bulk_Alignment, "2^P == Bulk_Alignment assert");

    __u64 s = reinterpret_cast<__u64>(src), d = reinterpret_cast<__u64>(dest);
    __u64 r = s % Bulk_Alignment;  /* remainder */
    __u64 h_cnt = (r == 0) ? 0 : Bulk_Alignment - r;

    /* copy head that makes bulk align */
    if (h_cnt != 0)
    {
        memcpy(reinterpret_cast<void *>(d), reinterpret_cast<void *>(s), h_cnt);
        s += h_cnt;
        d += h_cnt;
        count -= h_cnt;
    }

    /* copy bulk */
    __u64 bulk_size = (count >> P) << P;
    {
        memcpy_neon_128(reinterpret_cast<void *>(d), reinterpret_cast<void *>(s),
               bulk_size);
        s += bulk_size;
        d += bulk_size;
        count -= bulk_size;
    }

    /* copy tail */
    if (count != 0)
    {
        assert(count > 0);
        memcpy(reinterpret_cast<void *>(d), reinterpret_cast<void *>(s), count);
    }

    return dest;
#else
    return memcpy(dest, src, count);
#endif
}

int main(int argc, char** argv)
{
    if (argc != 2)
    {
        std::cerr << "Usage:  test_memcpy 856" << std::endl;
        exit (1);
    }

    int count = atoi(argv[1]);
    if (count < 0)
    {
        std::cerr << "Bad argument: " << count << std::endl;
    }

    char * src = new char[count];
    char * dst = new char[count];

    std::random_device rd;
    std::uniform_int_distribution<int> dist(0, 255);
    for (int i = 0; i < count; i++)
    {
        src[i] = static_cast<char>(dist(rd));
    }

    memcpy_bulk_data(dst, src, count);

    int miss = 0;
    for (int i = 0; i < count; i++)
    {
        if (src[i] != dst[i])
        {
            miss++;
        }
    }

    std::cout << "miss count = " << miss << std::endl;

    delete [] src;
    delete [] dst;

    return 0;
}
