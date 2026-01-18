//
//  Yield.swift
//  VersionLockout
//
//  Created by Jacob Rakidzich on 1/16/26.
//

import Foundation

/// Ensure higher priority tasks execute by yielding on a low pirority task.
func yield() async {
    await Task(priority: .low) {
        await Task.yield()
    }.value
}
