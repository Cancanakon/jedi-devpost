# JEDI (Just-in-time Execution & Defense Interface)

JEDI is an autonomous cybersecurity sentinel that intercepts, analyzes, and neutralizes malicious code or hardcoded secrets in real-time before they merge into the main branch.

## Tech Stack
*   **Backend:** Python, FastAPI, Uvicorn
*   **AI Engine:** Google Cloud Vertex AI 
*   **Database / Real-time Stream:** Firebase Firestore
*   **Frontend / Command Center:** Flutter, Dart, Riverpod
*   **Webhooks & Tunneling:** GitLab API, Ngrok

## Prerequisites
To run this project locally, you will need:
*   Python 3.x
*   Flutter SDK
*   Ngrok installed

## Setup Instructions

### 1. Backend Setup (FastAPI)
1. Navigate to the backend directory:
   `cd backend`
2. Install the required dependencies:
   `pip install -r requirements.txt`
3. Set up your environment variables. Create a `.env` file and add your credentials (Vertex AI, Firebase, etc.).
4. Start the local server:
   `uvicorn main:app --reload`
5. Start Ngrok to expose your local server to the web (for GitLab Webhooks):
   `ngrok http 8000`

### 2. Frontend Setup (Flutter Command Center)
1. Navigate to the frontend directory:
   `cd frontend`
2. Get the Flutter packages:
   `flutter pub get`
3. Run the application:
   `flutter run`

## License
This project is licensed under the MIT License - see the LICENSE file for details.
