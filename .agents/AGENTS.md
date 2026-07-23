# RoboBoy Workspace Rules

- **Main Server/GUI**: The primary user interface is the Flask application in `app.py`, running on `http://127.0.0.1:5001`.
- **Hacker Theme UI**: It serves the hacker simulator theme located in `templates/index.html`.
- **Ignore Flutter/FastAPI for Localhost**: Unless explicitly requested, do not run the Flutter frontend (`frontend/` folder) or the FastAPI backend (`backend/` folder). Running localhost means launching `python3 app.py` from the root directory.
