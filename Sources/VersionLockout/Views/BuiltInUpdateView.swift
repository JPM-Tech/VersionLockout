//
//  VersionLockoutView.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import SwiftUI
import Playgrounds

public struct BuiltInUpdateView: View {
    @Environment(\.openURL) var openURL
    
    let requireUpdate: Bool
    let updateUrl: URL
    let skip: () -> Void

    public init(
        requireUpdate: Bool,
        updateUrl: URL,
        skip: @escaping () -> Void = {}
    ) {
        self.requireUpdate = requireUpdate
        self.updateUrl = updateUrl
        self.skip = skip
    }

    var text: LocalizedStringKey {
        if requireUpdate {
            return "Hi friend! We've made some required updates! Please click the button to update the app."
        }
        return "Hi friend! We've made some cool new updates! This will soon be a required update, so we recommend you go update it in the AppStore now."
    }

    public var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(requireUpdate ? .red : .yellow)
                    
                    Text("Update Available")
                        .font(.title)
                    
                    Text(text)
                }
            }
            .multilineTextAlignment(.center)
            
            if !requireUpdate {
                Button("Skip") {
                    skip()
                }
                .font(.callout)
                .padding(.bottom)
            }
            
            Button("Update Now") {
                openURL(updateUrl)
            }
            .buttonStyle(.borderedProminent)
        }.padding()
    }
}

#Preview("Recommended Update") {
    BuiltInUpdateView(
        requireUpdate: false,
        updateUrl: URL(string: "https://apple.com")!
    ) {}
}

#Preview("Required Update") {
    BuiltInUpdateView(
        requireUpdate: true,
        updateUrl: URL(string: "https://apple.com")!
    ) {}
}
