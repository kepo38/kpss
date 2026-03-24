import requests

class GeminiAPI:
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = "https://gemini.api/v1"

    def generate_questions(self, topic, number_of_questions):
        url = f"{self.base_url}/generate"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        data = {"topic": topic, "count": number_of_questions}
        response = requests.post(url, json=data, headers=headers)
        response.raise_for_status()  # Raises an error for bad responses
        return response.json()


class QuestionGenerator:
    def __init__(self, api_key):
        self.api = GeminiAPI(api_key)

    def get_kpss_questions(self, topic, number_of_questions):
        try:
            questions_data = self.api.generate_questions(topic, number_of_questions)
            kpss_questions = []
            for question in questions_data:
                kpss_questions.append({
                    'question': question['text'],
                    'option_A': question['options'][0],
                    'option_B': question['options'][1],
                    'option_C': question['options'][2],
                    'option_D': question['options'][3],
                    'mnemonic': question['mnemonic']
                })
            return kpss_questions
        except Exception as e:
            print(f"Error generating questions: {e}")
            return []


# Example usage:
# generator = QuestionGenerator(api_key='YOUR_API_KEY')
# questions = generator.get_kpss_questions('Current Affairs', 5)
# print(questions)
