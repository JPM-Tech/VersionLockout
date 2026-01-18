//
//  VersionLockoutView.swift
//  VersionLockout
//
//  Created by Chase Lewis on 1/9/26.
//

import SwiftUI

public struct VersionLockoutView<
    LoadingView: View,
    Recommended: View,
    Required: View,
    EOL: View,
    Content: View
>: View {

    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: VersionLockoutViewModel

    @ViewBuilder let loading: () -> LoadingView
    @ViewBuilder let recommendUpdate: (URL, @escaping () -> Void) -> Recommended
    @ViewBuilder let requireUpdate: (URL) -> Required
    @ViewBuilder let eol: (String?) -> EOL
    @ViewBuilder let content: () -> Content

    public init(
        viewModel: VersionLockoutViewModel,
        @ViewBuilder ifLoading: @escaping () -> LoadingView = { EmptyView() },
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
        self.viewModel = viewModel
        self.loading = ifLoading
        self.requireUpdate = updateRequred
        self.recommendUpdate = updateRecommended
        self.eol = endOfLife
        self.content = content
    }

    public var body: some View {
        ZStack {
            switch viewModel.status {
            case let .eol(message):
                eol(message)
            case let .required(url):
                requireUpdate(url)
            case let .recommended(url):
                recommendUpdate(url) {
                    viewModel.status = .upToDate
                }
            case .upToDate:
                content()
            case nil:
                loading()
            }
        }
        .task {
            await viewModel.refreshStatus()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.refreshStatusIfNeeded()
                }
            }
        }
    }
}


#Preview {
    @Previewable @State var vm = VersionLockoutViewModel(URL(string: "https://jpmtech.io")!)
    VersionLockoutView(viewModel: vm) {
        Text("My basic content")
    }
}
