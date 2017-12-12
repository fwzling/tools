#ifndef __SIMPLE_FPS_COUNTER__
#define __SIMPLE_FPS_COUNTER__

#include <chrono>

class SimpleFpsCounter
{
public:
    using Clock = std::chrono::steady_clock;
    void update();
    unsigned int get() const;
protected:
    unsigned int n_frames = 0;
    unsigned int fps = 0;
    Clock::time_point last_time = Clock::now();
    Clock::duration interval =
        std::chrono::duration_cast<Clock::duration>(std::chrono::seconds(1));
};

#endif  /* __SIMPLE_FPS_COUNTER__ */
