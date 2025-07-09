# Testing OpenAI Integration

## Prerequisites
1. Build and run the app
2. Click the settings button (gear icon) in the chat toolbar
3. Go to "API Keys" settings

## Setup Steps
1. Click the "+" button at the bottom of the provider list
2. Select "OpenAI" from the menu
3. Enter a friendly name (e.g., "OpenAI GPT-4")
4. Enter your OpenAI API key
5. Select a model (e.g., "gpt-4-turbo-preview" or "gpt-3.5-turbo")
6. Check "Set as default provider"
7. Click "Save"

## Testing
1. Close the settings window
2. In the main chat, verify the provider selector shows your configured provider
3. Type a test message like "Hello! Can you tell me a joke?"
4. Press Enter or click the send button
5. Watch for:
   - Message appears with user bubble
   - Provider selector shows the active provider
   - Bot response streams in with provider badge
   - Bot message shows provider info (icon + model) in the bubble

## Expected Results
- Messages send successfully
- Responses stream in real-time
- Provider information displays correctly
- No errors in console

## Troubleshooting
- If you see "No Provider" - check API key configuration
- If messages fail - verify API key is valid
- Check Console.app for detailed error logs

## Debugging with Console Logs
The app now includes comprehensive debug logging. To view:
1. Open Console.app
2. Filter by "SideChat" or "[OpenAI]"
3. Watch for these key messages:
   - `[OpenAI] Starting sendMessage...` - Request initiated
   - `[OpenAI] Request built successfully` - Request prepared
   - `[OpenAI] Response status code: 200` - Successful API connection
   - `[OpenAI] Received chunk:` - Streaming response chunks
   - `[OpenAI] Stream completed` - Response finished

Common errors to look for:
- `[OpenAI] No API key found` - API key not saved properly
- `[OpenAI] Response status code: 401` - Invalid API key
- `[OpenAI] Response status code: 404` - Incorrect API URL (missing /v1)
- `[OpenAI] Error response:` - API error details
- `[OpenAI] Skipping empty message` - Empty messages being filtered

## Important Note
If you had previously configured OpenAI before this fix, you may need to:
1. Remove the existing OpenAI configuration
2. Add it again to get the correct base URL
3. Or manually edit the base URL in settings to include `/v1`