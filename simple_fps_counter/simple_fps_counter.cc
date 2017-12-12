#include "simple_fps_counter.h"

void SimpleFpsCounter::update()
{
    n_frames++;
    if ((Clock::now() - last_time) >= interval)
    {
        fps = n_frames;
        n_frames = 0;
        last_time += interval;
    }
}

unsigned int SimpleFpsCounter::get() const
{
    return fps;
}

