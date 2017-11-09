/**
 * A generic object pool.
 * Language level required: C++11
 * Usage:
 *  { 
 *      auto & pool = ObjectPool<Train>::getInstance();  // Obtain an object pool for type Train
 *      auto && ptr = pool.allocateObject();             // Ask for a Train object
 *
 *      std::cout << *ptr.getName();                     // Use the object for your business
 *  }                                                    // The object goes back to pool automatically
 **/

#include <memory>
#include <list>
#include <string>
#include <iostream>

class ObjectPoolException {
public:
    ObjectPoolException(std::string msg) : errorMsg(msg) {}
    std::string errorMsg;
};

template <typename T, size_t F = 1, size_t C = 100000>  // F is growth factor, C is capacity
class ObjectPool {
public:
    using Ptr_ty = std::unique_ptr<T, std::function<void (T*)>>;
    static const size_t initialSize = 10;

    static ObjectPool& getInstance() {
        if (instance == nullptr) {
            instance = new ObjectPool();
        }
        return *instance;
    }

    Ptr_ty allocateObject() {
        if (objectStore.empty()) {
            const int num = (allocatedCounter < C - F * allocatedCounter) ? (F * allocatedCounter) : (C - allocatedCounter) ;
            if (num <= 0) {
                throw new ObjectPoolException("Reached maximal capacity.");
            }
            createObjects(num);
        }

        T* objectPtr = objectStore.front();
        objectStore.pop_front();
        return Ptr_ty(objectPtr, [this](T* ptr){
            releaseObject(ptr);
        });
    }

    std::string status() {
        std::string status_str {"Object Pool Status: "};
        status_str += "Growth Factor = " + std::to_string(F) + "; ";
        status_str += "Capacity = " + std::to_string(C) + "; ";
        status_str += "Current Free Objects Number = " + std::to_string(objectStore.size()) + "; ";
        status_str += "Current Total Allocated Number = " + std::to_string(allocatedCounter) + "; ";
        return status_str;
    }
    
    ObjectPool(ObjectPool const&) = delete;
    void operator=(ObjectPool const&) = delete;
private:
    static ObjectPool* instance;
    std::list<T*> objectStore;
    size_t allocatedCounter = 0;

    ObjectPool() {
        createObjects(initialSize);
    }

    void createObjects(int n) {
        allocatedCounter += n;
        while (n-- > 0) {
            objectStore.push_front(new T);
        }
    }

    void releaseObject(T* objectPtr) {
        objectStore.push_front(objectPtr);
    }
};

template <typename T, size_t F, size_t C>
ObjectPool<T, F, C>* ObjectPool<T, F, C>::instance = nullptr;
