import AppKit
import CodeBarUI
import CodeCore
import CodePlatform
import Observation

@MainActor
@Observable
final class LibraryActions {
    private let library: any CodeLibraryStoring
    private let repository: (any CodeRepository)?
    @ObservationIgnored private let pasteboard = SystemPasteboard()

    private(set) var pinnedCodes: [ClinicalCode] = []
    private(set) var pinnedIDs: Set<String> = []
    private(set) var manifests: [CodeSetManifest] = []

    init(library: any CodeLibraryStoring, repository: (any CodeRepository)? = nil) {
        self.library = library
        self.repository = repository
    }

    func refresh() async {
        let pinned = (try? await library.pinnedCodes()) ?? []
        pinnedCodes = pinned
        pinnedIDs = Set(pinned.map(\.id))

        if let repository {
            manifests = (try? await repository.manifests()) ?? []
        }
    }

    func isPinned(_ code: ClinicalCode) -> Bool {
        pinnedIDs.contains(code.id)
    }

    func copy(_ code: ClinicalCode, format: CopyFormat) {
        let written = format.string(for: code)
        pasteboard.write(written)
        SearchPanelController.shared.confirmation.show(written)
        Task {
            try? await library.recordUse(of: code, format: format)
            await refresh()
        }
    }

    func togglePin(_ code: ClinicalCode) {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        Task {
            try? await library.togglePin(code)
            await refresh()
        }
    }
}

