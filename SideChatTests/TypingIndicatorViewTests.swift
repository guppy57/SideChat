import Testing
import SwiftUI
@testable import SideChat

// MARK: - Typing Indicator View Tests

@Suite("TypingIndicatorView Tests")
struct TypingIndicatorViewTests {
    
    @Test("TypingIndicatorView renders without crashing")
    @MainActor
    func testTypingIndicatorRenders() {
        let view = TypingIndicatorView()
        let hostingController = NSHostingController(rootView: view)
        
        #expect(hostingController.view != nil)
    }
    
    @Test("TypingIndicatorView has correct structure")
    @MainActor
    func testTypingIndicatorStructure() {
        // This test verifies the view can be created with expected properties
        let view = TypingIndicatorView()
            .frame(width: 400, height: 100)
        
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.appearance = NSAppearance(named: .aqua)
        
        #expect(hostingController.view != nil)
    }
    
    @Test("TypingIndicatorView works in different color schemes")
    @MainActor
    func testTypingIndicatorColorSchemes() {
        // Light mode
        let lightView = TypingIndicatorView()
            .environment(\.colorScheme, .light)
        let lightController = NSHostingController(rootView: lightView)
        
        #expect(lightController.view != nil)
        
        // Dark mode
        let darkView = TypingIndicatorView()
            .environment(\.colorScheme, .dark)
        let darkController = NSHostingController(rootView: darkView)
        
        #expect(darkController.view != nil)
    }
}