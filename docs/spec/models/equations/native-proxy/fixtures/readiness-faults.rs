use std::{
    ffi::{CStr, c_char, c_void},
    sync::atomic::{AtomicI32, Ordering},
};

static OWNED: AtomicI32 = AtomicI32::new(-1);

#[cfg_attr(target_arch = "x86_64", repr(C, packed))]
#[cfg_attr(not(target_arch = "x86_64"), repr(C))]
struct Event {
    events: u32,
    index: u64,
}

#[link(name = "dl")]
unsafe extern "C" {
    fn dlsym(handle: *mut c_void, name: *const c_char) -> *mut c_void;
    fn __errno_location() -> *mut i32;
}

fn fault(name: &str) -> bool {
    std::env::var("CAIRN_EPOLL_FAULT").as_deref() == Ok(name)
}

fn failure() -> i32 {
    // Linux libc exposes this thread's errno; EIO is deliberately non-retryable.
    unsafe { *__errno_location() = 5 };
    -1
}

fn original(name: &CStr) -> *mut c_void {
    // Linux's RTLD_NEXT resolves the libc implementation beyond this interposer.
    let pointer = unsafe { dlsym(-1_isize as *mut c_void, name.as_ptr()) };
    if pointer.is_null() {
        eprintln!("FAIL: readiness fault fixture could not resolve libc symbol");
        std::process::abort();
    }
    pointer
}

#[unsafe(no_mangle)]
unsafe extern "C" fn epoll_create1(flags: i32) -> i32 {
    if fault("create") {
        return failure();
    }
    // The resolved symbol has Linux libc's declared epoll_create1 ABI.
    let call: unsafe extern "C" fn(i32) -> i32 =
        unsafe { std::mem::transmute(original(c"epoll_create1")) };
    let descriptor = unsafe { call(flags) };
    OWNED.store(descriptor, Ordering::SeqCst);
    descriptor
}

#[unsafe(no_mangle)]
unsafe extern "C" fn epoll_ctl(
    descriptor: i32,
    operation: i32,
    target: i32,
    event: *mut Event,
) -> i32 {
    if (operation == 1 && fault("add")) || (operation == 2 && fault("delete")) {
        return failure();
    }
    // Forward the unchanged operation and live pointer with libc's exact ABI.
    let call: unsafe extern "C" fn(i32, i32, i32, *mut Event) -> i32 =
        unsafe { std::mem::transmute(original(c"epoll_ctl")) };
    unsafe { call(descriptor, operation, target, event) }
}

#[unsafe(no_mangle)]
unsafe extern "C" fn epoll_wait(
    descriptor: i32,
    events: *mut Event,
    count: i32,
    timeout: i32,
) -> i32 {
    if fault("wait") {
        return failure();
    }
    if fault("event") {
        // The real caller supplies two writable event slots; corrupt only the tag.
        unsafe {
            events.write(Event {
                events: 1,
                index: 2,
            })
        };
        return 1;
    }
    // Preserve the real queue, buffer and timeout for all other fault cases.
    let call: unsafe extern "C" fn(i32, *mut Event, i32, i32) -> i32 =
        unsafe { std::mem::transmute(original(c"epoll_wait")) };
    unsafe { call(descriptor, events, count, timeout) }
}

#[unsafe(no_mangle)]
unsafe extern "C" fn close(descriptor: i32) -> i32 {
    // Successful close consumes the descriptor even when we report an I/O error.
    let call: unsafe extern "C" fn(i32) -> i32 = unsafe { std::mem::transmute(original(c"close")) };
    let result = unsafe { call(descriptor) };
    if fault("close")
        && OWNED
            .compare_exchange(descriptor, -1, Ordering::SeqCst, Ordering::SeqCst)
            .is_ok()
        && result == 0
    {
        return failure();
    }
    result
}
