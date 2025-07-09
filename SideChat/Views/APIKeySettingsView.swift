import SwiftUI
import Defaults

// MARK: - API Key Settings View

/// Settings view for managing LLM provider API keys with native macOS interface
struct APIKeySettingsView: View {
    
    // MARK: - Properties
    
    @State private var selectedProviderId: UUID?
    @State private var configuredProviders: [ProviderConfiguration] = []
    @State private var showAddProviderMenu = false
    
    // Current editing state
    @State private var editingConfiguration: ProviderConfiguration?
    @State private var currentAPIKey = ""
    @State private var showAPIKey = false
    @State private var hasUnsavedChanges = false
    
    @State private var isTestingAPI = false
    @State private var testResult: TestResult?
    @State private var showingAlert = false
    
    @Default(.providerConfigurations) private var savedConfigurations
    @Default(.defaultLLMProvider) private var defaultProvider
    
    // MARK: - Body
    
    var body: some View {
        HSplitView {
            // Sidebar with provider list
            providerListView
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // Detail view for selected provider
            if let configuration = selectedConfiguration {
                providerDetailView(for: configuration)
                    .frame(minWidth: 400)
            } else {
                emptyStateView
                    .frame(minWidth: 400)
            }
        }
        .onAppear {
            loadConfigurations()
        }
        .onChange(of: savedConfigurations) { _, _ in
            loadConfigurations()
        }
    }
    
    // MARK: - Computed Properties
    
    private var selectedConfiguration: ProviderConfiguration? {
        configuredProviders.first { $0.id == selectedProviderId }
    }
    
    private var availableProvidersToAdd: [LLMProvider] {
        LLMProvider.allCases.filter { provider in
            !configuredProviders.contains { $0.provider == provider }
        }
    }
    
    // MARK: - Provider List View
    
    private var providerListView: some View {
        VStack(spacing: 0) {
            // Provider list
            List(selection: $selectedProviderId) {
                ForEach(configuredProviders) { configuration in
                    HStack {
                        Image(systemName: configuration.provider.icon)
                            .foregroundColor(providerColor(for: configuration.provider))
                            .frame(width: 20)
                        
                        Text(configuration.friendlyName)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if configuration.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(configuration.id)
                    .padding(.vertical, 2)
                }
            }
            .listStyle(SidebarListStyle())
            
            // Bottom toolbar with add/remove buttons
            HStack(spacing: 2) {
                // Add button with menu
                Menu {
                    ForEach(availableProvidersToAdd, id: \.self) { provider in
                        Button(action: { addProvider(provider) }) {
                            Label(provider.displayName, systemImage: provider.icon)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .disabled(availableProvidersToAdd.isEmpty)
                .help("Add Provider")
                
                // Remove button
                Button(action: removeSelectedProvider) {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(selectedProviderId == nil)
                .help("Remove Provider")
                
                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Provider Selected")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Select a provider from the list or add a new one")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Provider Detail View
    
    @ViewBuilder
    private func providerDetailView(for configuration: ProviderConfiguration) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: configuration.provider.icon)
                        .font(.largeTitle)
                        .foregroundColor(providerColor(for: configuration.provider))
                    
                    Text(configuration.provider.displayName)
                        .font(.largeTitle)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Set as Default") {
                        setAsDefault(configuration)
                    }
                    .disabled(configuration.isDefault)
                }
                .padding(.bottom, 8)
                
                // Configuration Form
                VStack(alignment: .leading, spacing: 16) {
                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        TextField("Set a friendly name", text: bindingForName(configuration))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editingConfiguration?.friendlyName) { _, _ in
                                hasUnsavedChanges = true
                            }
                    }
                    
                    // API Key field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API Key")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !ProviderConfiguration.apiKeyURL(for: configuration.provider).isEmpty {
                                Link("Find my key →", destination: URL(string: ProviderConfiguration.apiKeyURL(for: configuration.provider))!)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            Group {
                                if showAPIKey {
                                    TextField("API Key", text: $currentAPIKey)
                                } else {
                                    SecureField("API Key", text: $currentAPIKey)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: currentAPIKey) { _, _ in
                                hasUnsavedChanges = true
                            }
                            
                            Button(action: { showAPIKey.toggle() }) {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text("API key provided by \(configuration.provider.displayName).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Base URL field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        TextField("Base URL", text: bindingForBaseURL(configuration))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editingConfiguration?.baseURL) { _, _ in
                                hasUnsavedChanges = true
                            }
                        
                        Text("The Base URL of the \(configuration.provider.displayName) API. Leave empty for default.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Model selection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Model:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Picker("", selection: bindingForModel(configuration)) {
                                ForEach(ProviderConfiguration.availableModels(for: configuration.provider), id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 300)
                            .onChange(of: editingConfiguration?.selectedModel) { _, _ in
                                hasUnsavedChanges = true
                            }
                            
                            Button("Refresh") {
                                // TODO: Implement model refresh
                            }
                            .help("Refresh available models")
                        }
                    }
                }
                
                Spacer()
                
                // Save button
                HStack {
                    Spacer()
                    
                    Button("Save Changes") {
                        saveConfiguration()
                    }
                    .disabled(!hasUnsavedChanges)
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadConfigurationForEditing(configuration)
        }
        .onChange(of: selectedProviderId) { _, newId in
            if let newConfig = configuredProviders.first(where: { $0.id == newId }) {
                loadConfigurationForEditing(newConfig)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadConfigurations() {
        configuredProviders = savedConfigurations
        
        // Select first provider if none selected
        if selectedProviderId == nil, let first = configuredProviders.first {
            selectedProviderId = first.id
        }
    }
    
    private func loadConfigurationForEditing(_ configuration: ProviderConfiguration) {
        editingConfiguration = configuration
        hasUnsavedChanges = false
        
        // Load API key from keychain
        if let apiKey = KeychainManager.getAPIKey(for: configuration.provider) {
            currentAPIKey = apiKey
        } else {
            currentAPIKey = ""
        }
        showAPIKey = false
    }
    
    private func addProvider(_ provider: LLMProvider) {
        let newConfiguration = ProviderConfiguration(
            provider: provider,
            isDefault: configuredProviders.isEmpty
        )
        
        configuredProviders.append(newConfiguration)
        savedConfigurations = configuredProviders
        selectedProviderId = newConfiguration.id
    }
    
    private func removeSelectedProvider() {
        guard let selectedId = selectedProviderId,
              let index = configuredProviders.firstIndex(where: { $0.id == selectedId }) else { return }
        
        let provider = configuredProviders[index].provider
        
        // Remove from keychain
        try? KeychainManager.deleteAPIKey(for: provider)
        
        // Remove from list
        configuredProviders.remove(at: index)
        savedConfigurations = configuredProviders
        
        // Update selection
        if let first = configuredProviders.first {
            selectedProviderId = first.id
        } else {
            selectedProviderId = nil
        }
        
        // Update default if needed
        if configuredProviders.contains(where: { $0.isDefault }) == false,
           let first = configuredProviders.first {
            var updatedFirst = first
            updatedFirst.isDefault = true
            configuredProviders[0] = updatedFirst
            savedConfigurations = configuredProviders
        }
    }
    
    private func setAsDefault(_ configuration: ProviderConfiguration) {
        // Update all configurations
        for i in configuredProviders.indices {
            configuredProviders[i].isDefault = configuredProviders[i].id == configuration.id
        }
        
        // Save
        savedConfigurations = configuredProviders
        
        // Update default provider
        defaultProvider = configuration.provider
    }
    
    private func saveConfiguration() {
        guard let configuration = editingConfiguration,
              let index = configuredProviders.firstIndex(where: { $0.id == configuration.id }) else { return }
        
        // Save API key to keychain if changed
        if !currentAPIKey.isEmpty && currentAPIKey != "••••••••••••••••••••" {
            do {
                try KeychainManager.setAPIKey(currentAPIKey, for: configuration.provider)
            } catch {
                testResult = TestResult(success: false, message: "Failed to save API key: \(error.localizedDescription)")
                showingAlert = true
                return
            }
        }
        
        // Update configuration
        configuredProviders[index] = configuration
        savedConfigurations = configuredProviders
        
        hasUnsavedChanges = false
        
        testResult = TestResult(success: true, message: "Configuration saved successfully!")
        showingAlert = true
    }
    
    // MARK: - Binding Helpers
    
    private func bindingForName(_ configuration: ProviderConfiguration) -> Binding<String> {
        Binding(
            get: { editingConfiguration?.friendlyName ?? configuration.friendlyName },
            set: { newValue in
                editingConfiguration?.friendlyName = newValue
            }
        )
    }
    
    private func bindingForBaseURL(_ configuration: ProviderConfiguration) -> Binding<String> {
        Binding(
            get: { editingConfiguration?.baseURL ?? configuration.baseURL },
            set: { newValue in
                editingConfiguration?.baseURL = newValue
            }
        )
    }
    
    private func bindingForModel(_ configuration: ProviderConfiguration) -> Binding<String> {
        Binding(
            get: { editingConfiguration?.selectedModel ?? configuration.selectedModel },
            set: { newValue in
                editingConfiguration?.selectedModel = newValue
            }
        )
    }
    
    // MARK: - UI Helpers
    
    private func providerColor(for provider: LLMProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .local: return .purple
        }
    }
    
    // MARK: - Test Result
    
    private struct TestResult {
        let success: Bool
        let message: String
    }
}

// MARK: - Preview

#if DEBUG
struct APIKeySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeySettingsView()
    }
}
#endif