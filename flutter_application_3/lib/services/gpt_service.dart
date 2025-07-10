import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schedule_data.dart';

class GPTService {
  static const String _apiKey = ''; // Replace with your actual API key
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<Map<String, dynamic>> getResponse(String message) async {
    try {
      final today = DateTime.now();
      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final systemPrompt = '''
IMPORTANT: Never reply with only a summary, confirmation, or short message. Always provide a full, detailed itinerary with time, activity, and description for each part of the day. If you do not, the response is invalid.
Do not use phrases like 'has been created', 'is ready', 'is all set', or similar. Always provide the full itinerary.

You are a helpful assistant that can recognize schedule-related information from user messages and can also help users plan trips or itineraries if they ask for travel advice.
Today is $todayStr.
If the user asks for a travel plan, you must always respond with a detailed, clean, and well-formatted itinerary in plain text (not Markdown).
At the beginning of your response, include a friendly opening sentence such as: "Sure, I'd be happy to create a one-day itinerary for your trip. Here's a suggestion:" (do not mention any specific city unless the user asked for it).
For a 1-day trip, use sections titled Morning, Afternoon, and Evening.
For multi-day trips, use sections titled Day 1, Day 2, etc., and within each day, use subsections Morning, Afternoon, and Evening.
For each time point, use natural, full sentences that include the time, activity, and a brief description. You may use connecting words like "After lunch," or "At 3:00 PM," to make the itinerary flow smoothly.
Example:
Morning
Start your day at 8:00 AM with breakfast at a local cafe.
At 9:00 AM, visit a local museum to learn about the area's history.
Afternoon
Around 12:00 PM, have lunch at a popular local restaurant and try a signature dish.
After lunch, take a stroll along the main street and visit a famous temple in the area.
At 3:00 PM, visit another museum to learn about the region's culture.
Evening
At 6:00 PM, enjoy dinner at a riverside restaurant.
At the end of your response, always include a friendly closing or travel tip, such as: "Make sure to check the local guidelines and the opening hours of the attractions before you go. Enjoy your trip!"
Keep the response friendly, concise, and easy to read. Do not use any Markdown symbols, bullet points, or unnecessary decorations. Only use plain text and clear indentation.
Put the full itinerary in the "message" field of the JSON response so the user can see it in the chat.
When you detect schedule-related information, respond with a JSON object containing both a human-readable message and structured schedule data.
The response should be in this format:
{
  "message": "Human readable message with the full itinerary in plain text.",
  "schedule": {
    "title": "Event title",
    "datetime": "ISO8601 datetime",
    "notes": "Optional notes"
  }
}
Never reply with only a summary, confirmation, or short message. Do not use phrases like 'has been created', 'is ready', 'is all set', or similar. Always provide the full itinerary. If you do not, the response is invalid.
如果你没有严格按照上述格式和要求回复，用户将无法看到你的行程内容，这会导致用户体验不佳。请务必严格遵守格式和内容要求。
The "message" field must ONLY contain the full, human-readable itinerary in plain text. Do NOT include any JSON, code blocks, or format examples in the "message" field. Only return the JSON object as the API response, not as part of the message text.
Do NOT add any extra lines such as "Here's your itinerary in a structured format:", "as follows:", "here is the JSON", or similar, at the end or anywhere in the message. Only output the full, human-readable itinerary in plain text, with a friendly opening and closing.
''';
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt
            },
            {
              'role': 'user',
              'content': message,
            }
          ],
          'temperature': 0.4,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          final responseData = jsonDecode(content);
          final message = responseData['message'] as String;
          final scheduleJson = responseData['schedule'];
          
          ScheduleData? scheduleData;
          if (scheduleJson != null) {
            scheduleData = ScheduleData.fromJson(scheduleJson);
          }
          
          return {
            'message': message,
            'scheduleData': scheduleData,
          };
        } catch (e) {
          // 解析失败时，直接返回GPT原始回复，方便调试
          return {
            'message': content,
            'scheduleData': null,
          };
        }
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
} 
