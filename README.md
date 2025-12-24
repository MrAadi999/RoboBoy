# RoboBoy
this is latest  personal assitant 
# RoboBoy Voice Assistant 🤖

A powerful, multilingual voice assistant with **advanced modern GUI interface** that can perform various tasks including calculations, Wikipedia searches, weather updates, application management, and more!

## 🎨 **NEW: Modern GUI Features**

### **Advanced Interface**
- **🌓 Dark/Light Theme**: Switch between professional dark and light modes
- **📱 Multi-Panel Layout**: Organized sections for chat, commands, and memory
- **🎯 Quick Command Buttons**: One-click access to common functions
- **📊 Real-time Status Bar**: Live feedback and system status
- **⚙️ Settings Panel**: Easy configuration for API keys and preferences
- **💾 Memory Viewer**: Visual display of stored memories
- **🍎 Menu Bar**: File, Settings, Help, and Language options
- **🎨 Modern Styling**: Professional design with icons and animations

### **Enhanced User Experience**
- **🔔 Visual Feedback**: Status indicators for all operations
- **🎭 Color-Coded Messages**: User/Assistant message differentiation
- **📱 Responsive Design**: Better layout and scaling
- **⌨️ Keyboard Shortcuts**: Quick access via Enter key
- **🎨 Hover Effects**: Modern button interactions
- **📋 Tooltips**: Help text for all features

## Features ✨

- **🗣️ Voice Recognition**: Speak commands naturally
- **🔊 Text-to-Speech**: Audio responses in multiple languages
- **🌐 Multi-language Support**: Hinglish and English modes
- **💾 Memory System**: Remembers important information with visual panel
- **📚 Wikipedia Search**: Get information from Wikipedia
- **🌤️ Weather Updates**: Real-time weather information (with API key setup)
- **🧮 Mathematical Calculations**: Solve complex equations
- **💻 App Management**: Open applications on your system
- **🔄 System Commands**: Shutdown, restart functionality
- **💬 Chat Interface**: Text-based interaction as fallback
- **⚡ Quick Actions**: Pre-configured buttons for common tasks
- **🎛️ Advanced Settings**: Theme switching, API configuration

## Installation 📦

### Prerequisites

Make sure you have Python 3.6+ installed on your system.

### Required Dependencies

Install the required Python packages:

```bash
pip install speechrecognition pyttsx3 wikipedia requests
```

### System Dependencies

#### For macOS:
```bash
# Install PortAudio for pyttsx3
brew install portaudio
```

#### For Ubuntu/Debian:
```bash
sudo apt-get install python3-dev
sudo apt-get install portaudio19-dev
```

#### For Windows:
No additional system dependencies required.

## Setup ⚙️

### 1. Weather API Configuration (Optional)

To enable weather functionality:

1. Get a free API key from [OpenWeatherMap](https://openweathermap.org/api)
2. Open RoboBoy and go to **File > Settings**
3. Enter your API key in the settings panel
4. Save settings

### 2. Permissions

Ensure your application has access to:
- **Microphone**: For voice recognition
- **Speaker/Audio**: For text-to-speech output

### 3. Initial Setup

1. **Language Selection**: Choose between Hinglish AI (1) or English AI (2)
2. **Theme Selection**: Choose Dark or Light theme in settings
3. **API Keys**: Configure weather API if needed

## Usage 🚀

### Running the Application

```bash
python3 /Users/adityakumar/Desktop/jarvis_beginner/main_fixed_clean.py
```

### Interface Overview

#### **Main Chat Area**
- Central conversation space
- Color-coded messages (User: 🟢, Assistant: 🔵)
- Scrollable text history
- Real-time message updates

#### **Quick Commands Panel**
- **🕒 Time**: Get current time
- **📅 Date**: Get current date  
- **🧠 Remember**: Store information
- **💭 Recall**: View stored memories
- **🌐 Wikipedia**: Search Wikipedia
- **🌤️ Weather**: Get weather info
- **🧮 Calculate**: Mathematical calculations
- **📖 Help**: Show available commands
- **🔧 Open App**: Launch applications
- **❌ Exit**: Close application

#### **Memory Panel**
- Visual display of all stored memories
- Numbered list format
- Real-time updates
- Persistent storage

#### **Settings Panel**
- Language toggle (Hinglish/English)
- Theme selection (Dark/Light)
- API key configuration
- Easy save/apply functionality

### Available Commands 🗂️

#### **Voice Commands**
- Say "roboboy" followed by your command
- Example: "roboboy what is 15 times 25"

#### **Text Commands**
- Type commands directly in input box
- Click "Send" or press Enter
- Use quick command buttons for common tasks

#### **General Commands**
- `roboboy help` - Show available commands
- `roboboy exit` - Exit the application

#### **Information Commands**
- `roboboy time` - Get current time
- `roboboy date` - Get current date

#### **Memory Commands**
- `roboboy remember [data]` - Store information in memory
- `roboboy what do you remember` - Recall stored information

#### **Search Commands**
- `roboboy wikipedia [query]` - Search Wikipedia for information

#### **Weather Commands**
- `roboboy weather in [city]` - Get weather for a specific city

#### **Calculation Commands**
- `roboboy what is [expression]` - Calculate mathematical expressions
- `roboboy calculate [expression]` - Alternative calculation format
- `roboboy solve [expression]` - Solve equations

#### **System Commands**
- `roboboy open [application]` - Open specified application
- `roboboy shutdown` - Shutdown system
- `roboboy restart` - Restart system

### Voice Interaction 🎤

1. Click the "🎤 Voice" button in the input area
2. Speak your command clearly
3. Watch the status bar for recognition feedback
4. Wait for the audio response

### Text Interaction 💬

1. Type your command in the input box
2. Click "Send" or press Enter
3. View the conversation in the chat area
4. Monitor status updates in the status bar

## Language Support 🌏

### Hinglish Mode
- Responses in Hindi-English mix
- Cultural context understanding
- Informal, friendly interactions
- "Main tumhara RoboBoy hoon 🤖"

### English Mode
- Professional English responses
- Formal command structure
- International user-friendly
- "Hello Aditya 👋 I am RoboBoy 🤖"

## Configuration 🔧

### Theme Settings
- **Dark Theme**: Professional dark interface with green accents
- **Light Theme**: Clean light interface with blue accents
- Theme preference saved automatically

### Language Settings
- Language preference saved in `settings.txt`
- Change language via File > Settings menu

### API Key Management
- Weather API key stored securely in `api_keys.txt`
- Configure via Settings panel
- Real-time validation

### Memory Storage
- Persistent memory stored in `memory.txt`
- Visual display in memory panel
- Automatic updates

### Brain Training
- Add custom responses in `brain_hinglish.txt` or `brain_english.txt`
- Format: `question=answer`
- Example: `hello=Hi there! How can I help you?`

## Troubleshooting 🔍

### Common Issues

**1. Modern GUI Not Loading**
- Ensure all dependencies are installed
- Try running with: `python main_fixed.py`
- Check if tkinter is available

**2. Theme Not Applying**
- Restart the application
- Check theme file permissions
- Verify settings file integrity

**3. Settings Not Saving**
- Check file write permissions
- Ensure application has write access to directory

**4. Microphone Not Working**
- Check microphone permissions in system settings
- Ensure no other applications are using the microphone
- Try adjusting microphone sensitivity

**5. Speech Recognition Errors**
- Speak clearly and at moderate pace
- Reduce background noise
- Check internet connection for Google Speech API

**6. Text-to-Speech Issues**
- Check system audio settings
- Verify speakers/headphones are working
- Try restarting the audio engine

**7. Weather Not Working**
- Verify API key is correctly configured in Settings
- Check internet connection
- Ensure city name is spelled correctly

**8. Application Opening Fails**
- Ensure application names are exact matches
- Check if applications are installed in standard locations
- Verify system permissions

### Error Messages

- "Cannot divide by zero" - Mathematical error handling
- "City not found" - Weather API location issue
- "Multiple results found" - Wikipedia disambiguation
- "Invalid mathematical expression" - Calculation parsing error
- "API key not configured" - Weather service setup needed

### Status Bar Messages

- 🟢 "Ready" - System ready for commands
- 🔵 "Listening..." - Voice recognition active
- 🟡 "Processing..." - Command being processed
- 🟢 "Success" - Operation completed successfully
- 🔴 "Error" - Operation failed
- 🟠 "Warning" - Partial success or issues

## File Structure 📁

```
project/
├── main_fixed.py          # Main application with modern GUI
├── settings.txt           # Language preferences
├── theme.txt             # Theme selection (dark/light)
├── api_keys.txt          # API key storage
├── memory.txt            # Stored memories
├── brain_hinglish.txt    # Hinglish responses
├── brain_english.txt     # English responses
└── README.md             # This file
```

## Advanced Features 🎯

### Modern GUI Enhancements
- **Responsive Layout**: Adapts to different screen sizes
- **Theme Switching**: Live theme changes without restart
- **Real-time Status**: Live updates for all operations
- **Quick Actions**: One-click command execution
- **Visual Memory**: Organized memory display
- **Professional Styling**: Modern button design and colors

### Custom Brain Training
Add your own Q&A pairs:

1. Open `brain_hinglish.txt` or `brain_english.txt`
2. Add entries in format: `question=answer`
3. Example: `hello=Hi there! How can I help you?`

### Mathematical Expressions
Supports various calculation formats:
- `what is 15 * 25`
- `calculate (10 + 5) / 3`
- `solve 2^10`
- `compute sqrt(16)`

### Wikipedia Search Tips
- Use specific terms for better results
- Multiple results will show the first option
- Search terms are automatically optimized
- Status bar shows search progress

### Weather Configuration
- Easy API key setup through Settings menu
- Real-time weather data with detailed status
- Support for major cities worldwide
- Temperature and condition descriptions

## Screenshots 📸

### Dark Theme Interface
- Professional dark background with green accents
- Clean panel layout
- Modern button styling

### Light Theme Interface  
- Bright, clean interface with blue accents
- Professional appearance
- Easy on the eyes

### Settings Panel
- Language selection
- Theme switching
- API key configuration
- One-click save functionality

## Contributing 🤝

Feel free to contribute by:
- Adding new GUI features
- Improving language support
- Enhancing visual design
- Fixing bugs
- Adding new voice commands
- Improving documentation

## License 📄

This project is open source and available under the MIT License.

## Author 👨‍💻

**Aditya Kumar**
- Voice Assistant Developer
- Python Enthusiast
- GUI Designer

## Support 📞

For issues and questions:
1. Check the troubleshooting section
2. Review status bar messages
3. Ensure all dependencies are installed correctly
4. Verify permissions and settings

## Version History 📝

### Version 2.0 (Current)
- ✨ Complete GUI overhaul with modern design
- 🌓 Dark/Light theme support
- 🎛️ Advanced settings panel
- 📊 Real-time status updates
- 🎯 Quick command buttons
- 💾 Visual memory panel
- 🔧 Enhanced error handling
- 📱 Responsive design

### Version 1.0
- Basic GUI interface
- Voice recognition
- Text-to-speech
- Command processing

---

**RoboBoy** - Making voice interaction intelligent, fun, and beautiful! 🎉✨
