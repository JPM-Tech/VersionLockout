//
//  BuiltInEOLView.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import SwiftUI

public struct BuiltInEOLView: View {
    let message: LocalizedStringKey?
    
    public init(message: LocalizedStringKey? =  nil) {
        self.message = message
    }
    
    public var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("It's the end of the road for this app.")
                        .font(.title)
                    
                    if let message {
                        Text(message)
                    }
                }
            }
            .multilineTextAlignment(.center)
        }.padding()
    }
}

#Preview("No Message") {
    BuiltInEOLView()
}

#Preview("With Message") {
    BuiltInEOLView(message: LocalizedStringKey("Well friend, it's been a good run, but all good things must come to an end at some point."))
}
