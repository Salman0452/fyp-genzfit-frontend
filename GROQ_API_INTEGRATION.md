# Groq API Integration Guide

## What Changed

Switched from Google Gemini to Groq API with Llama 3.1 8B Instant model for AI recommendations.

## Why Groq?

✅ **Free Tier:** Generous free token limits  
✅ **Fast:** "Instant" inference times (milliseconds)  
✅ **Good Quality:** Llama 3.1 8B is excellent for fitness/nutrition recommendations  
✅ **Simple API:** OpenAI-compatible format  
✅ **Already Configured:** Your API key is already in .env!

## API Details

**Endpoint:** `https://api.groq.com/openai/v1/chat/completions`  
**Model:** `llama-3.1-8b-instant`  
**Your API Key:** Already configured in `.env`

## How It Works

```dart
// Request format
{
  "model": "llama-3.1-8b-instant",
  "messages": [
    {
      "role": "system",
      "content": "You are a professional fitness and nutrition expert..."
    },
    {
      "role": "user", 
      "content": "Generate 5 meal recommendations for..."
    }
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

The AI responds with personalized:
- **Meal Plans:** Name, calories, macros, ingredients, meal type
- **Exercise Plans:** Name, sets, reps, duration, difficulty, target muscles

## Testing

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Navigate to AI Recommendations:**
   - Home → "AI Recommendations"
   - Switch between Meals and Exercises tabs
   - Pull down to refresh and generate new recommendations

3. **Check console output:**
   - Should see successful API calls
   - If errors, check GROQ_API_KEY in .env

## Expected Response Time

- **Groq (Llama 3.1):** ~500ms - 1.5s ⚡
- Much faster than most LLM APIs!

## Free Tier Limits

- **Requests:** 30 requests/minute
- **Tokens:** 14,400 tokens/minute
- **Daily:** 14,400 requests/day

More than enough for development and testing!

## Error Handling

If API fails (rate limit, network issue, etc.):
- App automatically falls back to default recommendations
- User still sees content, just not personalized
- Error logged to console for debugging

## Customizing Prompts

Edit `lib/services/recommendation_service.dart`:

```dart
String _buildMealPrompt(UserModel user, Measurement? measurement, int count) {
  // Modify prompt here to change AI behavior
  // Add more context, change format, adjust requirements
}
```

## Rate Limit Best Practices

1. **Cache recommendations** in Firestore after generating
2. **Don't regenerate** on every screen visit
3. **Add loading states** to prevent multiple simultaneous requests
4. **Consider daily limits** per user in production

## Troubleshooting

### "GROQ_API_KEY not found"
- Check `.env` file exists
- Verify key name is exactly `GROQ_API_KEY`
- Restart app after editing .env

### "API error: 401"
- API key is invalid
- Get new key from console.groq.com

### "API error: 429"
- Rate limit exceeded
- Wait a minute and try again
- Or implement caching

### No recommendations showing
- Check console for errors
- Verify internet connection
- App should fall back to defaults if API fails

## Production Recommendations

For a production app:

1. **Backend Proxy:**
   ```
   App → Your Backend → Groq API
   ```
   - Hide API key on server
   - Implement your own rate limiting
   - Add analytics

2. **Caching Strategy:**
   - Save AI responses to Firestore
   - Only regenerate weekly or on user request
   - Reduces API costs and improves speed

3. **User Quotas:**
   - Limit recommendations per user per day
   - Prevents abuse of your API quota

## Resources

- **Groq Console:** https://console.groq.com
- **API Docs:** https://console.groq.com/docs/quickstart
- **Models:** https://console.groq.com/docs/models
- **Pricing:** https://groq.com/pricing (Free tier is generous!)
