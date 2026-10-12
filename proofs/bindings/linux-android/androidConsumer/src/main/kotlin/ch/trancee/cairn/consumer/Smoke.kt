package ch.trancee.cairn.consumer

import ch.trancee.cairn.smoke.ArithmeticException
import ch.trancee.cairn.smoke.Greeter
import ch.trancee.cairn.smoke.checkedAdd

fun main() {
    check(checkedAdd(2, 3) == 5)
    check(checkedAdd(Int.MIN_VALUE, 0) == Int.MIN_VALUE)
    try {
        checkedAdd(Int.MAX_VALUE, 1)
        error("Expected typed overflow")
    } catch (_: ArithmeticException) {
        println("PASS: typed overflow crossed FFI")
    }
    val greeter = Greeter("Hello")
    try {
        check(greeter.greet("Kotlin") == "Hello, Kotlin!")
    } finally {
        greeter.close()
    }
    val rejected = try {
        greeter.greet("closed")
        false
    } catch (_: IllegalStateException) {
        true
    }
    check(rejected) { "Closed Rust object remained callable" }
    greeter.close()
    println("PASS: value, boundary, typed error and object lifetime")
}
