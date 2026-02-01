import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [Stop] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let searchStopsUseCase: SearchStopsUseCase
    private var cancellables = Set<AnyCancellable>()

    init(searchStopsUseCase: SearchStopsUseCase) {
        self.searchStopsUseCase = searchStopsUseCase

        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        if query.isEmpty {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let stops = try await searchStopsUseCase.execute(query: query)
                DispatchQueue.main.async {
                    self.searchResults = stops
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
