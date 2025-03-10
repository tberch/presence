// Web Portal Implementation for Presence Application
// This file contains the main React components for the web portal

// App.js - Main application component
import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, Link, useNavigate, useParams } from 'react-router-dom';
import { io } from 'socket.io-client';
import axios from 'axios';
import './App.css';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { 
  faRadio, 
  faHistory, 
  faUser, 
  faSignOutAlt, 
  faSearch, 
  faBell,
  faComments,
  faCog
} from '@fortawesome/free-solid-svg-icons';

// API configuration
const apiUrl = process.env.REACT_APP_API_URL || 'https://presence-api.talkstudio.space';
// For local testing with Kubernetes
// const apiUrl = 'http://localhost';

// Main App component
function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // Check for authentication on load
  useEffect(() => {
    const token = localStorage.getItem('token');
    
    if (token) {
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      fetchUserProfile();
    } else {
      setLoading(false);
    }
  }, []);

  // Fetch user profile
  const fetchUserProfile = async () => {
    try {
      const response = await axios.get(`${apiUrl}/user/me`);
      setUser(response.data);
    } catch (error) {
      console.error('Error fetching user profile:', error);
      localStorage.removeItem('token');
      delete axios.defaults.headers.common['Authorization'];
    } finally {
      setLoading(false);
    }
  };

  // Handle login success
  const handleLoginSuccess = (userData, token) => {
    localStorage.setItem('token', token);
    axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    setUser(userData);
  };

  // Handle logout
  const handleLogout = () => {
    localStorage.removeItem('token');
    delete axios.defaults.headers.common['Authorization'];
    setUser(null);
  };

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="loader"></div>
      </div>
    );
  }

  return (
    <Router>
      <div className="min-h-screen bg-gray-100">
        <Routes>
          <Route 
            path="/login" 
            element={
              user ? 
                <Navigate to="/dashboard" replace /> : 
                <Login onLoginSuccess={handleLoginSuccess} />
            } 
          />
          <Route 
            path="/register" 
            element={
              user ? 
                <Navigate to="/dashboard" replace /> : 
                <Register onRegisterSuccess={handleLoginSuccess} />
            } 
          />
          <Route 
            path="/dashboard/*" 
            element={
              user ? 
                <Dashboard user={user} onLogout={handleLogout} /> : 
                <Navigate to="/login" replace />
            } 
          />
          <Route 
            path="/" 
            element={<Navigate to={user ? "/dashboard" : "/login"} replace />} 
          />
        </Routes>
      </div>
    </Router>
  );
}

// Login component
function Login({ onLoginSuccess }) {
  const [credentials, setCredentials] = useState({ username: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCredentials(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await axios.post(`${apiUrl}/user/auth/login`, credentials);
      onLoginSuccess(response.data.user, response.data.token);
      navigate('/dashboard');
    } catch (error) {
      setError(error.response?.data?.error || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-100 py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md space-y-8">
        <div>
          <h1 className="text-center text-3xl font-extrabold text-purple-700">Presence</h1>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">Sign in to your account</h2>
        </div>
        
        {error && (
          <div className="rounded-md bg-red-50 p-4">
            <div className="text-sm text-red-700">{error}</div>
          </div>
        )}
        
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="-space-y-px rounded-md shadow-sm">
            <div>
              <label htmlFor="username" className="sr-only">Username</label>
              <input
                id="username"
                name="username"
                type="text"
                required
                className="relative block w-full appearance-none rounded-t-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-purple-500 focus:outline-none focus:ring-purple-500 sm:text-sm"
                placeholder="Username"
                value={credentials.username}
                onChange={handleChange}
                disabled={loading}
              />
            </div>
            <div>
              <label htmlFor="password" className="sr-only">Password</label>
              <input
                id="password"
                name="password"
                type="password"
                required
                className="relative block w-full appearance-none rounded-b-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-purple-500 focus:outline-none focus:ring-purple-500 sm:text-sm"
                placeholder="Password"
                value={credentials.password}
                onChange={handleChange}
                disabled={loading}
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              className="group relative flex w-full justify-center rounded-md border border-transparent bg-purple-600 py-2 px-4 text-sm font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-75"
            >
              {loading ? 'Signing in...' : 'Sign in'}
            </button>
          </div>
          
          <div className="text-center text-sm">
            <p>
              Don't have an account?{' '}
              <Link to="/register" className="font-medium text-purple-600 hover:text-purple-500">
                Register
              </Link>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
}

// Register component
function Register({ onRegisterSuccess }) {
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    confirmPassword: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    // Validate passwords match
    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    
    setLoading(true);

    try {
      const response = await axios.post(`${apiUrl}/user/auth/register`, {
        username: formData.username,
        email: formData.email,
        password: formData.password
      });
      
      onRegisterSuccess(response.data.user, response.data.token);
      navigate('/dashboard');
    } catch (error) {
      setError(error.response?.data?.error || 'Registration failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-100 py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md space-y-8">
        <div>
          <h1 className="text-center text-3xl font-extrabold text-purple-700">Presence</h1>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">Create an account</h2>
        </div>
        
        {error && (
          <div className="rounded-md bg-red-50 p-4">
            <div className="text-sm text-red-700">{error}</div>
          </div>
        )}
        
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="-space-y-px rounded-md shadow-sm">
            <div>
              <label htmlFor="username" className="sr-only">Username</label>
              <input
                id="username"
                name="username"
                type="text"
                required
                className="relative block w-full appearance-none rounded-t-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-purple-500 focus:outline-none focus:ring-purple-500 sm:text-sm"
                placeholder="Username"
                value={formData.username}
                onChange={handleChange}
                disabled={loading}
              />
            </div>
            <div>
              <label htmlFor="email" className="sr-only">Email</label>
              <input
                id="email"
                name="email"
                type="email"
                required
                className="relative block w-full appearance-none border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-purple-500 focus:outline-none focus:ring-purple-500 sm:text-sm"
                placeholder="Email"
                value={formData.email}
                onChange={handleChange}
                disabled={loading}
              />
            </div>
            <div>
              <label htmlFor="password" className="sr-only">Password</label>
              <input
                id="password"
                name="password"
                type="password"
                required
                className="relative block w-full appearance-none border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-purple-500 focus:outline-none focus:ring-purple-500 sm:text-sm"
                placeholder="Password"
                value={formData.password}
                onChange={handleChange}
                disabled={loading}
              />
            </div>
            <div>
              <label htmlFor="confirmPassword" className="sr-only">Confirm Password</label>
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                required
                className="relative block w-full appearance-none rounded-b-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-purple-500 focus:outline-none focus:ring-purple-500 sm:text-sm"
                placeholder="Confirm Password"
                value={formData.confirmPassword}
                onChange={handleChange}
                disabled={loading}
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              className="group relative flex w-full justify-center rounded-md border border-transparent bg-purple-600 py-2 px-4 text-sm font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-75"
            >
              {loading ? 'Creating account...' : 'Create account'}
            </button>
          </div>
          
          <div className="text-center text-sm">
            <p>
              Already have an account?{' '}
              <Link to="/login" className="font-medium text-purple-600 hover:text-purple-500">
                Sign in
              </Link>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
}

// Dashboard component with nested routes
function Dashboard({ user, onLogout }) {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  
  // Connect to notification service via WebSocket
  useEffect(() => {
    const socket = io(`${apiUrl}/notifications`);
    
    socket.on('connect', () => {
      console.log('Connected to notification service');
      
      // Authenticate socket
      socket.emit('authenticate', { userId: user.id });
    });
    
    socket.on('authenticated', () => {
      console.log('Authenticated with notification service');
    });
    
    socket.on('notification', (notification) => {
      setNotifications(prev => [notification, ...prev]);
      setUnreadCount(prev => prev + 1);
    });
    
    socket.on('unread_notifications', ({ notifications: unreadNotifications }) => {
      setNotifications(unreadNotifications);
      setUnreadCount(unreadNotifications.length);
    });
    
    return () => {
      socket.disconnect();
    };
  }, [user.id]);

  // Handle notification click
  const handleNotificationClick = (notification) => {
    // Mark as read
    setUnreadCount(prev => Math.max(0, prev - 1));
    
    // In a real app, we would send this to the API
    // For this demo, just update the local state
    setNotifications(prev => 
      prev.map(n => 
        n.id === notification.id ? { ...n, read: true } : n
      )
    );
    
    // Handle navigation based on notification type
    if (notification.type === 'context_joined') {
      // Navigate to context
    }
  };

  return (
    <div className="flex h-screen">
      {/* Sidebar navigation */}
      <div className="fixed inset-y-0 left-0 z-40 hidden w-64 flex-shrink-0 flex-col bg-purple-800 lg:flex">
        <div className="flex h-20 items-center px-4">
          <h1 className="text-2xl font-bold text-white">Presence</h1>
        </div>
        
        <div className="flex flex-1 flex-col overflow-y-auto">
          <nav className="flex-1 space-y-1 px-2 py-4">
            <Link to="/dashboard" className="flex items-center rounded-md px-2 py-2 text-base font-medium text-white hover:bg-purple-700">
              <FontAwesomeIcon icon={faRadio} className="mr-4 h-6 w-6" />
              Discover
            </Link>
            
            <Link to="/dashboard/history" className="flex items-center rounded-md px-2 py-2 text-base font-medium text-white hover:bg-purple-700">
              <FontAwesomeIcon icon={faHistory} className="mr-4 h-6 w-6" />
              History
            </Link>
            
            <Link to="/dashboard/profile" className="flex items-center rounded-md px-2 py-2 text-base font-medium text-white hover:bg-purple-700">
              <FontAwesomeIcon icon={faUser} className="mr-4 h-6 w-6" />
              Profile
            </Link>
            
            <button 
              onClick={onLogout} 
              className="flex w-full items-center rounded-md px-2 py-2 text-base font-medium text-white hover:bg-purple-700"
            >
              <FontAwesomeIcon icon={faSignOutAlt} className="mr-4 h-6 w-6" />
              Logout
            </button>
          </nav>
        </div>
      </div>
      
      {/* Mobile header */}
      <div className="fixed inset-x-0 top-0 z-30 flex h-16 items-center justify-between bg-purple-800 px-4 lg:hidden">
        <h1 className="text-2xl font-bold text-white">Presence</h1>
        
        <div className="flex items-center">
          <button 
            className="mr-4 text-white"
            onClick={() => setShowNotifications(!showNotifications)}
          >
            <div className="relative">
              <FontAwesomeIcon icon={faBell} className="h-6 w-6" />
              {unreadCount > 0 && (
                <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-xs text-white">
                  {unreadCount}
                </span>
              )}
            </div>
          </button>
          
          {/* Mobile menu button */}
          <button className="text-white">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              className="h-6 w-6" 
              fill="none" 
              viewBox="0 0 24 24" 
              stroke="currentColor"
            >
              <path 
                strokeLinecap="round" 
                strokeLinejoin="round" 
                strokeWidth={2} 
                d="M4 6h16M4 12h16M4 18h16" 
              />
            </svg>
          </button>
        </div>
      </div>
      
      {/* Notification dropdown */}
      {showNotifications && (
        <div className="absolute right-4 top-16 z-50 w-80 rounded-md bg-white shadow-lg lg:right-8 lg:top-20">
          <div className="border-b border-gray-200 px-4 py-3">
            <h3 className="text-lg font-medium text-gray-900">Notifications</h3>
          </div>
          
          <div className="max-h-96 overflow-y-auto">
            {notifications.length > 0 ? (
              notifications.map(notification => (
                <div 
                  key={notification.id}
                  className={`border-b border-gray-200 px-4 py-3 hover:bg-gray-50 ${!notification.read ? 'bg-blue-50' : ''}`}
                  onClick={() => handleNotificationClick(notification)}
                >
                  <div className="flex justify-between">
                    <p className="font-medium text-gray-900">{notification.title}</p>
                    <p className="text-sm text-gray-500">
                      {new Date(notification.created_at).toLocaleTimeString()}
                    </p>
                  </div>
                  <p className="text-sm text-gray-600">{notification.body}</p>
                </div>
              ))
            ) : (
              <div className="px-4 py-6 text-center text-gray-500">
                No notifications
              </div>
            )}
          </div>
        </div>
      )}
      
      {/* Main content */}
      <div className="flex flex-1 flex-col lg:pl-64">
        <div className="flex-1 overflow-y-auto py-6 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <Routes>
              <Route path="/" element={<DiscoverPage user={user} />} />
              <Route path="/history" element={<HistoryPage user={user} />} />
              <Route path="/profile" element={<ProfilePage user={user} />} />
              <Route path="/context/:contextId" element={<ContextPage user={user} />} />
              <Route path="*" element={<Navigate to="/dashboard" replace />} />
            </Routes>
          </div>
        </div>
      </div>
    </div>
  );
}

// Discover Page
function DiscoverPage({ user }) {
  const [audioDetecting, setAudioDetecting] = useState(false);
  const [detectedContext, setDetectedContext] = useState(null);
  const [trendingContexts, setTrendingContexts] = useState([]);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    fetchTrendingContexts();
  }, []);

  // Fetch trending contexts
  const fetchTrendingContexts = async () => {
    try {
      const response = await axios.get(`${apiUrl}/context/contexts?sort=-usersCount&limit=10`);
      setTrendingContexts(response.data.contexts);
    } catch (error) {
      console.error('Error fetching trending contexts:', error);
    }
  };

  // Detect audio from microphone (simulated)
  const detectAudio = () => {
    setAudioDetecting(true);
    setError(null);
    setDetectedContext(null);
    
    // Simulate audio detection process
    setTimeout(() => {
      const simulateDetection = Math.random() > 0.3;
      
      if (simulateDetection) {
        // Successfully detected
        const mockContext = {
          id: `ctx_${Date.now()}`,
          name: getTrendingContextName(),
          type: getTrendingContextType(),
          users_count: Math.floor(Math.random() * 1000),
          created_at: new Date().toISOString()
        };
        
        setDetectedContext(mockContext);
        
        // In a real app, we would call the API to record this detection
      } else {
        // Failed to detect
        setError('No match found. Try again in a different location or with clearer audio.');
      }
      
      setAudioDetecting(false);
    }, 3000);
  };

  // Random context names for simulation
  const getTrendingContextName = () => {
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
  };

  // Random context types for simulation
  const getTrendingContextType = () => {
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
  };

  // Navigate to context page
  const viewContext = (contextId) => {
    navigate(`/dashboard/context/${contextId}`);
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900">Discover</h1>
      
      <div className="mt-6">
        {!detectedContext ? (
          <div className="mx-auto max-w-lg rounded-lg bg-white p-6 shadow-md">
            <h2 className="text-xl font-semibold text-gray-900">Detect what's playing</h2>
            <p className="mt-2 text-gray-600">
              Use your microphone to identify what's playing around you.
            </p>
            
            <button
              onClick={detectAudio}
              disabled={audioDetecting}
              className="mt-4 flex w-full items-center justify-center rounded-md bg-purple-600 px-4 py-3 font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-75"
            >
              {audioDetecting ? (
                <>
                  <svg className="mr-2 h-5 w-5 animate-spin text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Listening...
                </>
              ) : (
                <>
                  <FontAwesomeIcon icon={faRadio} className="mr-2 h-5 w-5" />
                  Detect Now
                </>
              )}
            </button>
            
            {error && (
              <div className="mt-4 rounded-md bg-red-50 p-4">
                <div className="text-sm text-red-700">{error}</div>
              </div>
            )}
          </div>
        ) : (
          <div className="mx-auto max-w-lg rounded-lg bg-white p-6 shadow-md">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-semibold text-green-600">Match Found!</h2>
              <div className="rounded-full bg-green-100 px-3 py-1 text-sm font-medium text-green-800">
                {detectedContext.type}
              </div>
            </div>
            
            <h3 className="mt-2 text-2xl font-bold text-gray-900">{detectedContext.name}</h3>
            
            <div className="mt-4 flex items-center text-gray-600">
              <FontAwesomeIcon icon={faUser} className="mr-2 h-5 w-5" />
              <span>{detectedContext.users_count} people here</span>
            </div>
            
            <div className="mt-6 flex space-x-4">
              <button
                onClick={() => viewContext(detectedContext.id)}
                className="flex-1 rounded-md bg-purple-600 px-4 py-2 font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
              >
                <FontAwesomeIcon icon={faComments} className="mr-2 h-5 w-5" />
                Join Chat
              </button>
              
              <button
                onClick={() => setDetectedContext(null)}
                className="flex-1 rounded-md bg-gray-200 px-4 py-2 font-medium text-gray-700 hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
              >
                Detect Something Else
              </button>
            </div>
          </div>
        )}
      </div>
      
      <div className="mt-10">
        <h2 className="text-xl font-bold text-gray-900">Trending Contexts</h2>
        
        <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {trendingContexts.map(context => (
            <div 
              key={context.id}
              className="overflow-hidden rounded-lg bg-white shadow transition-shadow hover:shadow-md"
              onClick={() => viewContext(context.id)}
            >
              <div className="p-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-lg font-medium text-gray-900">{context.name}</h3>
                  <div className="rounded-full bg-purple-100 px-3 py-1 text-xs font-medium text-purple-800">
                    {context.type}
                  </div>
                </div>
                
                <div className="mt-2 flex items-center text-sm text-gray-600">
                  <FontAwesomeIcon icon={faUser} className="mr-1 h-4 w-4" />
                  <span>{context.users_count} people</span>
                </div>
                
                <div className="mt-4">
                  <div className="text-right text-xs text-gray-500">
                    {new Date(context.created_at).toLocaleDateString()}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// History Page
function HistoryPage({ user }) {
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  // Load history on component mount
  useEffect(() => {
    fetchHistory();
  }, []);

  // Fetch user's detection history
  const fetchHistory = async () => {
    try {
      setLoading(true);
      // In a real app, we would fetch this from the API
      // For this demo, we'll use mock data
      
      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const mockHistory = Array(10).fill().map((_, i) => ({
        id: `ctx_${Date.now() - i * 10000000}`,
        name: getTrendingContextName(),
        type: getTrendingContextType(),
        timestamp: new Date(Date.now() - i * 3600000).toISOString(),
        users_count: Math.floor(Math.random() * 1000)
      }));
      
      setHistory(mockHistory);
    } catch (error) {
      console.error('Error fetching history:', error);
    } finally {
      setLoading(false);
    }
  };

  // Random context names for simulation
  const getTrendingContextName = () => {
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
  };

  // Random context types for simulation
  const getTrendingContextType = () => {
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
  };

  // Navigate to context
  const viewContext = (contextId) => {
    navigate(`/dashboard/context/${contextId}`);
  };

  // Clear history
  const clearHistory = () => {
    if (window.confirm('Are you sure you want to clear your history?')) {
      // In a real app, we would call the API
      setHistory([]);
    }
  };

  return (
    <div>
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Detection History</h1>
        
        {history.length > 0 && (
          <button
            onClick={clearHistory}
            className="rounded-md bg-red-100 px-4 py-2 text-sm font-medium text-red-700 hover:bg-red-200"
          >
            Clear History
          </button>
        )}
      </div>
      
      <div className="mt-6">
        {loading ? (
          <div className="flex justify-center py-12">
            <div className="loader"></div>
          </div>
        ) : history.length > 0 ? (
          <div className="overflow-hidden rounded-lg bg-white shadow">
            <ul className="divide-y divide-gray-200">
              {history.map(item => (
                <li 
                  key={item.id}
                  className="cursor-pointer hover:bg-gray-50"
                  onClick={() => viewContext(item.id)}
                >
                  <div className="px-4 py-4 sm:px-6">
                    <div className="flex items-center justify-between">
                      <div className="flex flex-1 flex-col md:flex-row md:items-center md:space-x-4">
                        <div>
                          <p className="truncate text-lg font-medium text-purple-600">{item.name}</p>
                          <div className="flex items-center text-sm text-gray-500">
                            <span className="truncate">{item.type}</span>
                            <span className="mx-1">•</span>
                            <span>{new Date(item.timestamp).toLocaleString()}</span>
                          </div>
                        </div>
                        
                        <div className="mt-2 flex md:mt-0">
                          <div className="flex items-center text-sm text-gray-500">
                            <FontAwesomeIcon icon={faUser} className="mr-1 h-4 w-4" />
                            <span>{item.users_count} people</span>
                          </div>
                        </div>
                      </div>
                      <div className="ml-2 flex flex-shrink-0 items-center">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                        </svg>
                      </div>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-lg bg-white py-12 shadow">
            <FontAwesomeIcon icon={faHistory} className="h-16 w-16 text-gray-300" />
            <h3 className="mt-4 text-lg font-medium text-gray-900">No detection history</h3>
            <p className="mt-1 text-gray-500">Your detected contexts will appear here</p>
            <button
              onClick={() => navigate('/dashboard')}
              className="mt-6 rounded-md bg-purple-600 px-4 py-2 font-medium text-white hover:bg-purple-700"
            >
              Detect Something
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// Profile Page
function ProfilePage({ user }) {
  const [profile, setProfile] = useState({
    displayName: user.username,
    email: user.email || '',
    bio: ''
  });
  const [editing, setEditing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Handle form input changes
  const handleChange = (e) => {
    const { name, value } = e.target;
    setProfile(prev => ({ ...prev, [name]: value }));
  };

  // Handle profile update
  const updateProfile = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');
    
    try {
      // In a real app, we would call the API
      // For this demo, we'll just simulate it
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Update successful
      setSuccess('Profile updated successfully');
      setEditing(false);
    } catch (error) {
      setError('Failed to update profile. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900">Profile</h1>
      
      <div className="mt-6 overflow-hidden rounded-lg bg-white shadow">
        <div className="px-4 py-5 sm:p-6">
          {success && (
            <div className="mb-4 rounded-md bg-green-50 p-4">
              <div className="text-sm text-green-700">{success}</div>
            </div>
          )}
          
          {error && (
            <div className="mb-4 rounded-md bg-red-50 p-4">
              <div className="text-sm text-red-700">{error}</div>
            </div>
          )}
          
          <div className="flex items-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-purple-600 text-xl font-bold text-white">
              {profile.displayName.charAt(0).toUpperCase()}
            </div>
            
            <div className="ml-4">
              <h2 className="text-xl font-medium text-gray-900">{profile.displayName}</h2>
              <p className="text-gray-600">{profile.email}</p>
            </div>
            
            <div className="ml-auto">
              <button
                onClick={() => setEditing(!editing)}
                className="rounded-md bg-purple-100 px-4 py-2 text-sm font-medium text-purple-700 hover:bg-purple-200"
              >
                {editing ? 'Cancel' : 'Edit Profile'}
              </button>
            </div>
          </div>
          
          {editing ? (
            <form onSubmit={updateProfile} className="mt-6">
              <div className="space-y-4">
                <div>
                  <label htmlFor="displayName" className="block text-sm font-medium text-gray-700">
                    Display Name
                  </label>
                  <input
                    type="text"
                    name="displayName"
                    id="displayName"
                    value={profile.displayName}
                    onChange={handleChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                  />
                </div>
                
                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                    Email
                  </label>
                  <input
                    type="email"
                    name="email"
                    id="email"
                    value={profile.email}
                    onChange={handleChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                  />
                </div>
                
                <div>
                  <label htmlFor="bio" className="block text-sm font-medium text-gray-700">
                    Bio
                  </label>
                  <textarea
                    name="bio"
                    id="bio"
                    rows="3"
                    value={profile.bio}
                    onChange={handleChange}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                  ></textarea>
                </div>
                
                <div className="flex justify-end">
                  <button
                    type="submit"
                    disabled={loading}
                    className="rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-75"
                  >
                    {loading ? 'Saving...' : 'Save Changes'}
                  </button>
                </div>
              </div>
            </form>
          ) : (
            <div className="mt-6">
              <h3 className="text-lg font-medium text-gray-900">Account Information</h3>
              
              <div className="mt-4 border-t border-gray-200 pt-4">
                <dl className="divide-y divide-gray-200">
                  <div className="flex justify-between py-3">
                    <dt className="text-sm font-medium text-gray-500">Username</dt>
                    <dd className="text-sm text-gray-900">{user.username}</dd>
                  </div>
                  
                  <div className="flex justify-between py-3">
                    <dt className="text-sm font-medium text-gray-500">Email</dt>
                    <dd className="text-sm text-gray-900">{profile.email || 'Not provided'}</dd>
                  </div>
                  
                  <div className="flex justify-between py-3">
                    <dt className="text-sm font-medium text-gray-500">Account Created</dt>
                    <dd className="text-sm text-gray-900">{new Date(user.created_at).toLocaleDateString()}</dd>
                  </div>
                </dl>
              </div>
              
              <div className="mt-6">
                <h3 className="text-lg font-medium text-gray-900">Settings</h3>
                
                <div className="mt-4 space-y-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-sm font-medium text-gray-900">Notifications</h4>
                      <p className="text-sm text-gray-500">Receive notifications about new matches</p>
                    </div>
                    <div className="relative flex items-center">
                      <input type="checkbox" className="h-6 w-11 rounded-full bg-gray-200" defaultChecked />
                    </div>
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-sm font-medium text-gray-900">Privacy</h4>
                      <p className="text-sm text-gray-500">Show your activity to other users</p>
                    </div>
                    <div className="relative flex items-center">
                      <input type="checkbox" className="h-6 w-11 rounded-full bg-gray-200" defaultChecked />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// Context Page with Chat
function ContextPage({ user }) {
  const { contextId } = useParams();
  const [context, setContext] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');
  const [socketConnected, setSocketConnected] = useState(false);
  const navigate = useNavigate();
  const socketRef = useRef(null);
  const messagesEndRef = useRef(null);

  // Load context data and connect to chat
  useEffect(() => {
    fetchContextData();
    connectToChat();
    
    return () => {
      // Disconnect socket when component unmounts
      if (socketRef.current) {
        socketRef.current.disconnect();
      }
    };
  }, [contextId]);

  // Scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Fetch context data
  const fetchContextData = async () => {
    try {
      setLoading(true);
      
      // In a real app, we would fetch this from the API
      // For this demo, we'll use mock data
      
      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const mockContext = {
        id: contextId,
        name: getTrendingContextName(),
        type: getTrendingContextType(),
        users_count: Math.floor(Math.random() * 1000),
        created_at: new Date().toISOString(),
        description: 'This is a sample context description that provides more information about what this context represents.'
      };
      
      setContext(mockContext);
      
      // Fetch messages
      const mockMessages = Array(10).fill().map((_, i) => ({
        id: `msg_${Date.now() - i * 10000}`,
        userId: i % 3 === 0 ? user.id : `user_${i}`,
        userName: i % 3 === 0 ? user.username : `User ${i}`,
        content: `This is message #${i + 1} in the chat room.`,
        createdAt: new Date(Date.now() - i * 60000).toISOString()
      }));
      
      setMessages(mockMessages.reverse());
    } catch (error) {
      console.error('Error fetching context:', error);
    } finally {
      setLoading(false);
    }
  };

  // Connect to chat service
  const connectToChat = () => {
    // In a real app, we would connect to the actual WebSocket
    // For this demo, we'll simulate it
    
    // Simulate connection establishment
    setTimeout(() => {
      setSocketConnected(true);
      
      // Simulate incoming messages
      const intervalId = setInterval(() => {
        if (Math.random() > 0.7) {
          const randomUserId = `user_${Math.floor(Math.random() * 10)}`;
          const newMessage = {
            id: `msg_${Date.now()}`,
            userId: randomUserId,
            userName: `User ${randomUserId.split('_')[1]}`,
            content: getRandomMessage(),
            createdAt: new Date().toISOString()
          };
          
          setMessages(prev => [...prev, newMessage]);
        }
      }, 10000);
      
      socketRef.current = {
        disconnect: () => clearInterval(intervalId)
      };
    }, 1500);
  };

  // Random context names for simulation
  const getTrendingContextName = () => {
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
  };

  // Random context types for simulation
  const getTrendingContextType = () => {
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
  };

  // Random messages for simulation
  const getRandomMessage = () => {
    const messages = [
      'This is amazing!',
      'I can\'t believe what just happened.',
      'Has anyone been to one of these before?',
      'First time watching, this is great.',
      'Who else is watching from home?',
      'The sound quality is incredible.',
      'What do you all think about this?',
      'I\'m so glad I found this.',
      'Anyone else having buffering issues?',
      'This is my favorite part coming up!'
    ];
    return messages[Math.floor(Math.random() * messages.length)];
  };

  // Send a message
  const sendMessage = (e) => {
    e.preventDefault();
    
    if (!message.trim() || !socketConnected) return;
    
    const newMessage = {
      id: `msg_${Date.now()}`,
      userId: user.id,
      userName: user.username,
      content: message.trim(),
      createdAt: new Date().toISOString()
    };
    
    setMessages(prev => [...prev, newMessage]);
    setMessage('');
    
    // In a real app, we would send this through WebSocket
  };

  // Return to discover page
  const goBack = () => {
    navigate('/dashboard');
  };

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="loader"></div>
      </div>
    );
  }

  return (
    <div className="h-full">
      <div className="flex items-center">
        <button
          onClick={goBack}
          className="mr-2 rounded-md text-gray-500 hover:text-gray-700"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
        </button>
        
        <h1 className="text-2xl font-bold text-gray-900">{context.name}</h1>
        
        <div className="ml-3 rounded-full bg-purple-100 px-3 py-1 text-sm font-medium text-purple-800">
          {context.type}
        </div>
      </div>
      
      <div className="mt-2 text-sm text-gray-500">
        <div className="flex items-center">
          <FontAwesomeIcon icon={faUser} className="mr-1 h-4 w-4" />
          <span>{context.users_count} people here</span>
          <span className="mx-2">•</span>
          <span>Created {new Date(context.created_at).toLocaleDateString()}</span>
        </div>
      </div>
      
      <div className="mt-4">{context.description}</div>
      
      <div className="mt-6 flex h-[calc(100vh-250px)] flex-col rounded-lg bg-white shadow">
        <div className="flex-1 overflow-y-auto px-4 py-4">
          {messages.map(msg => (
            <div 
              key={msg.id}
              className={`mb-4 flex ${msg.userId === user.id ? 'justify-end' : 'justify-start'}`}
            >
              <div 
                className={`max-w-3/4 rounded-lg px-4 py-2 ${
                  msg.userId === user.id 
                    ? 'rounded-br-none bg-purple-100 text-gray-900' 
                    : 'rounded-bl-none bg-gray-100 text-gray-900'
                }`}
              >
                {msg.userId !== user.id && (
                  <div className="mb-1 text-xs font-medium text-gray-500">{msg.userName}</div>
                )}
                <div>{msg.content}</div>
                <div className="mt-1 text-right text-xs text-gray-500">
                  {new Date(msg.createdAt).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                </div>
              </div>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>
        
        <div className="border-t border-gray-200 px-4 py-4">
          <form onSubmit={sendMessage} className="flex space-x-2">
            <input
              type="text"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Type a message..."
              className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
              disabled={!socketConnected}
            />
            <button
              type="submit"
              disabled={!message.trim() || !socketConnected}
              className="rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-75"
            >
              Send
            </button>
          </form>
          
          {!socketConnected && (
            <div className="mt-2 text-center text-sm text-gray-500">
              <svg className="mx-auto h-4 w-4 animate-spin text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <p>Connecting to chat...</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// Tailwind CSS for styling
// This would be in the App.css file
const styles = `
.loader {
  border: 4px solid rgba(0, 0, 0, 0.1);
  border-left-color: #6366f1;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
`;

export default App;
