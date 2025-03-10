// This is a React Native implementation for the Presence mobile app
// File: App.js - Main entry point for the React Native application

import React, { useState, useEffect, useRef } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { 
  SafeAreaView, 
  View, 
  Text, 
  TouchableOpacity, 
  StyleSheet, 
  FlatList,
  Image,
  ActivityIndicator,
  Alert,
  Platform,
  StatusBar
} from 'react-native';
import { Audio } from 'expo-audio';
import Ionicons from 'react-native-vector-icons/Ionicons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Notifications from 'expo-notifications';
import { AudioFingerprinter } from './services/fingerprinter';
import { APIService } from './services/api';

// Configure notifications
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

// API service configuration
const apiService = new APIService({
  baseUrl: 'https://presence-api.talkstudio.space',
  // For local testing with Kubernetes
  // baseUrl: 'http://localhost', 
});

// Fingerprint service
const fingerprinter = new AudioFingerprinter();

// Home Screen - Audio detection and context discovery
function HomeScreen({ navigation }) {
  const [isDetecting, setIsDetecting] = useState(false);
  const [context, setContext] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const recordingRef = useRef(null);

  // Request permissions
  useEffect(() => {
    (async () => {
      try {
        const { status } = await Audio.requestPermissionsAsync();
        if (status !== 'granted') {
          setError('Microphone permission is required to detect audio contexts');
        }
      } catch (err) {
        setError('Failed to request permissions: ' + err.message);
      }
    })();
  }, []);

  // Start audio detection
  const startDetection = async () => {
    try {
      setLoading(true);
      setError(null);
      setContext(null);
      setIsDetecting(true);

      // Configure audio recording
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        interruptionModeIOS: Audio.INTERRUPTION_MODE_IOS_DO_NOT_MIX,
        playsInSilentModeIOS: true,
        shouldDuckAndroid: true,
        interruptionModeAndroid: Audio.INTERRUPTION_MODE_ANDROID_DO_NOT_MIX,
        playThroughEarpieceAndroid: false,
      });

      // Start recording
      const recording = new Audio.Recording();
      await recording.prepareToRecordAsync(Audio.RECORDING_OPTIONS_PRESET_HIGH_QUALITY);
      await recording.startAsync();
      recordingRef.current = recording;
      
      // Wait a few seconds to capture enough audio
      setTimeout(stopDetectionAndMatch, 5000);
    } catch (err) {
      setError('Failed to start detection: ' + err.message);
      setIsDetecting(false);
      setLoading(false);
    }
  };

  // Stop detection and process the audio
  const stopDetectionAndMatch = async () => {
    try {
      if (!recordingRef.current) return;
      
      // Stop recording
      await recordingRef.current.stopAndUnloadAsync();
      
      // Get the recording URI
      const uri = recordingRef.current.getURI();
      recordingRef.current = null;

      // Generate fingerprint from audio
      const audioData = await fingerprinter.generateFingerprint(uri);

      // Get device ID
      const deviceId = await AsyncStorage.getItem('deviceId') || 
        `device_${Platform.OS}_${Date.now()}`;
      
      // Save device ID if not already saved
      if (!await AsyncStorage.getItem('deviceId')) {
        await AsyncStorage.setItem('deviceId', deviceId);
      }

      // Send to fingerprint service
      const result = await apiService.matchFingerprint({
        audioData,
        device_id: deviceId,
        location: await getCurrentLocation()
      });

      // Handle result
      if (result.matched) {
        setContext(result.context);
        
        // Save in history
        const history = JSON.parse(await AsyncStorage.getItem('contextHistory') || '[]');
        history.unshift({
          id: result.context.id,
          name: result.context.name,
          type: result.context.type,
          timestamp: new Date().toISOString(),
          confidence: result.confidence
        });
        // Limit history to 50 items
        if (history.length > 50) history.length = 50;
        await AsyncStorage.setItem('contextHistory', JSON.stringify(history));
      } else {
        setError('No match found. Try again in a different location or with clearer audio.');
      }
    } catch (err) {
      setError('Error processing audio: ' + err.message);
    } finally {
      setIsDetecting(false);
      setLoading(false);
    }
  };

  // Get current location (simplified)
  const getCurrentLocation = async () => {
    // In a real app, we would use geolocation
    return {
      latitude: 37.7749,
      longitude: -122.4194
    };
  };

  // Join a context (chat room)
  const joinContext = () => {
    if (context) {
      navigation.navigate('Chat', { contextId: context.id, contextName: context.name });
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" />
      <View style={styles.header}>
        <Text style={styles.title}>Presence</Text>
      </View>
      
      <View style={styles.contentContainer}>
        {!context ? (
          <View style={styles.detectionContainer}>
            <TouchableOpacity 
              style={[styles.detectButton, isDetecting && styles.detectingButton]}
              onPress={startDetection}
              disabled={isDetecting || loading}
            >
              {loading ? (
                <ActivityIndicator color="#fff" size="large" />
              ) : (
                <>
                  <Ionicons name={isDetecting ? "radio" : "radio-outline"} size={64} color="#fff" />
                  <Text style={styles.detectButtonText}>
                    {isDetecting ? 'Listening...' : 'Tap to Detect'}
                  </Text>
                </>
              )}
            </TouchableOpacity>
            
            {error && (
              <View style={styles.errorContainer}>
                <Text style={styles.errorText}>{error}</Text>
                <TouchableOpacity onPress={() => setError(null)}>
                  <Text style={styles.dismissText}>Dismiss</Text>
                </TouchableOpacity>
              </View>
            )}
            
            <Text style={styles.instructionText}>
              Tap the button to detect what's playing around you
            </Text>
          </View>
        ) : (
          <View style={styles.matchContainer}>
            <Text style={styles.matchTitle}>Found a match!</Text>
            <View style={styles.contextCard}>
              <Text style={styles.contextName}>{context.name}</Text>
              <Text style={styles.contextType}>{context.type}</Text>
              <Text style={styles.contextUsers}>{context.users_count} people here</Text>
              
              <TouchableOpacity style={styles.joinButton} onPress={joinContext}>
                <Text style={styles.joinButtonText}>Join Conversation</Text>
              </TouchableOpacity>
            </View>
            
            <TouchableOpacity 
              style={styles.detectAgainButton}
              onPress={() => setContext(null)}
            >
              <Text style={styles.detectAgainText}>Detect Something Else</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

// History Screen - Past detected contexts
function HistoryScreen({ navigation }) {
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadHistory();
    
    // Refresh history when the screen comes into focus
    const unsubscribe = navigation.addListener('focus', loadHistory);
    return unsubscribe;
  }, [navigation]);

  const loadHistory = async () => {
    try {
      setLoading(true);
      const historyData = await AsyncStorage.getItem('contextHistory');
      if (historyData) {
        setHistory(JSON.parse(historyData));
      }
    } catch (err) {
      console.error('Failed to load history:', err);
    } finally {
      setLoading(false);
    }
  };

  const clearHistory = async () => {
    try {
      await AsyncStorage.setItem('contextHistory', '[]');
      setHistory([]);
    } catch (err) {
      console.error('Failed to clear history:', err);
    }
  };

  const confirmClearHistory = () => {
    Alert.alert(
      'Clear History',
      'Are you sure you want to clear your detection history?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Clear', style: 'destructive', onPress: clearHistory }
      ]
    );
  };

  const renderHistoryItem = ({ item }) => (
    <TouchableOpacity 
      style={styles.historyItem}
      onPress={() => navigation.navigate('Chat', { 
        contextId: item.id, 
        contextName: item.name 
      })}
    >
      <View style={styles.historyItemContent}>
        <Text style={styles.historyItemName}>{item.name}</Text>
        <Text style={styles.historyItemType}>{item.type}</Text>
        <Text style={styles.historyItemDate}>
          {new Date(item.timestamp).toLocaleString()}
        </Text>
      </View>
      <Ionicons name="chevron-forward" size={24} color="#999" />
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>History</Text>
        {history.length > 0 && (
          <TouchableOpacity onPress={confirmClearHistory}>
            <Text style={styles.clearText}>Clear</Text>
          </TouchableOpacity>
        )}
      </View>
      
      {loading ? (
        <ActivityIndicator style={styles.loader} size="large" color="#6200ee" />
      ) : history.length > 0 ? (
        <FlatList
          data={history}
          renderItem={renderHistoryItem}
          keyExtractor={(item, index) => `${item.id}-${index}`}
          contentContainerStyle={styles.historyList}
        />
      ) : (
        <View style={styles.emptyContainer}>
          <Ionicons name="time-outline" size={80} color="#ccc" />
          <Text style={styles.emptyText}>No detection history yet</Text>
          <Text style={styles.emptySubtext}>
            Detected contexts will appear here
          </Text>
        </View>
      )}
    </SafeAreaView>
  );
}

// Chat Screen - Context-specific chat rooms
function ChatScreen({ route }) {
  const { contextId, contextName } = route.params;
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [user, setUser] = useState(null);
  const socketRef = useRef(null);

  // Load user data and connect to chat
  useEffect(() => {
    const loadUserAndConnect = async () => {
      try {
        setLoading(true);
        
        // Get user from local storage or use anonymous ID
        const deviceId = await AsyncStorage.getItem('deviceId');
        const userData = await AsyncStorage.getItem('userData');
        
        let currentUser;
        if (userData) {
          currentUser = JSON.parse(userData);
        } else {
          // Create anonymous user
          currentUser = {
            id: `anonymous_${deviceId}`,
            username: `visitor_${Math.floor(Math.random() * 1000)}`,
            isAnonymous: true
          };
          await AsyncStorage.setItem('userData', JSON.stringify(currentUser));
        }
        
        setUser(currentUser);
        
        // Load messages
        const roomMessages = await apiService.getChatMessages(contextId);
        setMessages(roomMessages);
        
        // Connect to chat service
        connectToChat(currentUser, contextId);
      } catch (err) {
        console.error('Failed to load chat:', err);
        Alert.alert('Error', 'Failed to load chat: ' + err.message);
      } finally {
        setLoading(false);
      }
    };
    
    loadUserAndConnect();
    
    return () => {
      // Disconnect from chat when leaving
      if (socketRef.current) {
        socketRef.current.disconnect();
      }
    };
  }, [contextId]);

  // Connect to chat service
  const connectToChat = (user, contextId) => {
    // In a real app, we would use a WebSocket connection library
    console.log(`Connecting to chat for context ${contextId} as user ${user.id}`);
    
    // Simulate WebSocket connection
    setTimeout(() => {
      setIsConnected(true);
      
      // Simulate receiving messages
      const mockMessage = {
        id: `msg_${Date.now()}`,
        userId: 'system',
        userName: 'System',
        content: `Welcome to the chat for "${contextName}"!`,
        createdAt: new Date().toISOString()
      };
      
      setMessages(prev => [mockMessage, ...prev]);
    }, 1000);
  };

  // Send a message
  const sendMessage = () => {
    if (!message.trim() || !isConnected || !user) return;
    
    const newMessage = {
      id: `msg_${Date.now()}`,
      userId: user.id,
      userName: user.username,
      content: message.trim(),
      createdAt: new Date().toISOString()
    };
    
    // In a real app, we would send this through WebSocket
    setMessages(prev => [newMessage, ...prev]);
    setMessage('');
    
    // Simulate API call
    apiService.sendChatMessage(contextId, message.trim());
  };

  const renderMessage = ({ item }) => (
    <View style={[
      styles.messageContainer,
      item.userId === user?.id ? styles.myMessage : styles.otherMessage
    ]}>
      {item.userId !== user?.id && (
        <Text style={styles.messageSender}>{item.userName}</Text>
      )}
      <Text style={styles.messageText}>{item.content}</Text>
      <Text style={styles.messageTime}>
        {new Date(item.createdAt).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
      </Text>
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.chatHeader}>
        <Text style={styles.chatHeaderTitle}>{contextName}</Text>
        {!isConnected && <ActivityIndicator size="small" color="#fff" />}
      </View>
      
      {loading ? (
        <ActivityIndicator style={styles.loader} size="large" color="#6200ee" />
      ) : (
        <>
          <FlatList
            data={messages}
            renderItem={renderMessage}
            keyExtractor={item => item.id}
            contentContainerStyle={styles.messageList}
            inverted
          />
          
          <View style={styles.inputContainer}>
            <TextInput
              style={styles.input}
              value={message}
              onChangeText={setMessage}
              placeholder="Type a message..."
              placeholderTextColor="#999"
              multiline
            />
            <TouchableOpacity 
              style={[styles.sendButton, !message.trim() && styles.sendButtonDisabled]}
              onPress={sendMessage}
              disabled={!message.trim() || !isConnected}
            >
              <Ionicons name="send" size={24} color="#fff" />
            </TouchableOpacity>
          </View>
        </>
      )}
    </SafeAreaView>
  );
}

// Profile Screen - User settings and account management
function ProfileScreen() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAnonymous, setIsAnonymous] = useState(true);
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  // Load user data
  useEffect(() => {
    const loadUser = async () => {
      try {
        setLoading(true);
        const userData = await AsyncStorage.getItem('userData');
        
        if (userData) {
          const parsedUser = JSON.parse(userData);
          setUser(parsedUser);
          setIsAnonymous(parsedUser.isAnonymous);
          setIsLoggedIn(!parsedUser.isAnonymous);
        }
      } catch (err) {
        console.error('Failed to load user:', err);
      } finally {
        setLoading(false);
      }
    };
    
    loadUser();
  }, []);

  // Handle login
  const handleLogin = async () => {
    // In a real app, navigate to login screen
    Alert.alert('Login', 'This would navigate to the login screen');
  };

  // Handle logout
  const handleLogout = async () => {
    // In a real app, we would call the logout API
    await AsyncStorage.removeItem('userData');
    setUser(null);
    setIsLoggedIn(false);
    setIsAnonymous(true);
  };

  // Show login confirmation
  const confirmLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to log out?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', style: 'destructive', onPress: handleLogout }
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Profile</Text>
      </View>
      
      {loading ? (
        <ActivityIndicator style={styles.loader} size="large" color="#6200ee" />
      ) : (
        <View style={styles.profileContainer}>
          <View style={styles.avatarContainer}>
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>
                {user?.username?.charAt(0).toUpperCase() || '?'}
              </Text>
            </View>
            <Text style={styles.username}>{user?.username || 'Guest'}</Text>
          </View>
          
          {isLoggedIn ? (
            <>
              <View style={styles.infoContainer}>
                <Text style={styles.infoLabel}>Email</Text>
                <Text style={styles.infoValue}>{user?.email || 'Not provided'}</Text>
              </View>
              
              <TouchableOpacity 
                style={styles.logoutButton}
                onPress={confirmLogout}
              >
                <Text style={styles.logoutButtonText}>Logout</Text>
              </TouchableOpacity>
            </>
          ) : (
            <View style={styles.loginContainer}>
              <Text style={styles.loginText}>
                You are browsing as a guest. Log in to save your preferences and history.
              </Text>
              
              <TouchableOpacity 
                style={styles.loginButton}
                onPress={handleLogin}
              >
                <Text style={styles.loginButtonText}>Log In or Sign Up</Text>
              </TouchableOpacity>
            </View>
          )}
          
          <View style={styles.settingsContainer}>
            <Text style={styles.settingsSectionTitle}>Settings</Text>
            
            <TouchableOpacity style={styles.settingsItem}>
              <Ionicons name="notifications-outline" size={24} color="#333" />
              <Text style={styles.settingsItemText}>Notification Preferences</Text>
              <Ionicons name="chevron-forward" size={20} color="#999" />
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.settingsItem}>
              <Ionicons name="globe-outline" size={24} color="#333" />
              <Text style={styles.settingsItemText}>Language</Text>
              <Ionicons name="chevron-forward" size={20} color="#999" />
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.settingsItem}>
              <Ionicons name="shield-outline" size={24} color="#333" />
              <Text style={styles.settingsItemText}>Privacy Settings</Text>
              <Ionicons name="chevron-forward" size={20} color="#999" />
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.settingsItem}>
              <Ionicons name="help-circle-outline" size={24} color="#333" />
              <Text style={styles.settingsItemText}>Help & Support</Text>
              <Ionicons name="chevron-forward" size={20} color="#999" />
            </TouchableOpacity>
          </View>
          
          <Text style={styles.versionText}>Presence v1.0.0</Text>
        </View>
      )}
    </SafeAreaView>
  );
}

// Main navigation structure
function MainTabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName;
          
          if (route.name === 'Home') {
            iconName = focused ? 'radio' : 'radio-outline';
          } else if (route.name === 'History') {
            iconName = focused ? 'time' : 'time-outline';
          } else if (route.name === 'Profile') {
            iconName = focused ? 'person' : 'person-outline';
          }
          
          return <Ionicons name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#6200ee',
        tabBarInactiveTintColor: '#999',
      })}
    >
      <Tab.Screen name="Home" component={HomeScreen} options={{ headerShown: false }} />
      <Tab.Screen name="History" component={HistoryScreen} options={{ headerShown: false }} />
      <Tab.Screen name="Profile" component={ProfileScreen} options={{ headerShown: false }} />
    </Tab.Navigator>
  );
}

// App entry point
export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen 
          name="Main" 
          component={MainTabNavigator} 
          options={{ headerShown: false }}
        />
        <Stack.Screen 
          name="Chat" 
          component={ChatScreen}
          options={({ route }) => ({ title: route.params.contextName })}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

// Services
// fingerprinter.js - Audio processing
export class AudioFingerprinter {
  async generateFingerprint(audioUri) {
    // In a real app, we would process the audio to extract features
    // For this demo, we'll just convert the audio to base64
    try {
      console.log(`Generating fingerprint for audio at ${audioUri}`);
      
      // In a real app, we would:
      // 1. Load the audio file
      // 2. Process it (FFT, peak detection, etc.)
      // 3. Generate a compact fingerprint
      
      // For demo purposes, we'll simulate it
      const audioData = `base64_audio_data_${Date.now()}`;
      
      return audioData;
    } catch (err) {
      console.error('Fingerprinting error:', err);
      throw err;
    }
  }
}

// api.js - API client
export class APIService {
  constructor(config) {
    this.baseUrl = config.baseUrl;
  }
  
  async matchFingerprint(data) {
    try {
      console.log('Matching fingerprint:', data);
      
      // In a real app, we would make an HTTP request to the API
      // For demo purposes, we'll simulate it
      
      // 70% chance of finding a match
      const matched = Math.random() > 0.3;
      
      if (matched) {
        return {
          matched: true,
          confidence: Math.floor(75 + Math.random() * 25), // 75-100%
          context: {
            id: `ctx_${Date.now()}`,
            name: this.getRandomContextName(),
            type: this.getRandomContextType(),
            users_count: Math.floor(Math.random() * 1000),
            created_at: new Date().toISOString()
          }
        };
      } else {
        return {
          matched: false,
          message: 'No matching context found'
        };
      }
    } catch (err) {
      console.error('API error:', err);
      throw err;
    }
  }
  
  async getChatMessages(contextId) {
    // Simulated messages
    return [
      {
        id: 'msg_1',
        userId: 'user_1',
        userName: 'Alice',
        content: 'Hello everyone! Just joined.',
        createdAt: new Date(Date.now() - 1000000).toISOString()
      },
      {
        id: 'msg_2',
        userId: 'user_2',
        userName: 'Bob',
        content: 'Welcome Alice! We were just discussing the show.',
        createdAt: new Date(Date.now() - 900000).toISOString()
      },
      {
        id: 'msg_3',
        userId: 'user_3',
        userName: 'Charlie',
        content: 'I can\'t believe what just happened!',
        createdAt: new Date(Date.now() - 800000).toISOString()
      }
    ];
  }
  
  async sendChatMessage(contextId, content) {
    console.log(`Sending message to context ${contextId}: ${content}`);
    // In a real app, we would send this to the API
    return { success: true };
  }
  
  getRandomContextName() {
    const names = [
      'CNN Breaking News',
      'NFL Game: Chiefs vs Eagles',
      'Taylor Swift Concert',
      'Joe Rogan Podcast #1984',
      'HBO Show: House of the Dragon',
      'NBA Finals: Lakers vs Celtics',
      'Local News at 11',
      'Movie: Dune Part Two',
      'Jimmy Fallon Show'
    ];
    return names[Math.floor(Math.random() * names.length)];
  }
  
  getRandomContextType() {
    const types = [
      'broadcast',
      'sports_event',
      'concert',
      'podcast',
      'tv_show',
      'movie',
      'live_event'
    ];
    return types[Math.floor(Math.random() * types.length)];
  }
}

// Styles
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa'
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 15,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#eee'
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333'
  },
  clearText: {
    fontSize: 16,
    color: '#6200ee'
  },
  contentContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20
  },
  detectionContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%'
  },
  detectButton: {
    backgroundColor: '#6200ee',
    padding: 30,
    borderRadius: 100,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 5,
    marginBottom: 30
  },
  detectingButton: {
    backgroundColor: '#4a0dab'
  },
  detectButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    marginTop: 10
  },
  instructionText: {
    textAlign: 'center',
    color: '#666',
    fontSize: 16,
    marginTop: 20
  },
  errorContainer: {
    backgroundColor: '#ffebee',
    padding: 15,
    borderRadius: 10,
    marginVertical: 20,
    width: '100%'
  },
  errorText: {
    color: '#c62828',
    fontSize: 16,
    marginBottom: 10
  },
  dismissText: {
    color: '#6200ee',
    fontSize: 14,
    textAlign: 'right'
  },
  matchContainer: {
    alignItems: 'center',
    width: '100%'
  },
  matchTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    color: '#333'
  },
  contextCard: {
    backgroundColor: '#fff',
    padding: 20,
    borderRadius: 15,
    width: '100%',
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 5,
    marginBottom: 20
  },
  contextName: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 5,
    color: '#333'
  },
  contextType: {
    fontSize: 16,
    color: '#666',
    marginBottom: 10
  },
  contextUsers: {
    fontSize: 14,
    color: '#666',
    marginBottom: 20
  },
  joinButton: {
    backgroundColor: '#6200ee',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center'
  },
  joinButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold'
  },
  detectAgainButton: {
    marginTop: 20
  },
  detectAgainText: {
    color: '#6200ee',
    fontSize: 16
  },
  // History screen styles
  historyList: {
    padding: 15
  },
  historyItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#fff',
    padding: 15,
    borderRadius: 10,
    marginBottom: 10,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2
  },
  historyItemContent: {
    flex: 1
  },
  historyItemName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 5
  },
  historyItemType: {
    fontSize: 14,
    color: '#666',
    marginBottom: 5
  },
  historyItemDate: {
    fontSize: 12,
    color: '#999'
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20
  },
  emptyText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#666',
    marginTop: 20
  },
  emptySubtext: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
    marginTop: 10
  },
  loader: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center'
  },
  // Chat screen styles
  chatHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#6200ee',
    paddingHorizontal: 20,
    paddingVertical: 15
  },
  chatHeaderTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff'
  },
  messageList: {
    padding: 15,
    paddingBottom: 70 // Space for input
  },
  messageContainer: {
    maxWidth: '80%',
    padding: 15,
    borderRadius: 20,
    marginBottom: 10
  },
  myMessage: {
    alignSelf: 'flex-end',
    backgroundColor: '#e3f2fd',
    borderBottomRightRadius: 5
  },
  otherMessage: {
    alignSelf: 'flex-start',
    backgroundColor: '#fff',
    borderBottomLeftRadius: 5
  },
  messageSender: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#666',
    marginBottom: 5
  },
  messageText: {
    fontSize: 16,
    color: '#333'
  },
  messageTime: {
    fontSize: 12,
    color: '#999',
    alignSelf: 'flex-end',
    marginTop: 5
  },
  inputContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 10,
    borderTopWidth: 1,
    borderTopColor: '#eee'
  },
  input: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    borderRadius: 20,
    paddingHorizontal: 15,
    paddingVertical: 10,
    fontSize: 16,
    maxHeight: 100
  },
  sendButton: {
    backgroundColor: '#6200ee',
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 10
  },
  sendButtonDisabled: {
    backgroundColor: '#ccc'
  },
  // Profile screen styles
  profileContainer: {
    flex: 1,
    padding: 20
  },
  avatarContainer: {
    alignItems: 'center',
    marginBottom: 30
  },
  avatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#6200ee',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 15
  },
  avatarText: {
    fontSize: 40,
    fontWeight: 'bold',
    color: '#fff'
  },
  username: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333'
  },
  infoContainer: {
    backgroundColor: '#fff',
    padding: 15,
    borderRadius: 10,
    marginBottom: 20
  },
  infoLabel: {
    fontSize: 14,
    color: '#999',
    marginBottom: 5
  },
  infoValue: {
    fontSize: 16,
    color: '#333'
  },
  loginContainer: {
    backgroundColor: '#fff',
    padding: 20,
    borderRadius: 10,
    marginBottom: 20
  },
  loginText: {
    fontSize: 16,
    color: '#666',
    marginBottom: 20,
    textAlign: 'center'
  },
  loginButton: {
    backgroundColor: '#6200ee',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center'
  },
  loginButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold'
  },
  logoutButton: {
    backgroundColor: '#f5f5f5',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 20
  },
  logoutButtonText: {
    color: '#c62828',
    fontSize: 16,
    fontWeight: 'bold'
  },
  settingsContainer: {
    backgroundColor: '#fff',
    borderRadius: 10,
    marginBottom: 20
  },
  settingsSectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#eee'
  },
  settingsItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#eee'
  },
  settingsItemText: {
    fontSize: 16,
    color: '#333',
    marginLeft: 15,
    flex: 1
  },
  versionText: {
    textAlign: 'center',
    color: '#999',
    fontSize: 14,
    marginTop: 20
  }
});
