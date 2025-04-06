//
//  Atomic.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/23/25.
//

//
//  Atomic.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/23/25.
//

import Foundation

@propertyWrapper
struct AtomicProperty<Value> {

  private var lock = NSLock()

  private var _value: Value

  init(wrappedValue: Value) {
    self._value = wrappedValue
  }

  var wrappedValue: Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }
}
