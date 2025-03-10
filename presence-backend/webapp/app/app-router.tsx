import React, { useState } from 'react';
import { Home, Search, Plus, Bell, User, Volume2 } from 'lucide-react';

// Import our components
import AudioRecorder from './AudioRecorder';
import SocialFeed from './SocialFeed';
import EventExplorer from './EventExplorer';
import UserProfile from './UserProfile';

const AppRouter = () => {
  const [currentRoute, setCurrentRoute] = useState('home');
  const [showRecorder, setShowRecorder] = useState(false);

  // Navigation items for the bottom bar
  const navItems = [
    { id: 'home', label: 'Home', icon: Home },
    { id: 'discover', label: 'Discover', icon: Search },
    { id: 'record', label: '', icon: Plus },
    { id: 'notifications', label: 'Alerts', icon: Bell },
    { id: 'profile', label: 'Profile', icon: User }
  ];

  const handleNavigation = (route) => {
    if (route === 'record') {
      setShowRecorder(true);
    } else {
      setCurrentRoute(route);
      setShowRecorder(false);
    }
  };

  const closeRecorder = () => {
    setShowRecorder(false);
  };

  // Render the appropriate component based on the current route
  const renderContent = () => {
    if (showRecorder) {
      return <AudioRecorder onClose={closeRecorder} />;
    }

    switch (currentRoute) {
      case 'home':
        return <SocialFeed />;
      case 'discover':
        return <EventExplorer />;
      case 'notifications':
        return (
          <div className="p-4 max-w-2xl mx-auto">
            <div className="bg-white shadow rounded-lg overflow-hidden">
              <div className="p-4 border-b border-gray-200">
                <h2 className="text-xl font-semibold text-gray-800">Notifications</h2>
              </div>
              <div className="p-4">
                <div className="flex flex-col items-center justify-center py-8">
                  <Bell className="h-12 w-12 text-gray-300 mb-4" />
                  <p className="text-gray-500 text-center">You have no new notifications</p>
                  <p className="text-gray-400 text-sm text-center mt-2">
                    Alerts about audio events and activity will appear here
                  </p>
                </div>
              </div>
            </div>
          </div>
        );
      case 'profile':
        return <UserProfile />;
      default:
        return <SocialFeed />;
    }
  };

  return (
    <div className="flex flex-col h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 px-4 py-3 flex justify-between items-center">
        <div className="flex items-center">
          <Volume2 className="text-blue-600 h-8 w-8" />
          <h1 className="text-xl font-bold ml-2 text-gray-900">SoundSpot</h1>
        </div>
        
        <div className="hidden md:flex items-center space-x-4">
          <div className="relative">
            <input
              type="text"
              placeholder="Search audio events..."
              className="py-2 px-4 pr-10 border border-gray-300 rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-64"
            />
            <Search className="absolute right-3 top-2 h-5 w-5 text-gray-400" />
          </div>
        </div>
        
        <div className="flex items-center">
          <Bell className="h-6 w-6 text-gray-500 mr-2" />
          <div className="h-8 w-8 rounded-full bg-gray-300 overflow-hidden">
            <img src="/api/placeholder/32/32" alt="User avatar" className="h-full w-full object-cover" />
          </div>
        </div>
      </header>
      
      {/* Main Content */}
      <main className="flex-1 overflow-y-auto">
        {renderContent()}
      </main>
      
      {/* Bottom Navigation */}
      <nav className="bg-white border-t border-gray-200 flex justify-around">
        {navItems.map(item => (
          <button 
            key={item.id}
            className={`flex flex-col items-center py-3 px-6 ${
              currentRoute === item.id && item.id !== 'record' ? 'text-blue-600' : 'text-gray-500'
            } ${item.id === 'record' ? 'relative -mt-5' : ''}`}
            onClick={() => handleNavigation(item.id)}
          >
            {item.id === 'record' ? (
              <div className="h-14 w-14 rounded-full bg-blue-600 flex items-center justify-center shadow-lg">
                <item.icon className="h-7 w-7 text-white" />
              </div>
            ) : (
              <>
                <item.icon className="h-6 w-6" />
                <span className="text-xs mt-1">{item.label}</span>
              </>
            )}
          </button>
        ))}
      </nav>
      
      {/* Modal for the recorder */}
      {showRecorder && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg w-full max-w-xl max-h-screen overflow-y-auto">
            <div className="p-4 flex justify-between border-b border-gray-200">
              <h2 className="text-xl font-semibold">Record Audio Event</h2>
              <button onClick={closeRecorder} className="text-gray-500 hover:text-gray-700">
                &times;
              </button>
            </div>
            <AudioRecorder onClose={closeRecorder} />
          </div>
        </div>
      )}
    </div>
  );
};

export default AppRouter;
