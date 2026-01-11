//
//  VersionLockoutView.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import SwiftUI

public struct VersionLockoutView<LoadingView: View, Recommended: View, Required: View, EOL: View, Content: View>: View {
    let url: URL
    
    @State var viewModel: VersionLockoutViewModel
    
    @ViewBuilder
    let loading: () -> LoadingView
    
    @ViewBuilder
    let recommedUpdate: (URL, @escaping () -> Void) -> Recommended
    
    @ViewBuilder
    let requireUpdate: (URL) -> Required
    
    @ViewBuilder
    let eol: (String?) -> EOL
    
    @ViewBuilder
    let content: () -> Content
    
    public init(
        versionLockoutURL: URL,
        @ViewBuilder ifLoading: @escaping () -> LoadingView = {
            EmptyView()
        },
        @ViewBuilder updateRecommended: @escaping (URL, @escaping () -> Void) -> Recommended = { url, skip in
            BuiltInUpdateView(requireUpdate: false, updateUrl: url, skip: skip)
        },
        @ViewBuilder updateRequred: @escaping (URL) -> Required = {
            BuiltInUpdateView(requireUpdate: true, updateUrl: $0)
        },
        @ViewBuilder endOfLife: @escaping (String?) -> EOL = { message in
            BuiltInEOLView(message: LocalizedStringKey(message ?? ""))
        },
        @ViewBuilder upToDate content: @escaping () -> Content
    ) {
        _viewModel = State(initialValue: VersionLockoutViewModel(versionLockoutURL))
        self.url = versionLockoutURL
        self.loading = ifLoading
        self.requireUpdate = updateRequred
        self.recommedUpdate = updateRecommended
        self.eol = endOfLife
        self.content = content
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loading()
            } else {
                switch viewModel.status {
                case let .eol(message):
                    eol(message)
                case let .required(url):
                    requireUpdate(url)
                case let .recommended(url):
                    recommedUpdate(url) {
                        self.viewModel.status = .upToDate
                    }
                default:
                    content()
                }
            }
        }
        .task {
            await viewModel.refreshStatus()
        }
    }
}

#Preview {
    VersionLockoutView(versionLockoutURL: URL(string: "https://jpmtech.io")!) {
        Text("My basic content")
    }
}
