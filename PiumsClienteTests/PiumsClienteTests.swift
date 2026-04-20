import XCTest
@testable import PiumsCliente

// MARK: - AppError Tests

final class AppErrorTests: XCTestCase {

    func testNetworkErrorDescription() {
        let err = AppError.network(URLError(.notConnectedToInternet))
        XCTAssertEqual(err.errorDescription, "Sin conexión a internet")
    }

    func testUnauthorizedDescription() {
        XCTAssertEqual(AppError.unauthorized.errorDescription, "Sesión expirada. Inicia sesión de nuevo")
    }

    func testNotFoundDescription() {
        XCTAssertEqual(AppError.notFound.errorDescription, "Recurso no encontrado")
    }

    func testServerErrorDescription() {
        XCTAssertEqual(AppError.serverError.errorDescription, "Error del servidor. Intenta más tarde")
    }

    func testDecodingErrorDescription() {
        let err = AppError.decoding(NSError(domain: "test", code: 0))
        XCTAssertEqual(err.errorDescription, "Error al procesar la respuesta")
    }

    func testHttpErrorReturnsBackendMessage() {
        let err = AppError.http(statusCode: 422, message: "El email ya está registrado")
        XCTAssertEqual(err.errorDescription, "El email ya está registrado")
    }

    func testInitFromURLError() {
        let urlError = URLError(.timedOut)
        let appError = AppError(from: urlError)
        XCTAssertEqual(appError, AppError.network(urlError))
    }

    func testInitFromAppErrorPassthrough() {
        let original = AppError.unauthorized
        let wrapped = AppError(from: original)
        XCTAssertEqual(wrapped, original)
    }

    func testEquality() {
        XCTAssertEqual(AppError.unauthorized, AppError.unauthorized)
        XCTAssertEqual(AppError.notFound, AppError.notFound)
        XCTAssertEqual(AppError.serverError, AppError.serverError)
        XCTAssertEqual(AppError.http(statusCode: 409, message: "A"), AppError.http(statusCode: 409, message: "B"))
        XCTAssertNotEqual(AppError.unauthorized, AppError.notFound)
    }
}

// MARK: - Conversation JSON Decoding Tests

final class ConversationDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func testDecodesParticipant1IdAsUserId() throws {
        let json = """
        {
          "id": "conv-1",
          "participant1Id": "user-abc",
          "participant2Id": "artist-xyz",
          "status": "ACTIVE",
          "bookingId": null,
          "lastMessageAt": null,
          "createdAt": "2026-01-01T00:00:00.000Z",
          "updatedAt": "2026-01-01T00:00:00.000Z",
          "unreadCount": 2,
          "messages": []
        }
        """.data(using: .utf8)!

        let conv = try JSONDecoder().decode(Conversation.self, from: json)
        XCTAssertEqual(conv.userId, "user-abc")
        XCTAssertEqual(conv.artistId, "artist-xyz")
        XCTAssertEqual(conv.unreadCount, 2)
    }

    func testDecodesConversationWithMessages() throws {
        let json = """
        {
          "id": "conv-2",
          "participant1Id": "user-1",
          "participant2Id": "artist-1",
          "status": "ACTIVE",
          "bookingId": "book-1",
          "lastMessageAt": "2026-04-20T10:00:00.000Z",
          "createdAt": "2026-01-01T00:00:00.000Z",
          "updatedAt": "2026-04-20T10:00:00.000Z",
          "unreadCount": 0,
          "messages": [
            {
              "id": "msg-1",
              "conversationId": "conv-2",
              "senderId": "artist-1",
              "content": "Hola!",
              "type": "TEXT",
              "status": "READ",
              "readAt": null,
              "createdAt": "2026-04-20T10:00:00.000Z",
              "updatedAt": null
            }
          ]
        }
        """.data(using: .utf8)!

        let conv = try JSONDecoder().decode(Conversation.self, from: json)
        XCTAssertEqual(conv.messages?.count, 1)
        XCTAssertEqual(conv.messages?.first?.senderId, "artist-1")
    }

    func testConversationsMissingWithOldFieldNamesFails() throws {
        // If the backend used userId/artistId (old iOS naming), decoding would silently produce empty strings.
        // This test documents that CodingKeys mapping is required.
        let jsonWithWrongKeys = """
        {
          "id": "conv-bad",
          "userId": "user-abc",
          "artistId": "artist-xyz",
          "status": "ACTIVE",
          "bookingId": null,
          "lastMessageAt": null,
          "createdAt": "2026-01-01T00:00:00.000Z",
          "updatedAt": "2026-01-01T00:00:00.000Z",
          "unreadCount": 0,
          "messages": []
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(Conversation.self, from: jsonWithWrongKeys))
    }
}

// MARK: - ChatMessage Decoding Tests

final class ChatMessageDecodingTests: XCTestCase {

    private func makeMessageJSON(status: String) -> Data {
        """
        {
          "id": "msg-1",
          "conversationId": "conv-1",
          "senderId": "user-abc",
          "content": "Hola artista",
          "type": "TEXT",
          "status": "\(status)",
          "readAt": null,
          "createdAt": "2026-04-20T10:00:00.000Z",
          "updatedAt": null
        }
        """.data(using: .utf8)!
    }

    func testReadComputedPropertyWhenStatusIsREAD() throws {
        let msg = try JSONDecoder().decode(ChatMessage.self, from: makeMessageJSON(status: "READ"))
        XCTAssertTrue(msg.read)
    }

    func testReadComputedPropertyWhenStatusIsSENT() throws {
        let msg = try JSONDecoder().decode(ChatMessage.self, from: makeMessageJSON(status: "SENT"))
        XCTAssertFalse(msg.read)
    }

    func testReadComputedPropertyWhenStatusIsDELIVERED() throws {
        let msg = try JSONDecoder().decode(ChatMessage.self, from: makeMessageJSON(status: "DELIVERED"))
        XCTAssertFalse(msg.read)
    }

    func testSenderIdIsDecoded() throws {
        let msg = try JSONDecoder().decode(ChatMessage.self, from: makeMessageJSON(status: "SENT"))
        XCTAssertEqual(msg.senderId, "user-abc")
    }

    func testIsOwnMessageLogic() throws {
        let msg = try JSONDecoder().decode(ChatMessage.self, from: makeMessageJSON(status: "SENT"))
        let currentUserId = "user-abc"
        XCTAssertTrue(msg.senderId == currentUserId)
        XCTAssertFalse(msg.senderId == "some-other-user")
    }
}

// MARK: - SearchViewModel Filter Tests

@MainActor
final class SearchViewModelFilterTests: XCTestCase {

    var vm: SearchViewModel!

    override func setUp() {
        super.setUp()
        vm = SearchViewModel()
    }

    func testInitialStateHasNoActiveFilters() {
        XCTAssertFalse(vm.hasActiveFilters)
    }

    func testSpecialtyFilterActivatesFlag() {
        vm.selectedSpecialty = .dj
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testTalentIdFilterActivatesFlag() {
        vm.selectedTalentId = "talent-123"
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testMinPriceAboveZeroActivatesFlag() {
        vm.minPrice = 500
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testMaxPriceBelowMaxActivatesFlag() {
        vm.maxPrice = 10000
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testMinRatingAboveZeroActivatesFlag() {
        vm.minRating = 3.5
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testCityFilterActivatesFlag() {
        vm.selectedCity = "Guatemala"
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testVerifiedFilterActivatesFlag() {
        vm.isVerified = true
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testSortOptionActivatesFlag() {
        vm.sortOption = .ratingDesc
        XCTAssertTrue(vm.hasActiveFilters)
    }

    func testClearFiltersResetsAll() {
        vm.selectedSpecialty = .musico
        vm.selectedTalentId = "t-1"
        vm.selectedTalentLabel = "Guitarra"
        vm.minPrice = 1000
        vm.maxPrice = 20000
        vm.minRating = 4.0
        vm.selectedCity = "Antigua Guatemala"
        vm.isVerified = true
        vm.sortOption = .priceAsc

        vm.clearFilters()

        XCTAssertNil(vm.selectedSpecialty)
        XCTAssertNil(vm.selectedTalentId)
        XCTAssertNil(vm.selectedTalentLabel)
        XCTAssertEqual(vm.minPrice, 0)
        XCTAssertEqual(vm.maxPrice, 50000)
        XCTAssertEqual(vm.minRating, 0)
        XCTAssertNil(vm.selectedCity)
        XCTAssertFalse(vm.isVerified)
        XCTAssertEqual(vm.sortOption, .relevance)
        XCTAssertFalse(vm.hasActiveFilters)
    }
}

// MARK: - TutorialManager State Machine Tests

@MainActor
final class TutorialManagerTests: XCTestCase {

    var manager: TutorialManager!

    override func setUp() {
        super.setUp()
        manager = TutorialManager()
    }

    func testInitialState() {
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.currentStep, 0)
    }

    func testStartActivatesAndResetsToFirstStep() {
        manager.currentStep = 3
        manager.start()
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.currentStep, 0)
    }

    func testNextAdvancesStep() {
        manager.start()
        manager.next()
        XCTAssertEqual(manager.currentStep, 1)
    }

    func testPreviousDecrementsStep() {
        manager.start()
        manager.next()
        manager.next()
        manager.previous()
        XCTAssertEqual(manager.currentStep, 1)
    }

    func testPreviousDoesNothingAtFirstStep() {
        manager.start()
        manager.previous()
        XCTAssertEqual(manager.currentStep, 0)
    }

    func testIsLastStepOnFinalIndex() {
        manager.currentStep = manager.steps.count - 1
        XCTAssertTrue(manager.isLastStep)
    }

    func testIsLastStepFalseOnFirstStep() {
        manager.currentStep = 0
        XCTAssertFalse(manager.isLastStep)
    }

    func testCurrentTabTargetMatchesStepTab() {
        for (index, step) in manager.steps.enumerated() {
            manager.currentStep = index
            XCTAssertEqual(manager.currentTabTarget, step.tab, "Step \(index) tab mismatch")
        }
    }

    func testCurrentTabTargetDefaultsToZeroWhenOutOfBounds() {
        manager.currentStep = 999
        XCTAssertEqual(manager.currentTabTarget, 0)
    }

    func testCurrentStepDataReturnsNilWhenOutOfBounds() {
        manager.currentStep = 999
        XCTAssertNil(manager.currentStepData)
    }

    func testCurrentStepDataReturnsCorrectStep() {
        manager.currentStep = 0
        XCTAssertEqual(manager.currentStepData?.title, "Panel Principal")
    }

    func testStepsCount() {
        XCTAssertEqual(manager.steps.count, 6)
    }

    func testNextOnLastStepDeactivates() {
        manager.start()
        manager.currentStep = manager.steps.count - 1
        manager.next()
        XCTAssertFalse(manager.isActive)
    }

    func testEndDeactivates() {
        manager.start()
        manager.end()
        XCTAssertFalse(manager.isActive)
    }
}

// MARK: - SearchSortOption Tests

final class SearchSortOptionTests: XCTestCase {

    func testAllCasesHaveDisplayNames() {
        for option in SearchSortOption.allCases {
            XCTAssertFalse(option.displayName.isEmpty, "\(option.rawValue) has empty displayName")
        }
    }

    func testRelevanceRawValueIsEmpty() {
        XCTAssertEqual(SearchSortOption.relevance.rawValue, "")
    }

    func testRatingDescRawValue() {
        XCTAssertEqual(SearchSortOption.ratingDesc.rawValue, "rating")
    }

    func testPriceAscRawValue() {
        XCTAssertEqual(SearchSortOption.priceAsc.rawValue, "price_asc")
    }

    func testPriceDescRawValue() {
        XCTAssertEqual(SearchSortOption.priceDesc.rawValue, "price_desc")
    }
}

// MARK: - SpecialtyOption Tests

final class SpecialtyOptionTests: XCTestCase {

    func testAllCasesHaveIcons() {
        for specialty in SpecialtyOption.allCases {
            XCTAssertFalse(specialty.icon.isEmpty, "\(specialty.rawValue) has empty icon")
        }
    }

    func testRawValuesMatchExpectedStrings() {
        XCTAssertEqual(SpecialtyOption.dj.rawValue, "DJ")
        XCTAssertEqual(SpecialtyOption.fotografia.rawValue, "Fotografía")
        XCTAssertEqual(SpecialtyOption.musico.rawValue, "Música")
    }

    func testIdMatchesRawValue() {
        for specialty in SpecialtyOption.allCases {
            XCTAssertEqual(specialty.id, specialty.rawValue)
        }
    }
}
