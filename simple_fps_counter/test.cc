#include <thread>
#include <chrono>
#include <cstdio>
#include "simple_fps_counter.h"

int main()
{
    SimpleFpsCounter fps;
    unsigned long long cnt = 0;

    while (true)
    {
        cnt++;
        if ((cnt % 30) == 0)
            printf("FPS: %u\n", fps.get());
        fps.update();
        std::this_thread::sleep_for(std::chrono::milliseconds(33));
    }
    return 0;
}
