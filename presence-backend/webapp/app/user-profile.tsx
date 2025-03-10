import React, { useState } from 'react';
import { User, Settings, Activity, Clock, Volume2, Bell, Shield, LogOut, MapPin, Edit, Upload } from 'lucide-react';

const UserProfile = () => {
  const [activeTab, setActiveTab] = useState('profile');
  const [user, setUser] = useState({
    name: 'Sarah Chen',
    username: '@sarahc',
    bio: 'Sound enthusiast. Always on the lookout for interesting audio experiences in the city.',
    location: 'New York, NY',
    joinDate: 'March 2025',
    avatar: '/api/placeholder/100/100',
    stats: {
      recordings: 24,
      followers: 156,
      following: 87
    }
  });
  
  const [recentActivity, setRecentActivity] = useState([
    { 
      id: 1, 
      type: 'recording', 
      title: 'Street Musician on Broadway', 
      timestamp: '2 hours ago',
      stats: { views: 43, likes: 12 }
    },
    { 
      id: 2, 
      type: 'comment', 
      title: 'Commented on "Central Park Dawn Chorus"', 
      timestamp: 'Yesterday',
      stats: { likes: 3 }
    },
    { 
      id: 3, 
      type: 'listening', 
      title: 'Jazz at Lincoln Center', 
      timestamp: '2 days ago'
    }
  ]);

  const [notificationSettings, setNotificationSettings] = useState({
    newFollowers: true,
    comments: true,
    likes: true,
    nearbyEvents: true,
    appUpdates: false
  });

  const [privacySettings, setPrivacySettings] = useState({
    publicProfile: true,
    showLocation: true,
    shareActivity: true
  });

  const toggleNotificationSetting = (setting) => {
    setNotificationSettings({
      ...notificationSettings,
      [setting]: !notificationSettings[setting]
    });
  };

  const togglePrivacySetting = (setting) => {
    setPrivacySettings({
      ...privacySettings,
      [setting]: !privacySettings[setting]
    });
  };

  return (
    <div className="max-w-3xl mx-auto bg-gray-50 min-h-screen">
      {/* Profile Header */}
      <div className="bg-white shadow rounded-lg overflow-hidden mb-4">
        <div className="h-32 bg-gradient-to-r from-blue-500 to-purple-600"></div>
        <div className="px-4 pb-4 relative">
          <div className="flex items-end -mt-16 mb-4">
            <div className="h-24 w-24 rounded-full border-4 border-white bg-white overflow-hidden">
              <img src={user.avatar} alt={user.name} className="h-full w-full object-cover" />
            </div>
            <button className="absolute bottom-4 right-4 bg-blue-600 text-white rounded-full p-2">
              <Edit className="h-5 w-5" />
            </button>
          </div>
          
          <div>
            <h2 className="text-2xl font-bold text-gray-900">{user.name}</h2>
            <p className="text-gray-600">{user.username}</p>
            
            <div className="flex items-center text-sm text-gray-600 mt-1">
              <MapPin className="h-4 w-4 mr-1" />
              <span>{user.location}</span>
            </div>
            
            <p className="mt-3 text-gray-700">{user.bio}</p>
            
            <div className="flex items-center text-sm text-gray-500 mt-2">
              <Clock className="h-4 w-4 mr-1" />
              <span>Joined {user.joinDate}</span>
            </div>
            
            <div className="flex justify-between mt-4 pt-4 border-t border-gray-100">
              <div className="text-center">
                <div className="font-bold text-gray-900">{user.stats.recordings}</div>
                <div className="text-xs text-gray-500">Recordings</div>
              </div>
              <div className="text-center">
                <div className="font-bold text-gray-900">{user.stats.followers}</div>
                <div className="text-xs text-gray-500">Followers</div>
              </div>
              <div className="text-center">
                <div className="font-bold text-gray-900">{user.stats.following}</div>
                <div className="text-xs text-gray-500">Following</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Tab Navigation */}
      <div className="bg-white shadow rounded-lg overflow-hidden mb-4">
        <div className="flex border-b border-gray-200">
          <button 
            className={`flex-1 py-3 font-medium text-sm ${activeTab === 'profile' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-gray-600'}`}
            onClick={() => setActiveTab('profile')}
          >
            <User className="h-4 w-4 inline-block mr-1" />
            Profile
          </button>
          <button 
            className={`flex-1 py-3 font-medium text-sm ${activeTab === 'activity' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-gray-600'}`}
            onClick={() => setActiveTab('activity')}
          >
            <Activity className="h-4 w-4 inline-block mr-1" />
            Activity
          </button>
          <button 
            className={`flex-1 py-3 font-medium text-sm ${activeTab === 'settings' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-gray-600'}`}
            onClick={() => setActiveTab('settings')}
          >
            <Settings className="h-4 w-4 inline-block mr-1" />
            Settings
          </button>
        </div>
        
        {/* Tab Content */}
        <div className="p-4">
          {activeTab === 'profile' && (
            <div>
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Your Recordings</h3>
                <div className="grid grid-cols-2 gap-3">
                  {[1, 2, 3, 4].map(item => (
                    <div key={item} className="bg-gray-100 rounded-lg p-3">
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center">
                          <Volume2 className="h-5 w-5 text-blue-600 mr-2" />
                          <span className="text-xs text-gray-500">2:45</span>
                        </div>
                        <span className="text-xs text-gray-500">3 days ago</span>
                      </div>
                      <h4 className="font-medium text-gray-900 mb-1">Street Performance #{item}</h4>
                      <p className="text-xs text-gray-600">Saxophone player at Washington Square</p>
                    </div>
                  ))}
                </div>
                <button className="mt-3 w-full py-2 text-sm text-blue-600 border border-blue-600 rounded-lg">
                  View All Recordings
                </button>
              </div>
              
              <div>
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Recently Followed</h3>
                <div className="space-y-3">
                  {[1, 2, 3].map(item => (
                    <div key={item} className="flex items-center justify-between">
                      <div className="flex items-center">
                        <div className="h-10 w-10 rounded-full bg-gray-300 mr-3">
                          <img src={`/api/placeholder/40/40`} alt="User avatar" className="h-full w-full object-cover rounded-full" />
                        </div>
                        <div>
                          <h4 className="font-medium text-gray-900">User Name #{item}</h4>
                          <p className="text-xs text-gray-600">@username{item}</p>
                        </div>
                      </div>
                      <button className="text-xs bg-gray-100 hover:bg-gray-200 text-gray-800 py-1 px-3 rounded-full">
                        Following
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
          
          {activeTab === 'activity' && (
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3">Recent Activity</h3>
              <div className="space-y-4">
                {recentActivity.map(activity => (
                  <div key={activity.id} className="border-b border-gray-100 pb-4 last:border-0">
                    <div className="flex items-start">
                      <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center mr-3">
                        {activity.type === 'recording' && <Volume2 className="h-4 w-4 text-blue-600" />}
                        {activity.type === 'comment' && <MessageCircle className="h-4 w-4 text-blue-600" />}
                        {activity.type === 'listening' && <Headphones className="h-4 w-4 text-blue-600" />}
                      </div>
                      <div className="flex-1">
                        <h4 className="font-medium text-gray-900">{activity.title}</h4>
                        <p className="text-xs text-gray-500 mt-1">{activity.timestamp}</p>
                        
                        {activity.stats && (
                          <div className="flex items-center mt-2 space-x-3">
                            {activity.stats.views && (
                              <span className="text-xs text-gray-600">
                                {activity.stats.views} views
                              </span>
                            )}
                            {activity.stats.likes && (
                              <span className="text-xs text-gray-600">
                                {activity.stats.likes} likes
                              </span>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
          
          {activeTab === 'settings' && (
            <div>
              {/* Notification Settings */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Notification Settings</h3>
                <div className="space-y-3">
                  {Object.entries(notificationSettings).map(([key, value]) => (
                    <div key={key} className="flex items-center justify-between">
                      <div>
                        <h4 className="font-medium text-gray-900">
                          {key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase())}
                        </h4>
                        <p className="text-xs text-gray-600">
                          {key === 'newFollowers' && 'Get notified when someone follows you'}
                          {key === 'comments' && 'Get notified when someone comments on your recordings'}
                          {key === 'likes' && 'Get notified when someone likes your recordings'}
                          {key === 'nearbyEvents' && 'Get notified about audio events near you'}
                          {key === 'appUpdates' && 'Get updates about new features'}
                        </p>
                      </div>
                      <button
                        className={`w-12 h-6 rounded-full flex items-center transition-colors duration-300 focus:outline-none ${
                          value ? 'bg-blue-600 justify-end' : 'bg-gray-300 justify-start'
                        }`}
                        onClick={() => toggleNotificationSetting(key)}
                      >
                        <span className="w-5 h-5 rounded-full bg-white shadow-md transform translate-x-0.5"></span>
                      </button>
                    </div>
                  ))}
                </div>
              </div>
              
              {/* Privacy Settings */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Privacy Settings</h3>
                <div className="space-y-3">
                  {Object.entries(privacySettings).map(([key, value]) => (
                    <div key={key} className="flex items-center justify-between">
                      <div>
                        <h4 className="font-medium text-gray-900">
                          {key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase())}
                        </h4>
                        <p className="text-xs text-gray-600">
                          {key === 'publicProfile' && 'Allow others to view your profile'}
                          {key === 'showLocation' && 'Show your location when recording audio events'}
                          {key === 'shareActivity' && 'Share your activity with followers'}
                        </p>
                      </div>
                      <button
                        className={`w-12 h-6 rounded-full flex items-center transition-colors duration-300 focus:outline-none ${
                          value ? 'bg-blue-600 justify-end' : 'bg-gray-300 justify-start'
                        }`}
                        onClick={() => togglePrivacySetting(key)}
                      >
                        <span className="w-5 h-5 rounded-full bg-white shadow-md transform translate-x-0.5"></span>
                      </button>
                    </div>
                  ))}
                </div>
              </div>
              
              {/* Other options */}
              <div>
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Account</h3>
                <div className="space-y-2">
                  <button className="flex items-center w-full p-3 text-left text-gray-700 rounded-lg hover:bg-gray-100">
                    <Upload className="h-5 w-5 mr-3 text-gray-500" />
                    <span>Change Profile Picture</span>
                  </button>
                  <button className="flex items-center w-full p-3 text-left text-gray-700 rounded-lg hover:bg-gray-100">
                    <Shield className="h-5 w-5 mr-3 text-gray-500" />
                    <span>Security Settings</span>
                  </button>
                  <button className="flex items-center w-full p-3 text-left text-red-600 rounded-lg hover:bg-red-50">
                    <LogOut className="h-5 w-5 mr-3" />
                    <span>Log Out</span>
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default UserProfile;
