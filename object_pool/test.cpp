#include <vector>
#include <cstdlib>
#include <iostream>
#include <ctime>
#include "ObjectPool.h"

class ResourceObject {
public:
    ResourceObject() : vs(std::vector<std::string>(5, "My name is Richard")) {}
    std::vector<std::string> vs;
};

std::list<ObjectPool<ResourceObject>::Ptr_ty> globallyInUse;

// Generate test cases for a random sequence of allocate/release actions
// 'A' represents allocate
// 'R' represents release
std::vector<char> generateTestCases(int n) {
    std::vector<char> v;
    std::srand(std::time(0));
    while (n--) {
        v.push_back((std::rand() % 2) ? 'A' : 'R');
    }
    #ifdef DEBUG
    std::cout << "Test Cases:" << std::endl;
    for_each(v.begin(), v.end(), [](char c){ std::cout << c << ' '; });
    std::cout << std::endl;
    #endif
    return v;
}

void runTestOnPool(char action) {
    auto & pool = ObjectPool<ResourceObject>::getInstance();
    #ifdef DEBUG
    std::cout << "Before >>> " << pool.status() << std::endl;
    #endif
    switch (action) {
        case 'A':
            globallyInUse.push_front(std::move(pool.allocateObject()));
            break;
        case 'R':
            if (!globallyInUse.empty()) {
                auto p = std::move(globallyInUse.front());
                globallyInUse.pop_front();
            }
            #ifdef DEBUG
            else {
                std::cout << "Nothing to release." << std::endl;
            }
            #endif
            break;
        default: 
            std::cout << "Undefined action." << std::endl;
            return;
    }
    #ifdef DEBUG
    std::cout << "After >>> " << pool.status() << std::endl;
    #endif
}


int main(int argc, char ** argv) {
    int testNum = 5;
    if (argc == 2) {
        testNum = std::atoi(argv[1]);
    }
    std::cout << "Actions number = " << testNum << std::endl;
    std::vector<char> tests = std::move(generateTestCases(testNum));
    for (auto t : tests) {
        runTestOnPool(t);
    }

    return 0;
}
